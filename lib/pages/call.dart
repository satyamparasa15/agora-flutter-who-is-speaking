import 'package:agora_flutter_who_is_speaking/model/user.dart';
import 'package:agora_flutter_who_is_speaking/utils/settings.dart';
import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:agora_rtc_engine/rtc_local_view.dart' as RtcLocalView;
import 'package:agora_rtc_engine/rtc_remote_view.dart' as RtcRemoteView;
import 'package:flutter/material.dart';

class CallPage extends StatefulWidget {
  /// non-modifiable channel name of the page
  final String channelName;

  /// non-modifiable client role of the page
  final ClientRole role;

  const CallPage({Key key, this.channelName, this.role}) : super(key: key);

  @override
  _CallPageState createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  RtcEngine _engine;
  Map<int, User> _userMap = new Map<int, User>();
  bool _muted = false;

  @override
  void dispose() {
    //clear users
    _userMap.clear();
    // destroy sdk
    _engine.leaveChannel();
    _engine.destroy();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // initialize agora sdk
    initialize();
  }

  Future<void> initialize() async {
    if (APP_ID.isEmpty) {
      print("'APP_ID missing, please provide your APP_ID in settings.dart");
      return;
    }
    await _initAgoraRtcEngine();
    _addAgoraEventHandlers();
    VideoEncoderConfiguration configuration = VideoEncoderConfiguration();
    configuration.dimensions = VideoDimensions(1920, 1080);
    await _engine.setVideoEncoderConfiguration(configuration);
    await _engine.joinChannel(Token, widget.channelName, null, 0);
  }

  /// Create agora sdk instance and initialize
  Future<void> _initAgoraRtcEngine() async {
    _engine = await RtcEngine.create(APP_ID);
    await _engine.setChannelProfile(ChannelProfile.Communication);
    await _engine.setClientRole(widget.role);
    await _engine.enableVideo();
    await _engine.enableAudio();
    await _engine.enableAudioVolumeIndication(600, 3, true);
  }

  void _addAgoraEventHandlers() {
    _engine.setEventHandler(
      RtcEngineEventHandler(error: (code) {
        print("error occurred $code---------------------------");
      }, joinChannelSuccess: (channel, uid, elapsed) {
        setState(() {
          _userMap.addAll({0: User(0, false)});
          print(
              "User joined to the channel success ------------------- $uid---");
        });
      }, leaveChannel: (stats) {
        setState(() {
          _userMap.clear();
        });
      }, userJoined: (uid, elapsed) {
        setState(() {
          _userMap.addAll({uid: User(uid, false)});
          print("Remote user joined to the channel--------> ${uid}");
        });
      }, userOffline: (uid, elapsed) {
        setState(() {
          print("User offline  to the channel--------> ${uid}");
          _userMap.remove(uid);
        });
      }, audioVolumeIndication: (info, v) {
        info.forEach((element) {
          if (element.volume > 10) {
            try {
              _userMap.forEach((key, value) {
                if (key.compareTo(element.uid) == 0) {
                  setState(() {
                    _userMap.update(key, (value) => User(key, true));
                  });
                  print(
                      "----------updated user data ${_userMap[key].toString()}");
                } else {
                  print(
                      "------------current speaking key in else case is ------ $key");
                  setState(() {
                    _userMap.update(key, (value) => User(key, false));
                  });
                  print(
                      "----------in else block user data ${_userMap[key].toString()}");
                }
              });
            } catch (error) {
              print('-------${error.toString()}');
            }
          }
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Group call"),
      ),
      body: Stack(
        children: [buildGridView(), _toolbar()],
      ),
    );
  }

  GridView buildGridView() {
    return GridView.builder(
      shrinkWrap: true,
      itemCount: _userMap.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _userMap.length % 2 == 0 ? 2 : 1),
      itemBuilder: (BuildContext context, int index) => Padding(
        padding: const EdgeInsets.all(10.0),
        child: Container(
          child: Container(
              width: 120,
              height: 200,
              color: Colors.redAccent,
              child: (_userMap.entries.elementAt(index).key == 0)
                  ? RtcLocalView.SurfaceView()
                  : RtcRemoteView.SurfaceView(
                      uid: _userMap.entries.elementAt(index).key)),
          decoration: BoxDecoration(
            border: Border.all(
                color: _userMap.entries.elementAt(index).value.isSpeaking
                    ? Colors.blue
                    : Colors.grey,
                width: 6),
            borderRadius: BorderRadius.all(
              Radius.circular(10.0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    if (widget.role == ClientRole.Audience) return Container();
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          RawMaterialButton(
            onPressed: _onToggleMute,
            child: Icon(
              _muted ? Icons.mic_off : Icons.mic,
              color: _muted ? Colors.white : Colors.blueAccent,
              size: 20.0,
            ),
            shape: CircleBorder(),
            elevation: 2.0,
            fillColor: _muted ? Colors.blueAccent : Colors.white,
            padding: const EdgeInsets.all(12.0),
          ),
          RawMaterialButton(
            onPressed: () => _onCallEnd(context),
            child: Icon(
              Icons.call_end,
              color: Colors.white,
              size: 35.0,
            ),
            shape: CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.redAccent,
            padding: const EdgeInsets.all(15.0),
          ),
          RawMaterialButton(
            onPressed: _onSwitchCamera,
            child: Icon(
              Icons.switch_camera,
              color: Colors.blueAccent,
              size: 20.0,
            ),
            shape: CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.white,
            padding: const EdgeInsets.all(12.0),
          )
        ],
      ),
    );
  }

  void _onCallEnd(BuildContext context) {
    Navigator.pop(context);
  }

  void _onToggleMute() {
    setState(() {
      _muted = !_muted;
    });
    _engine.muteLocalAudioStream(_muted);
  }

  void _onSwitchCamera() {
    _engine.switchCamera();
  }
}
