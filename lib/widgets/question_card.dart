import 'package:flutter/material.dart';

class QuestionCard extends StatelessWidget {
  final String question;
  final int selectedIndex;
  final Function(int) onOptionSelected;

  const QuestionCard({
    super.key,
    required this.question,
    required this.selectedIndex,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    List<String> options = ['Option-1', 'Option-2', 'Option-3', 'Option-4'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 22),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0), // light beige
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...List.generate(options.length, (index) {
            return GestureDetector(
              onTap: () => onOptionSelected(index),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        selectedIndex == index
                            ? Colors.green
                            : Colors.grey.shade300,
                    width: selectedIndex == index ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Text(
                  options[index],
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
