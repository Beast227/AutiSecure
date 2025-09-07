import 'package:flutter/material.dart';

class SurveyState extends ChangeNotifier {
  int currQuestion = 0;
  final totalQuestions = 10;
  List<int?> selectedOptions = List.filled(10, null);

  void selectOption(int questionIndex, int optionIndex) {
    selectedOptions[questionIndex] = optionIndex;
    currQuestion = questionIndex;
    notifyListeners();
  }

  void reserSurvey() {
    selectedOptions = List.filled(totalQuestions, null);
    currQuestion = 0;
    notifyListeners();
  }
}
