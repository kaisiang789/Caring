import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'core/theme.dart';
import 'screens/parent_home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/me_screen.dart';
import 'screens/nanny_home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const NannyApp());
}

class NannyApp extends StatelessWidget {
  const NannyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nanny App',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
      ),
      home: StreamBuilder<User?>(
        stream: AuthService().userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) return const MainLayout();
          return const LoginScreen();
        },
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  bool _isNannyMode = false;
  List<String> _globalPreferences = ["Non-smoking", "Cooking"];

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  void _fetchUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (doc.exists && doc.data() != null) {
          if (mounted) {
            setState(() {
              _isNannyMode = doc.data()!['role'] == 'Nanny';
            });
          }
        }
      } catch (e) {
        debugPrint("Failed to get user identity: $e");
      }
    }
  }

  void _toggleRole() {
    // Keep empty method aligned to prevent compilation errors
  }

  void _updatePreferences(List<String> newPrefs) {
    setState(() => _globalPreferences = newPrefs);
  }

  List<Widget> get _screens {
    List<Widget> screens = [
      _isNannyMode
          ? const NannyHomeScreen()
          : ParentHomeScreen(
              onNavigateToSearch: () => setState(() => _currentIndex = 1),
            ),
    ];
    if (!_isNannyMode) {
      screens.add(SearchScreen(userPreferences: _globalPreferences));
    }
    screens.addAll([
      const MessagesScreen(),
      BookingsScreen(isNannyMode: _isNannyMode),
      MeScreen(
        isNannyMode: _isNannyMode,
        onToggleRole: _toggleRole,
        userPreferences: _globalPreferences,
        onUpdatePreferences: _updatePreferences,
      ),
    ]);
    return screens;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.idTokenChanges(),
      builder: (context, authSnapshot) {
        final String currentUid =
            authSnapshot.data?.uid ??
            FirebaseAuth.instance.currentUser?.uid ??
            '';

        if (currentUid.isEmpty) {
          return Scaffold(body: SafeArea(child: _screens[_currentIndex]));
        }

        return Scaffold(
          body: SafeArea(child: _screens[_currentIndex]),
          bottomNavigationBar: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: currentUid)
                .snapshots(),
            builder: (context, snapshot) {
              bool globalHasUnread = false;
              if (snapshot.hasData && snapshot.data != null) {
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  bool isRoomUnread = data['unread_$currentUid'] ?? false;
                  if (isRoomUnread) {
                    globalHasUnread = true;
                    break;
                  }
                }
              }

              return BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                type: BottomNavigationBarType.fixed,
                backgroundColor: AppColors.white,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: const Color(0xFF94A3B8),
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  if (!_isNannyMode)
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.search_outlined),
                      activeIcon: Icon(Icons.search),
                      label: 'Search',
                    ),
                  BottomNavigationBarItem(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.chat_bubble_outline),
                        if (globalHasUnread)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(1),
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 10,
                                minHeight: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    activeIcon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.chat_bubble),
                        if (globalHasUnread)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(1),
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 10,
                                minHeight: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    label: 'Chat',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_today_outlined),
                    activeIcon: Icon(Icons.calendar_today),
                    label: 'Bookings',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Me',
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
