import 'dart:convert';
import 'package:autisecure/models/appointment.dart';
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
  static const String baseUrl = "https://autisense-backend.onrender.com/api";

  static Future<Map<String, dynamic>> fetchDoctors({
    required int page,
    required int limit,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // Fetch the token
    // Ensure you have a token
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    // Construct the URL with pagination query parameters
    // Adjust '/doctors/all' if your paginated endpoint is different
    final url = Uri.parse('$baseUrl/doctor/all?page=$page&limit=$limit');

    try {
      final response = await http.get(
        url,
        // Add the Authorization header
        headers: {'authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // --- Adjust based on YOUR backend response structure ---
        // Assuming your backend returns something like:
        // {
        //   "doctors": [ {...}, {...} ],
        //   "currentPage": 1,
        //   "totalPages": 3
        // }
        final List<dynamic> doctorsData = data['doctors'] ?? [];
        final int currentPage = data['currentPage'] ?? page;
        final int totalPages = data['totalPages'] ?? 1; // Default to 1 if not provided
        // Determine if there are more pages based on the response
        final bool hasMoreData = currentPage < totalPages;
        // --- End of backend assumption ---

        // Return the required Map structure
        return {
          'doctors': doctorsData.cast<Map<String, dynamic>>(),
          'hasMore': hasMoreData,
        };
      } else {
        // Provide more specific error information
        throw Exception(
            'Failed to load doctors (Status ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      // Catch network or decoding errors
      throw Exception('Failed to fetch doctors: $e');
    }
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 🔹 Get appointment requests for doctor
  static Future<List<Appointment>> fetchAppointmentRequests() async {
    debugPrint('📡 Starting fetchAppointmentRequests...');
    final token = await _getToken();

    if (token == null) {
      debugPrint('❌ Token not found!');
      throw Exception("Token not found");
    }

    final url = Uri.parse('$baseUrl/requests');
    debugPrint('🌐 Sending GET request to: $url');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📦 Raw response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          debugPrint(
            '✅ Successfully parsed appointment list (${decoded.length} items)',
          );
          return decoded.map((e) => Appointment.fromJson(e)).toList();
        } else if (decoded is Map && decoded.containsKey('appointments')) {
          debugPrint(
            '✅ Found "appointments" key with ${decoded["appointments"].length} items',
          );
          return (decoded["appointments"] as List)
              .map((e) => Appointment.fromJson(e))
              .toList();
        } else {
          debugPrint('⚠️ Unexpected response format: $decoded');
          return [];
        }
      } else {
        debugPrint('❌ Failed to fetch appointments: ${response.statusCode}');
        return [];
      }
    } catch (e, stack) {
      debugPrint("🚨 Exception while loading appointments: $e");
      debugPrint(stack.toString());
      return [];
    }
  }

  // 🔹 Approve appointment
  static Future<void> approveAppointment(String id) async {
    final token = await _getToken();
    if (token == null) throw Exception("Token not found");

    await http.post(
      Uri.parse('$baseUrl/approve'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'appointmentId': id}),
    );
  }

  // 🔹 Reject appointment
  static Future<void> rejectAppointment(String id) async {
    final token = await _getToken();
    if (token == null) throw Exception("Token not found");

    await http.post(
      Uri.parse('$baseUrl/reject'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'appointmentId': id}),
    );
  }
}

Future<Map<String, dynamic>?> getSurveyResults() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    debugPrint("❌ No auth token found, cannot fetch survey results.");
    return null;
  }

  // Assuming the GET route is the same as the POST route for surveys
  final url = Uri.parse('https://autisense-backend.onrender.com/api/survey');

  try {
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    debugPrint(token);

    if (response.statusCode == 200) {
      // Survey found, return the data
      return jsonDecode(response.body);
    } else if (response.statusCode == 400) {
      // No survey found for this user, which is a valid scenario
      debugPrint("ℹ️ No previous survey found on the server for this user.");
      return null;
    } else {
      // Handle other errors
      debugPrint("❌ Failed to fetch survey results: ${response.statusCode}");
      return null;
    }
  } catch (e) {
    debugPrint("❌ Error during getSurveyResults API call: $e");
    return null;
  }
}
