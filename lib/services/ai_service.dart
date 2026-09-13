import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  // ✅ Active Groq API Key
  static const String _groqApiKey = "YOUR_GROQ_API_KEY_HERE";
  static const String _groqUrl =
      "https://api.groq.com/openai/v1/chat/completions";
  // ✅ Active, valid model
  static const String _groqModel = "llama3-8b-8192";

  /// Multi-Dimensional AI Matcher Engine (Skills + Price + Rating)
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

    String lowerMsg = userMessage.toLowerCase().trim();
    List<String> requiredTags = [];
    String pricePref = "none";

    // 1. Instant local keyword & price extraction
    if (lowerMsg.contains("cook")) requiredTags.add("cooking");
    if (lowerMsg.contains("baby") ||
        lowerMsg.contains("infant") ||
        lowerMsg.contains("newborn")) {
      requiredTags.add("baby");
    }
    if (lowerMsg.contains("pet") ||
        lowerMsg.contains("dog") ||
        lowerMsg.contains("cat")) {
      requiredTags.add("pet");
    }
    if (lowerMsg.contains("first aid") || lowerMsg.contains("first-aid")) {
      requiredTags.add("first-aid");
    }

    if (lowerMsg.contains("high price") ||
        lowerMsg.contains("expensive") ||
        lowerMsg.contains("high budget") ||
        lowerMsg.contains("premium")) {
      pricePref = "high";
    } else if (lowerMsg.contains("low price") ||
        lowerMsg.contains("cheap") ||
        lowerMsg.contains("low budget") ||
        lowerMsg.contains("affordable")) {
      pricePref = "low";
    }

    // 2. Groq AI Intent Parsing
    final prompt =
        '''
Extract user requirements from this text: "$userMessage"
Return JSON ONLY with format:
{"tags": ["cooking", "newborn", "pet"], "price": "low"|"high"|"normal"}
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
          "temperature": 0.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String reply = (data['choices'][0]['message']['content'] ?? "")
            .toString()
            .trim();
        reply = reply.replaceAll("```json", "").replaceAll("```", "").trim();
        final Map<String, dynamic> parsed = jsonDecode(reply);

        if (parsed['tags'] != null) {
          for (var t in (parsed['tags'] as List)) {
            String tagStr = t.toString().toLowerCase().trim();
            if (tagStr.isNotEmpty && !requiredTags.contains(tagStr)) {
              requiredTags.add(tagStr);
            }
          }
        }
        if (parsed['price'] != null && pricePref == "none") {
          String p = parsed['price'].toString().toLowerCase();
          if (p == "high" || p == "low") pricePref = p;
        }
      }
    } catch (e) {
      debugPrint("Groq extraction debug: $e");
    }

    // 3. Multi-Dimensional Scoring
    List<Map<String, dynamic>> scoringPool = List.from(cloudNannies);
    Map<String, double> nannyScores = {};
    Map<String, int> nannyMatchedTagCount = {};

    for (var nanny in scoringPool) {
      double score = 0.0;
      int matchedCount = 0;

      List<String> nannySkills = [];
      if (nanny['tags'] is List) {
        nannySkills.addAll(
          (nanny['tags'] as List).map((e) => e.toString().toLowerCase().trim()),
        );
      }
      if (nanny['skills'] is List) {
        nannySkills.addAll(
          (nanny['skills'] as List).map(
            (e) => e.toString().toLowerCase().trim(),
          ),
        );
      }
      if (nanny['custom_addons_list'] is List) {
        for (var item in (nanny['custom_addons_list'] as List)) {
          if (item is Map && item['name'] != null) {
            nannySkills.add(item['name'].toString().toLowerCase().trim());
          }
        }
      }

      String aboutBio = (nanny['about'] ?? nanny['bio'] ?? '')
          .toString()
          .toLowerCase();
      String nannyName = (nanny['name'] ?? '').toString().toLowerCase();

      // Skill match (+1000 pts per skill)
      for (var req in requiredTags) {
        bool hasMatched = false;
        for (var skill in nannySkills) {
          if (skill.contains(req) ||
              req.contains(skill) ||
              (req == "cooking" &&
                  (skill.contains("cook") ||
                      skill.contains("meal") ||
                      skill.contains("烹饪")))) {
            hasMatched = true;
            break;
          }
        }
        if (hasMatched || aboutBio.contains(req) || nannyName.contains(req)) {
          score += 1000.0;
          matchedCount++;
        }
      }

      final double nannyRate =
          double.tryParse(nanny['hourly_rate']?.toString() ?? '25') ?? 25.0;
      final double nannyRating =
          double.tryParse(nanny['rating']?.toString() ?? '5.0') ?? 5.0;

      // Price weighting
      if (pricePref == "high") {
        score += (nannyRate * 3.0);
      } else if (pricePref == "low") {
        score += ((100.0 - nannyRate).clamp(0.0, 100.0) * 1.5);
      }

      // Rating weighting
      score += (nannyRating * 5.0);

      nannyScores[nanny['uid'] ?? ''] = score;
      nannyMatchedTagCount[nanny['uid'] ?? ''] = matchedCount;
    }

    // Sort descending by calculated score
    scoringPool.sort((a, b) {
      double scoreA = nannyScores[a['uid']] ?? 0.0;
      double scoreB = nannyScores[b['uid']] ?? 0.0;
      return scoreB.compareTo(scoreA);
    });

    var bestMatch = scoringPool.first;
    String finalUid = bestMatch['uid'] ?? '';
    String finalName = bestMatch['name'] ?? 'Caregiver';
    double finalRate =
        double.tryParse(bestMatch['hourly_rate']?.toString() ?? '25') ?? 25.0;
    int matchCount = nannyMatchedTagCount[finalUid] ?? 0;

    String reason = "Matched $finalName based on your criteria: ";
    List<String> matchDetails = [];
    if (requiredTags.isNotEmpty && matchCount > 0) {
      matchDetails.add("Skills (${requiredTags.join(', ')})");
    }
    if (pricePref == "high") {
      matchDetails.add("Premium rate (RM ${finalRate.toInt()}/hr)");
    } else if (pricePref == "low") {
      matchDetails.add("Affordable budget (RM ${finalRate.toInt()}/hr)");
    }
    reason += matchDetails.join(" + ") + ".";

    return {"uid": finalUid, "reason": reason};
  }

  /// Help & Support Bot
  Future<String> getHelpResponse(
    String userQuestion, {
    bool isNannyMode = false,
  }) async {
    final cleanQ = userQuestion.toLowerCase().trim();

    if (cleanQ == 'hi' || cleanQ == 'hello' || cleanQ == 'hey') {
      return "Hello! How can I assist you with NannyApp today? You can ask me how to book a nanny, check rates, or use live tracking.";
    }
    if (cleanQ.contains("how to book") || cleanQ.contains("booking")) {
      return "To book a nanny: Go to 'Explore', tap on a nanny profile, click 'Book Now', select your service date and add-ons, and confirm!";
    }

    final roleTitle = isNannyMode ? "Caregiver" : "Client Parent";
    final prompt =
        '''
You are the AI Support Assistant for NannyApp. Answer the $roleTitle's question concisely in English (under 3 sentences).
Question: "$userQuestion"
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
          "max_tokens": 180,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content']?.toString().trim() ??
            "How else can I assist you with NannyApp today?";
      }
    } catch (e) {
      debugPrint("Groq Support API error: $e");
    }

    return "You can easily manage bookings, check nanny rates, or track active care sessions from your Bookings tab. How else can I help?";
  }
}
