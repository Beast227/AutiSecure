import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/doctor_card.dart'; // We'll create this widget below

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  late Future<List<Map<String, dynamic>>> _doctorsFuture;

  @override
  void initState() {
    super.initState();
    _doctorsFuture = ApiService.fetchDoctors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: AppBar(
              title: const Text(
                "List of Doctors",
                style: TextStyle(
                  fontFamily: "Merriweather",
                  color: Colors.orange,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.white,
            ),
          ),
        ),
      ),

      backgroundColor: const Color(0x2BFFD45D),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _doctorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No doctors available right now."));
          }

          final doctors = snapshot.data!;
          debugPrint("The list of $doctors");

          return ListView.builder(
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doctor = doctors[index];

              return DoctorCard(
                doctor: doctor,
                onBookPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Book appointment with ${doctor['name'] ?? "Doctor"}",
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
