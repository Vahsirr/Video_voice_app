import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> checkSystemAlertWindowPermission(BuildContext context) async {
  if (Platform.isAndroid) {
    var androidInfo = await DeviceInfoPlugin().androidInfo;
    var sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 31) {
      if (await Permission.systemAlertWindow.isDenied) {
        showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (BuildContext context) {
            return Expanded(
              child: AlertDialog(
                title: const Text('Permission required'),
                content: const Text(
                    'For accepting the calls in the background you should provide access to show System Alerts from the background. Would you like to do it now?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Permission.systemAlertWindow.request().then((status) {
                        if (status.isGranted) {
                          Navigator.of(context).pop();
                        }
                      });
                    },
                    child: const Text(
                      'Allow',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Later',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    }
  }
}