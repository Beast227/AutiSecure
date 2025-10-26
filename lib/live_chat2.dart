import 'package:autisecure/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveChat2 extends StatefulWidget {
  const LiveChat2({super.key});

  @override
  State<LiveChat2> createState() => _LiveChat2State();
}

class _LiveChat2State extends State<LiveChat2>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool isRoleLoaded = false;
  bool isChatOpen = false;
  String selectedUser = '';
  String? userRole;
  String? userId;
  String? selectedConversationId;
  List conversations = [];
  List messages = [];
  List<Map<String, dynamic>> approvedAppointments = [];
  List<Map<String, dynamic>> pendingAppointments = [];

  final TextEditingController messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _loadAppointments();
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    userRole = prefs.getString('role');
    userId = prefs.getString('userId');

    debugPrint("🔹 Loaded userRole: $userRole");
    debugPrint("🔹 Loaded userId: $userId");

    await _loadConversations();
    setState(() {
      isRoleLoaded = true;
    });
  }

  Future<void> _loadConversations() async {
    try {
      final data = await ApiService.fetchConversations(
        role: userRole ?? 'user',
      );
      setState(() {
        conversations = data;
      });
    } catch (e) {
      debugPrint("Error loading conversations: $e");
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final data1 = await ApiService.fetchPendingAppointments();
      final data2 = await ApiService.fetchapprovedAppointments();
      setState(() {
        approvedAppointments = data2;
        pendingAppointments = data1;
      });
      debugPrint(
        "\nThhe appointments are :\n$approvedAppointments\n\n\t\t\t\t\t\t\t $pendingAppointments",
      );
    } catch (e) {
      debugPrint("\n\nError loading appointments: $e\n\n");
    }
  }

  Future<void> _openChat(Map conversation) async {
    selectedConversationId = conversation["_id"];
    selectedUser =
        conversation["participants"].firstWhere(
          (p) => p["id"] != userId,
          orElse: () => conversation["participants"][0],
        )["name"];
    setState(() => isChatOpen = true);
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      if (selectedConversationId == null) return;
      final data = await ApiService.fetchMessages(selectedConversationId!);
      setState(() => messages = data.reversed.toList());
    } catch (e) {
      debugPrint("Error fetching messages: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || selectedConversationId == null) return;

    final success = await ApiService.sendMessage(
      conversationId: selectedConversationId!,
      senderId: userId!,
      message: text,
    );

    if (success) {
      messageController.clear();
      await _loadMessages();
    }
  }

  void _showAppointmentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return FutureBuilder(
          future: _loadAppointments(), // ✅ always reload fresh
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 300,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.orange.shade700,
                  ),
                ),
              );
            }

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
                          ? DateFormat('yyyy-MM-dd').format(date)
                          : 'Unknown';

                  final startTime = req['appointmentStartTime'] ?? 'Not set';
                  final endTime = req['appointmentEndTime'] ?? 'Not set';
                  final patient = req['patient']?['name'] ?? 'Unknown';
                  final description = req['description'] ?? 'No description';

                  return Card(
                    color: approved ? Colors.green.shade50 : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Text(patient[0].toUpperCase()),
                      ),
                      title: Text(
                        patient,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("Date: $formattedDate"),
                          Text("Time : $startTime to $endTime"),
                          Text("Issue: $description"),
                        ],
                      ),
                      trailing: Icon(
                        approved ? Icons.check_circle : Icons.arrow_forward_ios,
                        color: approved ? Colors.green : Colors.orange,
                      ),
                      onTap:
                          approved
                              ? null
                              : () => _showApprovalForm(req, () async {
                                await _loadAppointments();
                                setModalState(() {});
                              }),
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
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              approved
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              approved
                                  ? "No approved appointments 🎉"
                                  : "No pending requests 🎉",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        )
                      else
                        ...list.map((e) => buildCard(e, approved: approved)),
                      const SizedBox(height: 15),
                      Divider(thickness: 1, color: Colors.grey.shade300),
                    ],
                  );
                }

                return DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.7,
                  maxChildSize: 0.95,
                  builder: (_, controller) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: ListView(
                        controller: controller,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              margin: const EdgeInsets.only(top: 8, bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          buildSection(
                            "Approved Requests",
                            approvedAppointments,
                            approved: true,
                          ),
                          buildSection("Pending Requests", pendingAppointments),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      floatingActionButton: AnimatedScale(
        scale: (userRole == "Doctor" && !isChatOpen) ? 1.0 : 0.0,
        duration: Duration(milliseconds: 300),
        child: AnimatedOpacity(
          opacity: (userRole == "Doctor" && !isChatOpen) ? 1.0 : 0.0,
          duration: Duration(milliseconds: 300),
          child: FloatingActionButton(
            backgroundColor: Colors.orange.shade700,
            onPressed: _showAppointmentsSheet,
            child: const Icon(Icons.add, size: 30, color: Colors.white),
          ),
        ),
      ),

      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isChatOpen ? _buildChatWindow() : _buildChatList(),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    debugPrint("Fetched Conversations Data: ${conversations.toString()}");

    if (conversations.isEmpty) {
      // Show a nice placeholder when no chats exist
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 70,
                color: Colors.orange.shade300,
              ),
              const SizedBox(height: 20),
              const Text(
                "No conversations yet",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5A2500),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "To start a new chat, book an appointment first!",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final convo = conversations[index];
        final participants = convo["participants"];
        final otherUser = participants.firstWhere(
          (p) => p["id"] != userId,
          orElse: () => participants.first,
        );

        return Card(
          color: Colors.white,
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.orange.shade200,
              child: Text(
                otherUser["name"][0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5A2500),
                ),
              ),
            ),
            title: Text(
              otherUser["name"],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(otherUser["role"]),
            trailing: const Icon(
              Icons.chat_bubble_outline,
              color: Color(0xFFFF7A00),
            ),
            onTap: () => _openChat(convo),
          ),
        );
      },
    );
  }

  void showOverlayToast(
    BuildContext context,
    String message, {
    Color? bgColor,
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder:
          (_) => Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: bgColor ?? Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () => overlayEntry.remove());
  }

  Future<void> _showApprovalForm(
    Map<String, dynamic> request,
    VoidCallback refreshModal,
  ) async {
    DateTime? date;
    TimeOfDay? start;
    TimeOfDay? end;
    bool isLoading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final safeName = request['patient']?['name'] ?? 'Unknown';
            final issue =
                (request['description']?.toString().trim().isNotEmpty ?? false)
                    ? request['description']
                    : 'No description provided';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 25,
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
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                      icon: Icons.calendar_month,
                      label:
                          date == null
                              ? "Select Date"
                              : DateFormat('yyyy-MM-dd').format(date!),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setModalState(() => date = d);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildPickerButton(
                      context: context,
                      icon: Icons.access_time,
                      label:
                          start == null
                              ? "Select Start Time"
                              : start!.format(context),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (t != null) setModalState(() => start = t);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildPickerButton(
                      context: context,
                      icon: Icons.timer_off,
                      label:
                          end == null
                              ? "Select End Time"
                              : end!.format(context),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (t != null) setModalState(() => end = t);
                      },
                    ),
                    const SizedBox(height: 25),

                    if (isLoading)
                      Center(
                        child: CircularProgressIndicator(
                          color: Colors.orange.shade700,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                setModalState(() => isLoading = true);
                                await ApiService.rejectAppointment(
                                  request['appointmentId'],
                                );
                                showOverlayToast(
                                  context,
                                  "Appointment Rejected",
                                  bgColor: Colors.red.shade600,
                                );
                                refreshModal();
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.red.shade600,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Reject",
                                style: TextStyle(
                                  color: Colors.red.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (date == null ||
                                    start == null ||
                                    end == null) {
                                  showOverlayToast(
                                    context,
                                    "Please select all details",
                                    bgColor: Colors.red.shade600,
                                  );
                                  return;
                                }
                                final startM = start!.hour * 60 + start!.minute;
                                final endM = end!.hour * 60 + end!.minute;
                                if (endM <= startM) {
                                  showOverlayToast(
                                    context,
                                    "End time must be after start time",
                                    bgColor: Colors.red.shade600,
                                  );
                                  return;
                                }

                                setModalState(() => isLoading = true);
                                final success =
                                    await ApiService.approveAppointment(
                                      requestId:
                                          request["appointmentId"]
                                              ?.toString() ??
                                          "",
                                      date: DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(date!),
                                      startTime: start!.format(context),
                                      endTime: end!.format(context),
                                    );
                                setModalState(() => isLoading = false);

                                if (success) {
                                  showOverlayToast(
                                    context,
                                    "Appointment approved successfully",
                                    bgColor: Colors.green.shade600,
                                  );
                                  refreshModal();
                                  Navigator.pop(context);
                                } else {
                                  showOverlayToast(
                                    context,
                                    "Failed to approve appointment",
                                    bgColor: Colors.red.shade600,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Confirm",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatWindow() {
    return Column(
      children: [
        Container(
          color: Colors.orange.shade700,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => isChatOpen = false),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              ),
              Text(
                selectedUser,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            reverse: true,
            itemCount: messages.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isMe = msg["senderId"] == userId;

              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        isMe ? Colors.orange.shade300 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    msg["message"],
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    hintText: "Type your message...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.orange),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
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
      icon: Icon(icon, color: Colors.orange.shade700),
      label: Text(label, style: TextStyle(color: Colors.orange.shade700)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.orange.shade400, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
