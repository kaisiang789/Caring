import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  static const String _groqApiKey =
      "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";
  static const String _groqUrl =
      "https://api.groq.com/openai/v1/chat/completions";
  static const String _groqModel = "llama-3.1-8b-instant";

  /// Concise matching algorithm: Adds 1 point per fulfilled criteria to pick the optimal match.
  Future<Map<String, String>> getMatchByChat(
    List<Map<String, dynamic>> cloudNannies,
    String userMessage,
  ) async {
    if (cloudNannies.isEmpty) {
      return {
        "uid": "",
        "reason": "There are currently no registered Nannies in the database.",
      };
    }

    // 1. Natural Language Intent Extraction via LLM
    final prompt =
        '''
You are a professional feature extraction agent for a caregiving system.
Analyze the Parent's caregiving request and extract their key intentions into a strict JSON object.

[PARENT USER REQUIREMENT]
"$userMessage"

[STRICT OUTPUT FORMAT JSON]
{
  "price_preference": "low" | "high" | "none",   // "low" for cheap/budget, "high" for expensive
  "rating_preference": "low" | "high" | "none",  // "low" for low rating, "high" for top rated
  "location_keyword": "extracted city or area name or none",
  "tags": ["cooking", "baby care", "infants", etc] // extract any child care skills or tags mentioned
}
Respond with the JSON object ONLY. No markdown, no backticks, no prose.
''';

    String pricePref = "none";
    String ratingPref = "none";
    String locKeyword = "none";
    List<String> requiredTags = [];

    try {
      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          "Authorization": "Bearer $_groqApiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": _groqModel,
          "messages": [
            {"role": "user", "content": prompt},
          ],
          "temperature": 0.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String reply = (data['choices'][0]['message']['content'] ?? "")
            .toString()
            .trim();
        reply = reply.replaceAll("```json", "").replaceAll("```", "").trim();
        final Map<String, dynamic> parsedIntent = jsonDecode(reply);

        pricePref = parsedIntent['price_preference'] ?? "none";
        ratingPref = parsedIntent['rating_preference'] ?? "none";
        locKeyword = (parsedIntent['location_keyword'] ?? "none")
            .toString()
            .toLowerCase();

        if (parsedIntent['tags'] != null) {
          requiredTags = List<String>.from(parsedIntent['tags'])
              .map((t) => t.toLowerCase().trim())
              .where((t) => t.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      debugPrint("Groq Intent Extraction fallback: $e");
      String lowerMsg = userMessage.toLowerCase();
      if (lowerMsg.contains("low price") || lowerMsg.contains("cheap"))
        pricePref = "low";
      if (lowerMsg.contains("low rating") || lowerMsg.contains("bad rating"))
        ratingPref = "low";
      if (lowerMsg.contains("cooking")) requiredTags.add("cooking");
      if (lowerMsg.contains("baby")) requiredTags.add("baby care");
    }

    // Local fallback parsing for edge cases
    String lowerMsg = userMessage.toLowerCase();
    if (lowerMsg.contains("low rating") || lowerMsg.contains("low star")) {
      ratingPref = "low";
    }

    // =========================================================================
    // 2. Incremental Scoring Engine (Base score = 0, +1 per fulfilled condition)
    // =========================================================================
    List<Map<String, dynamic>> scoringPool = List.from(cloudNannies);
    Map<String, double> nannyScores = {};

    for (var nanny in scoringPool) {
      double score = 0.0; // Base score starts at 0
      final String nannyName = (nanny['name'] ?? '').toString().toLowerCase();
      final String nannyLoc = (nanny['location'] ?? nanny['address'] ?? '')
          .toString()
          .toLowerCase();

      // Consolidate all nanny tags including Custom Add-ons
      List<String> nannyTags = (nanny['tags'] as List<dynamic>? ?? [])
          .map((t) => t.toString().toLowerCase().trim())
          .toList();

      if (nanny['custom_addons_list'] != null) {
        for (var item in (nanny['custom_addons_list'] as List)) {
          if (item is Map && item['name'] != null) {
            nannyTags.add(item['name'].toString().toLowerCase().trim());
          }
        }
      }

      final double nannyRate =
          double.tryParse(nanny['hourly_rate']?.toString() ?? '25') ?? 25.0;
      final double nannyRating =
          double.tryParse(nanny['rating']?.toString() ?? '5.0') ?? 5.0;

      // Rule 1: Skill Tag Match (+1 point per matched tag)
      for (var reqTag in requiredTags) {
        bool isMatched = false;

        for (var nTag in nannyTags) {
          if (nTag.contains(reqTag) || reqTag.contains(nTag)) {
            isMatched = true;
            break;
          }
          // Synonym matching (Baby / Infant / Newborn)
          if ((reqTag.contains("baby") || reqTag.contains("infant")) &&
              (nTag.contains("newborn") ||
                  nTag.contains("baby") ||
                  nTag.contains("infant"))) {
            isMatched = true;
            break;
          }
        }

        if (isMatched || nannyName.contains(reqTag)) {
          score += 1.0; // +1 point for matching skill
        }
      }

      // Rule 2: Proximity Location Match (+1 point)
      if (locKeyword != "none" &&
          locKeyword.isNotEmpty &&
          nannyLoc.contains(locKeyword)) {
        score += 1.0; // +1 point for matching location
      }

      // Rule 3: Price Preference Match (+1 point)
      if (pricePref == "low" && nannyRate <= 25.0) {
        score += 1.0; // +1 point for low rate budget criteria
      } else if (pricePref == "high" && nannyRate > 25.0) {
        score += 1.0; // +1 point for premium caregiver criteria
      }

      // Rule 4: Rating Preference Match (+1 point)
      if (ratingPref == "low" && nannyRating < 4.0) {
        score += 1.0; // +1 point for low rating filter criteria
      } else if (ratingPref == "high" && nannyRating >= 4.5) {
        score += 1.0; // +1 point for high rating filter criteria
      }

      nannyScores[nanny['uid'] ?? ''] = score;
    }

    // Sort by composite points in descending order
    scoringPool.sort((a, b) {
      double scoreA = nannyScores[a['uid']] ?? 0.0;
      double scoreB = nannyScores[b['uid']] ?? 0.0;
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      } else {
        // Tie-breaker mechanism based on actual rating
        double ratingA =
            double.tryParse(a['rating']?.toString() ?? '5.0') ?? 5.0;
        double ratingB =
            double.tryParse(b['rating']?.toString() ?? '5.0') ?? 5.0;
        return ratingPref == "low"
            ? ratingA.compareTo(ratingB)
            : ratingB.compareTo(ratingA);
      }
    });

    var topMatchNanny = scoringPool.first;
    String finalUid = topMatchNanny['uid'] ?? '';
    String finalName = topMatchNanny['name'] ?? 'Caregiver';
    int maxMatchedCount = (nannyScores[finalUid] ?? 0.0).toInt();

    // Dynamically build summary analytics report
    String generatedReason =
        "We found the best match: $finalName ($maxMatchedCount requirement(s) perfectly matched). ";
    if (requiredTags.isNotEmpty) {
      generatedReason +=
          "Matched skill criteria (${requiredTags.join(', ')}). ";
    }
    if (ratingPref == "low") {
      generatedReason += "Selected based on low-rating filter preference. ";
    } else if (pricePref == "low") {
      generatedReason += "Fits budget preference. ";
    }

    return {"uid": finalUid, "reason": generatedReason};
  }

  // =========================================================================
  // 3. Groq Help & Support Assistant (Dual-Role Operations)
  // =========================================================================
  Future<String> getHelpResponse(
    String userQuestion, {
    bool isNannyMode = false,
  }) async {
    final roleTitle = isNannyMode ? "Caregiver (Nanny)" : "Client Parent";

    final prompt =
        '''
You are the official AI Support Assistant inside NannyApp responding to a $roleTitle.
Help the user answer their question politely, accurately, and professionally in English. Keep the answer concise (within 3 sentences).

[PLATFORM KNOWLEDGE BASE]
${isNannyMode ? '''
- To accept/decline jobs: Go to 'Home' or 'Bookings' tab -> Click 'Accept' or 'Decline' on job requests.
- To complete a job: Go to 'Bookings' -> Click 'Submit For Verification' once service is done.
- To set rates & extra services: Go to 'Me' -> 'Account Settings' -> Edit Base Rate, Holiday Charge, and Custom Add-on Services.
- To manage availability: Toggle the 'Online / Offline' switch on the Home Screen.
- Payouts & Earnings: Total verified earnings are updated after Parent clicks 'Confirm Payout'.
''' : '''
- To book a caregiver: Go to 'Search' or 'Home' -> View Nanny Profile -> Click 'Book Now' -> Pick Date & Time.
- Live tracking: Go to 'Bookings' -> Click 'Live Tracking' for ongoing active jobs.
- Payout & Reviews: Go to 'Bookings' -> Click 'Confirm Payout & Rate Caregiver' after service completion. You can also edit your review anytime under Completed bookings.
- Preferences: Go to 'Me' -> 'Set Preferences' to customize matching tags.
'''}

Question asked by $roleTitle: "$userQuestion"
Answer:
''';

    try {
      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          "Authorization": "Bearer $_groqApiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": _groqModel,
          "messages": [
            {"role": "user", "content": prompt},
          ],
          "temperature": 0.3,
          "max_tokens": 250,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content']?.toString().trim() ??
            "How else can I assist you with today?";
      }
      return "Thank you for reaching out. Our support desk has logged your ticket and will follow up shortly.";
    } catch (e) {
      return "I've received your request regarding '$userQuestion'. Our team will guide you through this shortly.";
    }
  }
}
