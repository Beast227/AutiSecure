import 'package:flutter/material.dart';

class DocLiveChat extends StatefulWidget {
  const DocLiveChat({super.key});

  @override
  State<DocLiveChat> createState() => _DocLiveChatState();
}

class _DocLiveChatState extends State<DocLiveChat> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text("Doctor Live chat"));
  }
}
