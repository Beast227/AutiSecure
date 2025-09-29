import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, dynamic>> submitSurvey(Map<String, dynamic> payload) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final storedSurveyId = prefs.getString('surveyId');

  debugPrint("$storedSurveyId");

  if (token == null || token.isEmpty) {
    return {
      "success": false,
      "message": "No token found. Please log in again.",
    };
  }

  // ✅ Use POST for first time, PUT for updates
  final url = "https://autisense-backend.onrender.com/api/survey";

  final response =
      storedSurveyId != null
          ? await http.put(
            Uri.parse(url),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode(payload),
          )
          : await http.post(
            Uri.parse(url),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode(payload),
          );

  try {
    final decoded = jsonDecode(response.body);
    final surveyData = decoded["survey"];

    // ✅ Save surveyId for next time
    if (surveyData != null && surveyData["_id"] != null) {
      prefs.setString("surveyId", surveyData["_id"]);
      debugPrint(" the survey id is ${surveyData["_id"]}");
    }

    return {
      "success": response.statusCode == 200,
      "message": decoded["message"] ?? "Survey submitted",
      "score": decoded["result"] ?? (surveyData?["score"]),
      "survey": surveyData,
    };
  } catch (e) {
    return {"success": false, "message": "Failed to parse server response"};
  }
}

Future<Map<String, dynamic>> analyzeASDVideoUrl(String videoUrl) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final apiEndpoint = Uri.parse(
    "https://autisense-backend.onrender.com/api/video/analyze",
  );

  final response = await http.post(
    apiEndpoint,
    headers: {
      'Content-Type': 'application/json',
      "Authorization": "Barer $token",
    },
    body: jsonEncode({"videoUrl": videoUrl}),
  );

  debugPrint("analysing the video");
  if (response.statusCode == 200) {
    debugPrint(response.body);
    return jsonDecode(response.body);
  } else {
    throw Exception("Failed to analyze video: ${response.body}");
  }
}

Future<Map<String, dynamic>> getSurveyScore() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  try {
    final response = await http.post(
      Uri.parse("https://autisense-backend.onrender.com/api/survey"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      }, // JSON object with key "surveyResponse"
    ); // replace with your GET route
    if (response.statusCode == 200) {
      debugPrint("$response");
      return jsonDecode(response.body);
    } else {
      return {"error": "Failed to fetch score"};
    }
  } catch (e) {
    return {"error": e.toString()};
  }
}

class ApiService {
  static const String baseurl = "https://autisense-backend.onrender.com/api";

  static Future<List<Map<String, dynamic>>> fetchDoctors() async {
    final response = await http.get(Uri.parse("$baseurl/doctor/all"));

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonBody = json.decode(response.body);
      final List<dynamic> data = jsonBody['doctors'];
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load Doctors");
    }
  }

  static Future<bool> bookAppointment(Map<String, dynamic> appointment) async {
    final response = await http.post(
      Uri.parse("$baseurl/appointments"),
      headers: {"content-Type": "application/json"},
      body: json.encode(appointment),
    );

    return response.statusCode == 201;
  }
}
