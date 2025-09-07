import 'package:autisecure/state_models/survey_state.dart';
import 'package:autisecure/widgets/question_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final survey = Provider.of<SurveyState>(context);

    return Scaffold(
      backgroundColor: const Color(0x2BFFD45D),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text('${survey.currQuestion + 1}/${survey.totalQuestions}'),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (survey.currQuestion + 1) / survey.totalQuestions,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.brown),
              ),
              const SizedBox(height: 16),

              ...List.generate(survey.totalQuestions, (index) {
                return QuestionCard(
                  question: '${index + 1}. What is Your name ?',
                  selectedIndex: survey.selectedOptions[index] ?? -1,
                  onOptionSelected: (optionIndex) {
                    survey.selectOption(index, optionIndex);
                  },
                );
              }),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text(
                  "Submit",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
