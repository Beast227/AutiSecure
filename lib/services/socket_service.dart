import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static final SocketService _instance = SocketService._internal();

  // --- 1. Make socket nullable ---
  io.Socket? socket;
  bool _isConnected = false;

  static const String _tokenKey = 'token';

  factory SocketService() => _instance;
  SocketService._internal();

  bool get isConnected =>
      _isConnected && socket?.connected == true; // Improved check

  Future<void> connect() async {
    debugPrint("⚡ [SocketService] connect() CALLED");

    _isConnected = false;
    socket?.disconnect();
    socket = null; // reset previous instance

    debugPrint("⚡ [SocketService] connect() CALLED 2");


    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      debugPrint("❌ No token found.");
      return;
    }

    debugPrint("🟡 Attempting socket connection...");

    socket = io.io(
      'https://autisense-backend.onrender.com',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableReconnection()
          .setQuery({'token': token})
          .build(),
    );

    socket!.onConnect((_) {
      _isConnected = true;
      debugPrint("✅ Socket connected: ${socket!.id}");
    });

    socket!.onConnectError((data) {
      debugPrint("❌ Socket connect error: $data");
    });

    socket!.onError((data) {
      debugPrint("❌ Socket error: $data");
    });

    socket!.connect();
  }

  void joinRoom(String conversationId) {
    if (!isConnected) return; // Use getter
    socket?.emit("joinConversation", conversationId);
    debugPrint("SOCKET: Emitted 'joinConversation' for $conversationId");
  }

  void sendMessage(String conversationId, String message) {
    if (!isConnected) return; // Use getter
    socket?.emit("sendMessage", {
      "conversationId": conversationId,
      "message": message,
    });
  }

  void onMessageReceived(Function(dynamic data) callback) {
    // Check if socket is not null
    if (socket != null) {
      socket!.on("receiveMessage", callback);
    }
  }

  void offMessageReceived(Function(dynamic data) callback) {
    // Check if socket is not null and is connected
    if (socket != null && socket!.connected) {
      socket!.off("receiveMessage", callback);
    }
  }

  void disconnect() {
    if (socket != null && _isConnected) {
      socket!.disconnect();
      _isConnected = false;
      debugPrint("🔌 Socket manually disconnected.");
    }
  }
}
