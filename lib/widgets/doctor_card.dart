import 'package:autisecure/mainScreens/subScreen/appointmentPage.dart';
import 'package:flutter/material.dart';

class DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback? onBookPressed;

  const DoctorCard({super.key, required this.doctor, this.onBookPressed});

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
                          "Experience: ${int.tryParse(doctor['experience'].toString()) != null && int.parse(doctor['experience'].toString()) > 10 ? "10+" : doctor['experience'].toString()} years",
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

            if (onBookPressed != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppointmentPage(doctor: doctor),
                      ),
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
          ],
        ),
      ),
    );
  }
}
