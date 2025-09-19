import 'package:autisecure/mainScreens/subScreen/Appointment.dart';
import 'package:flutter/material.dart';

class DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onBookPressed;

  const DoctorCard({
    super.key,
    required this.doctor,
    required this.onBookPressed,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Doctor Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      doctor['imageUrl'] != null
                          ? Image.network(
                            doctor['imageUrl'],
                            width: screenWidth * 0.25,
                            height: 190,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Image.asset(
                                  "assets/doctor_avatar.png",
                                  width: screenWidth * 0.25,
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                          )
                          : Image.asset(
                            "assets/doctor_avatar.png",
                            width: screenWidth * 0.25,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Dr. ${doctor['name'] ?? "Unknown"}",
                        style: const TextStyle(
                          color: Color(0xFF0015FF),
                          fontFamily: "Merriweather",
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (doctor['speciality'] != null) ...[
                        Text(
                          doctor['speciality'],
                          style: const TextStyle(
                            color: Color(0xFF0015FF),
                            fontFamily: "Merriweather",
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      if (doctor['experience'] != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          "Experience: ${doctor['experience'] > 10 ? "10+" : doctor['experience']}",
                          style: const TextStyle(
                            color: Color(0xFF0015FF),
                            fontFamily: "Merriweather",
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      if (doctor['description'] != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          "About: ${doctor['description']}",
                          style: const TextStyle(
                            color: Color(0xFF0015FF),
                            fontFamily: "Merriweather",
                          ),
                        ),
                      ],
                      if (doctor['clinicAddress'] != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          "Clinic: ${doctor['clinicAddress']}",
                          style: const TextStyle(
                            color: Color(0xFF0015FF),
                            fontFamily: "Merriweather",
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Full-width Book Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (context) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                          left: 16,
                          right: 16,
                          top: 20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                "Book Appointment",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Example fields
                            TextField(
                              decoration: const InputDecoration(
                                labelText: "Select Date",
                                prefixIcon: Icon(Icons.calendar_today),
                                border: OutlineInputBorder(),
                              ),
                              readOnly: true,
                              onTap: () async {
                                final DateTime? pickedDate =
                                    await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime(2100),
                                    );
                              },
                            ),
                            const SizedBox(height: 12),

                            TextField(
                              decoration: const InputDecoration(
                                labelText: "Reason for Visit",
                                prefixIcon: Icon(Icons.note),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context); // close bottom sheet
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Appointment booked with Dr. ${doctor['name']}",
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                child: const Text("Confirm Appointment"),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.calendar_month),
                label: const Text(
                  "Book an Appointment",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
