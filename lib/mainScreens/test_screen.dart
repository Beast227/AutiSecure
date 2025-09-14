import 'dart:convert';
import 'dart:io';
import 'package:autisecure/services/api_service.dart' as api_service;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:percent_indicator/circular_percent_indicator.dart'; // for animated score
import 'package:animate_do/animate_do.dart'; // for animations
import '../models/question_model.dart';
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
  int aqScore = 0;
  bool loading = true;
  bool showScoreAnimation = false;

  File? selectedVideo;
  String? asdResult;

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
    try {
      final String response = await rootBundle.loadString(
        'assets/questions.json',
      );
      final List data = jsonDecode(response);
      final loadedQuestions =
          data.map((q) => QuestionModel.fromJson(q)).toList();

      // ignore: use_build_context_synchronously
      final surveyState = context.read<SurveyState>();
      surveyState.initialize(loadedQuestions.length);

      final prefs = await SharedPreferences.getInstance();
      final savedAnswers = prefs.getStringList('selectedAnswers');
      final savedScore = prefs.getInt('aqScore');

      if (savedAnswers != null) {
        for (int i = 0; i < savedAnswers.length; i++) {
          if (savedAnswers[i] != "") {
            surveyState.updateAnswer(i, int.parse(savedAnswers[i]));
          }
        }
      }

      if (savedScore != null) {
        aqScore = savedScore;
      }

      setState(() {
        questions = loadedQuestions;
        loading = false;
      });
    } catch (e) {
      debugPrint("❌ Failed to load questions: $e");
      setState(() {
        questions = [];
        loading = false;
      });
    }
  }

  Future<void> submitAnswers(BuildContext context) async {
    final surveyState = context.read<SurveyState>();

    List<String> responses =
        surveyState.selectedAnswers
            .map((index) => index != null ? fixedOptions[index] : "")
            .toList();

    Map<String, dynamic> payload = {"surveyResponse": responses};
    debugPrint("Survey Payload: ${jsonEncode(payload)}");

    final result = await api_service.submitSurvey(payload);
    debugPrint("Submit API response: $result");

    // ✅ Extract actual score
    if (result["score"] != null) {
      setState(() {
        aqScore = result["score"];
        showScoreAnimation = true;
      });

      final prefs = await SharedPreferences.getInstance();
      prefs.setInt('aqScore', aqScore);
      prefs.setStringList(
        'selectedAnswers',
        surveyState.selectedAnswers.map((e) => e?.toString() ?? "").toList(),
      );
    }

    if (!mounted) return;

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result["message"] ?? "Survey submitted successfully"),
      ),
    );
  }

  Future<void> pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => selectedVideo = File(picked.path));
    }
  }

  Future<void> analyzeVideo() async {
    if (selectedVideo == null) return;

    final result = await api_service.analyzeASDVideo(selectedVideo!);
    setState(() {
      asdResult = result["analysis"];
    });
  }

  double getProgress(List<int?> selectedAnswers) {
    int answered = selectedAnswers.where((e) => e != null).length;
    return questions.isNotEmpty ? answered / questions.length : 0;
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (aqScore > 0)
                  ZoomIn(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 6,
                      margin: const EdgeInsets.all(8),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text(
                              "Your AQ Score",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            CircularPercentIndicator(
                              radius: 70,
                              lineWidth: 12,
                              percent: (aqScore / 50).clamp(0.0, 1.0),
                              center: Text(
                                "$aqScore",
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      aqScore > 30
                                          ? Colors.green
                                          : aqScore > 15
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                              ),
                              progressColor:
                                  aqScore > 30
                                      ? Colors.green
                                      : aqScore > 15
                                      ? Colors.orange
                                      : Colors.red,
                              backgroundColor: Colors.grey.shade200,
                              animation: true,
                              animationDuration: 1500,
                            ),
                            const SizedBox(height: 15),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                backgroundColor: Colors.orange,
                                iconColor: Colors.white,
                              ),
                              onPressed: () {
                                surveyState.reset();
                                setState(() {
                                  aqScore = 0;
                                });
                              },
                              label: const Text(
                                "Retake Survey",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: 20),

                FadeInDown(
                  child: ProgressHeader(
                    currentIndex: surveyState.currentIndex,
                    totalQuestions: questions.length,
                    progress: getProgress(surveyState.selectedAnswers),
                  ),
                ),
                const SizedBox(height: 20),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder:
                      (child, animation) => SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(1, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
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

                const SizedBox(height: 10),

                NavigationButtons(
                  isFirstQuestion: surveyState.currentIndex == 0,
                  isLastQuestion:
                      surveyState.currentIndex == questions.length - 1,
                  onNext: surveyState.nextQuestion,
                  onBack: surveyState.previousQuestion,
                  onSubmit: () => submitAnswers(context),
                  canSubmit: !surveyState.selectedAnswers.contains(null),
                ),

                const SizedBox(height: 20),

                const Divider(thickness: 2, height: 40),

                FadeInUp(
                  child: Column(
                    children: [
                      const Text(
                        "Upload Video for ASD Analysis",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (selectedVideo != null)
                        Column(
                          children: [
                            Text(
                              "Selected: ${selectedVideo!.path.split('/').last}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: pickVideo,
                            icon: const Icon(Icons.upload_file),
                            label: const Text("Choose Video"),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: analyzeVideo,
                            icon: const Icon(Icons.analytics),
                            label: const Text("Analyze"),
                          ),
                        ],
                      ),
                      if (asdResult != null)
                        BounceInDown(
                          child: Card(
                            color: Colors.blue.shade50,
                            margin: const EdgeInsets.only(top: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                "ASD Analysis Result:\n$asdResult",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
