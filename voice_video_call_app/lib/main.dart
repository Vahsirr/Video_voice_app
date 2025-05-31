import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_video_call_app/app_router.dart';
import 'package:voice_video_call_app/provider/caller_details_provider.dart';
import 'package:voice_video_call_app/reciever_screen.dart';
import 'package:voice_video_call_app/services/authentication_service.dart';
import 'package:voice_video_call_app/services/navigation_service.dart';
import 'package:voice_video_call_app/services/signalling.service.dart';

Future<void> backgroundHandler(RemoteMessage message) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  token = prefs.getString("userID");
  String? body = message.notification!.body;
  String? loginUserNumber = message.data['loginUserNumber'];
  if (token != null) {
    showCallkitIncoming(token, body!, loginUserNumber!);
  }
}

Future<void> showCallkitIncoming(
    String uuid, String body, String loginUserNumber) async {
  final params = CallKitParams(
    id: uuid,
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
  );
  await FlutterCallkitIncoming.showCallkitIncoming(params);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Platform.isAndroid
      ? await Firebase.initializeApp(
          options: const FirebaseOptions(
          apiKey: "AIzaSyDd6-Avzawp9ITgqlWAvgYeJDqx_GJ6Yt0",
          appId: "1:646974222367:android:0f44b006bd59d8fdb9a52a",
          messagingSenderId: "646974222367",
          projectId: "video-voice-call-app",
          storageBucket: "video-voice-call-app.appspot.com",
        ))
      : await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(backgroundHandler);

  FirebaseMessaging.instance.getToken().then((token) {
    debugPrint('Device Token FCM: $token');
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

AuthenticationService authService = AuthenticationService();
dynamic token;

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final String websocketUrl = "ws://192.168.29.21:9000";
  String? currentUuid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    webSocketInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    debugPrint('$state');
    if (state == AppLifecycleState.resumed) {
      //Check call when open app from background
      //  var currentCall = await getCurrentCall();
      //  if(currentCall==null)
      //  {
      //    checkAndNavigationCallingPage();
      //  }else{
      //    NavigationService.instance
      //     .pushNamedIfNotCurrent(AppRoute.splashScreen, args: currentCall);
      //  }
      debugPrint('i am in resume');
    } else if (state == AppLifecycleState.detached) {
      debugPrint('i am in detached');
    } else if (state == AppLifecycleState.hidden) {
      debugPrint('i am in hidden');
    } else if (state == AppLifecycleState.inactive) {
      debugPrint('i am in inactive');
    } else if (state == AppLifecycleState.paused) {
      debugPrint('i am in paused');
    }
  }

  Future<void> webSocketInit() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString("userID");
    if (token != null) {
      SignallingService.instance.init(
        websocketUrl: websocketUrl,
        selfCallerID: token.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DetailsProvider(),
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        darkTheme: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(),
        ),
        themeMode: ThemeMode.dark,
        onGenerateRoute: AppRoute.generateRoute,
        initialRoute: AppRoute.splashScreen,
        navigatorKey: NavigationService.instance.navigationKey,
        navigatorObservers: <NavigatorObserver>[
          NavigationService.instance.routeObserver
        ],
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final Widget? child;
  const SplashScreen({super.key, this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? currentUuid;

  @override
  void initState() {
    _init();
    super.initState();
  }

  Future<void> _init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString("userID");
    // ignore: use_build_context_synchronously
    final newtoken = Provider.of<DetailsProvider>(context, listen: false);

    if (token != null) {
      var currentCall = await getCurrentCall();
      if (currentCall != null) {
        debugPrint('where am i right now : $currentCall');

        SignallingService.instance.socket!.on("newCall", (data) async {
          debugPrint("Received newCall caller with data: $data");
          if (mounted) {
            debugPrint("happy happy");
            debugPrint("really really  : $data");
            Provider.of<DetailsProvider>(context, listen: false)
                .updateOffer(data);
            dynamic incomingSDPOffer =
                Provider.of<DetailsProvider>(context, listen: false).offer;
            debugPrint('i am getting $incomingSDPOffer');
            if (incomingSDPOffer != null) {
              final exit = Provider.of<DetailsProvider>(context, listen: false);
              exit.updateAppClose(true);
              Navigator.of(context).pushReplacement<void, void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const RecieveScreen(),
                ),
              );
            }
          }
        });
      } else {
        newtoken.updateData(token);
        // ignore: use_build_context_synchronously
        Navigator.of(context)
            .pushReplacementNamed(AppRoute.homeScreen, arguments: token);
      }
    } else {
      await Future.delayed(const Duration(seconds: 3), () {
        Navigator.of(context).pushReplacementNamed(AppRoute.signUpScreen);
      });
    }
  }

  Future<dynamic> getCurrentCall() async {
    // check current call from pushkit if possible
    var calls = await FlutterCallkitIncoming.activeCalls();
    if (calls is List) {
      if (calls.isNotEmpty) {
        debugPrint('DATA: $calls');
        currentUuid = calls[0]['id'];
        return calls[0];
      } else {
        currentUuid = "";
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final exit = Provider.of<DetailsProvider>(context, listen: false).isClosed;
    // if (exit == true) {
    debugPrint('i have been exited from app $exit');
    // }
    return const Scaffold(
      body: Center(
        child: Text(
          "Welcome To Flutter Firebase",
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
