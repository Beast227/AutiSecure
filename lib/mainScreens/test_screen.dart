import 'dart:convert';
import 'package:autisecure/services/api_service.dart' as ApiService;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/question_model.dart';
import '../services/api_service.dart';
import '../widgets/progress_header.dart';
import '../widgets/question_card.dart';
import '../widgets/navigation_buttons.dart';
import '../state_models/survey_state.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  List<QuestionModel> questions = [];
  bool loading = true;

  final List<String> fixedOptions = [
    "Strongly Agree",
    "Agree",
    "Disagree",
    "Strongly Disagree",
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final String response = await rootBundle.loadString(
      'assets/questions.json',
    );
    final List data = jsonDecode(response);

    final loadedQuestions = data.map((q) => QuestionModel.fromJson(q)).toList();

    // ignore: use_build_context_synchronously
    final surveyState = context.read<SurveyState>();
    surveyState.initialize(loadedQuestions.length);

    setState(() {
      questions = loadedQuestions;
      loading = false;
    });
  }

  double getProgress(List<int?> selectedAnswers) {
    int answered = selectedAnswers.where((e) => e != null).length;
    return questions.isNotEmpty ? answered / questions.length : 0;
  }

  Future<void> submitAnswers(BuildContext context) async {
    final surveyState = context.read<SurveyState>();

    // Convert selected indices directly to option strings
    List<String> responses =
        surveyState.selectedAnswers
            .map((index) => index != null ? fixedOptions[index] : "")
            .toList();

    // Wrap the responses in a key "surveyResponse"
    Map<String, dynamic> payload = {"surveyResponse": responses};

    // Print payload
    debugPrint("Survey Payload: ${jsonEncode(payload)}");

    final result = await ApiService.submitSurvey(payload);
    if (result.containsKey("score")) {
      debugPrint("Received Score: ${result['score']}");
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      // ignore: use_build_context_synchronously
      context,
    ).showSnackBar(SnackBar(content: Text(result["message"])));

    if (result["success"]) {
      surveyState.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Consumer<SurveyState>(
      builder: (context, surveyState, _) {
        return Scaffold(
          backgroundColor: const Color(0x2BFFD45D),
          body: Column(
            children: [
              ProgressHeader(
                currentIndex: surveyState.currentIndex,
                totalQuestions: questions.length,
                progress: getProgress(surveyState.selectedAnswers),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                  child: QuestionCard(
                    key: ValueKey(surveyState.currentIndex),
                    question: questions[surveyState.currentIndex],
                    options: fixedOptions,
                    selectedAnswer:
                        surveyState.selectedAnswers[surveyState.currentIndex],
                    onOptionSelected: (value) {
                      surveyState.updateAnswer(surveyState.currentIndex, value);
                    },
                  ),
                ),
              ),
              NavigationButtons(
                isFirstQuestion: surveyState.currentIndex == 0,
                isLastQuestion:
                    surveyState.currentIndex == questions.length - 1,
                onNext: surveyState.nextQuestion,
                onBack: surveyState.previousQuestion,
                onSubmit: () => submitAnswers(context),
                canSubmit: !surveyState.selectedAnswers.contains(null),
              ),
            ],
          ),
        );
      },
    );
  }
}
