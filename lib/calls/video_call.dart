import 'package:flutter/material.dart';

class VideoCall extends StatelessWidget {
  final String callerName;
  const VideoCall({super.key, required this.callerName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(color: Colors.black),
          Positioned(
            top: 50,
            left: 20,
            child: Text(
              callerName,
              style: TextStyle(color: Colors.white, fontSize: 22),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 100,
            child: Container(
              width: 120,
              height: 160,
              color: Colors.grey.shade800,
              child: Center(
                child: Text("You", style: TextStyle(color: Colors.white)),
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  backgroundColor: Colors.white,
                  onPressed: () {},
                  child: Icon(Icons.mic_off),
                ),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () {},
                  child: Icon(Icons.call_end),
                ),
                FloatingActionButton(
                  backgroundColor: Colors.white,
                  onPressed: () {},
                  child: Icon(Icons.videocam_off, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
