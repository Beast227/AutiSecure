import 'package:autisecure/widgets/question_card.dart';
import 'package:flutter/material.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  int currentQuestion = 0;
  final int totalQuestions = 10;
  List<int?> selectedOptions = List.filled(10, null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text('${currentQuestion + 1}/$totalQuestions'),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (currentQuestion + 1) / totalQuestions,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.brown),
              ),
              const SizedBox(height: 16),

              ...List.generate(totalQuestions, (index) {
                return QuestionCard(
                  question: '${index + 1}. What is Your name ?',
                  selectedIndex: selectedOptions[index] ?? -1,
                  onOptionSelected: (optionIndex) {
                    setState(() {
                      selectedOptions[index] = optionIndex;
                      currentQuestion = index;
                    });
                  },
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () {}, child: Text("Submit")),
            ],
          ),
        ),
      ),
    );
  }
}
