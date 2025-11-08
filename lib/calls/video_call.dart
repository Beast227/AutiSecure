import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoCall extends StatefulWidget {
  final String callerName;
  final String selfUserId;
  final String peerUserId;

  const VideoCall({
    super.key,
    required this.callerName,
    required this.selfUserId,
    required this.peerUserId,
  });

  @override
  State<VideoCall> createState() => _VideoCallState();
}

class _VideoCallState extends State<VideoCall> {
  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _loadTokenAndInitCall();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.close();
    super.dispose();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _loadTokenAndInitCall() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');

    if (_token == null || _token!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Authentication token not found! Please log in again."),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
      return;
    }

    await _startCall();
  }

  Future<void> _startCall() async {
    final Map<String, dynamic> config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(config);

    MediaStream localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });

    _localRenderer.srcObject = localStream;
    localStream.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, localStream);
    });

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
      }
    };

    // Here you’d connect signaling (via your socket or API)
    print("Token used for signaling/auth: $_token");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          RTCVideoView(
            _remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          ),
          Positioned(
            top: 50,
            left: 20,
            child: Text(
              widget.callerName,
              style: const TextStyle(color: Colors.white, fontSize: 22),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 140,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  backgroundColor: Colors.white,
                  onPressed: () async {
                    setState(() => _micEnabled = !_micEnabled);
                    _localRenderer.srcObject?.getAudioTracks().forEach((t) {
                      t.enabled = _micEnabled;
                    });
                  },
                  child: Icon(
                    _micEnabled ? Icons.mic : Icons.mic_off,
                    color: Colors.black,
                  ),
                ),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(Icons.call_end),
                ),
                FloatingActionButton(
                  backgroundColor: Colors.white,
                  onPressed: () async {
                    setState(() => _cameraEnabled = !_cameraEnabled);
                    _localRenderer.srcObject?.getVideoTracks().forEach((t) {
                      t.enabled = _cameraEnabled;
                    });
                  },
                  child: Icon(
                    _cameraEnabled
                        ? Icons.videocam
                        : Icons.videocam_off,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
