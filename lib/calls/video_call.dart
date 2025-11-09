import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum CallState { ringing, connected, ended }

class VideoCall extends StatefulWidget {
  final IO.Socket socket;
  final String callerName;
  final String selfUserId; // string id of current user
  final String?
  peerUserId; // string id of peer (callee for caller, caller for callee)
  final String conversationId; // conversation id (useful for backend)
  final bool isCaller; // true when this client initiated the call
  final String? peerSocketId; // <-- ADDED: Known socket ID of peer (for callee)

  const VideoCall({
    super.key,
    required this.socket,
    required this.callerName,
    required this.selfUserId,
    required this.peerUserId,
    required this.conversationId,
    this.isCaller = false,
    this.peerSocketId, // <-- ADDED
  });

  @override
  State<VideoCall> createState() => _VideoCallState();
}

class _VideoCallState extends State<VideoCall> {
  late RTCVideoRenderer _localRenderer;
  late RTCVideoRenderer _remoteRenderer;
  MediaStream? _localStream;
  RTCPeerConnection? _pc;

  String? _peerSocketId; // <-- ADDED: Stores the peer's socket ID
  bool _isMuted = false;
  bool _isVideoOff = false;
  CallState _callState = CallState.ringing;
  bool _cleanupDone = false;
  bool _localMediaStarted = false; // <-- ADDED to prevent addTrack errors

  @override
  void initState() {
    super.initState();
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    _initRenderers();

    if (!widget.isCaller) {
      // Callee already knows the caller's socket ID
      _peerSocketId = widget.peerSocketId;
      debugPrint("📞 Callee initialized with peerSocketId: $_peerSocketId");

      _callState = CallState.connected; // Callee is connected immediately
      // Future.microtask(() => _startLocalMediaAndPeer(asCaller: false));
    } else {
      _callState = CallState.ringing; // Caller starts as ringing
    }

    _registerSocketHandlers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    debugPrint("🎛 Renderers initialized");
  }

  void _registerSocketHandlers() {
    final s = widget.socket;

    debugPrint(
      "🔗 Registering socket handlers in VideoCall (socket id=${s.id})",
    );

    s.off('callAccepted');
    s.on('callAccepted', (data) async {
      debugPrint("✅ socket callAccepted => $data");
      if (!mounted) return;

      final conv = data['conversationId']?.toString();
      if (conv != widget.conversationId) {
        debugPrint("ℹ️ callAccepted for other conversation ($conv) - ignoring");
        return;
      }

      // --- CRUCIAL: For CALLER, get the callee's socket ID ---
      if (widget.isCaller) {
        final calleeSocketId = data['calleeSocketId']?.toString();
        if (calleeSocketId == null) {
          debugPrint(
            "❌ FATAL: 'calleeSocketId' missing from 'callAccepted' event",
          );
          _showSnack("Call handshake failed. Missing peer ID.");
          _endCallLocal(isError: true);
          return;
        }
        setState(() {
          _peerSocketId = calleeSocketId;
        });
        debugPrint("📞 Caller received calleeSocketId: $_peerSocketId");
      }
      // --- End Caller Logic ---

      if (_callState == CallState.ringing) {
        setState(() => _callState = CallState.connected);
        // Now that we have the _peerSocketId, we can start media and create offer
        await _startLocalMediaAndPeer(asCaller: widget.isCaller);
      } else {
        debugPrint(
          "ℹ️ callAccepted received but call is already connected. Ignoring.",
        );
      }
    });

    s.off('callRejected');
    s.on('callRejected', (data) {
      debugPrint("❌ socket callRejected => $data");
      if (!mounted) return;
      _showSnack("Call rejected by peer");
      _endCallLocal();
    });

    s.off('callEnded');
    s.on('callEnded', (data) {
      debugPrint("🛑 socket callEnded => $data");
      if (!mounted) return;
      _showSnack("Call ended by peer");
      _endCallLocal();
    });

    s.off('offer');
    s.on('offer', (data) async {
      debugPrint("📩 socket.offer => $data");
      final conv = data['conversationId']?.toString();
      if (conv != widget.conversationId) {
        debugPrint("ℹ️ offer for different conversation ($conv) -> ignore");
        return;
      }

      final offer = data['offer'];
      try {
        await _ensurePeerConnection(); // Ensure PC is created

        // If local media not started yet (callee), start local media
        if (_localStream == null) {
          await _startLocalMediaAndPeer(asCaller: false);
        }

        await _pc!.setRemoteDescription(
          RTCSessionDescription(offer['sdp'], offer['type']),
        );
        debugPrint("✅ Remote offer set, creating answer...");
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);

        if (_peerSocketId == null) {
          debugPrint("❌ Cannot send answer, peerSocketId is null");
          return;
        }

        widget.socket.emit('answer', {
          'conversationId': widget.conversationId,
          'answer': answer.toMap(),
          'to': _peerSocketId, // <-- UPDATED: Use socket ID
        });
        debugPrint("📤 Sent answer to $_peerSocketId");
      } catch (e, st) {
        debugPrint("❌ Error handling offer: $e\n$st");
      }
    });

    s.off('answer');
    s.on('answer', (data) async {
      debugPrint("📩 socket.answer => $data");
      final conv = data['conversationId']?.toString();
      if (conv != widget.conversationId) {
        debugPrint("ℹ️ answer for different conversation ($conv) -> ignore");
        return;
      }
      final answer = data['answer'];
      try {
        await _pc?.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
        debugPrint("✅ Remote answer applied");
      } catch (e) {
        debugPrint("❌ Error applying remote answer: $e");
      }
    });

    s.off('ice-candidate');
    s.on('ice-candidate', (data) async {
      final conv = data['conversationId']?.toString();
      if (conv != widget.conversationId) {
        debugPrint(
          "ℹ️ ice-candidate for different conversation ($conv) -> ignore",
        );
        return;
      }
      final candidateMap = data['candidate'];
      if (candidateMap == null) return;

      // Wait for PC to be created
      await _ensurePeerConnection();

      try {
        final cand = RTCIceCandidate(
          candidateMap['candidate'],
          candidateMap['sdpMid'],
          candidateMap['sdpMLineIndex'],
        );
        await _pc?.addCandidate(cand);
        debugPrint("🧊 Added remote ICE candidate");
      } catch (e) {
        debugPrint("❌ Error adding remote ICE candidate: $e");
      }
    });

    debugPrint("🎥 Socket handlers registered");
  }

  Future<void> _emitInitiateCall() async {
    try {
      final payload = {
        'conversationId': widget.conversationId,
        'from': widget.selfUserId,
        'to': widget.peerUserId,
        'callerName': widget.callerName,
      };
      debugPrint("📞 Emitting initiateCall => $payload");
      widget.socket.emit('initiateCall', payload);
    } catch (e) {
      debugPrint("⚠️ Failed to emit initiateCall: $e");
    }
  }

  Future<void> _startLocalMediaAndPeer({required bool asCaller}) async {
    if (_localMediaStarted) {
      // --- THIS WAS THE LINE WITH THE ERROR ---
      debugPrint(
        "ℹ️ _startLocalMediaAndPeer: Media already started, skipping.",
      );
      // --- END FIX ---
      return; // <-- FIX for addTrack error
    }
    _localMediaStarted = true; // <-- FIX for addTrack error

    debugPrint("🎬 startLocalMediaAndPeer(asCaller=$asCaller)");
    try {
      // 1) start local media
      final constraints = {
        'audio': true,
        'video': {'facingMode': 'user', 'width': 640, 'height': 480},
      };
      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      _localStream = stream;
      _localRenderer.srcObject = _localStream;
      debugPrint(
        "✅ Local stream started, tracks: ${_localStream!.getTracks().length}",
      );

      // 2) create peer connection
      await _ensurePeerConnection();

      // 3) Add local tracks
      _localStream?.getTracks().forEach((track) {
        try {
          debugPrint("🛤️ Adding track: ${track.kind}");
          _pc?.addTrack(track, _localStream!);
        } catch (e) {
          // This catch is important if addTrack is called multiple times
          debugPrint("⚠️ Error adding track (ignoring): $e");
        }
      });

      // 4) if caller, create offer and send
      if (asCaller) {
        if (_peerSocketId == null) {
          debugPrint(
            "❌ FATAL: _startLocalMediaAndPeer called for CALLER but peerSocketId is null.",
          );
          _showSnack("Call connection failed (Peer ID missing)");
          _endCallLocal(isError: true);
          return;
        }
        final offer = await _pc!.createOffer();
        await _pc!.setLocalDescription(offer);
        widget.socket.emit('offer', {
          'conversationId': widget.conversationId,
          'offer': offer.toMap(),
          'to': _peerSocketId, // <-- UPDATED
        });
        debugPrint("📤 Offer sent to $_peerSocketId");
      } else {
        debugPrint("⏳ Callee: waiting for remote offer...");
      }
    } catch (e, st) {
      debugPrint("❌ Error in startLocalMediaAndPeer: $e\n$st");
      _showSnack("Failed to start camera/mic");
      _endCallLocal(isError: true);
    }
  }

  Future<void> _ensurePeerConnection() async {
    if (_pc != null) return;
    debugPrint("🔧 Creating RTCPeerConnection...");
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        // add TURN servers for production
      ],
    };

    _pc = await createPeerConnection(config);

    _pc!.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate == null) return;

      if (_peerSocketId == null) {
        debugPrint(
          "⚠️ Cannot send ICE candidate, _peerSocketId is null. Queuing.",
        );
        // We might get candidates before the peer accepts.
        // A more robust solution would queue them.
        return;
      }
      final candidateObj = candidate.toMap();
      debugPrint("📤 onIceCandidate -> emit to $_peerSocketId: $candidateObj");
      widget.socket.emit('ice-candidate', {
        'conversationId': widget.conversationId,
        'candidate': candidateObj,
        'to': _peerSocketId, // <-- UPDATED
      });
    };

    _pc!.onTrack = (RTCTrackEvent event) {
      debugPrint("🎧 onTrack event, streams: ${event.streams.length}");
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
        debugPrint("✅ Remote stream attached to renderer");

        if (mounted) setState(() {});
      }
    };

    _pc!.onConnectionState = (state) {
      debugPrint("🔁 PeerConnection state changed: $state");
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        debugPrint("🛑 Peer connection failed or disconnected.");
        _endCallLocal();
      }
    };

    debugPrint("✅ PeerConnection created");
  }

  void _toggleMute() {
    if (_localStream == null) {
      debugPrint("⚠️ toggleMute: no local stream");
      return;
    }
    final aud = _localStream!.getAudioTracks();
    if (aud.isEmpty) return;
    final enabled = !aud.first.enabled;
    for (var t in aud) t.enabled = enabled;
    setState(() => _isMuted = !enabled);
    debugPrint(_isMuted ? "🔇 Muted" : "🎙️ Unmuted");
  }

  void _toggleVideo() {
    if (_localStream == null) {
      debugPrint("⚠️ toggleVideo: no local stream");
      return;
    }
    final vids = _localStream!.getVideoTracks();
    if (vids.isEmpty) return;
    final enabled = !vids.first.enabled;
    for (var t in vids) t.enabled = enabled;
    setState(() => _isVideoOff = !enabled);
    debugPrint(_isVideoOff ? "📷 OFF" : "📷 ON");
  }

  Future<void> _cleanup() async {
    if (_cleanupDone) return;
    _cleanupDone = true;
    debugPrint("🧹 Cleanup starting...");

    try {
      try {
        _pc?.onIceCandidate = null;
        _pc?.onTrack = null;
        _pc?.onConnectionState = null;
        await _pc?.close();
      } catch (e) {
        debugPrint("⚠️ error closing pc: $e");
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
        debugPrint("⚠️ error disposing local stream: $e");
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
      debugPrint("❌ cleanup error: $e");
    }
    _localMediaStarted = false;
    debugPrint("✅ Cleanup done");
  }

  Future<void> _endCallLocal({bool isError = false}) async {
    if (_callState == CallState.ended) return; // Already ended

    try {
      if (!isError) {
        // Only emit 'endCall' or 'cancelCall' if it's a user action, not an error cleanup
        if (_peerSocketId != null) {
          // Call is connected or ringing and peer has accepted
          debugPrint("📤 endCall emitted to $_peerSocketId");
          widget.socket.emit('endCall', {
            'conversationId': widget.conversationId,
            'to': _peerSocketId, // <-- UPDATED
          });
        } else if (widget.isCaller && _callState == CallState.ringing) {
          // Caller is hanging up while ringing
          debugPrint("🚫 Emitting cancelCall to user ${widget.peerUserId}");
          widget.socket.emit('cancelCall', {
            'conversationId': widget.conversationId,
            'toUserId':
                widget.peerUserId, // Use the User ID (server must handle this)
          });
        }
      }

      setState(() => _callState = CallState.ended);
      await _cleanup();

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint("❌ endCallLocal error: $e");
    }
  }

  @override
  void dispose() {
    debugPrint("🧹 VideoCall.dispose - removing socket handlers");

    // Ensure cleanup is called, especially if _endCallLocal wasn't
    if (_callState != CallState.ended) {
      _endCallLocal();
    } else {
      _cleanup(); // Just in case
    }

    super.dispose();
  }

  Widget _buildRemoteViewCover() {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: RTCVideoView(
          _remoteRenderer,
          mirror: true,
        ), // Mirror remote view
      ),
    );
  }

  Widget _buildLocalPreview() {
    return SizedBox(
      width: 120,
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child:
            _localStream != null
                ? RTCVideoView(_localRenderer, mirror: true)
                : Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(Icons.person, color: Colors.white),
                  ),
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
              Text(
                "📞 Calling ${widget.callerName}...",
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              Text(
                "Waiting for peer to accept...",
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
        break;
      case CallState.connected:
        bodyContent = Stack(
          children: [
            _buildRemoteViewCover(),
            Positioned(
              left: 16,
              bottom: 120, // Position above controls
              child: _buildLocalPreview(),
            ),
          ],
        );
        break;
      case CallState.ended:
        bodyContent = const Center(
          child: Text(
            "Call ended",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        );
        // Pop after a delay
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) Navigator.of(context).pop();
        });
        break;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: bodyContent),
          if (_callState == CallState.connected)
            Positioned(
              top: 52,
              left: 16,
              child: Text(
                widget.callerName,
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),

          // Always show controls unless ended
          if (_callState != CallState.ended)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: 'mic',
                    backgroundColor: _isMuted ? Colors.red : Colors.white,
                    onPressed: _toggleMute,
                    child: Icon(
                      _isMuted ? Icons.mic_off : Icons.mic,
                      color: _isMuted ? Colors.white : Colors.black,
                    ),
                  ),
                  FloatingActionButton(
                    heroTag: 'end',
                    backgroundColor: Colors.red,
                    onPressed: () => _endCallLocal(isError: false),
                    child: const Icon(Icons.call_end),
                  ),
                  FloatingActionButton(
                    heroTag: 'cam',
                    backgroundColor: _isVideoOff ? Colors.red : Colors.white,
                    onPressed: _toggleVideo,
                    child: Icon(
                      _isVideoOff ? Icons.videocam_off : Icons.videocam,
                      color: _isVideoOff ? Colors.white : Colors.black,
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
