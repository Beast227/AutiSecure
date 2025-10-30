import 'dart:convert';
import 'dart:io';

// Ensure correct path for api_service
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

// Ensure correct paths for local imports
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

// 1. ADD 'with AutomaticKeepAliveClientMixin'
class _TestScreenState extends State<TestScreen>
    with AutomaticKeepAliveClientMixin {
  List<QuestionModel> questions = [];
  int aqScore = 0;
  bool loading = true; // For initial survey data load
  bool showScoreAnimation = false;

  // --- Video State Variables ---
  File? selectedVideo;
  VideoPlayerController? _videoController;
  bool _isUploading = false; // To show progress/disable buttons
  bool _isAnalyzing = false; // To show progress/disable buttons
  // --- End Video State ---

  final List<String> fixedOptions = [
    "Strongly Agree",
    "Agree",
    "Disagree",
    "Strongly Disagree",
  ];

  // 2. OVERRIDE 'wantKeepAlive' AND RETURN TRUE
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    loadSurveyData(); // Renamed for clarity
  }

  @override
  void dispose() {
    _videoController?.dispose(); // Dispose video controller
    super.dispose();
  }

  // Helper to safely show SnackBars
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.orangeAccent, // Use theme color
      ),
    );
  }


  // --- Score Interpretation Helpers ---
  String _getScoreInterpretation(int score) {
    if (score <= 25) {
      return "Within the typical (non-autistic) range";
    } else if (score >= 26 && score <= 31) {
      return "Borderline / Intermediate";
    } else {
      return "Indicates clinically significant autistic traits (high likelihood)";
    }
  }

  Color _getScoreColor(int score) {
    if (score <= 25) {
      return Colors.green; // Typical
    } else if (score >= 26 && score <= 31) {
      return Colors.orange; // Borderline
    } else {
      return Colors.red; // High Likelihood
    }
  }

  // --- Video Helper Functions ---

  Future<void> pickVideo() async {
    // Disable if already processing
    if (_isUploading || _isAnalyzing) return;

    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      _videoController?.dispose(); // Dispose previous controller
      _videoController = VideoPlayerController.file(File(picked.path))
        ..initialize().then((_) {
          if (mounted) setState(() {}); // Refresh UI for preview
        });
      if (mounted) setState(() => selectedVideo = File(picked.path));
    }
  }

  Future<String?> uploadVideoToCloudinary(File videoFile) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

    if (cloudName == null || uploadPreset == null) {
     debugPrint("Cloudinary credentials missing in .env");
     _showSnackBar("Cloudinary configuration error.", isError: true);
     return null;
    }

    if (mounted) setState(() => _isUploading = true); // Show uploading state
    _showSnackBar("Uploading video..."); // Inform user

    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/video/upload",
    );

    try {
      final request = http.MultipartRequest("POST", url)
        ..fields["upload_preset"] = uploadPreset! // Use non-null preset
        ..files.add(
          await http.MultipartFile.fromPath("file", videoFile.path),
        );

      final response = await request.send();

      if (response.statusCode == 200) {
        final res = await http.Response.fromStream(response);
        final data = jsonDecode(res.body);
        debugPrint("✅ Video uploaded: ${data["secure_url"]}");
        _showSnackBar("Video uploaded successfully."); // Success feedback
        return data["secure_url"];
      } else {
        debugPrint("❌ Video upload failed: ${response.statusCode}");
         final res = await http.Response.fromStream(response);
         debugPrint("Error Body: ${res.body}");
         _showSnackBar("Video upload failed (${response.statusCode}). Check logs.", isError: true);
        return null;
      }
    } catch (e) {
      debugPrint("❌ Error uploading video: $e");
       _showSnackBar("Error during video upload: $e", isError: true);
      return null;
    } finally {
      if(mounted) setState(() => _isUploading = false); // Hide uploading state
    }
  }

  Future<void> analyzeVideo() async {
    if (selectedVideo == null || _isUploading || _isAnalyzing) {
      _showSnackBar("Please select a video first, or wait for the current operation.", isError: true);
      return;
    }
    if (!mounted) return;

    final videoUrl = await uploadVideoToCloudinary(selectedVideo!);

    if (videoUrl == null) {
      // Error snackbar is shown in uploadVideoToCloudinary
      return;
    }

    // Video uploaded successfully, now analyze
    if (!mounted) return;
    setState(() => _isAnalyzing = true); // Show analyzing state
    _showSnackBar("Video uploaded. Starting analysis...");

    try {
      debugPrint("Sending URL for analysis: $videoUrl");
      await api_service.analyzeASDVideoUrl(videoUrl);
      debugPrint("\nEnd of analysis request trigger.");
      _showSnackBar("Video analysis request sent. Results will be available soon."); // Inform user
    } catch (e) {
     debugPrint("❌ Error sending video for analysis: $e");
      _showSnackBar("Error starting analysis: $e", isError: true);
    } finally {
      if(mounted) setState(() => _isAnalyzing = false); // Hide analyzing state
    }
  }

  // --- Survey Data Loading and Submission ---

  Future<void> loadSurveyData() async { // Renamed from loadData
    setState(() => loading = true); // Ensure loading is true at start
    try {
      final String response = await rootBundle.loadString('assets/questions.json');
      final List data = jsonDecode(response);
      final loadedQuestions = data.map((q) => QuestionModel.fromJson(q)).toList();

      if (!mounted) return;
      final surveyState = context.read<SurveyState>();
      surveyState.initialize(loadedQuestions.length);

      final prefs = await SharedPreferences.getInstance();
      final savedScore = prefs.getInt('aqScore');
      final savedAnswers = prefs.getStringList('selectedAnswers');

      if (savedScore != null && savedScore > 0 && savedAnswers != null) {
        debugPrint("✅ Loading survey from SharedPreferences.");
        aqScore = savedScore;
        for (int i = 0; i < savedAnswers.length && i < surveyState.selectedAnswers.length; i++) {
          if (savedAnswers[i].isNotEmpty) {
            surveyState.updateAnswer(i, int.tryParse(savedAnswers[i]));
          }
        }
      } else {
        debugPrint("ℹ️ No local survey data. Fetching from server...");
        final serverResults = await api_service.getSurveyResults(); 

        if (serverResults != null && serverResults['survey'] != null && serverResults['survey'] is Map) {
           debugPrint("✅ Found survey on server.");
           final Map<String, dynamic> surveyData = serverResults['survey'];
           final List<dynamic>? serverResponses = surveyData['responses'] as List?;
           final int? serverScore = surveyData['score'] as int?;

            if (serverScore != null && serverResponses != null) {
                 aqScore = serverScore;
                 List<String> answersToSave = List.filled(loadedQuestions.length, ""); 

                 for (int i = 0; i < serverResponses.length && i < loadedQuestions.length; i++) {
                    if (serverResponses[i] != null && serverResponses[i].toString().isNotEmpty) {
                       final answerIndex = fixedOptions.indexOf(serverResponses[i].toString());
                       if (answerIndex != -1) {
                         surveyState.updateAnswer(i, answerIndex);
                          answersToSave[i] = answerIndex.toString(); 
                       }
                    }
                 }
                  await prefs.setInt('aqScore', serverScore);
                  await prefs.setStringList('selectedAnswers', answersToSave);
                  debugPrint("📝 Server data saved to SharedPreferences.");
            } else {
                 debugPrint("⚠️ Server survey data format incorrect (missing score or responses).");
            }

        } else {
          debugPrint("ℹ️ No survey data on server or incorrect format.");
           await prefs.remove('aqScore');
           await prefs.remove('selectedAnswers');
        }
      }

       if(mounted) {
         setState(() {
           questions = loadedQuestions;
         });
       }

    } catch (e) {
      debugPrint("❌ Failed to load survey data: $e");
       if(mounted) _showSnackBar("Failed to load survey data: $e", isError: true);
        if(mounted) {
            setState(() {
               questions = []; 
               aqScore = 0;
            });
        }
    } finally {
        if(mounted) setState(() => loading = false); 
    }
  }


 Future<void> submitAnswers() async { 
    if (aqScore > 0 || _isUploading || _isAnalyzing) return;

    final surveyState = context.read<SurveyState>();

     if (surveyState.selectedAnswers.contains(null)) {
        _showSnackBar("Please answer all questions before submitting.", isError: true);
        return;
     }


    List<String> responses = surveyState.selectedAnswers
        .map((index) => index != null ? fixedOptions[index] : "")
        .toList();

    Map<String, dynamic> payload = {"surveyResponse": responses};
    debugPrint("Survey Payload: ${jsonEncode(payload)}");
     _showSnackBar("Submitting survey..."); 

    try {
        final result = await api_service.submitSurvey(payload); 
        debugPrint("Submit API response: $result");

        if (!mounted) return; 

        if (result["score"] != null && result["score"] is int) {
           final receivedScore = result["score"] as int;
           setState(() {
             aqScore = receivedScore;
             showScoreAnimation = true; 
           });

           final prefs = await SharedPreferences.getInstance();
           await prefs.setInt('aqScore', aqScore);
           final answersToSave = surveyState.selectedAnswers
               .map((e) => e?.toString() ?? "")
               .toList();
           await prefs.setStringList('selectedAnswers', answersToSave);

            _showSnackBar(result["message"] ?? "Survey submitted successfully!");

        } else {
             _showSnackBar(result["message"] ?? "Survey submitted, but score not received.", isError: true);
        }
    } catch (e) {
        debugPrint("❌ Error submitting survey: $e");
         if (!mounted) return;
         _showSnackBar("Error submitting survey: $e", isError: true);
    }
  }


  double getProgress(List<int?> selectedAnswers) {
    int answered = selectedAnswers.where((e) => e != null).length;
    return questions.isNotEmpty ? answered / questions.length : 0.0;
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // 3. CALL super.build(context)
    super.build(context);

    if (loading) {
      return const Scaffold(
          backgroundColor: Color(0xFFFFF5E3), // Match theme
          body: Center(child: CircularProgressIndicator(color: Colors.orange))
      );
    }

    return Consumer<SurveyState>(
      builder: (context, surveyState, _) {
        final double currentProgress = getProgress(surveyState.selectedAnswers);
        final bool canSubmitSurvey = !surveyState.selectedAnswers.contains(null);

        return Scaffold(
          backgroundColor: const Color(0xFFFFF5E3), // Match other screens
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
                // --- Score Display Card (Shows if score exists) ---
                if (aqScore > 0)
                  ZoomIn( 
                    duration: const Duration(milliseconds: 500),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15), 
                      ),
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
                              radius: 65.0, 
                              lineWidth: 10.0,
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
                             Padding(
                               padding: const EdgeInsets.symmetric(horizontal: 10.0),
                               child: Text(
                                _getScoreInterpretation(aqScore),
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.w500,
                                  color: _getScoreColor(aqScore),
                                ),
                                textAlign: TextAlign.center,
                               ),
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                // --- Survey Questions Section (Shows if score is 0) ---
                else if (questions.isNotEmpty) ...[
                  FadeInDown( 
                     duration: const Duration(milliseconds: 400),
                    child: ProgressHeader(
                      currentIndex: surveyState.currentIndex,
                      totalQuestions: questions.length,
                      progress: currentProgress, 
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                     transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SizeTransition(sizeFactor: animation, child: child)
                     ),
                    child: QuestionCard(
                      key: ValueKey('question_${surveyState.currentIndex}'),
                      question: questions[surveyState.currentIndex],
                      options: fixedOptions,
                      selectedAnswer:
                          surveyState.selectedAnswers[surveyState.currentIndex],
                      onOptionSelected: (value) {
                        surveyState.updateAnswer(surveyState.currentIndex, value);
                      },
                    ),
                  ),
                  const SizedBox(height: 20), 
                  NavigationButtons(
                    isFirstQuestion: surveyState.currentIndex == 0,
                    isLastQuestion: surveyState.currentIndex == questions.length - 1,
                    onNext: surveyState.nextQuestion,
                    onBack: surveyState.previousQuestion,
                    onSubmit: submitAnswers, 
                    canSubmit: canSubmitSurvey, 
                  ),
                ] else if (!loading) 
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Icon(Icons.error_outline, color: Colors.red.shade300, size: 40),
                             const SizedBox(height: 10),
                             const Text(
                                "Could not load survey questions.\nPlease check your connection and try again.",
                                style: TextStyle(color: Colors.red, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 15),
                              ElevatedButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text("Retry"),
                                  onPressed: loadSurveyData, 
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              )
                           ],
                        ),
                      )
                    ),


                // --- Video Section (Always visible below survey/score) ---
                const Divider(thickness: 1.5, height: 40, indent: 20, endIndent: 20),
                FadeInUp( 
                   duration: const Duration(milliseconds: 500),
                  child: Column(
                    children: [
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
                          style: TextStyle(
                           fontSize: 14,
                           color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: (_isUploading || _isAnalyzing) ? null : pickVideo,
                            icon: const Icon(Icons.video_library_outlined, size: 20), 
                            label: const Text("Choose Video"),
                            style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.orange, 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: (selectedVideo == null || _isUploading || _isAnalyzing) ? null : analyzeVideo,
                             style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.deepOrange, 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                enableFeedback: !(selectedVideo == null || _isUploading || _isAnalyzing)
                            ),
                            icon: _isUploading || _isAnalyzing
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.analytics_outlined, size: 20),
                            label: Text(_isUploading ? "Uploading..." : _isAnalyzing ? "Analyzing..." : "Analyze"),

                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      // Video Preview
                      if (_videoController != null &&
                          _videoController!.value.isInitialized)
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
                         const Center(child: Padding(
                           padding: EdgeInsets.all(12.0),
                           child: CircularProgressIndicator(color: Colors.orange),
                         )),
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