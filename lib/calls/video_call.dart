// lib/calls/video_call.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum CallState { ringing, connected, ended }

class VideoCall extends StatefulWidget {
  final IO.Socket socket;
  final String callerName;
  final String selfUserId; // string id of current user
  final String? peerUserId; // string id of peer (callee for caller, caller for callee)
  final String conversationId; // conversation id (useful for backend)
  final bool isCaller; // true when this client initiated the call

  const VideoCall({
    super.key,
    required this.socket,
    required this.callerName,
    required this.selfUserId,
    required this.peerUserId,
    required this.conversationId,
    this.isCaller = false,
  });

  @override
  State<VideoCall> createState() => _VideoCallState();
}

class _VideoCallState extends State<VideoCall> {
  late RTCVideoRenderer _localRenderer;
  late RTCVideoRenderer _remoteRenderer;
  MediaStream? _localStream;
  RTCPeerConnection? _pc;

  bool _isMuted = false;
  bool _isVideoOff = false;
  CallState _callState = CallState.ringing;
  bool _cleanupDone = false;

  @override
  void initState() {
    super.initState();
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    _initRenderers();
    _registerSocketHandlers();

    // If this screen was opened by caller, emit initiateCall
    if (widget.isCaller) {
      Future.microtask(() => _emitInitiateCall());
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    print("🎛 Renderers initialized");
  }

  void _registerSocketHandlers() {
    final s = widget.socket;

    print("🔗 Registering socket handlers in VideoCall (socket id=${s.id})");

    s.on('incomingCall', (data) {
      print("📲 incomingCall (shouldn't normally reach here inside active VideoCall): $data");
    });

    s.on('callAccepted', (data) async {
      print("✅ socket callAccepted => $data");
      if (!mounted) return;
      // Only proceed if this acceptance is for our conversation
      final conv = data['conversationId']?.toString();
      if (conv != widget.conversationId) {
        print("ℹ️ callAccepted for other conversation ($conv) - ignoring");
        return;
      }
      setState(() => _callState = CallState.connected);
      await _startLocalMediaAndPeer(asCaller: widget.isCaller);
    });

    s.on('callRejected', (data) {
      print("❌ socket callRejected => $data");
      if (!mounted) return;
      _showSnack("Call rejected by peer");
      _endCallLocal();
    });

    s.on('callEnded', (data) {
      print("🛑 socket callEnded => $data");
      if (!mounted) return;
      _showSnack("Call ended by peer");
      _endCallLocal();
    });

    s.on('offer', (data) async {
      print("📩 socket.offer => $data");
      // data: { offer: {sdp, type}, from: <userId>, conversationId: ... }
      final conv = data['conversationId']?.toString();
      if (conv != widget.conversationId) {
        print("ℹ️ offer for different conversation ($conv) -> ignore");
        return;
      }

      final offer = data['offer'];
      final from = data['from']?.toString();
      try {
        await _ensurePeerConnection();
        // If local media not started yet (callee), start local media and add tracks
        if (_localStream == null) {
          await _startLocalMediaAndPeer(asCaller: false);
        }
        await _pc!.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['type']));
        print("✅ Remote offer set, creating answer...");
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        widget.socket.emit('answer', {
          'conversationId': widget.conversationId,
          'answer': answer.toMap(),
          'to': from,
        });
        print("📤 Sent answer to $from");
      } catch (e, st) {
        print("❌ Error handling offer: $e\n$st");
      }
    });

    s.on('answer', (data) async {
      print("📩 socket.answer => $data");
      final conv = data['conversationId']?.toString();
      if (conv != widget.conversationId) {
        print("ℹ️ answer for different conversation ($conv) -> ignore");
        return;
      }
      final answer = data['answer'];
      try {
        await _pc?.setRemoteDescription(RTCSessionDescription(answer['sdp'], answer['type']));
        print("✅ Remote answer applied");
      } catch (e) {
        print("❌ Error applying remote answer: $e");
      }
    });

    s.on('ice-candidate', (data) async {
      // data: { candidate: {candidate, sdpMid, sdpMLineIndex}, from, conversationId }
      final conv = data['conversationId']?.toString();
      if (conv != widget.conversationId) {
        print("ℹ️ ice-candidate for different conversation ($conv) -> ignore");
        return;
      }
      final candidateMap = data['candidate'];
      if (candidateMap == null) return;
      try {
        final cand = RTCIceCandidate(
          candidateMap['candidate'],
          candidateMap['sdpMid'],
          candidateMap['sdpMLineIndex'],
        );
        await _pc?.addCandidate(cand);
        print("🧊 Added remote ICE candidate");
      } catch (e) {
        print("❌ Error adding remote ICE candidate: $e");
      }
    });

    print("🎥 Socket handlers registered");
  }

  Future<void> _emitInitiateCall() async {
    try {
      final payload = {
        'conversationId': widget.conversationId,
        'from': widget.selfUserId,
        'to': widget.peerUserId,
        'callerName': widget.callerName,
      };
      print("📞 Emitting initiateCall => $payload");
      widget.socket.emit('initiateCall', payload);
      // the server should then notify the callee (incomingCall) and eventually emit callAccepted to caller
    } catch (e) {
      print("⚠️ Failed to emit initiateCall: $e");
    }
  }

  Future<void> _startLocalMediaAndPeer({required bool asCaller}) async {
    print("🎬 startLocalMediaAndPeer(asCaller=$asCaller)");
    try {
      // 1) start local media if not started
      if (_localStream == null) {
        final constraints = {
          'audio': true,
          'video': {'facingMode': 'user', 'width': 640, 'height': 480},
        };
        final stream = await navigator.mediaDevices.getUserMedia(constraints);
        _localStream = stream;
        _localRenderer.srcObject = _localStream;
        print("✅ Local stream started, tracks: ${_localStream!.getTracks().length}");
      }

      // 2) create peer connection if missing and add tracks
      await _ensurePeerConnection();

      // Add local tracks
      _localStream?.getTracks().forEach((track) {
        try {
          _pc?.addTrack(track, _localStream!);
        } catch (e) {
          // ignore if track already added
        }
      });

      // 3) if caller, create offer and send
      if (asCaller) {
        final offer = await _pc!.createOffer();
        await _pc!.setLocalDescription(offer);
        widget.socket.emit('offer', {
          'conversationId': widget.conversationId,
          'offer': offer.toMap(),
          'to': widget.peerUserId,
        });
        print("📤 Offer sent to ${widget.peerUserId}");
      } else {
        print("⏳ Callee: waiting for remote offer...");
      }
    } catch (e, st) {
      print("❌ Error in startLocalMediaAndPeer: $e\n$st");
    }
  }

  Future<void> _ensurePeerConnection() async {
    if (_pc != null) return;
    print("🔧 Creating RTCPeerConnection...");
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        // add TURN servers for production
      ]
    };

    _pc = await createPeerConnection(config);

    _pc!.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate == null) return;
      final candidateObj = candidate.toMap();
      print("📤 onIceCandidate -> emit to ${widget.peerUserId}: $candidateObj");
      widget.socket.emit('ice-candidate', {
        'conversationId': widget.conversationId,
        'candidate': candidateObj,
        'to': widget.peerUserId,
      });
    };

    _pc!.onTrack = (RTCTrackEvent event) {
      print("🎧 onTrack event, streams: ${event.streams.length}");
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
        print("✅ Remote stream attached to renderer");
      }
    };

    _pc!.onConnectionState = (state) {
      print("🔁 PeerConnection state changed: $state");
    };

    print("✅ PeerConnection created");
  }

  void _toggleMute() {
    if (_localStream == null) {
      print("⚠️ toggleMute: no local stream");
      return;
    }
    final aud = _localStream!.getAudioTracks();
    if (aud.isEmpty) return;
    final enabled = !aud.first.enabled;
    for (var t in aud) t.enabled = enabled;
    setState(() => _isMuted = !enabled);
    print(_isMuted ? "🔇 Muted" : "🎙️ Unmuted");
  }

  void _toggleVideo() {
    if (_localStream == null) {
      print("⚠️ toggleVideo: no local stream");
      return;
    }
    final vids = _localStream!.getVideoTracks();
    if (vids.isEmpty) return;
    final enabled = !vids.first.enabled;
    for (var t in vids) t.enabled = enabled;
    setState(() => _isVideoOff = !enabled);
    print(_isVideoOff ? "📷 OFF" : "📷 ON");
  }

  Future<void> _cleanup() async {
    if (_cleanupDone) return;
    _cleanupDone = true;
    print("🧹 Cleanup starting...");

    try {
      try {
        _pc?.onIceCandidate = null;
        _pc?.onTrack = null;
        await _pc?.close();
      } catch (e) {
        print("⚠️ error closing pc: $e");
      }
      _pc = null;

      try {
        if (_localStream != null) {
          for (var t in _localStream!.getTracks()) {
            try {
              t.stop();
            } catch (e) {
              // ignore
            }
          }
          await _localStream?.dispose();
          _localStream = null;
        }
      } catch (e) {
        print("⚠️ error disposing local stream: $e");
      }

      try {
        _localRenderer.srcObject = null;
      } catch (_) {}
      try {
        _remoteRenderer.srcObject = null;
      } catch (_) {}

      try {
        await _localRenderer.dispose();
      } catch (_) {}
      try {
        await _remoteRenderer.dispose();
      } catch (_) {}
    } catch (e) {
      print("❌ cleanup error: $e");
    }

    print("✅ Cleanup done");
  }

  Future<void> _endCallLocal() async {
    try {
      // emit end to peer
      try {
        widget.socket.emit('endCall', {
          'conversationId': widget.conversationId,
          'from': widget.selfUserId,
          'to': widget.peerUserId,
        });
        print("📤 endCall emitted");
      } catch (e) {
        print("⚠️ emit endCall failed: $e");
      }
      setState(() => _callState = CallState.ended);
      await _cleanup();

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      print("❌ endCallLocal error: $e");
    }
  }

  @override
  void dispose() {
    print("🧹 VideoCall.dispose - removing socket handlers");
    try {
      widget.socket.off('incomingCall');
      widget.socket.off('callAccepted');
      widget.socket.off('callRejected');
      widget.socket.off('callEnded');
      widget.socket.off('offer');
      widget.socket.off('answer');
      widget.socket.off('ice-candidate');
    } catch (_) {}
    _cleanup();
    super.dispose();
  }

  Widget _buildRemoteViewCover() {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: RTCVideoView(_remoteRenderer),
      ),
    );
  }

  Widget _buildLocalPreview() {
    return SizedBox(
      width: 120,
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _localStream != null
            ? RTCVideoView(_localRenderer, mirror: true)
            : Container(
                color: Colors.grey.shade900,
                child: const Center(child: Icon(Icons.person, color: Colors.white)),
              ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    switch (_callState) {
      case CallState.ringing:
        bodyContent = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("📞 Calling ${widget.callerName}...", style: const TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              Text("Waiting for peer to accept...", style: const TextStyle(color: Colors.white70)),
            ],
          ),
        );
        break;
      case CallState.connected:
        bodyContent = Stack(children: [
          _buildRemoteViewCover(),
          Positioned(left: 16, bottom: 120, child: _buildLocalPreview()),
        ]);
        break;
      case CallState.ended:
        bodyContent = const Center(child: Text("Call ended", style: TextStyle(color: Colors.white, fontSize: 20)));
        break;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: bodyContent),
          if (_callState == CallState.connected)
            Positioned(top: 52, left: 16, child: Text(widget.callerName, style: const TextStyle(color: Colors.white, fontSize: 20))),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              FloatingActionButton(
                heroTag: 'mic',
                backgroundColor: Colors.white,
                onPressed: _toggleMute,
                child: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.black),
              ),
              FloatingActionButton(
                heroTag: 'end',
                backgroundColor: Colors.red,
                onPressed: _endCallLocal,
                child: const Icon(Icons.call_end),
              ),
              FloatingActionButton(
                heroTag: 'cam',
                backgroundColor: Colors.white,
                onPressed: _toggleVideo,
                child: Icon(_isVideoOff ? Icons.videocam_off : Icons.videocam, color: Colors.black),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
