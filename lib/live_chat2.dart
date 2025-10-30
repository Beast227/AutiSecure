import 'dart:convert';
import 'dart:io';
import 'package:autisecure/services/api_service.dart';
import 'package:autisecure/login_signup/login_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badges/badges.dart' as badges;

class LiveChat2 extends StatefulWidget {
  const LiveChat2({super.key});

  @override
  State<LiveChat2> createState() => _LiveChat2State();
}

class _LiveChat2State extends State<LiveChat2>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  bool isChatOpen = false;
  String selectedUser = '';
  String? userId;
  String? selectedConversationId;
  List conversations = [];
  List messages = [];
  List<Map<String, dynamic>> approvedAppointments = [];
  List<Map<String, dynamic>> pendingAppointments = [];
  int _pendingCount = 0;

  final TextEditingController messageController = TextEditingController();

  static const String _pendingCacheKey = 'pendingAppointmentsCache';
  static const String _approvedCacheKey = 'approvedAppointmentsCache';
  static const String _conversationsCacheKey = 'conversationsCache';
  static const String _userIdKey = 'userId';
  static const String _roleKey = 'role';
  static const String _tokenKey = 'token';

  @override
  void initState() {
    super.initState();
    // Load details and initial data
    _loadDoctorDetailsAndInitialData();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorDetailsAndInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    // Load only userId, assume role is Doctor
    userId = prefs.getString(_userIdKey);

    debugPrint("🔹 Doctor User ID: $userId");

    if (userId == null || userId!.isEmpty) {
      _showSnackBar("User ID not found. Please log in again.", isError: true);
      _logOut(); // Log out if essential ID is missing
      return;
    }

    // Run fetches concurrently
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

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : Colors.orangeAccent, // Use theme color
        behavior: SnackBarBehavior.floating, // Make it float above FAB
      ),
    );
  }

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
    await _loadMessages(); // Load messages for the selected chat
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || selectedConversationId == null || userId == null)
      return;

    // Optimistic UI update
    final tempMessage = {
      "message": text,
      "senderId": userId!,
      // --- CORRECTED TYPO ---
      "timestamp": DateTime.now().toIso8601String(), // Was toIso_8601String
    };
    if (mounted) {
      setState(() {
        messages.insert(0, tempMessage);
      });
    }
    messageController.clear();

    try {
      final success = await ApiService.sendMessage(
        conversationId: selectedConversationId!,
        senderId: userId!,
        message: text,
      );

      if (!success && mounted) {
        _showSnackBar("Failed to send message.", isError: true);
        setState(() {
          messages.remove(tempMessage);
        });
      } else if (mounted) {
        // Reload messages on success to confirm
        await _loadMessages();
      }
    } catch (e) {
      debugPrint("❌ Error sending message: $e");
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
    await prefs.remove(_pendingCacheKey);
    await prefs.remove(_approvedCacheKey);
    await prefs.remove(_conversationsCacheKey);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showAppointmentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Make modal background transparent
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        // Use StatefulBuilder to allow updates *within* the modal after approve/reject
        return StatefulBuilder(
          builder: (context, setModalState) {
            // --- Modal Build Helpers ---
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
                              await _loadAppointments(
                                forceRefresh: true,
                              ); // Force refresh lists
                              if (mounted)
                                setModalState(() {}); // Rebuild modal UI
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
                    ...list.map(
                      (e) => buildCard(e, approved: approved),
                    ), // Spread operator
                  const SizedBox(height: 15),
                  if (title ==
                      "Pending Requests") // Add divider only after pending
                    Divider(
                      thickness: 1,
                      color: Colors.grey.shade300,
                      height: 20,
                    ),
                ],
              );
            }
            // --- End Modal Build Helpers ---

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
                      // Draggable Handle
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
                      // Scrollable Content
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
                    // Draggable Handle
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
                                  if (mounted) {
                                    setApprovalModalState(
                                      () => isProcessing = false,
                                    );
                                  }
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
                                // Validation
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
                                  if (mounted) {
                                    setApprovalModalState(
                                      () => isProcessing = false,
                                    );
                                  }
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
                    const SizedBox(height: 20), // Padding at the bottom
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

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

  Widget _buildSquareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
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

  void _sendMediaMessage(File file, {bool isVideo = false}) {
    // Upload logic or directly show in chat
    setState(() {
      messages.insert(0, {
        "senderId": userId,
        "message": isVideo ? "[Video File]" : "[Image File]",
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
                      icon: Icons.photo,
                      label: "Gallery",
                      color: Colors.orange,
                      onTap: () async {
                        final XFile? image = await _picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        Navigator.pop(context);
                        if (image != null) {
                          _sendMediaMessage(File(image.path), isVideo: false);
                        }
                      },
                    ),
                    _buildSquareOption(
                      icon: Icons.videocam_rounded,
                      label: "Video",
                      color: Colors.orange,
                      onTap: () async {
                        final XFile? video = await _picker.pickVideo(
                          source: ImageSource.gallery,
                        );
                        Navigator.pop(context);
                        if (video != null) {
                          _sendMediaMessage(File(video.path), isVideo: true);
                        }
                      },
                    ),
                    _buildSquareOption(
                      icon: Icons.camera_alt_rounded,
                      label: "Camera",
                      color: Colors.orange,
                      onTap: () async {
                        final XFile? photo = await _picker.pickImage(
                          source: ImageSource.camera,
                        );
                        Navigator.pop(context);
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

  Widget _buildChatWindow() {
    return Column(
      children: [
        // 🟠 Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade700, Colors.orange.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.shade200.withOpacity(0.6),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => isChatOpen = false),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                tooltip: "Back to Chats",
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: const Icon(Icons.person, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selectedUser,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.videocam_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 20),
              Icon(Icons.call_rounded, color: Colors.white, size: 24),
            ],
          ),
        ),

        // 💬 Message List
        Expanded(
          child:
              messages.isEmpty
                  ? const Center(
                    child: Text(
                      "No messages yet. Start chatting!",
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  )
                  : ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      if (msg == null ||
                          msg is! Map ||
                          msg["message"] == null ||
                          msg["senderId"] == null) {
                        return const SizedBox.shrink();
                      }
                      final isMe = msg["senderId"] == userId;
                      final isImage = msg["type"] == "image";

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding:
                              isImage
                                  ? const EdgeInsets.all(4)
                                  : const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 14,
                                  ),
                          decoration: BoxDecoration(
                            color:
                                isMe
                                    ? Colors.orange.shade100
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMe ? 18 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 3,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child:
                              isImage
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      msg["message"],
                                      fit: BoxFit.cover,
                                    ),
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

        // ✉️ Message Input Area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),
                  tooltip: "Send Image or Video",
                  onPressed: _pickMedia,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        hintText: "Type your message...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
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
                  child: IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: _sendMessage,
                    tooltip: "Send Message",
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
    // Show loading indicator while role/conversations load initially
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (conversations.isEmpty) {
      // Improved placeholder for empty state
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
              // Message specific to Doctor role
              Text(
                "Approved appointments will appear here.",
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Add a refresh button to the empty state
              IconButton(
                icon: const Icon(Icons.refresh, size: 30, color: Colors.orange),
                tooltip: "Refresh Conversations",
                onPressed:
                    () =>
                        _loadConversations(forceRefresh: true), // Force refresh
              ),
            ],
          ),
        ),
      );
    }

    // Display the list of conversations
    return RefreshIndicator(
      onRefresh: () => _loadConversations(forceRefresh: true), // Force refresh
      color: Colors.orange,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final convo = conversations[index];
          // Basic validation for conversation structure
          if (convo == null ||
              convo is! Map ||
              convo["participants"] == null ||
              convo["participants"] is! List ||
              (convo["participants"] as List).isEmpty) {
            return const SizedBox.shrink();
          }

          final List participants = convo["participants"];
          // Find the other participant more safely
          final otherUser = participants.firstWhere(
            (p) => p is Map && p["id"] != userId,
            orElse:
                () => participants.firstWhere(
                  (p) => p is Map,
                  orElse: () => null,
                ), // Fallback
          );

          // Handle case where other user couldn't be determined
          if (otherUser == null) return const SizedBox.shrink();

          final String otherUserName = otherUser["name"] ?? "Unknown User";
          // Since this screen is for Doctors, the other user is likely a 'User'
          // final String otherUserRole = otherUser["role"] ?? "Tap to Chat...";
          final String otherUserRole = "Tap to Chat...";
          final String initial =
              otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : "?";

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
                child: Text(
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
                otherUserRole,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: Icon(
                Icons.message,
                color: Colors.orange.shade400,
                size: 30,
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
    super.build(context); // Keep state alive
    return Scaffold(
      backgroundColor: Colors.orange.shade50, // Consistent background
      floatingActionButton:
          !isChatOpen
              ? badges.Badge(
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
              )
              : null,

      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          // Conditionally show loading, chat window, or chat list
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  ) // Show loading initially
                  : isChatOpen
                  ? _buildChatWindow() // Show chat window if open
                  : _buildChatList(), // Show conversation list otherwise
        ),
      ),
    );
  }
}
 