import 'package:autisecure/mainScreens/doctor/live_chat/chat_screen.dart';
import 'package:autisecure/models/appointment.dart';
import 'package:autisecure/models/chat.dart';
import 'package:autisecure/services/api_service.dart';
import 'package:flutter/material.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Chat> chatList = [];

  void _openAppointmentsSheet(context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => FutureBuilder<List<Appointment>>(
            future: ApiService.fetchAppointmentRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                final appointments = snapshot.data!;
                return DraggableScrollableSheet(
                  expand: false,
                  maxChildSize: 0.85,
                  minChildSize: 0.5,
                  builder:
                      (context, scrollController) => ListView.builder(
                        controller: scrollController,
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final appt = appointments[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 4,
                            child: ListTile(
                              title: Text(
                                appt.userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text("Time: ${appt.time}"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                    onPressed: () async {
                                      await ApiService.approveAppointment(
                                        appt.id,
                                      );
                                      setState(() {
                                        chatList.add(
                                          Chat(
                                            chatId: appt.id,
                                            userId: appt.userId,
                                            userName: appt.userName,
                                          ),
                                        );
                                      });
                                      Navigator.pop(context);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.cancel,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      await ApiService.rejectAppointment(
                                        appt.id,
                                      );
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                );
              } else {
                return const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: Text("No new appointment requests")),
                );
              }
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child:
            chatList.isEmpty
                ? const Center(child: Text("No active chats yet"))
                : ListView.builder(
                  itemCount: chatList.length,
                  itemBuilder: (context, index) {
                    final chat = chatList[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: const Icon(Icons.person, color: Colors.black),
                        ),
                        title: Text(chat.userName),
                        subtitle: const Text("Tap to chat"),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DChatScreen(chat: chat),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAppointmentsSheet(context),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
    );
  }
}
