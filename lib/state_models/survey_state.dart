import 'package:flutter/material.dart';

class SurveyState extends ChangeNotifier {
  List<int?> selectedAnswers = [];
  int currentIndex = 0;

  void initialize(int questionCount) {
    if (selectedAnswers.isEmpty) {
      selectedAnswers = List<int?>.filled(questionCount, null);
      currentIndex = 0;
      notifyListeners();
    }
  }

  void updateAnswer(int index, int? value) {
    selectedAnswers[index] = value;
    notifyListeners();
  }

  void nextQuestion() {
    if (currentIndex < selectedAnswers.length - 1) {
      currentIndex++;
      notifyListeners();
    }
  }

  void previousQuestion() {
    if (currentIndex > 0) {
      currentIndex--;
      notifyListeners();
    }
  }

  void reset() {
    selectedAnswers = List<int?>.filled(selectedAnswers.length, null);
    currentIndex = 0;
    notifyListeners();
  }
}
