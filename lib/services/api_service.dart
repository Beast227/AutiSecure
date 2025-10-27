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

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // live chat api calls
  // In your api_service.dart

  static Future<List<Map<String, dynamic>>> fetchConversations({
    // Changed return type
    required String role,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    // Use the correct endpoints corresponding to your routes
    final endpoint =
        role == 'doctor'
            ? "$baseUrl/conversation/doctor" // Ensure this matches your route
            : "$baseUrl/conversation/user"; // Ensure this matches your route

    try {
      // Add try-catch block
      final res = await http.get(
        Uri.parse(endpoint),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        // Decode the response body, which IS the array
        final List<dynamic> data = jsonDecode(res.body);
        // Cast the dynamic list to the expected type and return it directly
        return data.cast<Map<String, dynamic>>();
      } else {
        // Throw a more informative exception
        throw Exception(
          "Failed to fetch conversations (Status ${res.statusCode}): ${res.body}",
        );
      }
    } catch (e) {
      // Catch network or decoding errors
      throw Exception("Error during fetchConversations: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPendingAppointments() async {
    final token = await _getToken();

    final res = await http.get(
      Uri.parse("$baseUrl/appointments/requests"),
      headers: {"Authorization": "Bearer $token"},
    );
    debugPrint("$token");

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      final approvedReq = data['appointmentRequests'];

      if (approvedReq == null || approvedReq is! List) {
        debugPrint("No approved requests found or invalid structure.");
        return [];
      }

      // Safely cast each element to Map<String, dynamic>
      final List<Map<String, dynamic>> appointments =
          (data["appointmentRequests"] as List)
              .map((e) => e as Map<String, dynamic>)
              .toList();

      return appointments;
    } else {
      throw Exception("Failed to fetch appointments: ${res.body}");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchapprovedAppointments() async {
    final token = await _getToken();

    final res = await http.get(
      Uri.parse("$baseUrl/appointments/approve"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final approvedReq = data['approvedRequests'];
      debugPrint(
        " the data fetched here is as follows \n\n${data['approvedRequests']}",
      );

      if (approvedReq == null || approvedReq is! List) {
        debugPrint("No approved requests found or invalid structure.");
        return [];
      }
      final List<Map<String, dynamic>> appointments =
          approvedReq
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

      return appointments;
    } else {
      throw Exception("Failed to fetch appointments: ${res.body}");
    }
  }

  static Future<bool> approveAppointment({
    required String requestId,
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    final token = await _getToken();
    debugPrint("Data: $requestId, $date, $startTime, $endTime");

    final res = await http.post(
      Uri.parse("$baseUrl/appointments/approve"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "requestId": requestId,
        "date": date,
        "startTime": startTime,
        "endTime": endTime,
      }),
    );
    debugPrint("${res.statusCode}");
    return res.statusCode == 200;
  }

  static Future<List<dynamic>> fetchMessages(String conversationId) async {
    final token = await _getToken();

    final res = await http.get(
      Uri.parse("$baseUrl/chat/$conversationId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data["messages"];
    } else {
      throw Exception("Failed to load messages");
    }
  }

  static Future<bool> sendMessage({
    required String conversationId,
    required String senderId,
    required String message,
  }) async {
    final token = await _getToken();

    final res = await http.post(
      Uri.parse("$baseUrl/chat/send"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "conversationId": conversationId,
        "senderId": senderId,
        "message": message,
      }),
    );

    return res.statusCode == 200;
  }

  static Future<void> approveAppointmentWithDetails({
    required String appointmentId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/appointments/approve'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'requestId': appointmentId,
        'date': date.toIso8601String(),
        'startTime': "${startTime.hour}:${startTime.minute}",
        'endTime': "${endTime.hour}:${endTime.minute}",
      }),
    );
    debugPrint(
      "✅ Approved appointment $appointmentId with date/time, status: ${response.statusCode}",
    );
  }

  static Future<void> rejectAppointment(String appointmentId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/appointments/reject'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'appointmentId': appointmentId}),
    );
    debugPrint(
      "✅ Rejected appointment $appointmentId, status: ${response.statusCode}",
    );
  }

  // the below is the general api calls
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
        final int totalPages =
            data['totalPages'] ?? 1; // Default to 1 if not provided
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
          'Failed to load doctors (Status ${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      // Catch network or decoding errors
      throw Exception('Failed to fetch doctors: $e');
    }
  }

  static Future<List<Appointment>> fetchAppointmentRequests() async {
    final token = await _getToken();
    if (token == null) throw Exception("Token not found");

    try {
      debugPrint("📡 Starting fetchAppointmentRequests...");
      final response = await http.get(
        Uri.parse('$baseUrl/appointments/requests'),
        headers: {'Authorization': 'Bearer $token'},
      );
      debugPrint("🌐 GET request sent to: $baseUrl/requests");
      debugPrint("📥 Response status: ${response.statusCode}");
      debugPrint("📦 Raw response body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);

        if (jsonData.containsKey('appointmentRequests')) {
          final List appointmentsData = jsonData['appointmentRequests'];
          debugPrint("✅ Parsed ${appointmentsData.length} appointment(s)");

          return appointmentsData.map((e) => Appointment.fromJson(e)).toList();
        } else {
          debugPrint("⚠️ Unexpected response format: $jsonData");
          return [];
        }
      } else {
        throw Exception('Failed to fetch appointments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("❌ Failed to fetch appointments: $e");
      return [];
    }
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
