import 'package:flutter/material.dart';

class QuizQuestions extends StatelessWidget {
  final String question;
  final List<String> options;
  final void Function(String selectedOption) onOptionSelected;

  const QuizQuestions({
    super.key,
    required this.question,
    required this.options,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        ...options.map(
          (option) => Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 6),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              onPressed: () => onOptionSelected,
              child: Text(option, style: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }
}
