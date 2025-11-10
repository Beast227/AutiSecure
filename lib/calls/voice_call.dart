import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum VoiceCallState { ringing, connected, ended }

class VoiceCall extends StatefulWidget {
  final IO.Socket socket;
  final String callerName;
  final String selfUserId;
  final String? peerUserId;
  final String conversationId;
  final bool isCaller;
  final String? peerSocketId;

  const VoiceCall({
    super.key,
    required this.socket,
    required this.callerName,
    required this.selfUserId,
    required this.peerUserId,
    required this.conversationId,
    this.isCaller = false,
    this.peerSocketId,
  });

  @override
  State<VoiceCall> createState() => _VoiceCallState();
}

class _VoiceCallState extends State<VoiceCall> {
  MediaStream? _localStream;
  RTCPeerConnection? _pc;

  String? _peerSocketId;
  bool _isMuted = false;
  VoiceCallState _callState = VoiceCallState.ringing;
  bool _cleanupDone = false;
  bool _localMediaStarted = false;

  @override
  void initState() {
    super.initState();

    _peerSocketId = widget.peerSocketId;
    _callState =
        widget.isCaller ? VoiceCallState.ringing : VoiceCallState.connected;

    _registerSocketHandlers();
  }

  void _registerSocketHandlers() {
    final s = widget.socket;

    s.off('callAccepted');
    s.on('callAccepted', (data) async {
      if (data['conversationId'] != widget.conversationId) return;

      if (widget.isCaller) {
        _peerSocketId = data['calleeSocketId']?.toString();
      }

      if (_callState == VoiceCallState.ringing) {
        setState(() => _callState = VoiceCallState.connected);
        await _startLocalAudio(asCaller: widget.isCaller);
      }
    });

    s.off('callEnded');
    s.on('callEnded', (_) => _endCallLocal());
  }

  Future<void> _startLocalAudio({required bool asCaller}) async {
    if (_localMediaStarted) return;
    _localMediaStarted = true;

    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    _localStream = stream;

    await _ensurePeerConnection();

    for (var track in stream.getAudioTracks()) {
      _pc?.addTrack(track, stream);
    }

    if (asCaller && _peerSocketId != null) {
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      widget.socket.emit('offer', {
        'conversationId': widget.conversationId,
        'offer': offer.toMap(),
        'to': _peerSocketId,
      });
    }
  }

  Future<void> _ensurePeerConnection() async {
    if (_pc != null) return;
    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });
  }

  void _toggleMute() {
    if (_localStream == null) return;
    final audioTrack = _localStream!.getAudioTracks().first;
    audioTrack.enabled = !audioTrack.enabled;
    setState(() => _isMuted = !audioTrack.enabled);
  }

  Future<void> _endCallLocal() async {
    setState(() => _callState = VoiceCallState.ended);
    await _cleanup();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cleanup() async {
    if (_cleanupDone) return;
    _cleanupDone = true;

    try {
      _pc?.close();
      _pc = null;
      _localStream?.dispose();
      _localStream = null;
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_callState != VoiceCallState.ended) _endCallLocal();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget mainContent;

    switch (_callState) {
      case VoiceCallState.ringing:
        mainContent = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_in_talk, color: Colors.white, size: 80),
            const SizedBox(height: 16),
            Text(
              "Calling ${widget.callerName}...",
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 10),
            const CircularProgressIndicator(color: Colors.white),
          ],
        );
        break;

      case VoiceCallState.connected:
        mainContent = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 120, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              widget.callerName,
              style: const TextStyle(color: Colors.white, fontSize: 22),
            ),
            const SizedBox(height: 6),
            const Text(
              "Voice Call Connected",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        );
        break;

      case VoiceCallState.ended:
        mainContent = const Center(
          child: Text(
            "Call Ended",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        );
        break;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: mainContent),

          if (_callState != VoiceCallState.ended)
            Positioned(
              bottom: 40,
              right: 0,
              left: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    backgroundColor: _isMuted ? Colors.red : Colors.white,
                    onPressed: _toggleMute,
                    child: Icon(
                      _isMuted ? Icons.mic_off : Icons.mic,
                      color: _isMuted ? Colors.white : Colors.black,
                    ),
                  ),
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: _endCallLocal,
                    child: const Icon(Icons.call_end),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
