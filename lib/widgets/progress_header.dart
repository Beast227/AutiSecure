import 'package:flutter/material.dart';

class ProgressHeader extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final double progress;

  const ProgressHeader({
    super.key,
    required this.currentIndex,
    required this.totalQuestions,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Question ${currentIndex + 1} of $totalQuestions"),
              Text("${(progress * 100).toStringAsFixed(0)}%"),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            color: Colors.blue,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
