import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class CallPage extends StatefulWidget {
  final String channelName;
  final bool isVideo;

  const CallPage({super.key, required this.channelName, this.isVideo = true});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  late RtcEngine _engine;
  int? _remoteUid;
  bool _localUserJoined = false;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      const RtcEngineContext(
        appId: "YOUR_AGORA_APP_ID", // 👈 replace with your ID
      ),
    );

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() => _localUserJoined = true);
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          setState(() => _remoteUid = null);
        },
      ),
    );

    await _engine.enableVideo();
    await _engine.joinChannel(
      token: "", // for testing (use token later for security)
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child:
                _remoteUid != null
                    ? AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: _engine,
                        canvas: VideoCanvas(uid: _remoteUid),
                        connection: const RtcConnection(channelId: "test"),
                      ),
                    )
                    : const Text(
                      'Waiting for the other user...',
                      style: TextStyle(color: Colors.white),
                    ),
          ),
          if (_localUserJoined)
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 120,
                height: 160,
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 25),
              child: FloatingActionButton(
                backgroundColor: Colors.red,
                onPressed: () => Navigator.pop(context),
                child: const Icon(Icons.call_end),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
