import 'package:flutter/material.dart';

class NavigationButtons extends StatelessWidget {
  final bool isFirstQuestion;
  final bool isLastQuestion;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback? onSubmit;
  final bool canSubmit;

  const NavigationButtons({
    super.key,
    required this.isFirstQuestion,
    required this.isLastQuestion,
    required this.onNext,
    required this.onBack,
    required this.onSubmit,
    required this.canSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: isFirstQuestion ? null : onBack,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000),
            ),
            child: Text(
              "Back",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7B00),
            ),
            onPressed: isLastQuestion ? (canSubmit ? onSubmit : null) : onNext,
            child: Text(
              isLastQuestion ? "Submit" : "Next",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
