// ignore: file_names
import 'package:autisecure/mainScreens/chatScreen.dart';
import 'package:flutter/material.dart';

class LiveList extends StatefulWidget {
  const LiveList({super.key});

  @override
  State<LiveList> createState() => _LiveListState();
}

class _LiveListState extends State<LiveList> {
  final List<Map<String, String>> users = [
    {"name": "Dr. Smith", "lastMsg": "Hello, how are you?", "time": "10:30 AM"},
    {
      "name": "Dr. Emma",
      "lastMsg": "Your report looks good!",
      "time": "Yesterday",
    },
    {"name": "Dr. Alex", "lastMsg": "We’ll schedule a call.", "time": "Monday"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange,
              child: Text(users[index]['lastMsg']!),
            ),
            subtitle: Text(users[index]["lastMsg"]!),
            trailing: Text(users[index]["time"]!),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(userName: users[index]["name"]!),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
