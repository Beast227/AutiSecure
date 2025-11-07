import 'dart:convert';
import 'dart:io';

import 'package:autisecure/services/api_service.dart';
import 'package:autisecure/login_signup/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:autisecure/services/socket_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class LiveChat2 extends StatefulWidget {
  const LiveChat2({super.key});

  @override
  State<LiveChat2> createState() => _LiveChat2State();
}

class _LiveChat2State extends State<LiveChat2>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final SocketService socketService = SocketService();

  bool _isLoading = true;
  bool isChatOpen = false;
  String selectedUser = '';
  String? userId;
  String? selectedConversationId;
  List conversations = [];
  List messages = [];

  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const String _conversationsCacheKey = 'conversationsCache';
  static const String _userIdKey = 'userId';
  static const String _roleKey = 'role';
  static const String _tokenKey = 'token';

  @override
  void initState() {
    super.initState();
    _loadDoctorDetailsAndInitialData();
  }

  @override
  void dispose() {
    messageController.dispose();
    _scrollController.dispose();
    socketService.offMessageReceived(_handleIncomingMessage);
    socketService.disconnect();
    super.dispose();
  }

  Future<void> _loadDoctorDetailsAndInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString(_userIdKey);

    debugPrint("🔹 User ID: $userId"); // <-- Changed

    if (userId == null || userId!.isEmpty) {
      _showSnackBar("User ID not found. Please log in again.", isError: true);
      _logOut();
      return;
    }

    await _connectAndListen();
    await _loadConversations();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _connectAndListen() async {
    try {
      await socketService.connect();

      Future.delayed(const Duration(seconds: 1), () {
        socketService.onMessageReceived(_handleIncomingMessage);
        debugPrint(
          "✅ [LiveChat2] Socket listener registered after connection.",
        );
      });
    } catch (e) {
      debugPrint("❌ Failed to connect socket: $e");
      _showSnackBar("Real-time connection failed: $e", isError: true);
    }
  }

  void _handleIncomingMessage(dynamic data) {
    debugPrint('SOCKET: Message Received: $data');

    if (data is Map) {
      final Map<String, dynamic> newMessage = Map<String, dynamic>.from(
        data as Map,
      );

      final msgConvoId = newMessage['conversationId'];

      if (isChatOpen && msgConvoId == selectedConversationId) {
        dynamic senderData = newMessage['sender'];
        String senderId = "";

        if (senderData is Map<String, dynamic>) {
          senderId = senderData['id']?.toString() ?? '';
        } else {
          senderId = senderData?.toString() ?? '';
        }

        if (senderId != userId) {
          setState(() {
            messages.insert(0, newMessage);
          });
          _scrollToBottom();
        }
      }

      setState(() {
        final convoIndex = conversations.indexWhere(
          (c) => c['_id'] == msgConvoId,
        );
        if (convoIndex != -1) {
          final convo = conversations.removeAt(convoIndex);
          convo['lastMessage'] = newMessage['message'];
          convo['updatedAt'] = newMessage['createdAt'];
          conversations.insert(0, convo);
        }
      });
    } else {
      debugPrint("⚠️ Unexpected data type from socket: ${data.runtimeType}");
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.orangeAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadConversations({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedDataString;

    if (!forceRefresh) {
      cachedDataString = prefs.getString(_conversationsCacheKey);
      if (cachedDataString != null) {
        try {
          final List<dynamic> cachedDynamicList = json.decode(cachedDataString);
          if (mounted) {
            setState(() {
              conversations = cachedDynamicList.cast<Map<String, dynamic>>();
              debugPrint("✅ Loaded conversations from cache.");
            });
          }
        } catch (e) {
          debugPrint("⚠️ Error decoding conversations cache: $e");
          await prefs.remove(_conversationsCacheKey);
        }
      }
    }

    try {
      final List<Map<String, dynamic>> fetchedConversations =
          await ApiService.fetchConversations(role: 'user'); // <-- Changed

      if (!mounted) return;

      final String fetchedDataString = json.encode(fetchedConversations);

      if (fetchedDataString != cachedDataString) {
        debugPrint("🔄 Updated conversations cache.");
        await prefs.setString(_conversationsCacheKey, fetchedDataString);
        setState(() {
          conversations = fetchedConversations;
        });
        if (cachedDataString != null) {
          _showSnackBar("Conversations updated.");
        }
      } else {
        debugPrint("ℹ️ Conversations are up-to-date.");
      }
    } catch (e) {
      debugPrint("❌ Error loading conversations: $e");
      if (cachedDataString == null) {
        if (mounted)
          _showSnackBar("Could not load conversations.", isError: true);
      }
    }
  }

  Future<void> _loadMessages() async {
    if (selectedConversationId == null) return;
    try {
      final data = await ApiService.fetchMessages(selectedConversationId!);
      if (mounted) {
        setState(() => messages = data.reversed.toList());
      }
    } catch (e) {
      debugPrint("❌ Error fetching messages: $e");
      if (mounted) _showSnackBar("Could not load messages.", isError: true);
    }
  }

  Future<void> _openChat(Map conversation) async {
    if (userId == null) {
      _showSnackBar("User ID not found. Cannot open chat.", isError: true);
      return;
    }

    selectedConversationId = conversation["_id"]?.toString();
    if (selectedConversationId == null) {
      _showSnackBar("Conversation ID missing.", isError: true);
      return;
    }

    socketService.joinRoom(selectedConversationId!);
    socketService.offMessageReceived(_handleIncomingMessage);
    socketService.onMessageReceived(_handleIncomingMessage);

    final List participants = conversation["participants"] ?? [];
    final otherUser = participants.firstWhere(
      (p) => p is Map && p["id"] != userId,
      orElse: () => participants.isNotEmpty && participants.first is Map
          ? participants.first
          : {"name": "Unknown"},
    );
    selectedUser = otherUser["name"] ?? "Unknown User";

    setState(() => isChatOpen = true);

    await _loadMessages();
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || selectedConversationId == null || userId == null) return;

    if (!socketService.isConnected) {
      _showSnackBar("Not connected. Reconnecting...", isError: true);
      await _connectAndListen();
      await Future.delayed(const Duration(seconds: 1));
      if (!socketService.isConnected) {
        _showSnackBar("Connection failed. Please try again.", isError: true);
        return;
      }
    }

    final tempMessage = {
      "message": text,
      "sender": {"id": userId, "role": "user"}, // <-- Changed
      "senderPic": null,
      "conversationId": selectedConversationId!,
      "createdAt": DateTime.now().toIso8601String(),
    };
    if (mounted) {
      setState(() {
        messages.insert(0, tempMessage);
        messageController.clear();
      });
      _scrollToBottom();
    }

    try {
      socketService.sendMessage(selectedConversationId!, text);
    } catch (e) {
      debugPrint("❌ Error emitting message: $e");
      if (mounted) {
        _showSnackBar("Error sending message: $e", isError: true);
        setState(() {
          messages.remove(tempMessage);
        });
      }
    }
  }

  Future<void> _logOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_conversationsCacheKey);

    socketService.disconnect();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildChatWindow() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(
            top: 8.0,
            bottom: 12.0,
            left: 8.0,
            right: 16.0,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade700, Colors.orange.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.shade200.withOpacity(0.6),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => isChatOpen = false),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: "Back to Chats",
              ),
              const SizedBox(width: 4),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withOpacity(0.3),
                child: Text(
                  selectedUser.isNotEmpty ? selectedUser[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selectedUser,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.videocam_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => _showSnackBar(
                  "Video call not implemented yet.",
                  isError: true,
                ),
                tooltip: "Video Call",
              ),
              IconButton(
                icon: const Icon(
                  Icons.call_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => _showSnackBar(
                  "Audio call not implemented yet.",
                  isError: true,
                ),
                tooltip: "Audio Call",
              ),
            ],
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Text(
                    "No messages yet. Start chatting!",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    if (msg == null ||
                        msg is! Map ||
                        msg["message"] == null ||
                        msg["sender"] == null) {
                      return const SizedBox.shrink();
                    }

                    dynamic senderData = msg['sender'];
                    String senderId = "";
                    if (senderData is Map<String, dynamic>) {
                      senderId = senderData['id']?.toString() ?? '';
                    } else {
                      senderId = senderData?.toString() ?? '';
                    }
                    final isMe = senderId == userId;

                    final bool isLocalFile = msg["filePath"] != null;
                    final bool isVideo = msg["message"].toString().contains(
                          "[Video File",
                        );

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: isLocalFile
                            ? const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              )
                            : const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 14,
                              ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.orange.shade200
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: isLocalFile
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isVideo
                                        ? Icons.videocam_outlined
                                        : Icons.image_outlined,
                                    color: Colors.grey.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      msg["message"].toString(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                msg["message"].toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),
                  tooltip: "Send Media",
                  onPressed: _pickMedia,
                ),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    style: const TextStyle(fontSize: 16),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color: Colors.orange.shade400,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatList() {
    if (conversations.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 60,
                color: Colors.orange.shade300,
              ),
              const SizedBox(height: 16),
              const Text(
                "No Conversations Yet",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5A2500),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Your conversations with doctors will appear here.", // <-- Changed
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              IconButton(
                icon: const Icon(Icons.refresh, size: 30, color: Colors.orange),
                tooltip: "Refresh Conversations",
                onPressed: () => _loadConversations(forceRefresh: true),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadConversations(forceRefresh: true),
      color: Colors.orange,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final convo = conversations[index];
          if (convo == null ||
              convo is! Map ||
              convo["participants"] == null ||
              convo["participants"] is! List ||
              (convo["participants"] as List).isEmpty) {
            return const SizedBox.shrink();
          }

          final List participants = convo["participants"];
          final otherUser = participants.firstWhere(
            (p) => p is Map && p["id"] != userId,
            orElse: () => participants.firstWhere(
              (p) => p is Map,
              orElse: () => null,
            ),
          );

          if (otherUser == null) return const SizedBox.shrink();

          final String otherUserName = otherUser["name"] ?? "Unknown User";
          final String initial =
              otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : "?";
          final String lastMessage =
              convo['lastMessage'] ?? 'No messages yet...';
          final String lastMessageTime = convo['updatedAt'] != null
              ? DateFormat(
                  'h:mm a',
                ).format(DateTime.parse(convo['updatedAt']).toLocal())
              : '';
          final String? otherUserImageUrl = otherUser['imageUrl'];

          return Card(
            color: Colors.white,
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.orange.shade100,
                backgroundImage:
                    (otherUserImageUrl != null && otherUserImageUrl.isNotEmpty)
                        ? NetworkImage(otherUserImageUrl)
                        : null,
                child:
                    (otherUserImageUrl != null && otherUserImageUrl.isNotEmpty)
                        ? null
                        : Text(
                            initial,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
              ),
              title: Text(
                otherUserName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                lastMessage,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: lastMessage == 'No messages yet...'
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    lastMessageTime,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.orange.shade400,
                    size: 16,
                  ),
                ],
              ),
              onTap: () => _openChat(convo),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 16,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      floatingActionButton: null,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          key: ValueKey(isChatOpen),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                )
              : isChatOpen
                  ? _buildChatWindow()
                  : _buildChatList(),
        ),
      ),
    );
  }

  void _sendMediaMessage(File file, {bool isVideo = false}) {
    // TODO: Implement file upload
    _showSnackBar("Media upload not implemented yet.", isError: true);

    if (!mounted) return;
    setState(() {
      messages.insert(0, {
        "sender": {"id": userId, "role": "user"}, // This was already 'user'
        "message": isVideo
            ? "[Video File: ${file.path.split('/').last}]"
            : "[Image File: ${file.path.split('/').last}]",
        "timestamp": DateTime.now().toIso8601String(),
        "filePath": file.path,
      });
    });
  }

  final ImagePicker _picker = ImagePicker();
  Future<void> _pickMedia() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Text(
                  "Choose Media",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildSquareOption(
                      icon: Icons.photo_outlined,
                      label: "Gallery",
                      color: Colors.orange,
                      onTap: () async {
                        Navigator.pop(context);
                        final XFile? image = await _picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (image != null) {
                          _sendMediaMessage(File(image.path), isVideo: false);
                        }
                      },
                    ),
                    _buildSquareOption(
                      icon: Icons.videocam_outlined,
                      label: "Video",
                      color: Colors.orange,
                      onTap: () async {
                        Navigator.pop(context);
                        final XFile? video = await _picker.pickVideo(
                          source: ImageSource.gallery,
                        );
                        if (video != null) {
                          _sendMediaMessage(File(video.path), isVideo: true);
                        }
                      },
                    ),
                    _buildSquareOption(
                      icon: Icons.camera_alt_outlined,
                      label: "Camera",
                      color: Colors.orange,
                      onTap: () async {
                        Navigator.pop(context);
                        final XFile? photo = await _picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 80,
                        );
                        if (photo != null) {
                          _sendMediaMessage(File(photo.path), isVideo: false);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSquareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withAlpha((255 * 0.08).round()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha((255 * 0.3).round())),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}