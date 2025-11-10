import 'dart:convert';
import 'dart:io';

import 'package:animations/animations.dart';
import 'package:autisecure/widgets/analysis/video_analysis.dart';
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
import 'package:video_compress/video_compress.dart';
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

class _TestScreenState extends State<TestScreen>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _analysisData;
  List<QuestionModel> questions = [];
  int aqScore = 0;
  bool loading = true;
  bool showScoreAnimation = false;

  File? selectedVideo;
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  bool _isAnalyzing = false;

  final List<String> fixedOptions = [
    "Strongly Agree",
    "Agree",
    "Disagree",
    "Strongly Disagree",
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    loadSurveyData();
    _loadAnalysisFromPrefsAndSetState();
    loadLatestVideoAnalysisFromServer();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.orangeAccent,
      ),
    );
  }

  String _getScoreInterpretation(int score) {
    if (score <= 25) return "Within the typical (non-autistic) range";
    if (score <= 31) return "Borderline / Intermediate";
    return "Indicates clinically significant autistic traits (high likelihood)";
  }

  Color _getScoreColor(int score) {
    if (score <= 25) return Colors.green;
    if (score <= 31) return Colors.orange;
    return Colors.red;
  }

  // ---------------- Video Handling ----------------
  Future<void> pickVideo() async {
    if (_isUploading || _isAnalyzing) return;

    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);

    if (picked != null) {
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(File(picked.path))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });

      if (mounted) setState(() => selectedVideo = File(picked.path));
    }
  }

  // Upload video to Cloudinary
  Future<String?> uploadVideoToCloudinary(File videoFile) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

    if (cloudName == null || uploadPreset == null) {
      _showSnackBar("Cloudinary configuration missing.", isError: true);
      return null;
    }

    if (!mounted) return null;
    setState(() => _isUploading = true);
    _showSnackBar("Uploading video...");

    try {
      File fileToUpload = videoFile;

      // Compress video before uploading
      final compressed = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (compressed?.file != null) fileToUpload = compressed!.file!;

      final url = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudName/video/upload",
      );

      final request =
          http.MultipartRequest("POST", url)
            ..fields["upload_preset"] = uploadPreset
            ..files.add(
              await http.MultipartFile.fromPath("file", fileToUpload.path),
            );

      final response = await request.send().timeout(const Duration(minutes: 5));
      final resBody = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(resBody.body);
        _showSnackBar("Video uploaded successfully.");
        debugPrint("✅ Video uploaded successfully: ${data['secure_url']}");
        return data["secure_url"];
      } else {
        _showSnackBar("Upload failed (${response.statusCode})", isError: true);
        debugPrint("❌ Upload failed: ${resBody.body}");
        return null;
      }
    } catch (e, stackTrace) {
      _showSnackBar("Error uploading video: $e", isError: true);
      debugPrint("❌ Error uploading video: $e");
      debugPrint(stackTrace.toString());
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // Analyze the video after upload
  Future<void> analyzeVideo() async {
    if (selectedVideo == null || _isUploading || _isAnalyzing) {
      _showSnackBar(
        "Select a video or wait for ongoing process.",
        isError: true,
      );
      return;
    }

    final videoUrl = await uploadVideoToCloudinary(selectedVideo!);
    if (videoUrl == null) return;

    setState(() => _isAnalyzing = true);
    _showSnackBar("Uploading video...");

    try {
      final accepted = await api_service.analyzeASDVideoUrl(videoUrl);

      if (!mounted) return;

      if (accepted) {
        _showSnackBar("✅ Analysis started.\nReturn later to see the report.");
        debugPrint("✅ Server returned 202. Processing asynchronously.");
      } else {
        _showSnackBar("⚠️ Server did not accept video.", isError: true);
      }
    } catch (e, stackTrace) {
      _showSnackBar("❌ Error analyzing video: $e", isError: true);
      debugPrint("❌ Error analyzing video: $e\n$stackTrace");
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // Save analysis locally in structured JSON format
  Future<void> _saveAnalysisToPrefs({
    required Map<String, dynamic> traits,
    required String prediction,
    required String confidence,
    required String videoUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final Map<String, dynamic> analysisData = {
        "traits": traits,
        "prediction": prediction,
        "confidence": confidence,
        "videoUrl": videoUrl,
        "timestamp": DateTime.now().toIso8601String(),
      };

      await prefs.setString("asd_analysis", jsonEncode(analysisData));

      debugPrint("✅ Analysis saved locally in structured format.");
    } catch (e, stackTrace) {
      debugPrint("❌ Error saving analysis to prefs: $e");
      debugPrint(stackTrace.toString());
      _showSnackBar("Failed to save analysis locally.", isError: true);
    }
  }

  // Load analysis from SharedPreferences safely
  Future<void> _loadAnalysisFromPrefsAndSetState() async {
    try {
      final Map<String, dynamic>? analysisData = await _loadAnalysisFromPrefs();
      if (analysisData != null && mounted) {
        setState(() {});
        debugPrint("✅ Loaded analysis from prefs: $analysisData");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Failed to load analysis from prefs: $e");
      debugPrint(stackTrace.toString());
      _showSnackBar("Failed to load analysis.", isError: true);
    }
  }

  // Helper to read SharedPreferences safely
  Future<Map<String, dynamic>?> _loadAnalysisFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString('asd_analysis');

      debugPrint("✅ Raw analysis data from prefs: $jsonData");

      if (jsonData == null) return null;

      return jsonDecode(jsonData);
    } catch (e, stackTrace) {
      debugPrint("❌ Error reading analysis from prefs: $e");
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  Future<void> loadLatestVideoAnalysisFromServer() async {
    try {
      final List<dynamic> reports = await api_service.getASDVideoReports();

      if (reports.isEmpty) {
        debugPrint("ℹ️ No previous reports found.");
        return;
      }

      final latest =
          reports.first; // assuming backend returns sorted (newest first)
      debugPrint("✅ Latest Report: $latest");

      // Safely parse values
      final traits = Map<String, dynamic>.from(latest["detected_traits"] ?? {});

      final prediction =
          latest["final_prediction"]?["label"]?.toString() ??
          latest["final_prediction"]?["prediction"]?.toString() ??
          "UNKNOWN";

      // Ensure confidence always in percentage text form
      final rawConfidence = latest["final_prediction"]?["confidence"];
      final confidence =
          rawConfidence is num
              ? "${(rawConfidence * 100).toStringAsFixed(2)}%"
              : rawConfidence?.toString() ?? "0%";

      final videoUrl = latest["videoUrl"]?.toString() ?? "";

      // Save to SharedPreferences
      await _saveAnalysisToPrefs(
        traits: traits,
        prediction: prediction,
        confidence: confidence,
        videoUrl: videoUrl,
      );

      // Now refresh UI by loading again and updating state
      final data = await _loadAnalysisFromPrefs();
      if (!mounted) return;
      setState(() {
        _analysisData = data;
      });

      debugPrint("✅ Video analysis loaded & UI updated successfully.");
    } catch (e, stackTrace) {
      debugPrint("❌ Error loading previous analysis: $e");
      debugPrint(stackTrace.toString());
    }
  }

  // ---------------- Survey Handling ----------------
  Future<void> loadSurveyData() async {
    setState(() => loading = true);
    try {
      final jsonStr = await rootBundle.loadString('assets/questions.json');
      final data = jsonDecode(jsonStr) as List;
      final loadedQuestions =
          data.map((q) => QuestionModel.fromJson(q)).toList();

      final surveyState = context.read<SurveyState>();
      surveyState.initialize(loadedQuestions.length);

      final prefs = await SharedPreferences.getInstance();
      final savedScore = prefs.getInt('aqScore');
      final savedAnswers = prefs.getStringList('selectedAnswers');

      if (savedScore != null && savedScore > 0 && savedAnswers != null) {
        aqScore = savedScore;
        for (
          int i = 0;
          i < savedAnswers.length && i < surveyState.selectedAnswers.length;
          i++
        ) {
          surveyState.updateAnswer(i, int.tryParse(savedAnswers[i]));
        }
      } else {
        // Optionally load from server
        final serverResults = await api_service.getSurveyResults();
        if (serverResults != null && serverResults['survey'] != null) {
          final Map<String, dynamic> surveyData = serverResults['survey'];
          final List<dynamic>? serverResponses =
              surveyData['responses'] as List?;
          final int? serverScore = surveyData['score'] as int?;
          if (serverScore != null && serverResponses != null) {
            aqScore = serverScore;
            for (
              int i = 0;
              i < serverResponses.length && i < loadedQuestions.length;
              i++
            ) {
              final idx = fixedOptions.indexOf(serverResponses[i].toString());
              if (idx != -1) surveyState.updateAnswer(i, idx);
            }
            await prefs.setInt('aqScore', serverScore);
          }
        }
      }

      if (mounted) setState(() => questions = loadedQuestions);
    } catch (e) {
      debugPrint("Failed to load survey: $e");
      _showSnackBar("Failed to load survey: $e", isError: true);
      setState(() {
        questions = [];
        aqScore = 0;
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submitAnswers() async {
    final surveyState = context.read<SurveyState>();
    if (surveyState.selectedAnswers.contains(null)) {
      _showSnackBar("Please answer all questions.", isError: true);
      return;
    }

    List<String> responses =
        surveyState.selectedAnswers
            .map((i) => i != null ? fixedOptions[i] : "")
            .toList();
    final payload = {"surveyResponse": responses};

    try {
      final result = await api_service.submitSurvey(payload);
      if (!mounted) return;
      debugPrint("$result");
      debugPrint("✅ error submitting data");
      final receivedScore = result["score"] as int?;
      if (receivedScore != null) {
        setState(() {
          aqScore = receivedScore;
          showScoreAnimation = true;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('aqScore', aqScore);
        await prefs.setStringList(
          'selectedAnswers',
          surveyState.selectedAnswers.map((e) => e?.toString() ?? "").toList(),
        );

        _showSnackBar(result["message"] ?? "Survey submitted successfully!");
        debugPrint(result["message"] ?? "Survey submitted successfully!");
        debugPrint("✅ error submitting data");
      } else {
        _showSnackBar(
          result["message"] ?? "Score not received.",
          isError: true,
        );
        debugPrint(result["message"] ?? "✅Score not received.");
        debugPrint("✅ error submitting data");
      }
    } catch (e) {
      _showSnackBar("Error submitting survey: $e", isError: true);
      debugPrint("✅Error submitting survey: $e");
    }
  }

  double getProgress(List<int?> selectedAnswers) {
    int answered = selectedAnswers.where((e) => e != null).length;
    return questions.isNotEmpty ? answered / questions.length : 0.0;
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF5E3),
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    return Consumer<SurveyState>(
      builder: (context, surveyState, _) {
        final progress = getProgress(surveyState.selectedAnswers);
        final canSubmitSurvey = !surveyState.selectedAnswers.contains(null);

        return Scaffold(
          backgroundColor: const Color(0xFFFFF5E3),
          appBar: AppBar(
            title: const Text(
              "Autism Screening",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
                fontFamily: "Merriweather",
              ),
            ),
            backgroundColor: const Color(0xFFFFF2E0),
            elevation: 1,
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- AQ Score ---
                if (aqScore > 0)
                  ZoomIn(
                    duration: const Duration(milliseconds: 500),
                    child: _buildScoreCard(surveyState),
                  )
                // --- Survey ---
                else if (questions.isNotEmpty) ...[
                  FadeInDown(
                    duration: const Duration(milliseconds: 400),
                    child: ProgressHeader(
                      currentIndex: surveyState.currentIndex,
                      totalQuestions: questions.length,
                      progress: progress,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // *** Updated Animation Section ***
                  PageTransitionSwitcher(
                    duration: const Duration(milliseconds: 750),
                    transitionBuilder: (
                      Widget child,
                      Animation<double> primaryAnimation,
                      Animation<double> secondaryAnimation,
                    ) {
                      return SharedAxisTransition(
                        animation: primaryAnimation,
                        secondaryAnimation: secondaryAnimation,
                        transitionType: SharedAxisTransitionType.horizontal,
                        child: child,
                      );
                    },
                    child: QuestionCard(
                      key: ValueKey('question_${surveyState.currentIndex}'),
                      question: questions[surveyState.currentIndex],
                      options: fixedOptions,
                      selectedAnswer:
                          surveyState.selectedAnswers[surveyState.currentIndex],
                      onOptionSelected: (value) {
                        surveyState.updateAnswer(
                          surveyState.currentIndex,
                          value,
                        );

                        // Move to next question automatically *if not last*
                        if (surveyState.currentIndex < questions.length - 1) {
                          Future.delayed(const Duration(milliseconds: 300), () {
                            surveyState.nextQuestion();
                          });
                        } else {
                          // Auto-submit when last answer is selected
                          submitAnswers();
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  NavigationButtons(
                    isFirstQuestion: surveyState.currentIndex == 0,
                    isLastQuestion:
                        surveyState.currentIndex == questions.length - 1,
                    onNext: surveyState.nextQuestion,
                    onBack: surveyState.previousQuestion,
                    onSubmit: submitAnswers,
                    canSubmit: canSubmitSurvey,
                  ),
                ],
                const SizedBox(height: 30),

                // --- Video Section ---
                const Divider(
                  thickness: 1.5,
                  height: 40,
                  indent: 20,
                  endIndent: 20,
                ),
                _buildVideoSection(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreCard(SurveyState surveyState) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    elevation: 4,
    margin: const EdgeInsets.symmetric(vertical: 8.0),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            "Your AQ Score",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          CircularPercentIndicator(
            radius: 65,
            lineWidth: 10,
            percent: (aqScore / 50).clamp(0.0, 1.0),
            center: Text(
              "$aqScore",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: _getScoreColor(aqScore),
              ),
            ),
            progressColor: _getScoreColor(aqScore),
            backgroundColor: Colors.grey.shade300,
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 1200,
          ),
          const SizedBox(height: 15),
          Text(
            _getScoreInterpretation(aqScore),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _getScoreColor(aqScore),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 20),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('aqScore');
              await prefs.remove('selectedAnswers');
              surveyState.reset();
              setState(() {
                aqScore = 0;
                showScoreAnimation = false;
              });
              _showSnackBar("Survey reset.");
            },
            label: const Text(
              "Retake Survey",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildVideoSection() => FadeInUp(
    duration: const Duration(milliseconds: 500),
    child: Column(
      children: [
        // Title
        const Text(
          "Optional: Upload Video for Analysis",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          "(Recommended for ages 3-12)",
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),

        // Selected Video Name
        if (selectedVideo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              "Selected: ${selectedVideo!.path.split('/').last}",
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // Buttons Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: (_isUploading || _isAnalyzing) ? null : pickVideo,
              icon: const Icon(Icons.video_library_outlined, size: 20),
              label: const Text("Choose Video"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed:
                  (selectedVideo == null || _isUploading || _isAnalyzing)
                      ? null
                      : analyzeVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon:
                  _isUploading || _isAnalyzing
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.analytics_outlined, size: 20),
              label: Text(
                _isUploading
                    ? "Uploading..."
                    : _isAnalyzing
                    ? "Analyzing..."
                    : "Analyze",
              ),
            ),
          ],
        ),

        const SizedBox(height: 25),

        // Video Preview
        if (_videoController != null && _videoController!.value.isInitialized)
          Column(
            children: [
              Text(
                "Video Preview",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange.shade800,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              ),
              IconButton(
                icon: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause_circle_filled_outlined
                      : Icons.play_circle_fill_outlined,
                  size: 45,
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
          )
        else if (selectedVideo != null)
          const Center(child: CircularProgressIndicator(color: Colors.orange)),

        const SizedBox(height: 20),

        // ====== ANALYSIS RESULTS SECTION ======
        if (_analysisData == null)
          const Text(
            "No analysis data available.",
            style: TextStyle(color: Colors.grey),
          )
        else
          VideoAnalysisCard(
            traits: Map<String, dynamic>.from(_analysisData!['traits'] ?? {}),
            prediction: _analysisData!['prediction'] ?? "UNKNOWN",
            confidence: _analysisData!['confidence'] ?? "0%",
            videoUrl: _analysisData!['videoUrl'] ?? "",
          ),
      ],
    ),
  );
}
