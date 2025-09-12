import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, dynamic>> submitSurvey(Map<String, dynamic> payload) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token == null || token.isEmpty) {
    return {
      "success": false,
      "message": "No token found. Please log in again.",
    };
  }

  final response = await http.post(
    Uri.parse("https://autisense-backend.onrender.com/api/survey"),
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    },
    body: jsonEncode(payload), // JSON object with key "surveyResponse"
  );

  if (response.statusCode == 200) {
    return {"success": true, "message": "Survey submitted successfully"};
  } else {
    return {
      "success": false,
      "message": "Server error: ${response.statusCode}, body: ${response.body}",
    };
  }
}
