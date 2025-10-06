import 'package:autisecure/models/chat.dart';
import 'package:flutter/material.dart';

class DChatScreen extends StatefulWidget {
  final Chat chat;
  const DChatScreen({super.key, required this.chat});

  @override
  State<DChatScreen> createState() => _DChatScreenState();
}

class _DChatScreenState extends State<DChatScreen> {
  final List<String> messages = [];
  final TextEditingController controller = TextEditingController();

  void sendMessage() {
    if (controller.text.trim().isEmpty) return;
    setState(() {
      messages.add(controller.text.trim());
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chat.userName)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder:
                  (context, index) => Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(messages[index]),
                    ),
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.orange),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
