import 'package:flutter/material.dart';
import 'package:voice_video_call_app/call_screen.dart';
import 'package:voice_video_call_app/home.dart';
import 'package:voice_video_call_app/main.dart';
import 'package:voice_video_call_app/reciever_screen.dart';
import 'package:voice_video_call_app/sign_up.dart';

class AppRoute {

  static const callingPage = '/calling_page';

  static const homeScreen = '/home_page';

  static const signUpScreen = '/signup_page';

  static const splashScreen = '/splash_page';

  static const recievingPage = '/recieving_page';

  static Route<Object>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splashScreen:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case homeScreen:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case signUpScreen:
        return MaterialPageRoute(
          builder: (_) => SignUpScreen(),
          settings: settings,
        );
      case recievingPage:
        return MaterialPageRoute(
          builder: (_) => const RecieveScreen(),
          settings: settings,
        );
      case callingPage:
        return MaterialPageRoute(
          builder: (_) => const CallScreen(),
          settings: settings,
        );
      default:
        return null;
    }
  }
}
