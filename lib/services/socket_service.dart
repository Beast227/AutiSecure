import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? socket;
  bool _isConnected = false;
  bool _isConnecting = false;

  static const String _tokenKey = 'token'; // Make sure this key is correct

  /// Stream controller to broadcast incoming call events to the UI.
  final StreamController<Map<String, dynamic>> _incomingCallController =
      StreamController.broadcast();

  /// Public stream for the UI to listen for incoming calls.
  Stream<Map<String, dynamic>> get incomingCallStream =>
      _incomingCallController.stream;

  bool get isConnected => _isConnected && socket?.connected == true;

  // -------------------- MAIN CONNECTION --------------------
  Future<void> connect() async {
    debugPrint("⚡ [SocketService] connect() called");

    if (isConnected || _isConnecting) {
      debugPrint("✅ Already connected or connecting. Skipping.");
      return;
    }

    _isConnecting = true;

    final prefs = await SharedPreferences.getInstance();
    // TODO: Ensure you are saving the token with this key after login
    final token = prefs.getString(_tokenKey);

    if (token == null || token.isEmpty) {
      debugPrint("❌ No token found, cannot connect to socket.");
      return;
    }

    socket?.disconnect();
    socket = null;

    socket = io.io(
      'https://autisense-backend.onrender.com',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableReconnection()
          .setQuery({'token': token})
          .build(),
    );

    // --- Listeners (register BEFORE connect)
    socket!.onConnect((_) {
      _isConnected = true;
      _isConnecting = false;
      debugPrint("✅ Socket connected: ${socket!.id}");
    });

    socket!.onConnectError((data) {
      _isConnected = false;
      _isConnecting = false;
      debugPrint("❌ Socket connect error: $data");
    });

    socket!.onError((data) {
      _isConnected = false;
      _isConnecting = false;
      debugPrint("❌ Socket general error: $data");
    });

    // Default chat message listener
    socket!.on("receiveMessage", (data) {
      debugPrint("📩 [SocketService] receiveMessage: $data");
      // Note: You might want a Stream for this too, like the incoming call
    });

    // Video call event listeners
    _registerVideoCallListeners();

    socket!.connect();
  }

  // -------------------- CHAT FEATURES --------------------
  void joinRoom(String conversationId) {
    if (!isConnected) {
      debugPrint("⚠️ Tried joining room before connection");
      return;
    }
    socket?.emit("joinRoom", conversationId);
    debugPrint("📡 Joined room: $conversationId");
  }

  void sendMessage(String conversationId, String message) {
    if (!isConnected) {
      debugPrint("⚠️ Tried sending before connection");
      return;
    }
    socket?.emit("sendMessage", {
      "conversationId": conversationId,
      "message": message,
    });
    debugPrint("💬 Message emitted for conversation $conversationId");
  }

  void onMessageReceived(void Function(dynamic) callback) {
    if (socket == null) {
      debugPrint("⚠️ Socket is null; cannot register receiveMessage listener.");
      return;
    }
    socket!.off("receiveMessage");
    socket!.on("receiveMessage", callback);
    debugPrint("📡 Listening for receiveMessage events.");
  }

  void offMessageReceived(void Function(dynamic) callback) {
    socket?.off("receiveMessage", callback);
    debugPrint("🧹 Removed receiveMessage listener.");
  }

  void dispose() {
    _incomingCallController.close();
    debugPrint("🧹 [SocketService] Stream controllers closed.");
  }

  void disconnect() {
    if (socket != null) {
      socket!.disconnect();
      _isConnected = false;
      debugPrint("🔌 Socket manually disconnected.");
    }
  }

  // -------------------- VIDEO CALL FEATURES --------------------
  void initiateCall({
    required String conversationId,
    required String fromUserId,
    required String toUserId,
    required String callerName,
  }) {
    if (!isConnected) {
      debugPrint("⚠️ Tried initiating call before connection");
      return;
    }

    final payload = {
      'conversationId': conversationId,
      'from': fromUserId,
      'to': toUserId,
      'callerName': callerName,
    };

    socket!.emit('initiateCall', payload);
    debugPrint("📞 [SocketService] initiateCall => $payload");
  }

  void initiateVoiceCall({
    required String conversationId,
    required String fromUserId,
    required String toUserId,
    required String callerName,
  }) {
    if (!isConnected) {
      debugPrint("⚠️ Tried initiating VOICE call before connection");
      return;
    }

    final payload = {
      'conversationId': conversationId,
      'from': fromUserId,
      'to': toUserId,
      'callerName': callerName,
    };

    socket!.emit('initiateVoiceCall', payload);
    debugPrint("🎙️ [SocketService] initiateVoiceCall => $payload");
  }

  /// Callee accepts the call
  void acceptCall(String conversationId, String toSocketId) {
    if (!isConnected) return;
    final payload = {
      'conversationId': conversationId,
      'to': toSocketId,
      'from': socket?.id, // Send our own socket ID so caller can store it
    };
    socket?.emit('acceptCall', payload);
    debugPrint("✅ [SocketService] acceptCall => $payload");
  }

  /// Callee rejects the call
  void rejectCall(String conversationId, String toSocketId) {
    if (!isConnected) return;
    final payload = {'conversationId': conversationId, 'to': toSocketId};
    socket?.emit('rejectCall', payload);
    debugPrint("❌ [SocketService] rejectCall => $payload");
  }

  /// Anyone ends the call
  void endCall(String conversationId, String toSocketId) {
    if (!isConnected) return;
    final payload = {'conversationId': conversationId, 'to': toSocketId};
    socket?.emit('endCall', payload);
    debugPrint("🛑 [SocketService] endCall => $payload");
  }

  // --- WebRTC signaling events ---

  void sendOffer(
    String conversationId,
    String toSocketId,
    Map<String, dynamic> offer,
  ) {
    if (!isConnected) return;
    final payload = {
      'conversationId': conversationId,
      'offer': offer,
      'to': toSocketId,
    };
    socket?.emit('offer', payload);
    debugPrint("📤 [SocketService] Sent Offer to $toSocketId");
  }

  void sendAnswer(
    String conversationId,
    String toSocketId,
    Map<String, dynamic> answer,
  ) {
    if (!isConnected) return;
    final payload = {
      'conversationId': conversationId,
      'answer': answer,
      'to': toSocketId,
    };
    socket?.emit('answer', payload);
    debugPrint("📤 [SocketService] Sent Answer to $toSocketId");
  }

  void sendIceCandidate(
    String conversationId,
    String toSocketId,
    Map<String, dynamic> candidate,
  ) {
    if (!isConnected) return;
    final payload = {
      'conversationId': conversationId,
      'candidate': candidate,
      'to': toSocketId,
    };
    socket?.emit('ice-candidate', payload);
    debugPrint("📤 [SocketService] Sent ICE Candidate to $toSocketId");
  }

  // -------------------- REGISTER CALL EVENTS --------------------
  void _registerVideoCallListeners() {
    if (socket == null) return;

    socket!.off('incomingCall');
    socket!.on('incomingCall', (data) {
      debugPrint("📲 [SocketService] Incoming call => $data");
      if (data is Map<String, dynamic>) {
        _incomingCallController.add(data);
      }
    });

    socket!.off('callAccepted');
    socket!.on('callAccepted', (data) {
      debugPrint("✅ [SocketService] Call accepted => $data");
    });

    socket!.off('callRejected');
    socket!.on('callRejected', (data) {
      debugPrint("❌ [SocketService] Call rejected => $data");
    });

    socket!.off('callEnded');
    socket!.on('callEnded', (data) {
      debugPrint("🛑 [SocketService] Call ended => $data");
    });

    socket!.off('offer');
    socket!.on('offer', (data) {
      debugPrint("📩 [SocketService] Received Offer");
    });

    socket!.off('answer');
    socket!.on('answer', (data) {
      debugPrint("📩 [SocketService] Received Answer");
    });

    socket!.off('ice-candidate');
    socket!.on('ice-candidate', (data) {
      debugPrint("📩 [SocketService] Received ICE Candidate");
    });

    debugPrint("🎥 [SocketService] Registered all video call listeners");
  }
}
