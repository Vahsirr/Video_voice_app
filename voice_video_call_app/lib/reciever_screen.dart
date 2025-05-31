import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform, exit;
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:voice_video_call_app/app_router.dart';
import 'package:voice_video_call_app/provider/caller_details_provider.dart';
import 'package:voice_video_call_app/services/signalling.service.dart';

class RecieveScreen extends StatefulWidget {
  const RecieveScreen({
    super.key,
  });

  @override
  State<RecieveScreen> createState() => _RecieveScreenState();
}

class _RecieveScreenState extends State<RecieveScreen> {
  late CallKitParams? calling;
  dynamic incomingSDPOffer;
  String calleeId = '';
  String selfID = '';
  bool isVideoOn = false;
  // bool _callEnd = false;

  // socket instance
  final socket = SignallingService.instance.socket;

  // videoRenderer for localPeer
  final _localRTCVideoRenderer = RTCVideoRenderer();

  // videoRenderer for remotePeer
  final _remoteRTCVideoRenderer = RTCVideoRenderer();

  // mediaStream for localPeer
  MediaStream? _localStream;

  // RTC peer connection
  RTCPeerConnection? _rtcPeerConnection;

  // list of rtcCandidates to be sent over signalling
  List<RTCIceCandidate> rtcIceCadidates = [];

  // media status
  bool isAudioOn = true, isFrontCameraSelected = true;
  // isVideoOn = true,

  @override
  void initState() {
    // initializing renderers
    _localRTCVideoRenderer.initialize();
    _remoteRTCVideoRenderer.initialize();
    incomingSDPOffer =
        Provider.of<DetailsProvider>(context, listen: false).offer;
    debugPrint('i am getting incomingSDPOffer $incomingSDPOffer');
    debugPrint(
        'i am getting sdpOffer from caller: ${incomingSDPOffer["sdpOffer"]["type"]}');
    calleeId = Provider.of<DetailsProvider>(context, listen: false)
        .calleeId
        .toString();
    selfID =
        Provider.of<DetailsProvider>(context, listen: false).token.toString();
    final exit = Provider.of<DetailsProvider>(context, listen: false).isClosed;
    debugPrint('i am in reciever screen $exit');
    // setup Peer Connection
    _setupPeerConnection(incomingSDPOffer);

    socket!.on("endConnectivity", (data) {
      debugPrint("Received endConnectivity event: $data");
      _handleCallTermination();
    });
    super.initState();
  }

  _setupPeerConnection(incomingSDPOffer) async {
    _rtcPeerConnection = await createPeerConnection({
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302'
          ]
        }
      ]
    });

    // listen for remotePeer mediaTrack event
    _rtcPeerConnection!.onTrack = (event) {
      _remoteRTCVideoRenderer.srcObject = event.streams[0];
      setState(() {});
    };

    // get localStream
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': isAudioOn,
      'video': isVideoOn
          ? {'facingMode': isFrontCameraSelected ? 'user' : 'environment'}
          : false,
    });

    // add mediaTrack to peerConnection
    _localStream!.getTracks().forEach((track) {
      _rtcPeerConnection!.addTrack(track, _localStream!);
    });

    // set source for local video renderer
    _localRTCVideoRenderer.srcObject = _localStream;
    setState(() {});

    _rtcPeerConnection!.onIceConnectionState = (state) {
      debugPrint("IceConnectionState changed: $state");
    };

    _rtcPeerConnection!.onIceGatheringState = (state) {
      debugPrint("IceGatheringState changed: $state");
    };

    _rtcPeerConnection!.onSignalingState = (state) {
      debugPrint("SignalingState changed: $state");
    };

    if (incomingSDPOffer != null) {
      socket!.on("IceCandidate", (data) {
        debugPrint("Received IceCandidate event with data: $data");
        debugPrint("Received IceCandidate: ${data["iceCandidate"]}");
        String candidate = data["iceCandidate"]["candidate"];
        String sdpMid = data["iceCandidate"]["id"];
        int sdpMLineIndex = data["iceCandidate"]["label"];

        // add iceCandidate
        _rtcPeerConnection!.addCandidate(RTCIceCandidate(
          candidate,
          sdpMid,
          sdpMLineIndex,
        ));
      });

      await _rtcPeerConnection!.setRemoteDescription(
        RTCSessionDescription(incomingSDPOffer["sdpOffer"]["sdp"],
            incomingSDPOffer["sdpOffer"]["type"]),
      );

      // create SDP answer
      RTCSessionDescription answer = await _rtcPeerConnection!.createAnswer();

      // set SDP answer as localDescription for peerConnection
      _rtcPeerConnection!.setLocalDescription(answer);

      // send SDP answer to remote peer over signalling
      socket!.emit("answerCall", {
        "callerId": incomingSDPOffer["callerId"]!,
        "sdpAnswer": answer.toMap(),
      });

      _rtcPeerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        socket!.emit("IceCandidate", {
          "calleeId": selfID, // Callee ID
          "iceCandidate": {
            "id": candidate.sdpMid,
            "label": candidate.sdpMLineIndex,
            "candidate": candidate.candidate
          }
        });
      };
    } else {
      debugPrint(
          "Offer details missing in makeCall event. Requesting offer...");
    }
  }

  _handleCallTermination() async {
    // if (!_callTerminated) {
    //   _callTerminated = true;
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      await _localStream?.dispose();
    }

    if (_rtcPeerConnection != null) {
      await _rtcPeerConnection!.close();
    }

    socket!.disconnect();
    await endCurrentCall();
    // ignore: use_build_context_synchronously
    // final exitApp = Provider.of<DetailsProvider>(context, listen: false).isClosed;
    // debugPrint('i am in reciever screen in leave call $exitApp');
    // if (exitApp == true) {
    // SystemNavigator.pop();
    // Future.delayed(const Duration(milliseconds: 1000), () {
    //   SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    // });

    // if (Platform.isAndroid) {
    //   // ignore: use_build_context_synchronously
    //   // Navigator.pop(context);
    //   SystemNavigator.pop();
    // } else {
    //   exit(0);
    // }
    // } else {
    //   // ignore: use_build_context_synchronously
    // ignore: use_build_context_synchronously
    // Navigator.pop(context);
    //   print(' i am in else part');
    // }

    // NavigationService.instance.goBack();
    // }

    // ignore: use_build_context_synchronously
    Navigator.of(context).popAndPushNamed(AppRoute.homeScreen);
  }

  _leaveCall() async {
    socket!.emit('endCall', {
      "calleeId": selfID,
      "callerId": incomingSDPOffer["callerId"]!,
    });

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      await _localStream?.dispose();
    }

    // if (!_callEnd) {
    //   _callEnd = true;
    if (_rtcPeerConnection != null) {
      await _rtcPeerConnection!.close();
    }

    socket!.disconnect();
    await endCurrentCall();
    // ignore: use_build_context_synchronously
    // final exitApp = Provider.of<DetailsProvider>(context, listen: false).isClosed;
    // debugPrint('i am in reciever screen in leave call $exitApp');
    // if (exitApp == true) {
    // SystemNavigator.pop();
    // Future.delayed(const Duration(milliseconds: 1000), () {
    //   SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    // });
    // if (Platform.isAndroid) {
    //   // ignore: use_build_context_synchronously
    //   // Navigator.pop(context);
    //   SystemNavigator.pop();
    // } else {
    //   exit(0);
    // }
     // ignore: use_build_context_synchronously
     Navigator.of(context).popAndPushNamed(AppRoute.homeScreen);
    // } else {
    //   // ignore: use_build_context_synchronously
    //   Navigator.pop(context);
    //   debugPrint(' i am in else part in end call');
    // }

    // }
  }

  _toggleMic() {
    // change status
    isAudioOn = !isAudioOn;
    // enable or disable audio track
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text("W2W Call App"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(children: [
                RTCVideoView(
                  _remoteRTCVideoRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: SizedBox(
                    height: 150,
                    width: 120,
                    child: RTCVideoView(
                      _localRTCVideoRenderer,
                      mirror: isFrontCameraSelected,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                )
              ]),
            ),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: Icon(isAudioOn ? Icons.mic : Icons.mic_off),
                      onPressed: _toggleMic,
                    ),
                    IconButton(
                      icon: const Icon(Icons.call_end),
                      iconSize: 30,
                      onPressed: _leaveCall,
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  Future<void> endCurrentCall() async {
    await FlutterCallkitIncoming.endCall(selfID);
  }

  @override
  void dispose() {
    _localRTCVideoRenderer.dispose();
    _remoteRTCVideoRenderer.dispose();
    _localStream?.dispose();
    super.dispose();
  }
}
