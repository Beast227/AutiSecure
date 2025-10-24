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
  List appointments = [];

  final TextEditingController messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
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
      final data = await ApiService.fetchPendingAppointments();
      setState(() => appointments = data);
      debugPrint("\nThhe appointments are :\n$appointments\n");
    } catch (e) {
      debugPrint("Error loading appointments: $e");
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
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Load appointments if not already loaded
            if (appointments.isEmpty) {
              _loadAppointments().then((_) => setModalState(() {}));
            }

            if (appointments.isEmpty) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.orange.shade700,
                  ),
                ),
              );
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.95,
              builder: (context, controller) {
                return ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final req = appointments[index];

                    // Parse date
                    final startDate = DateTime.tryParse(
                      req['appointmentStartDate'] ?? '',
                    );
                    final formattedDate =
                        startDate != null
                            ? DateFormat('yyyy-MM-dd').format(startDate)
                            : 'Unknown Date';

                    // Use description as subtitle
                    final description = req['description'] ?? 'No description';

                    // Show patientId for now (replace with actual name if available)
                    final patientName =
                        req['patient']['name'] ?? req['patientId'] ?? 'Unknown';

                    debugPrint("🔹 Appointment: $req");

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: Text(patientName[0]),
                        ),
                        title: Text(patientName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("description: $description"),
                            Text("Date: $formattedDate"),
                            Text(
                              "Time: ${req['appointmentStartTime']} - ${req['appointmentEndTime']}",
                            ),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.orange,
                        ),
                        onTap: () => _showApprovalForm(req),
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

  void _showApprovalForm(Map<String, dynamic> request) {
    DateTime? date;
    TimeOfDay? start;
    TimeOfDay? end;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 25,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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

                  // Patient Info
                  Text(
                    "Patient: ${request['patient']['name']}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Issue: ${request['description']}",
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 20),

                  // Date Picker
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
                      if (d != null) setStateModal(() => date = d);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Start Time Picker
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
                      if (t != null) setStateModal(() => start = t);
                    },
                  ),
                  const SizedBox(height: 12),

                  // End Time Picker
                  _buildPickerButton(
                    context: context,
                    icon: Icons.timer_off,
                    label:
                        end == null ? "Select End Time" : end!.format(context),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (t != null) setStateModal(() => end = t);
                    },
                  ),
                  const SizedBox(height: 25),

                  // Action Buttons: Confirm & Reject
                  Row(
                    children: [
                      // Reject Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Appointment Rejected"),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.red.shade600,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
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

                      // Confirm Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (date == null || start == null || end == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please select all details."),
                                ),
                              );
                              return;
                            }

                            final success = await ApiService.approveAppointment(
                              requestId: request["_id"],
                              date: DateFormat('yyyy-MM-dd').format(date!),
                              startTime: start!.format(context),
                              endTime: end!.format(context),
                            );

                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Appointment approved successfully!",
                                  ),
                                ),
                              );
                              Navigator.pop(context);
                              await _loadConversations();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.orange.shade700,
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
