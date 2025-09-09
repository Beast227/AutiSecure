import 'package:autisecure/widgets/question_card.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final List<Map<String, dynamic>> questions = [
    {
      "question": "What is your favorite color?",
      "options": ["Red", "Blue", "Green", "Yellow"],
    },
    {
      "question": "What is your favorite animal?",
      "options": ["Dog", "Cat", "Rabbit", "Parrot"],
    },
    {
      "question": "What is your favorite fruit?",
      "options": ["Apple", "Banana", "Mango", "Grapes"],
    },
    {
      "question": "What is your favorite sport?",
      "options": ["Football", "Cricket", "Tennis", "Basketball"],
    },
  ];

  List<String?> selectedAnswers = [];
  bool isSubmitting = false;
  bool surveyOpen = false;
  List<Map<String, dynamic>> submittedResults = [];

  @override
  void initState() {
    super.initState();
    _resetAnswers();
  }

  void _resetAnswers() {
    selectedAnswers = List<String?>.filled(questions.length, null);
  }

  Future<void> _submitAnswers() async {
    if (selectedAnswers.contains(null)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please answer all questions before submitting."),
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final payload = List.generate(
        questions.length,
        (index) => {
          "question": questions[index]["question"],
          "answer": selectedAnswers[index],
        },
      );

      debugPrint("Submitting answers: $payload");

      final response = await http.post(
        Uri.parse(
          "https://your-backend-api.com/submit",
        ), // replace with real API
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"answers": payload}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          submittedResults = payload;
          surveyOpen = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Answers submitted successfully ✅")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Submission failed: $e")));
    }

    if (mounted) {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int answeredCount =
        selectedAnswers.where((answer) => answer != null).length;

    return Scaffold(
      backgroundColor: const Color(0xFFFDEEE1),
      body: SafeArea(
        // Always check if survey data exists
        child:
            surveyOpen
                ? _buildSurvey(answeredCount)
                : submittedResults.isNotEmpty
                ? _buildResults()
                : _buildTakeSurveyButton(),
      ),
    );
  }

  Widget _buildSurvey(int answeredCount) {
    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: answeredCount / questions.length,
                color: Colors.brown,
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(height: 6),
              Text(
                "$answeredCount/${questions.length} answered",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Survey content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...List.generate(questions.length, (index) {
                  final q = questions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: QuestionCard(
                      question: q["question"],
                      options: List<String>.from(q["options"]),
                      selectedOption: selectedAnswers[index],
                      onChanged: (val) {
                        setState(() {
                          selectedAnswers[index] = val;
                        });
                      },
                    ),
                  );
                }),
                // Submit button
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 255, 145, 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSubmitting ? null : _submitAnswers,
                    child:
                        isSubmitting
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              "Submit",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: submittedResults.length,
            itemBuilder: (context, index) {
              final result = submittedResults[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(result["question"]),
                  subtitle: Text("Your Answer: ${result["answer"]}"),
                ),
              );
            },
          ),
        ),
        // Take Survey Again button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 255, 145, 0),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              setState(() {
                _resetAnswers();
                surveyOpen = true;
                submittedResults = [];
              });
            },
            child: const Text(
              "Take Survey Again",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTakeSurveyButton() {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 255, 145, 0),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          setState(() {
            surveyOpen = true;
            _resetAnswers();
          });
        },
        child: const Text(
          "Take Survey",
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
