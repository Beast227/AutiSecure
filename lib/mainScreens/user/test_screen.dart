import 'dart:convert';
import 'dart:io';
import 'package:autisecure/services/api_service.dart' as api_service;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:animate_do/animate_do.dart';
import 'package:video_player/video_player.dart';
import '../../models/question_model.dart';
import '../../widgets/progress_header.dart';
import '../../widgets/question_card.dart';
import '../../widgets/navigation_buttons.dart';
import '../../state_models/survey_state.dart';

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
  VideoPlayerController? _videoController;

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

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<String?> uploadVideoToCloudinary(File videoFile) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/video/upload",
    );

    final request =
        http.MultipartRequest("POST", url)
          ..fields["upload_preset"] = uploadPreset!
          ..files.add(
            await http.MultipartFile.fromPath("file", videoFile.path),
          );

    final response = await request.send();

    if (response.statusCode == 200) {
      final res = await http.Response.fromStream(response);
      final data = jsonDecode(res.body);
      debugPrint("✅ Video uploaded: ${data["secure_url"]}");
      return data["secure_url"];
    } else {
      debugPrint("❌ Video upload failed: ${response.statusCode}");
      return null;
    }
  }

  Future<void> analyzeVideo() async {
    if (selectedVideo == null) return;

    final videoUrl = await uploadVideoToCloudinary(selectedVideo!);

    if (videoUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Video upload failed.")));
      return;
    }

    debugPrint("Uploading the video into cloudinary ");
    await api_service.analyzeASDVideoUrl(videoUrl);
    debugPrint("\nEnd of analysis");
  }

  Future<void> loadData() async {
    try {
      // Load the question structure (unchanged)
      final String response = await rootBundle.loadString(
        'assets/questions.json',
      );
      final List data = jsonDecode(response);
      final loadedQuestions =
          data.map((q) => QuestionModel.fromJson(q)).toList();

      final surveyState = context.read<SurveyState>();
      surveyState.initialize(loadedQuestions.length);

      // Step 1: Check SharedPreferences first (unchanged)
      final prefs = await SharedPreferences.getInstance();
      final savedScore = prefs.getInt('aqScore');
      final savedAnswers = prefs.getStringList('selectedAnswers');

      if (savedScore != null && savedScore > 0 && savedAnswers != null) {
        debugPrint(
          "✅ Found saved survey in SharedPreferences. Loading locally.",
        );

        aqScore = savedScore;
        for (int i = 0; i < savedAnswers.length; i++) {
          if (savedAnswers[i].isNotEmpty) {
            surveyState.updateAnswer(i, int.parse(savedAnswers[i]));
          }
        }
      } else {
        // Step 2: If no local data, call the API (unchanged)
        debugPrint("ℹ️ No local data found. Fetching from server...");
        final serverResults = await api_service.getSurveyResults();

        // --- THIS IS THE FIX ---
        // Check for the nested 'survey' object instead of 'responses' directly.
        if (serverResults != null && serverResults['survey'] != null) {
          debugPrint(
            "✅ Found previous survey on server. Populating and saving locally.",
          );

          // Extract the nested 'survey' object first.
          final Map<String, dynamic> surveyData = serverResults['survey'];

          // Now, access 'responses' and 'score' from the nested surveyData object.
          final List<dynamic> serverResponses = surveyData['responses'];
          final int serverScore = surveyData['score'];

          // The rest of the logic remains the same
          aqScore = serverScore;
          for (int i = 0; i < serverResponses.length; i++) {
            if (serverResponses[i].toString().isNotEmpty) {
              final answerIndex = fixedOptions.indexOf(serverResponses[i]);
              if (answerIndex != -1) {
                surveyState.updateAnswer(i, answerIndex);
              }
            }
          }

          await prefs.setInt('aqScore', serverScore);
          final answersToSave =
              surveyState.selectedAnswers
                  .map((e) => e?.toString() ?? "")
                  .toList();
          await prefs.setStringList('selectedAnswers', answersToSave);
          debugPrint(
            "📝 Server data saved to SharedPreferences for future offline access.",
          );
        } else {
          debugPrint("ℹ️ No survey data on server. Starting a fresh survey.");
        }
      }

      // Update the UI (unchanged)
      setState(() {
        questions = loadedQuestions;
        loading = false;
      });
    } catch (e) {
      debugPrint("❌ Failed to load data: $e");
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
      _videoController?.dispose(); // Dispose previous controller
      _videoController = VideoPlayerController.file(File(picked.path))
        ..initialize().then((_) {
          setState(() {}); // Refresh UI
        });
      setState(() => selectedVideo = File(picked.path));
    }
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
                const SizedBox(height: 20),
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
                      const SizedBox(height: 20),
                      // Video Preview
                      if (_videoController != null &&
                          _videoController!.value.isInitialized)
                        Column(
                          children: [
                            Text(
                              "Selected Video Preview",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange.shade800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _videoController!.value.isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    size: 40,
                                    color: Colors.deepOrange.shade700,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _videoController!.value.isPlaying
                                          ? _videoController!.pause()
                                          : _videoController!.play();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
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
