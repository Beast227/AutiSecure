import 'package:flutter/material.dart';

class AppointmentScreen extends StatelessWidget {
  final Map<String, dynamic> doctor;

  const AppointmentScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Book Appointment with Dr. ${doctor['name']}"),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Doctor: Dr. ${doctor['name'] ?? 'Unknown'}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (doctor['speciality'] != null)
              Text("Speciality: ${doctor['speciality']}"),
            const SizedBox(height: 8),
            if (doctor['clinicAddress'] != null)
              Text("Clinic: ${doctor['clinicAddress']}"),
            const SizedBox(height: 24),

            // Example: You can add a date picker, time slots, etc.
            const Text(
              "Select Date and Time",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // In future you can open a date picker here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Date Picker Coming Soon!")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text("Choose Date"),
            ),
          ],
        ),
      ),
    );
  }
}
