import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? socket;
  bool _isConnected = false;

  static const String _tokenKey = 'token';

  bool get isConnected => _isConnected && socket?.connected == true;

  Future<void> connect() async {
    debugPrint("⚡ [SocketService] connect() called");

    if (isConnected) {
      debugPrint("✅ Already connected. Skipping reconnect.");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    if (token == null || token.isEmpty) {
      debugPrint("❌ No token found, cannot connect to socket.");
      return;
    }

    // Close any previous instance cleanly
    socket?.disconnect();
    socket = null;

    socket = io.io(
      'https://autisecure-backend.onrender.com', // ✅ correct URL
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
      debugPrint("✅ Socket connected: ${socket!.id}");
    });

    socket!.onConnectError((data) {
      _isConnected = false;
      debugPrint("❌ Socket connect error: $data");
    });

    socket!.onError((data) {
      _isConnected = false;
      debugPrint("❌ Socket general error: $data");
    });

    // Add the receiveMessage listener once here
    socket!.on("receiveMessage", (data) {
      debugPrint("📩 [SocketService] receiveMessage triggered: $data");
    });

    socket!.connect();
  }

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

  void disconnect() {
    if (socket != null) {
      socket!.disconnect();
      _isConnected = false;
      debugPrint("🔌 Socket manually disconnected.");
    }
  }
}
