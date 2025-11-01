import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static final SocketService _instance = SocketService._internal();

  io.Socket? socket;
  bool _isConnected = false;
  Completer<void>? _connectionCompleter;

  static const String _tokenKey = 'token';

  factory SocketService() => _instance;
  SocketService._internal();

  bool get isConnected => _isConnected && socket?.connected == true;

  Future<void> connect() async {
    debugPrint("⚡ [SocketService] connect() CALLED");

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      debugPrint("🟡 [SocketService] Already connecting, awaiting...");
      return _connectionCompleter!.future;
    }

    if (isConnected) {
      debugPrint("✅ [SocketService] Already connected.");
      return;
    }

    _connectionCompleter = Completer<void>();

    _isConnected = false;
    socket?.disconnect();
    socket = null;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      debugPrint("❌ No token found.");
      _connectionCompleter!.completeError("No token found");
      return _connectionCompleter!.future;
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
      if (!_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete();
      }
    });

    socket!.onConnectError((data) {
      debugPrint("❌ Socket connect error: $data");
      if (!_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(data);
      }
    });

    socket!.onError((data) {
      debugPrint("❌ Socket error: $data");
    });

    socket!.connect();
    return _connectionCompleter!.future;
  }

  void joinRoom(String conversationId) {
    if (!isConnected) {
      debugPrint("⚠️ [SocketService] joinRoom called but not connected.");
      return;
    }
    socket?.emit("joinConversation", conversationId);
    debugPrint("SOCKET: Emitted 'joinConversation' for $conversationId");
  }

  void sendMessage(String conversationId, String message) {
    if (!isConnected) {
      debugPrint("⚠️ [SocketService] sendMessage called but not connected.");
      return;
    }
    socket?.emit("sendMessage", {
      "conversationId": conversationId,
      "message": message,
    });
  }

  void onMessageReceived(Function(dynamic data) callback) {
    if (socket != null) {
      socket!.on("receiveMessage", callback);
    }
  }

  void offMessageReceived(Function(dynamic data) callback) {
    if (socket != null) {
      socket!.off("receiveMessage", callback);
    }
  }

  void disconnect() {
    if (socket != null) {
      socket!.disconnect();
      _isConnected = false;
      debugPrint("🔌 Socket manually disconnected.");
    }

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.completeError("Manual disconnect");
    }
    _connectionCompleter = null;
  }
}