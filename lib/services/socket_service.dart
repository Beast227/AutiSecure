// lib/services/socket_service.dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  late io.Socket socket;
  bool _connected = false;

  factory SocketService() => _instance;

  SocketService._internal();

  void connect(String token) {
    if (_connected) return; // Prevent duplicate connections

    socket = io.io(
      'https://my-chat-app.onrender.com', // Replace with Render backend URL
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableReconnection()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    socket.onConnect((_) {
      _connected = true;
      debugPrint("✅ Socket connected: ${socket.id}");
    });

    socket.onDisconnect((_) {
      _connected = false;
      debugPrint("❌ Socket disconnected");
    });
  }

  void joinRoom(String conversationId) {
    socket.emit("joinRoom", conversationId);
  }

  void sendMessage(String conversationId, String senderId, String message) {
    socket.emit("sendMessage", {
      "conversationId": conversationId,
      "sender": senderId,
      "message": message,
    });
  }

  void onMessageReceived(Function(dynamic data) callback) {
    socket.on("receiveMessage", callback);
  }

  void disconnect() {
    socket.disconnect();
    _connected = false;
  }
}
