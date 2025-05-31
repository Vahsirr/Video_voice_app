import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';
import 'package:voice_video_call_app/app_router.dart';
import 'package:voice_video_call_app/main.dart';
import 'package:voice_video_call_app/provider/caller_details_provider.dart';
import 'package:voice_video_call_app/services/navigation_service.dart';
import 'package:http/http.dart' as http;
import 'package:voice_video_call_app/services/signalling.service.dart';

class Contact {
  final String id;
  final String name;
  final String phoneNumber;

  Contact({required this.id, required this.name, required this.phoneNumber});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  dynamic incomingSDPOffer;
  String loginUserName = '';
  String loginUserNumber = '';
  String selfCallerId = '';

  @override
  void initState() {
    super.initState();
    final calleeData = Provider.of<DetailsProvider>(context, listen: false);
    selfCallerId =
        Provider.of<DetailsProvider>(context, listen: false).token.toString();
    debugPrint('my self callerId : $selfCallerId');

    SignallingService.instance.socket!.on("newCall", (data) async {
      debugPrint("Received makeCall event with data: $data");
      if (mounted) {
        calleeData.updateOffer(data);
      }
    });

    listenerEvent();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      String? body = message.notification!.body;
      String? loginUserNumber = message.data['loginUserNumber'];
      FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
        id: selfCallerId,
        nameCaller: body,
        handle: loginUserNumber,
        duration: 30000,
        textAccept: 'Accept',
        textDecline: 'Decline',
        missedCallNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: true,
          subtitle: 'Missed call',
          callbackText: 'Call back',
        ),
        extra: <String, dynamic>{},
        headers: <String, dynamic>{'apiKey': 'Abc@123!', 'platform': 'flutter'},
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0955fa',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          isShowFullLockedScreen: true,
        ),
      ));
    });

    requestNotificationPermission();
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DetailsProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: authService.signOut),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          List<Contact> contacts = snapshot.data!.docs
              .map((doc) {
                if (doc.id == selfCallerId) {
                  loginUserName = doc['Name'];
                  loginUserNumber = doc['Phone_Number'];
                }
                // Assuming each user document has 'name' and 'phoneNumber' fields
                return Contact(
                  id: doc.id,
                  name: doc['Name'],
                  phoneNumber: doc['Phone_Number'].toString(),
                );
              })
              .where((contact) =>
                  contact.id != selfCallerId) // Filtering out current user
              .toList();
          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              Contact contact = contacts[index];
              return ListTile(
                title: Text(contact.name),
                subtitle: Text(contact.phoneNumber),
                trailing: IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () async {
                    String? recipientToken;

                    try {
                      var snapshot = await FirebaseFirestore.instance
                          .collection('tokenCollection')
                          .where("user_id", isEqualTo: contact.id)
                          .get();

                      // Check if data exists, then access token_id
                      if (snapshot.docs.isNotEmpty) {
                        recipientToken = snapshot.docs[0].data()["token_id"];
                      } else {
                        // Handle case where token is not found (e.g., print message)
                        debugPrint(
                            'Token ID not found for contact: ${contact.name}');
                      }
                    } catch (error) {
                      // Handle errors during Firestore interaction
                      debugPrint('Error fetching token: $error');
                    }

                    if (recipientToken != null) {
                      sendPushNotification(
                          recipientToken, selfCallerId, contact.id);
                    }

                    dataProvider.updateCalleeID(contact.id);

                    NavigationService.instance
                        .pushNamedIfNotCurrent(AppRoute.callingPage);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> requestNotificationPermission() async {
    await FlutterCallkitIncoming.requestNotificationPermission({
      "rationaleMessagePermission":
          "Notification permission is required, to show notification.",
      "postNotificationMessageRequired":
          "Notification permission is required, Please allow notification permission from setting."
    });
  }

  Future<void> listenerEvent() async {
    try {
      final sdpoffer = Provider.of<DetailsProvider>(context, listen: false);
      FlutterCallkitIncoming.onEvent.listen((event) async {
        debugPrint('HOME: $event');
        switch (event!.event) {
          case Event.actionCallIncoming:
            break;
          case Event.actionCallStart:
            break;
          case Event.actionCallAccept:
            NavigationService.instance.pushNamedIfNotCurrent(
                AppRoute.recievingPage,
                args: event.body!);
            break;
          case Event.actionCallDecline:
            sdpoffer.updateOffer(incomingSDPOffer["sdpOffer"] = null);
            debugPrint("Call rejected");
            await requestHttp("ACTION_CALL_DECLINE_FROM_DART");
            break;
          case Event.actionCallEnded:
            break;
          case Event.actionCallTimeout:
            break;
          case Event.actionCallCallback:
            break;
          case Event.actionCallToggleHold:
            break;
          case Event.actionCallToggleMute:
            break;
          case Event.actionCallToggleDmtf:
            break;
          case Event.actionCallToggleGroup:
            break;
          case Event.actionCallToggleAudioSession:
            break;
          case Event.actionDidUpdateDevicePushTokenVoip:
            break;
          case Event.actionCallCustom:
            break;
        }
        // callback(event);
      });
    } on Exception catch (e) {
      debugPrint('$e');
    }
  }

  Future<void> sendPushNotification(
      String token, String callerId, String calleeId) async {
    try {
      http.Response response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization':
              'key=AAAAlqKrMB8:APA91bGuIjVja4SCmrYrbEBCVMtrZRzBKM5dB2Kv962ajAfrtBh-bhU53c_-VEy5q8mCGCZMK3ymCaXLyllAYgVES8YHm714Vkij-GCkhd4TYeioDoEJaoK6DME9p3-i7a3wDQsy4fYu',
        },
        body: jsonEncode(
          <String, dynamic>{
            'notification': <String, dynamic>{
              'body': loginUserName,
              'title': 'call from',
              'sound': 'default',
            },
            'priority': 'high',
            'data': <String, dynamic>{
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'id': '1',
              'loginUserNumber': loginUserNumber,
              'callerId': callerId,
              'calleeId': calleeId,
              'status': 'done',
            },
            'to': token,
          },
        ),
      );
      response;
    } catch (e) {
      e;
    }
  }

  Future<void> requestHttp(content) async {
    get(Uri.parse(
        'https://webhook.site/2748bc41-8599-4093-b8ad-93fd328f1cd2?data=$content'));
  }
}
