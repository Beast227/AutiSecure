import 'package:autisecure/mainScreens/doctor_screen.dart';
import 'package:autisecure/mainScreens/test_screen.dart';
import 'package:autisecure/widgets/cards.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool showSurvey = false;

  final String question = 'What is the capital of Japan?';
  final List<String> options = ['Beijing', 'Seoul', 'Tokyo', 'Bangkok'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(43, 255, 212, 93),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SimpleCard(
                title: "Autism Syndrome detection in infants",
                description:
                    "some random informationsome random informationsome random informationsome random informationsome random informationsome random information",
              ),
              SimpleCard(
                title: "Wanna Know your autistic or not  !?",
                buttonText: "Take a Survey!",
                onButtonPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TestScreen()),
                  );
                },
              ),
              SimpleCard(
                title: "Wanna try a video analysis of Autism ??",
                buttonText: "Upload  Video",
                imageUrl: "assets/images/video_analysis.png",
                onButtonPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TestScreen()),
                  );
                },
              ),
              SimpleCard(
                title: "Want to contact a Doctor",
                buttonText: "Check List of Doctors",
                imageUrl: "assets/images/Doctor_Image.png",
                onButtonPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DoctorScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
