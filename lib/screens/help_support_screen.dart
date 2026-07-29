import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/ai_service.dart'; // Ensure this path correctly imports your latest AiService

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      "sender": "ai",
      "text":
          "Hello! I am your NannyApp Assistant. How can I help you today? You can ask me about booking, cancellations, or updates! 🤖",
    },
  ];
  bool _isTyping = false;

  void _handleSend() async {
    if (_controller.text.trim().isEmpty) return;
    String userText = _controller.text.trim();
    _controller.clear();

    // 1. Immediately render the user's message to the bubble
    setState(() {
      _messages.add({"sender": "user", "text": userText});
      _isTyping = true;
    });

    // 2. Highlight fix: Call our latest refactored method containing Groq + Web intelligent anti-disconnection engine!
    String aiReply = await AiService().getHelpResponse(userText);

    // 3. Simulate a small typewriter real delay
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _messages.add({"sender": "ai", "text": aiReply});
        _isTyping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.dark),
        title: const Text(
          "Help & Support",
          style: TextStyle(
            color: AppColors.dark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Chat bubble list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                var msg = _messages[index];
                bool isMe = msg['sender'] == 'user';
                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primary : AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: TextStyle(
                        color: isMe ? Colors.white : AppColors.dark,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Typing indicator
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.only(left: 20, bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Assistant is typing...",
                  style: TextStyle(color: AppColors.gray, fontSize: 12),
                ),
              ),
            ),

          // Bottom input box
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.lightGray,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: "Ask a question...",
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _handleSend,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
