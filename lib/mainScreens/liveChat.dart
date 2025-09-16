import 'dart:convert';
import 'package:autisecure/services/socket_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LiveChat extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final String token;

  const LiveChat({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.token,
  });

  @override
  State<LiveChat> createState() => _LiveChatState();
}

class _LiveChatState extends State<LiveChat> {
  final List<Map<String, dynamic>> messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late SocketService _socketService;

  String? profileImageUrl; // <-- store user's image
  String? userRole;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo(); // Fetch profile before chat starts

    _socketService = SocketService();
    _socketService.connect(widget.token);
    _socketService.joinRoom(widget.conversationId);

    _socketService.onMessageReceived((data) {
      if (data['conversationID'] == widget.conversationId) {
        setState(() {
          messages.add(data);
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _fetchUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Token not found. Please log in again."),
          ),
        );
      }
      return;
    }

    final url = Uri.parse(
      role == "Doctor"
          ? "https://autisense-backend.onrender.com/api/doctor/data"
          : "https://autisense-backend.onrender.com/api/user/data",
    );

    try {
      final response = await http.get(
        url,
        headers: {'authorization': 'Bearer $token'},
      );
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          userRole = role;
          profileImageUrl = responseData['imageUrl'];
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Failed to load user data: ${responseData['message']}",
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching user info: $e")));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    _socketService.sendMessage(
      widget.conversationId,
      widget.currentUserId,
      _controller.text.trim(),
    );

    setState(() {
      messages.add({
        "conversationId": widget.conversationId,
        "sender": widget.currentUserId,
        "senderPic": profileImageUrl, // <-- attach image here
        "message": _controller.text.trim(),
        "createdAt": DateTime.now().toIso8601String(),
      });
      _controller.clear();
    });

    _scrollToBottom();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['sender'] == widget.currentUserId;
                final senderPic = msg['senderPic'] ?? profileImageUrl;

                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe)
                        CircleAvatar(
                          radius: 16,
                          backgroundImage:
                              senderPic != null && senderPic.isNotEmpty
                                  ? NetworkImage(senderPic)
                                  : null,
                          child:
                              senderPic == null
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                        ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width *
                              0.7, // 70% of screen width
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.orange[200] : Colors.grey[300],
                            borderRadius: BorderRadius.only(
                              topLeft: isMe ? Radius.circular(12) : Radius.zero,
                              topRight:
                                  isMe ? Radius.zero : Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 10,
                            ),
                            child: Text(
                              msg['message'],
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      if (isMe)
                        CircleAvatar(
                          radius: 16,
                          backgroundImage:
                              senderPic != null && senderPic.isNotEmpty
                                  ? NetworkImage(senderPic)
                                  : null,
                          child:
                              senderPic == null
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.orange[50],
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.orange[100],
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: Colors.orange[900]),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.orange[700],
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
