import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_video_call_app/app_router.dart';
import 'package:voice_video_call_app/provider/caller_details_provider.dart';
import 'package:voice_video_call_app/services/authentication_service.dart';
import 'package:voice_video_call_app/services/signalling.service.dart';
import 'package:voice_video_call_app/sign_up.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final AuthenticationService authService = AuthenticationService();

  final String websocketUrl = "ws://192.168.29.21:9000";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
      ),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 20.0),
                ElevatedButton(
                  onPressed: () async {
                    String? errorMessage =
                        await authService.signInWithEmailAndPassword(
                      emailController.text,
                      passwordController.text,
                    );
                    if (errorMessage == null) {
                      String? token =
                          await FirebaseMessaging.instance.getToken();
                      debugPrint(token);
                      await FirebaseFirestore.instance
                          .collection('tokenCollection')
                          .doc(authService
                              .getCurrentUserId()) // Assuming this method gets the current user's ID
                          .set({
                        'token_id': token,
                        'user_id': authService.getCurrentUserId(),
                      });
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      prefs.setString(
                          "userID", authService.getCurrentUserId().toString());
                      var selfCallerID =
                          authService.getCurrentUserId().toString();
                      // ignore: use_build_context_synchronously
                      final newtoken = Provider.of<DetailsProvider>(context, listen: false);

                      newtoken.updateData(selfCallerID);

                      SignallingService.instance.init(
                        websocketUrl: websocketUrl,
                        selfCallerID: selfCallerID,
                      );

                      // ignore: use_build_context_synchronously
                      Navigator.of(context).pushReplacementNamed(
                          AppRoute.homeScreen,
                          arguments: selfCallerID);
                    } else {
                      // Show error message to the user
                      showDialog(
                        // ignore: use_build_context_synchronously
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Error'),
                          content: Text(errorMessage),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: const Text('Sign In'),
                ),
                const SizedBox(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    const SizedBox(
                      width: 5,
                    ),
                    GestureDetector(
                        onTap: () {
                          Get.off((() => SignUpScreen()));
                        },
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(
                              color: Colors.blue, fontWeight: FontWeight.bold),
                        ))
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
