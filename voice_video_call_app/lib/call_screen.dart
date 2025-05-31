import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:voice_video_call_app/provider/caller_details_provider.dart';
import 'package:voice_video_call_app/services/signalling.service.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late CallKitParams? calling;
  String calleeId = '';
  String callerId = '';
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
    _localRTCVideoRenderer.initialize();
    _remoteRTCVideoRenderer.initialize();
    calleeId = Provider.of<DetailsProvider>(context, listen: false)
        .calleeId
        .toString();
    callerId =
        Provider.of<DetailsProvider>(context, listen: false).token.toString();

    _setupPeerConnection();

    socket!.on("endConnectivity", (data) {
      debugPrint("Received endConnectivity event: $data");
      _handleCallTermination();
    });

    super.initState();
  }

  _setupPeerConnection() async {
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

    // listen for local iceCandidate and add it to the list of IceCandidate
    _rtcPeerConnection!.onIceCandidate =
        (RTCIceCandidate candidate) => rtcIceCadidates.add(candidate);

    // when call is accepted by remote peer
    socket!.on("callAnswered", (data) async {
      // set SDP answer as remoteDescription for peerConnection
      debugPrint("Received callAnswered event with data: $data");
      await _rtcPeerConnection!.setRemoteDescription(
        RTCSessionDescription(
          data["sdpAnswer"]["sdp"],
          data["sdpAnswer"]["type"],
        ),
      );
      socket!.on("IceCandidate", (data) {
        debugPrint("Received IceCandidate: ${data["iceCandidate"]}");
        String candidate = data["iceCandidate"]["candidate"];
        String sdpMid = data["iceCandidate"]["id"];
        int sdpMLineIndex = data["iceCandidate"]["label"];
        _rtcPeerConnection!.addCandidate(RTCIceCandidate(
          candidate,
          sdpMid,
          sdpMLineIndex,
        ));
      });

      // send iceCandidate generated to remote peer over signalling
      for (RTCIceCandidate candidate in rtcIceCadidates) {
        socket!.emit("IceCandidate", {
          "calleeId": calleeId,
          "iceCandidate": {
            "id": candidate.sdpMid,
            "label": candidate.sdpMLineIndex,
            "candidate": candidate.candidate
          }
        });
      }
    });

    // create SDP Offer
    RTCSessionDescription offer = await _rtcPeerConnection!.createOffer();
    debugPrint("Created SDP Offer: $offer");

    // set SDP offer as localDescription for peerConnection
    await _rtcPeerConnection!.setLocalDescription(offer);

    // make a call to remote peer over signalling
    socket!.emit('makeCall', {
      "calleeId": calleeId,
      "sdpOffer": offer.toMap(),
    });
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
    // NavigationService.instance.goBack();
    // }
    // endCurrentCall();
    // ignore: use_build_context_synchronously
    Navigator.pop(context);
    // Navigator.of(context).pushReplacementNamed(AppRoute.homeScreen);
  }

  _leaveCall() async {
    socket!.emit('endCall', {
      "calleeId": calleeId,
      "callerId": callerId,
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
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    // }
    // endCurrentCall();
    // NavigationService.instance.goBack();
  }

  _toggleMic() {
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
        title: const Text("P2P Call App"),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> endCurrentCall() async {
    await FlutterCallkitIncoming.endCall(callerId);
  }

  @override
  void dispose() {
    _localRTCVideoRenderer.dispose();
    _remoteRTCVideoRenderer.dispose();
    _localStream?.dispose();
    super.dispose();
  }
}
