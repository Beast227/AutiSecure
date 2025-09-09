import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class SurveyState extends ChangeNotifier {
  List<Map<String, dynamic>> _questions = [];
  List<int?> _selectedOptions = [];
  int _currQuestion = 0;

  List<Map<String, dynamic>> get questions => List.unmodifiable(_questions);
  List<int?> get selectedOptions => List.unmodifiable(_selectedOptions);
  int get currQuestion => _currQuestion;
  int get totalQuestions => _questions.length;
  bool get isComplete => !_selectedOptions.contains(null);

  Future<void> loadSurvey() async {
    try {
      final String response = await rootBundle.loadString('assets/quiz.json');
      final Map<String, dynamic> data = json.decode(response);

      final rawQuestions = data["questions"];

      if (rawQuestions is List) {
        _questions =
            rawQuestions.map((q) => Map<String, dynamic>.from(q)).toList();
      } else if (rawQuestions is Map) {
        _questions =
            rawQuestions.values
                .map((q) => Map<String, dynamic>.from(q))
                .toList();
      } else {
        throw const FormatException(
          "Invalid format: 'questions' must be a List or Map",
        );
      }

      _selectedOptions = List<int?>.filled(_questions.length, null);

      notifyListeners();
    } catch (e, stack) {
      debugPrint("❌ Error loading survey: $e");
      debugPrint(stack.toString());
    }
  }

  void selectOption(int questionIndex, int optionIndex) {
    if (questionIndex < 0 || questionIndex >= _selectedOptions.length) {
      debugPrint("⚠️ Invalid questionIndex: $questionIndex");
      return;
    }

    _selectedOptions[questionIndex] = optionIndex;
    _currQuestion = questionIndex;

    notifyListeners();
  }
}
