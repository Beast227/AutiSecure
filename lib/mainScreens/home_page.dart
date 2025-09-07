import 'package:autisecure/globals.dart' as globals;
import 'package:autisecure/landing_screen.dart';
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
      backgroundColor: const Color(0x2BFFD45D),
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
                  globals.selectedIndex = 1; // Test tab
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const Landingscreen()),
                  );
                },
              ),
              SimpleCard(
                title: "Wanna try a video analysis of Autism ??",
                buttonText: "Upload  Video",
                imageUrl: "assets/images/video_analysis.png",
                onButtonPressed: () {
                  globals.selectedIndex = 1; // Doctor tab
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const Landingscreen()),
                  );
                },
              ),
              SimpleCard(
                title: "Want to contact a Doctor",
                buttonText: "Check List of Doctors",
                imageUrl: "assets/images/Doctor_Image.png",
                onButtonPressed: () {
                  globals.selectedIndex = 2; // Doctor tab
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const Landingscreen()),
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
