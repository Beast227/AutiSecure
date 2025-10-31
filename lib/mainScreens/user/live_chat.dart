import 'dart:convert';
import 'dart:io';

import 'package:autisecure/services/api_service.dart';
import 'package:autisecure/login_signup/login_screen.dart'; // Ensure correct path
import 'package:autisecure/mainScreens/user/subScreen/appointment_page.dart'; // Ensure this path is correct
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // For date formatting
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badges/badges.dart' as badges; // Import badges package
import 'package:file_picker/file_picker.dart'; // Keep user's imports
import 'package:flutter_sound/public/flutter_sound_recorder.dart'; // Keep user's imports
import 'package:geocoding/geocoding.dart'; // Keep user's imports
import 'package:geolocator/geolocator.dart'; // Keep user's imports
import 'package:image_picker/image_picker.dart';

// Import the SocketService
import 'package:autisecure/services/socket_service.dart'; // Adjust path as needed
// --- 1. ADD SOCKET.IO IMPORT ---
import 'package:socket_io_client/socket_io_client.dart' as IO;

class LiveChat2 extends StatefulWidget {
  const LiveChat2({super.key});

  @override
  State<LiveChat2> createState() => _LiveChat2State();
}

class _LiveChat2State extends State<LiveChat2>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs/pages

  // --- 2. ADD SOCKET VARIABLE ---
  IO.Socket? socket;

  // State Variables
  bool _isLoading = true; // Combined loading state
  bool isChatOpen = false;
  String selectedUser = '';
  String? userId; // Still need the doctor's own ID
  String? selectedConversationId;
  List conversations = [];
  List messages = [];
  List<Map<String, dynamic>> approvedAppointments = [];
  List<Map<String, dynamic>> pendingAppointments = [];
  int _pendingCount = 0; // For badge

  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController =
      ScrollController(); // Added controller

  // Cache Keys
  static const String _pendingCacheKey = 'pendingAppointmentsCache';
  static const String _approvedCacheKey = 'approvedAppointmentsCache';
  static const String _conversationsCacheKey = 'conversationsCache';
  static const String _userIdKey = 'userId';
  static const String _roleKey = 'role';
  static const String _tokenKey = 'token';
  SocketService socketService = SocketService();

  @override
  void initState() {
    super.initState();
    // Load details and initial data
    _loadDoctorDetailsAndInitialData();
  }

  @override
  void dispose() {
    messageController.dispose();
    _scrollController.dispose(); // Dispose scroll controller
    // --- 3. DISPOSE SOCKET ---
    socket?.disconnect();
    socket?.dispose();
    super.dispose();
  }

  // --- Initialization ---
  Future<void> _loadDoctorDetailsAndInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    // Load only userId, assume role is Doctor
    userId = prefs.getString(_userIdKey);

    debugPrint("🔹 Doctor User ID: $userId");
    debugPrint("Socket called");
    await socketService.connect(); // Connect to socket server
    debugPrint("Socket finished calling");


    if (userId == null || userId!.isEmpty) {
      _showSnackBar("User ID not found. Please log in again.", isError: true);
      _logOut(); // Log out if essential ID is missing
      return;
    }

    // Run HTTP fetches concurrently
    await Future.wait([
      _loadConversations(),
      _loadAppointments(), // Load appointments (cache first, then fetch)
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false; // Mark loading as complete
      });
    }
  }

  // --- END SOCKET FUNCTION UPDATE ---

  void _setupMessageListener() {
    // Listen for the 'reveiveMessage' event (with the typo from your backend)
    socket!.on('reveiveMessage', (data) {
      debugPrint('SOCKET: Message Received: $data');
      if (data is Map<String, dynamic>) {
        final newMessage = data;
        final msgConvoId = newMessage['conversationId'];

        // 1. If user is in the correct chat window, add message to UI
        if (isChatOpen && msgConvoId == selectedConversationId) {
          dynamic senderData = newMessage['sender'];
          String senderId = "";

          if (senderData is Map<String, dynamic>) {
            senderId = senderData['id']?.toString() ?? '';
          } else {
            senderId = senderData?.toString() ?? '';
          }

          // Only add if it's NOT from me (my own messages are added optimistically)
          if (senderId != userId) {
            if (mounted) {
              setState(() {
                messages.insert(0, newMessage);
              });
              _scrollToBottom(); // Scroll down on new message
            }
          }
        }

        // 2. Update the conversation list (lastMessage, sort)
        if (mounted) {
          setState(() {
            // Find the conversation
            final convoIndex = conversations.indexWhere(
              (c) => c['_id'] == msgConvoId,
            );
            if (convoIndex != -1) {
              // Remove from list
              final convo = conversations.removeAt(convoIndex);
              // Update its last message and time
              convo['lastMessage'] = newMessage['message'];
              convo['updatedAt'] =
                  newMessage['createdAt']; // Use timestamp from server
              // Add back to the top of the list
              conversations.insert(0, convo);
            }
          });
        }
      }
    });
  }

  // Helper to safely show SnackBars
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

  // --- 3. ADD SCROLLTOBOTTOM FUNCTION ---
  void _scrollToBottom() {
    // Wait for the frame to build, then animate to the end
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController
              .position
              .minScrollExtent, // reverse: true means min is the bottom
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- Data Loading Functions ---

  Future<void> _loadConversations({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedDataString;

    // 1. Load from cache first
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
          await prefs.remove(_conversationsCacheKey); // Clear corrupted cache
        }
      }
    }

    // 2. Fetch from network
    try {
      // Hardcode 'doctor' role for fetching conversations
      final List<Map<String, dynamic>> fetchedConversations =
          await ApiService.fetchConversations(role: 'doctor');

      if (!mounted) return;

      final String fetchedDataString = json.encode(fetchedConversations);

      // 3. Compare and Update Cache/State if necessary
      if (fetchedDataString != cachedDataString) {
        debugPrint("🔄 Updated conversations cache.");
        await prefs.setString(_conversationsCacheKey, fetchedDataString);
        setState(() {
          conversations = fetchedConversations;
        });
        // Only show snackbar if it's an update, not the very first load
        if (cachedDataString != null) {
          _showSnackBar("Conversations updated.");
        }
      } else {
        debugPrint("ℹ️ Conversations are up-to-date.");
      }
    } catch (e) {
      debugPrint("❌ Error loading conversations: $e");
      // Only show error if there was no cache to load initially
      if (cachedDataString == null) {
        if (mounted)
          _showSnackBar("Could not load conversations.", isError: true);
      }
    }
  }

  Future<void> _loadAppointments({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load from cache first (unless forced refresh)
    if (!forceRefresh) {
      final cachedPending = prefs.getString(_pendingCacheKey);
      final cachedApproved = prefs.getString(_approvedCacheKey);

      bool cacheLoaded = false;
      try {
        if (cachedPending != null) {
          pendingAppointments =
              (json.decode(cachedPending) as List).cast<Map<String, dynamic>>();
          cacheLoaded = true;
        }
        if (cachedApproved != null) {
          approvedAppointments =
              (json.decode(cachedApproved) as List)
                  .cast<Map<String, dynamic>>();
          cacheLoaded = true;
        }
        if (cacheLoaded && mounted) {
          debugPrint("✅ Loaded appointments from cache.");
          setState(() {
            // Update count based on cache
            _pendingCount = pendingAppointments.length;
          });
        }
      } catch (e) {
        debugPrint("⚠️ Error decoding appointment cache: $e");
        await prefs.remove(
          _pendingCacheKey,
        ); // Clear potentially corrupted cache
        await prefs.remove(_approvedCacheKey);
        pendingAppointments = []; // Reset state lists
        approvedAppointments = [];
        if (mounted) setState(() => _pendingCount = 0);
      }
    } else {
      // If forcing refresh, clear current state lists
      pendingAppointments = [];
      approvedAppointments = [];
      if (mounted) setState(() => _pendingCount = 0);
    }

    // 2. Fetch from network
    try {
      // Fetch concurrently
      final results = await Future.wait([
        ApiService.fetchPendingAppointments(),
        ApiService.fetchapprovedAppointments(),
      ]);

      final List<Map<String, dynamic>> fetchedPending = results[0];
      final List<Map<String, dynamic>> fetchedApproved = results[1];

      if (!mounted) return;

      // 3. Compare and Update Cache/State if necessary
      final String fetchedPendingStr = json.encode(fetchedPending);
      final String fetchedApprovedStr = json.encode(fetchedApproved);
      final String? currentCachedPending = prefs.getString(_pendingCacheKey);
      final String? currentCachedApproved = prefs.getString(_approvedCacheKey);

      bool updated = false;
      if (fetchedPendingStr != currentCachedPending) {
        await prefs.setString(_pendingCacheKey, fetchedPendingStr);
        pendingAppointments = fetchedPending;
        updated = true;
        debugPrint("🔄 Updated pending appointments cache.");
      }
      if (fetchedApprovedStr != currentCachedApproved) {
        await prefs.setString(_approvedCacheKey, fetchedApprovedStr);
        approvedAppointments = fetchedApproved;
        updated = true;
        debugPrint("🔄 Updated approved appointments cache.");
      }

      if (updated) {
        setState(() {
          // Update count based on fetched data
          _pendingCount = pendingAppointments.length;
        });
      } else {
        debugPrint("ℹ️ Appointments are up-to-date.");
      }
    } catch (e) {
      debugPrint("❌ Error loading appointments from API: $e");
      // Show error only if there was no cache to load initially
      if (prefs.getString(_pendingCacheKey) == null &&
          prefs.getString(_approvedCacheKey) == null) {
        if (mounted)
          _showSnackBar("Could not load appointments.", isError: true);
      }
    }
  }

  Future<void> _loadMessages() async {
    if (selectedConversationId == null) return;
    try {
      final data = await ApiService.fetchMessages(selectedConversationId!);
      if (mounted) {
        setState(
          () => messages = data.reversed.toList(),
        ); // Show latest messages at bottom
      }
    } catch (e) {
      debugPrint("❌ Error fetching messages: $e");
      if (mounted) _showSnackBar("Could not load messages.", isError: true);
    }
  }

  // --- Chat Actions ---

  Future<void> _openChat(Map conversation) async {
    if (userId == null) {
      _showSnackBar("User ID not found. Cannot open chat.", isError: true);
      return;
    }
    // Safely get conversation ID
    selectedConversationId = conversation["_id"]?.toString();
    if (selectedConversationId == null) {
      _showSnackBar("Conversation ID missing.", isError: true);
      return;
    }

    // --- USE SOCKET SERVICE ---
    socketService.joinRoom(selectedConversationId!);

    // Safely get participant name
    final List participants = conversation["participants"] ?? [];
    final otherUser = participants.firstWhere(
      (p) => p is Map && p["id"] != userId,
      orElse:
          () =>
              participants.isNotEmpty && participants.first is Map
                  ? participants.first
                  : {"name": "Unknown"},
    );
    selectedUser = otherUser["name"] ?? "Unknown User";

    setState(() => isChatOpen = true);
    await _loadMessages(); // Still load history via HTTP
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || selectedConversationId == null || userId == null)
      return;

    if (!socketService.isConnected) {
      _showSnackBar("Not connected. Reconnecting...", isError: true);
      await socketService.connect(); // Attempt to reconnect
      await Future.delayed(const Duration(seconds: 1));
      if (!socketService.isConnected) {
        _showSnackBar("Connection failed. Please try again.", isError: true);
        return;
      }
    }

    // --- Optimistic UI ---
    final tempMessage = {
      "message": text,
      "sender": {
        "id": userId,
        "role": "doctor",
      }, // Match the populated structure
      "senderPic": null, // My pic will be added by _buildChatWindow
      "conversationId": selectedConversationId!,
      "createdAt": DateTime.now().toIso8601String(),
    };
    if (mounted) {
      setState(() {
        messages.insert(0, tempMessage);
        messageController.clear();
      });
      _scrollToBottom(); // Scroll down when *I* send a message
    }
    // --- End Optimistic UI ---

    try {
      // Use the SocketService to send the message
      socketService.sendMessage(selectedConversationId!, text);
    } catch (e) {
      debugPrint("❌ Error emitting message: $e");
      if (mounted) {
        _showSnackBar("Error sending message: $e", isError: true);
        // Remove optimistic message if sending fails
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
    await prefs.remove(_pendingCacheKey);
    await prefs.remove(_approvedCacheKey);
    await prefs.remove(_conversationsCacheKey);

    // --- DISCONNECT SOCKET ON LOGOUT ---
    socketService.disconnect();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // --- Appointments Modal ---

  void _showAppointmentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildCard(
              Map<String, dynamic> req, {
              bool approved = false,
            }) {
              final dateStr = req['date'] ?? req['appointmentStartDate'];
              final date = DateTime.tryParse(dateStr ?? '');
              final formattedDate =
                  date != null
                      ? DateFormat('E, MMM d, yyyy').format(date)
                      : 'Unknown Date';

              final startTime = req['appointmentStartTime'] ?? 'N/A';
              final endTime = req['appointmentEndTime'] ?? 'N/A';
              final patient = req['patient']?['name'] ?? 'Unknown Patient';
              final description =
                  req['description'] ?? 'No description provided';
              final String appointmentId =
                  req['appointmentId']?.toString() ??
                  req['_id']?.toString() ??
                  '';

              return Card(
                color: approved ? Colors.green.shade50 : Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        approved
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                    child: Text(
                      patient.isNotEmpty ? patient[0].toUpperCase() : '?',
                      style: TextStyle(
                        color:
                            approved
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                      ),
                    ),
                  ),
                  title: Text(
                    patient,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text("🗓️ Date: $formattedDate"),
                      Text("🕒 Time: $startTime - $endTime"),
                      Text(
                        "📋 Issue: $description",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  trailing:
                      approved
                          ? Icon(
                            Icons.check_circle_outline,
                            color: Colors.green.shade600,
                            size: 28,
                          )
                          : Icon(
                            Icons.pending_actions_outlined,
                            color: Colors.orange.shade700,
                            size: 28,
                          ),
                  onTap:
                      approved || appointmentId.isEmpty
                          ? null
                          : () {
                            _showApprovalForm(req, () async {
                              await _loadAppointments(forceRefresh: true);
                              if (mounted) setModalState(() {});
                            });
                          },
                ),
              );
            }

            Widget buildSection(
              String title,
              List<Map<String, dynamic>> list, {
              bool approved = false,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0, bottom: 8.0),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            approved
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                      ),
                    ),
                  ),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          approved
                              ? "No approved appointments"
                              : "No pending requests",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    )
                  else
                    ...list.map((e) => buildCard(e, approved: approved)),
                  const SizedBox(height: 15),
                  if (title == "Pending Requests")
                    Divider(
                      thickness: 1,
                      color: Colors.grey.shade300,
                      height: 20,
                    ),
                ],
              );
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              builder: (_, controller) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          margin: const EdgeInsets.only(top: 8, bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: controller,
                          children: [
                            buildSection(
                              "Pending Requests",
                              pendingAppointments,
                            ),
                            buildSection(
                              "Approved Appointments",
                              approvedAppointments,
                              approved: true,
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showApprovalForm(
    Map<String, dynamic> request,
    VoidCallback refreshParentModal,
  ) async {
    DateTime? date;
    TimeOfDay? start;
    TimeOfDay? end;
    bool isProcessing = false;

    final String appointmentId =
        request['appointmentId']?.toString() ??
        request['_id']?.toString() ??
        '';
    if (appointmentId.isEmpty) {
      _showSnackBar("Cannot approve: Missing appointment ID.", isError: true);
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setApprovalModalState) {
            final safeName = request['patient']?['name'] ?? 'Unknown Patient';
            final issue =
                (request['description']?.toString().trim().isNotEmpty ?? false)
                    ? request['description']
                    : 'No description provided';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Text(
                      "Approve Appointment",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Patient: $safeName",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Issue: $issue",
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 20),

                    // Date & Time Pickers
                    _buildPickerButton(
                      context: context,
                      icon: Icons.calendar_month_outlined,
                      label:
                          date == null
                              ? "Select Date"
                              : DateFormat('yyyy-MM-dd').format(date!),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: date ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setApprovalModalState(() => date = d);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildPickerButton(
                      context: context,
                      icon: Icons.access_time_outlined,
                      label:
                          start == null
                              ? "Select Start Time"
                              : start!.format(context),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: start ?? TimeOfDay.now(),
                        );
                        if (t != null) setApprovalModalState(() => start = t);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildPickerButton(
                      context: context,
                      icon: Icons.timer_off_outlined,
                      label:
                          end == null
                              ? "Select End Time"
                              : end!.format(context),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: end ?? TimeOfDay.now(),
                        );
                        if (t != null) {
                          if (start != null) {
                            final startMinutes =
                                start!.hour * 60 + start!.minute;
                            final endMinutes = t.hour * 60 + t.minute;
                            if (endMinutes <= startMinutes) {
                              _showSnackBar(
                                "End time must be after start time.",
                                isError: true,
                              );
                              return;
                            }
                          }
                          setApprovalModalState(() => end = t);
                        }
                      },
                    ),
                    const SizedBox(height: 25),

                    // Action Buttons
                    if (isProcessing)
                      Center(
                        child: CircularProgressIndicator(
                          color: Colors.orange.shade700,
                        ),
                      )
                    else
                      Row(
                        children: [
                          // Reject Button
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close),
                              label: const Text("Reject"),
                              onPressed: () async {
                                setApprovalModalState(
                                  () => isProcessing = true,
                                );
                                try {
                                  await ApiService.rejectAppointment(
                                    appointmentId,
                                  );
                                  _showSnackBar(
                                    "Appointment Rejected",
                                    isError: false,
                                  );
                                  refreshParentModal();
                                  if (mounted) Navigator.pop(context);
                                } catch (e) {
                                  _showSnackBar(
                                    "Failed to reject: $e",
                                    isError: true,
                                  );
                                } finally {
                                  if (mounted)
                                    setApprovalModalState(
                                      () => isProcessing = false,
                                    );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade600,
                                side: BorderSide(
                                  color: Colors.red.shade300,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Approve Button
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text("Confirm"),
                              onPressed: () async {
                                if (date == null ||
                                    start == null ||
                                    end == null) {
                                  _showSnackBar(
                                    "Please select date and times.",
                                    isError: true,
                                  );
                                  return;
                                }
                                final startM = start!.hour * 60 + start!.minute;
                                final endM = end!.hour * 60 + end!.minute;
                                if (endM <= startM) {
                                  _showSnackBar(
                                    "End time must be after start time.",
                                    isError: true,
                                  );
                                  return;
                                }

                                setApprovalModalState(
                                  () => isProcessing = true,
                                );
                                try {
                                  final success =
                                      await ApiService.approveAppointment(
                                        requestId: appointmentId,
                                        date: DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(date!),
                                        startTime: start!.format(context),
                                        endTime: end!.format(context),
                                      );

                                  if (success) {
                                    _showSnackBar(
                                      "Appointment approved successfully",
                                    );
                                    refreshParentModal();
                                    if (mounted) Navigator.pop(context);
                                  } else {
                                    _showSnackBar(
                                      "Failed to approve appointment.",
                                      isError: true,
                                    );
                                  }
                                } catch (e) {
                                  _showSnackBar(
                                    "Error approving appointment: $e",
                                    isError: true,
                                  );
                                } finally {
                                  if (mounted)
                                    setApprovalModalState(
                                      () => isProcessing = false,
                                    );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.orange.shade700,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Generic Picker Button used in Approval Form
  Widget _buildPickerButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.orange.shade700, size: 20),
      label: Text(
        label,
        style: TextStyle(color: Colors.orange.shade900, fontSize: 16),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.orange.shade900,
        side: BorderSide(color: Colors.orange.shade300, width: 1),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerLeft,
      ),
    );
  }

  // --- Main Chat Window UI ---
  Widget _buildChatWindow() {
    return Column(
      children: [
        // Chat Header
        Container(
          // Upgraded Header Style
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
              // Add CircleAvatar
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withOpacity(0.3),
                // TODO: Get other user's image URL from conversation object
                // backgroundImage: NetworkImage(otherUserImageUrl),
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
                    fontWeight: FontWeight.w600, // Changed weight
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Add Video/Audio Call Icons
              IconButton(
                icon: const Icon(
                  Icons.videocam_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed:
                    () => _showSnackBar(
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
                onPressed:
                    () => _showSnackBar(
                      "Audio call not implemented yet.",
                      isError: true,
                    ),
                tooltip: "Audio Call",
              ),
            ],
          ),
        ),

        // Message List
        Expanded(
          child:
              messages.isEmpty
                  ? const Center(
                    child: Text(
                      "No messages yet. Start chatting!",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : ListView.builder(
                    // --- 4. ATTACH SCROLL CONTROLLER ---
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
                        // Check 'sender'
                        return const SizedBox.shrink();
                      }

                      // --- Fix: Handle different sender structures ---
                      dynamic senderData = msg['sender'];
                      String senderId = "";
                      if (senderData is Map<String, dynamic>) {
                        senderId = senderData['id']?.toString() ?? '';
                      } else {
                        senderId =
                            senderData?.toString() ??
                            ''; // Backend might just send ID
                      }
                      final isMe = senderId == userId;
                      // --- End Fix ---

                      // --- Check for local file path ---
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
                          padding:
                              isLocalFile
                                  ? const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  )
                                  : const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 14,
                                  ),
                          decoration: BoxDecoration(
                            color:
                                isMe
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
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child:
                              isLocalFile
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

        // Message Input Area
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
          // Use SafeArea to avoid system intrusions (like home bar)
          child: SafeArea(
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.center, // Align items vertically
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline_rounded, // Use a filled icon
                    color: Colors.orange,
                    size: 28,
                  ),
                  tooltip: "Send Media",
                  onPressed: _pickMedia, // Call the media picker
                ),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    style: const TextStyle(fontSize: 16),
                    maxLines: null, // Allow multiline input
                    textInputAction:
                        TextInputAction.newline, // Support multiline
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
                      ), // Adjusted padding
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      isDense: true, // Make text field compact
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                // Animated Send Button
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

  // --- Main Chat List UI ---
  Widget _buildChatList() {
    if (conversations.isEmpty && !_isLoading) {
      // Check for loading state
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
                "Approved appointments will appear here.",
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

    // Display the list of conversations
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
            orElse:
                () => participants.firstWhere(
                  (p) => p is Map,
                  orElse: () => null,
                ),
          );

          if (otherUser == null) return const SizedBox.shrink();

          final String otherUserName = otherUser["name"] ?? "Unknown User";
          final String otherUserRole = otherUser["role"] ?? "User";
          final String initial =
              otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : "?";
          // Get last message info
          final String lastMessage =
              convo['lastMessage'] ?? 'No messages yet...';
          final String lastMessageTime =
              convo['updatedAt'] != null
                  ? DateFormat('h:mm a').format(
                    DateTime.parse(convo['updatedAt']).toLocal(),
                  ) // Format time
                  : '';
          final String? otherUserImageUrl =
              otherUser['imageUrl']; // Get image URL

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
                  fontStyle:
                      lastMessage == 'No messages yet...'
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
                  ), // Smaller icon
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

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep state alive
    return Scaffold(
      backgroundColor: Colors.orange.shade50, // Consistent background
      floatingActionButton: badges.Badge(
        showBadge: _pendingCount > 0,
        position: badges.BadgePosition.topEnd(top: -4, end: -4),
        badgeContent: Text(
          _pendingCount.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red),
        child: FloatingActionButton(
          backgroundColor: Colors.orange.shade700,
          onPressed: _showAppointmentsSheet,
          tooltip: "View Appointments",
          child: const Icon(
            Icons.calendar_month_outlined,
            size: 28,
            color: Colors.white,
          ),
        ),
      ),

      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          key: ValueKey(isChatOpen),
          child:
              _isLoading
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

  // --- Media Picker Widgets ---

  void _sendMediaMessage(File file, {bool isVideo = false}) {
    // This is a placeholder
    // TODO: Implement file upload (e.g., to Cloudinary) and then
    // call _sendMessage with the URL and a type identifier.
    _showSnackBar("Media upload not implemented yet.", isError: true);

    // For now, it just adds a local placeholder.
    if (!mounted) return;
    setState(() {
      messages.insert(0, {
        "sender": {"id": userId, "role": "doctor"}, // Match sender structure
        "message":
            isVideo
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
                        Navigator.pop(context); // Close modal first
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
          // --- FIX for deprecated withOpacity ---
          color: color.withAlpha((255 * 0.08).round()), // Use withAlpha
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withAlpha((255 * 0.3).round()),
          ), // Use withAlpha
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
} // End of _LiveChat2State
