import 'dart:io';
import 'package:audioplayers/audio_cache.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:overlay_support/overlay_support.dart';
import 'dart:ui';
import 'dart:convert';

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}

class MessagingConfig {
  static final MessagingConfig _singleton = new MessagingConfig._internal();
  static MessagingConfig get singleton => _singleton;

  factory MessagingConfig() {
    return _singleton;
  }

  MessagingConfig._internal();

  Function(Map<String, dynamic>) onMessageCallback;
  dynamic onBackgroundMessageHandler;
  Function notificationInForeground;
  String iconApp;
  bool isVibrate;
  Map<String, dynamic> sound;

  final _awsMessaging = const MethodChannel('flutter.io/awsMessaging');
  final _vibrate = const MethodChannel('flutter.io/vibrate');
  BuildContext context;
  init(BuildContext context, Function(Map<String, dynamic>) onMessageCallback,
      {bool isAWSNotification = true,
        String iconApp,
        Function notificationInForeground,
        dynamic onBackgroundMessageHandler,
        bool isVibrate = false,
        Map<String, dynamic> sound}) {
    this.context = context;
    this.iconApp = iconApp;
    this.onMessageCallback = onMessageCallback;
    this.notificationInForeground = notificationInForeground;
    this.onBackgroundMessageHandler = onBackgroundMessageHandler;
    this.isVibrate = isVibrate;
    this.sound = sound;
    if (sound != null) {
      if (Platform.isAndroid) {
        const audioSoundSetup =
        const MethodChannel('flutter.io/audioSoundSetup');
        audioSoundSetup
            .invokeMethod('setupSound', sound)
            .then((value) => print(value));
      }
    }
    if (Platform.isIOS && isAWSNotification) {
      setHandler();
    } else {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print(jsonEncode(message.notification));
        print(jsonEncode(message.data));
        // print(jsonEncode(message));
        // print("onMessage: $message");
        inAppMessageHandlerRemoteMessage(message);
      });
      // FirebaseMessaging.onBackgroundMessage((RemoteMessage message) {
      //   print("onBackground: $message");
      //   return myBackgroundMessageHandler(message.data);
      // });
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage message){
        // print(jsonEncode(message.data));
        // print(jsonEncode(message));
        // print("getInitialMessage: $message");
        print(jsonEncode(message.notification));
        myBackgroundMessageHandler(message.data);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // print(jsonEncode(message.data));
        // print(jsonEncode(message));
        // print("onResume: $message");
        print(jsonEncode(message.notification));
        myBackgroundMessageHandler(message.data);
      });
    }
  }

  void setHandler() {
    _awsMessaging.setMethodCallHandler(methodCallHandler);
  }

  Future<dynamic> methodCallHandler(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'onMessage':
        print(methodCall.arguments);
        Map<String, dynamic> message =
        Map<String, dynamic>.from(methodCall.arguments);
        this.inAppMessageHandler(message);
        return null;
      case 'onLaunch':
        print(methodCall.arguments);
        Map<String, dynamic> message =
        Map<String, dynamic>.from(methodCall.arguments);
        this.myBackgroundMessageHandler(message);
        return null;
      default:
        throw PlatformException(code: 'notimpl', message: 'not implemented');
    }
  }

  Future<dynamic> inAppMessageHandlerRemoteMessage(RemoteMessage message) async {
    if (message!= null && message.data != null && message.data['title'] != null && message.data['message'] != null) {
      showAlertNotificationForeground(
          message.data['title'], message.data['message'], message.data);
      try {
        if (isVibrate) {
          _vibrate.invokeMethod('vibrate');
        }
        if (Platform.isIOS) {
          if (sound != null) {
            AudioCache player = AudioCache();
            player.play(sound["asset"]);
          }
        }
      } catch (e) {
        print(e);
      }
    }
    if (notificationInForeground != null) {
      notificationInForeground();
    }
  }
  Future<dynamic> inAppMessageHandler(Map<String, dynamic> message) async {
    String notiTitle;
    String notiDes;
    print(message);
    if (message.containsKey("notification")) {
      notiTitle = message["notification"]["title"].toString();
      notiDes = message["notification"]["body"].toString();
    } else if(message.containsKey("aps")){
      notiTitle = message["aps"]["alert"]["title"].toString();
      notiDes = message["aps"]["alert"]["body"].toString();
    }else{
      notiTitle = message["title"].toString();
      notiDes = message["message"].toString();
    }
    if (notiTitle != null && notiDes != null) {
      showAlertNotificationForeground(notiTitle, notiDes, message);
      try {
        if (isVibrate) {
          _vibrate.invokeMethod('vibrate');
        }
        if (Platform.isIOS) {
          if (sound != null) {
            AudioCache player = AudioCache();
            player.play(sound["asset"]);
          }
        }
      } catch (e) {
        print(e);
      }
    }
    if (notificationInForeground != null) {
      notificationInForeground();
    }
  }

  void showAlertNotificationForeground(
      String notiTitle, String notiDes, Map<String, dynamic> message) {
    showOverlayNotification((context) {
      return BannerNotification(
        notiTitle: notiTitle,
        notiDescription: notiDes,
        iconApp: iconApp,
        onReplay: () {
          if (onMessageCallback != null) {
            onMessageCallback(message);
          }
          OverlaySupportEntry.of(context).dismiss();
        },
      );
    }, duration: Duration(seconds: 5));
  }

  Future<dynamic> myBackgroundMessageHandler(
      Map<String, dynamic> message) async {
    if (onMessageCallback != null) {
      onMessageCallback(message);
    }
  }
}

class BannerNotification extends StatefulWidget {
  final String notiTitle;
  final String notiDescription;
  final String iconApp;
  final Function onReplay;

  BannerNotification(
      {this.notiTitle, this.notiDescription, this.onReplay, this.iconApp});

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return BannerNotificationState();
  }
}

class BannerNotificationState extends State<BannerNotification> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
            boxShadow: [
              BoxShadow(
                color: HexColor("DEE7F1"),
                blurRadius: 3.0,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Card(
            margin: EdgeInsets.zero,
            color: Colors.white,
            child: ListTile(
              onTap: () {
                if (widget.onReplay != null) widget.onReplay();
              },
              title: Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                        maxWidth: 40,
                        maxHeight: 40,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Container(
                          child: widget.iconApp == null
                              ? Container()
                              : Image.asset(widget.iconApp,
                              fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 5.0),
                            child: Text(
                              widget.notiTitle,
                              maxLines: 1,
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 5.0, top: 5.0, bottom: 5.0),
                            child: Text(widget.notiDescription,
                                maxLines: 2,
                                style: TextStyle(
                                    color: Colors.black, fontSize: 12),
                                textAlign: TextAlign.left),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
              subtitle: Container(
                padding: EdgeInsets.only(top: 15, bottom: 5),
                alignment: Alignment.center,
                child: Container(
                  height: 5,
                  width: 50,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(2.5)),
                      color: HexColor("E2E4EC")),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
