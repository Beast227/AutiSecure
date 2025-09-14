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
      elevation: 6,
      color: const Color.fromARGB(
        255,
        255,
        183,
        68,
      ), // 🟠 Light background for card
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.orange, width: 1), // Border color
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.question,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(
                  255,
                  131,
                  48,
                  0,
                ), // Darker text for question
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              options.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white, // Default option background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        selectedAnswer == index
                            ? Colors.orange
                            : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: RadioListTile<int>(
                  activeColor: Colors.deepOrange,
                  title: Text(
                    options[index],
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color:
                          selectedAnswer == index
                              ? Colors.deepOrange.shade900
                              : Colors.black87,
                    ),
                  ),
                  value: index,
                  groupValue: selectedAnswer,
                  onChanged: onOptionSelected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
