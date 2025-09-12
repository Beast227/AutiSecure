import 'package:flutter/material.dart';
import '../models/question_model.dart';

class QuestionCard extends StatelessWidget {
  final QuestionModel question;
  final List<String> options;
  final int? selectedAnswer;
  final ValueChanged<int?> onOptionSelected;

  const QuestionCard({
    super.key,
    required this.question,
    required this.options,
    required this.selectedAnswer,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey(question.question),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.question,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...List.generate(
              options.length,
              (index) => RadioListTile<int>(
                title: Text(options[index]),
                value: index,
                groupValue: selectedAnswer,
                onChanged: onOptionSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
