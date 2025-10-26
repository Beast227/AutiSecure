// ignore: file_names
import 'dart:convert';

import 'package:autisecure/widgets/doctor_card.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppointmentPage extends StatefulWidget {
  final Map<String, dynamic> doctor;

  const AppointmentPage({super.key, required this.doctor});

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  final TextEditingController reasonController = TextEditingController();

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  Future<void> bookApointment(context) async {
    if (startDate == null ||
        endDate == null ||
        startTime == null ||
        endTime == null ||
        reasonController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields.")));
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End date must be after start date.")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final url = Uri.parse(
      "https://autisense-backend.onrender.com/api/appointments/create",
    );
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Token not found. Please log in again.")),
      );
      return;
    }

    final body = {
      "doctorId": widget.doctor["_id"],
      "appointmentStartDate": startDate?.toIso8601String(),
      "appointmentEndDate": endDate?.toIso8601String(),
      "appointmentStartTime": startTime?.format(context),
      "appointmentEndTime": endTime?.format(context),
      "description": reasonController.text,
    };
    debugPrint("Data to be sent : $body");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Appointment successfully submitted!!\n\n");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appointment booked successfully!")),
        );

        if (mounted) Navigator.pop(context);
      } else {
        debugPrint(
          "The appointment couldnt be booked due to :${response.body}",
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to book appointment: ${response.body}"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget buildHeader() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Image.asset("assets/logo.png", height: 60),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          "AutiSecure",
          style: TextStyle(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: "Merriweather",
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F0E0),
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: Colors.orange,
        title: buildHeader(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              child: const Text(
                "Book Appointment",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: "Merriweather",
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),

            // Doctor Info
            DoctorCard(doctor: widget.doctor),
            const SizedBox(height: 24),

            // Date Selection
            Text(
              "Select the Start and End Date",
              style: TextStyle(
                color: Colors.orange,
                fontFamily: "Merriweather",
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildDateButton(
                    label: "Start Date",
                    value: startDate,
                    onPick: (picked) => setState(() => startDate = picked),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateButton(
                    label: "End Date",
                    value: endDate,
                    onPick: (picked) => setState(() => endDate = picked),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time Selection
            Text(
              "Select the Start and End Time",
              style: TextStyle(
                color: Colors.orange,
                fontFamily: "Merriweather",
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTimeButton(
                    label: "Start Time",
                    value: startTime,
                    onPick: (picked) => setState(() => startTime = picked),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeButton(
                    label: "End Time",
                    value: endTime,
                    onPick: (picked) => setState(() => endTime = picked),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Reason
            Text(
              "Type in the Reason",
              style: TextStyle(
                color: Colors.orange,
                fontFamily: "Merriweather",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Reason for Visit",
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  bookApointment(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Confirm Appointment",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reusable Date Picker Button
  Widget _buildDateButton({
    required String label,
    required DateTime? value,
    required Function(DateTime) onPick,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value != null ? "${value.day}/${value.month}/${value.year}" : label,
            style: const TextStyle(fontSize: 16),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(6),
            child: const Icon(Icons.calendar_today, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Reusable Time Picker Button
  Widget _buildTimeButton({
    required String label,
    required TimeOfDay? value,
    required Function(TimeOfDay) onPick,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () async {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (pickedTime != null) onPick(pickedTime);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value != null ? value.format(context) : label,
            style: const TextStyle(fontSize: 16),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(6),
            child: const Icon(Icons.access_time, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
