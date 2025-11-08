import 'package:flutter/material.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String conversationId;
  final dynamic data; // optional additional data

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.conversationId,
    this.data,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _anim.repeat(reverse: false);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Incoming Video Call", style: TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 12),
            Text(widget.callerName, style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 36),
            Center(
              child: SizedBox(
                height: 180,
                width: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.6).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut)),
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.withOpacity(0.12),
                        ),
                      ),
                    ),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.person, color: Colors.white, size: 48),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: "reject",
                  backgroundColor: Colors.red,
                  onPressed: () => Navigator.pop(context, false),
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
                FloatingActionButton(
                  heroTag: "accept",
                  backgroundColor: Colors.green,
                  onPressed: () => Navigator.pop(context, true),
                  child: const Icon(Icons.call, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
