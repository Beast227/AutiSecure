import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoAnalysisCard extends StatefulWidget {
  final Map<String, dynamic> traits;
  final String prediction;
  final String confidence;
  final String videoUrl;

  const VideoAnalysisCard({
    super.key,
    required this.traits,
    required this.prediction,
    required this.confidence,
    required this.videoUrl,
  });

  @override
  State<VideoAnalysisCard> createState() => _VideoAnalysisCardState();
}

class _VideoAnalysisCardState extends State<VideoAnalysisCard> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Color _getPredictionColor() {
    return widget.prediction.toUpperCase() == "AUTISTIC"
        ? Colors.red.shade400
        : Colors.green.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Color.fromARGB(255, 243, 233, 219),
          width: 2,
        ),
      ),
      elevation: 8,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prediction Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getPredictionColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    widget.prediction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Confidence: ${widget.confidence}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isInitialized)
              Column(
                children: [
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: _videoController.value.aspectRatio,
                      child: VideoPlayer(_videoController),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _videoController.value.isPlaying
                          ? Icons.pause_circle_filled_outlined
                          : Icons.play_circle_fill_outlined,
                      size: 45,
                      color: Colors.deepOrange.shade700,
                    ),
                    onPressed: () {
                      setState(() {
                        _videoController.value.isPlaying
                            ? _videoController.pause()
                            : _videoController.play();
                      });
                    },
                  ),
                ],
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            SizedBox(height: 20),
            // Traits Table
            const Text(
              "Detected Traits",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Divider(height: 16, thickness: 1, color: Colors.orange),
            Column(
              children:
                  widget.traits.entries.map((entry) {
                    final isDetected = entry.value == 1 || entry.value == true;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Icon(
                            isDetected ? Icons.check_circle : Icons.cancel,
                            color:
                                isDetected
                                    ? Colors.green.shade600
                                    : Colors.red.shade200,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 16),

            // Video Section
          ],
        ),
      ),
    );
  }
}
