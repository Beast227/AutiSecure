import 'package:autisecure/globals.dart' as globals;
import 'package:autisecure/landing_screens/landing_screen.dart';
import 'package:autisecure/widgets/cards.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF2E9), // light background
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Intro card about ASD detection
              SimpleCard(
                title: "Autism Syndrome Detection in Infants",
                description:
                    "Early detection of Autism Spectrum Disorder (ASD) in infants allows timely interventions. Signs like reduced eye contact, delayed gestures, and repetitive behaviors can indicate risk. Behavioral observations and AI-based analysis help at-risk infants receive personalized support for better developmental outcomes.",
              ),

              // Survey card
              SimpleCard(
                title: "Want to know if your child might be at risk?",
                buttonText: "Take a Survey!",
                onButtonPressed: () {
                  globals.selectedIndex = 1; // Test tab
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const Landingscreen()),
                  );
                },
              ),

              // Video analysis card
              SimpleCard(
                title: "Try a Video Analysis for Autism",
                buttonText: "Upload Video",
                imageUrl: "assets/images/video_analysis.png",
                onButtonPressed: () {
                  globals.selectedIndex = 1; // Doctor tab
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const Landingscreen()),
                  );
                },
              ),

              // Consult a doctor card
              SimpleCard(
                title: "Need More Guidance?",
                description:
                    "If you want personalized support, you can book an appointment with a doctor. "
                    "The system allows live video calls, voice calls, and live chat with certified professionals. "
                    "Doctors can also provide prescriptions and guidance based on the generated ASD report.",
                buttonText: "Consult a Doctor",
                imageUrl: "assets/images/Doctor_Image.png",
                onButtonPressed: () {
                  globals.selectedIndex = 2; // Doctor tab
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const Landingscreen()),
                  );
                },
              ),

              // Informative cards for caregivers
              SimpleCard(
                title: "Importance of Early Intervention",
                description:
                    "Starting therapy early in infancy can improve social, communication, and cognitive skills, reducing long-term challenges and helping children achieve better independence.",
              ),

              SimpleCard(
                title: "Common Early Signs of ASD",
                description:
                    "Look for limited eye contact, delayed speech or gestures, repetitive behaviors, and unusual reactions to sensory stimuli. Early recognition is key for timely intervention.",
              ),

              SimpleCard(
                title: "Role of Technology in Detection",
                description:
                    "AI-powered video analysis and machine learning models can support early detection by tracking behavioral patterns and developmental milestones more accurately than observation alone.",
              ),

              SimpleCard(
                title: "Support and Resources",
                description:
                    "Caregivers can access therapy programs, educational support, and community groups to help children with ASD thrive. Professional guidance ensures personalized and effective interventions.",
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
