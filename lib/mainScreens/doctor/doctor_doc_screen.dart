import 'package:flutter/material.dart';
// Ensure correct import paths
import '../../services/api_service.dart';
import '../../widgets/doctor_card.dart';

class DocDocListScreen extends StatefulWidget {
  const DocDocListScreen({super.key});

  @override
  State<DocDocListScreen> createState() => _DocDocListScreenState();
}

class _DocDocListScreenState extends State<DocDocListScreen> {
  // Change the type to match the ApiService return type
  late Future<Map<String, dynamic>> _doctorsFuture;
  final int _initialLimit = 10; // Define how many doctors to load initially

  @override
  void initState() {
    super.initState();
    // Provide the required page and limit arguments for the initial fetch
    _doctorsFuture = ApiService.fetchDoctors(page: 1, limit: _initialLimit);
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
      // Update FutureBuilder type to Map<String, dynamic>
      body: FutureBuilder<Map<String, dynamic>>(
        future: _doctorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Error fetching doctors: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("No data received."));
          }

          // Extract the list of doctors from the map
          final List<dynamic> doctorsDynamic = snapshot.data!['doctors'] ?? [];
          // Safely cast to the correct type
          final List<Map<String, dynamic>> doctors = doctorsDynamic.cast<Map<String, dynamic>>();

          // Check if the extracted list is empty
          if (doctors.isEmpty) {
             return const Center(child: Text("No doctors available right now."));
          }


          debugPrint("Displaying ${doctors.length} doctors");

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doctor = doctors[index];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: DoctorCard(
                  doctor: doctor,
                  onBookPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Book appointment with ${doctor['name'] ?? "Doctor"}",
                        ),
                         backgroundColor: Colors.orangeAccent,
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}