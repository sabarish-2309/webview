import 'dart:isolate';
import 'dart:math';
import 'dart:ui';
import 'package:clipboard_manager/clipboard_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:android_alarm_manager/android_alarm_manager.dart';
import "package:shared_preferences/shared_preferences.dart";

const String countKey = 'count';

const String isolateName = 'isolate';

final ReceivePort port = ReceivePort();

SharedPreferences prefs;

Future<void> main() async {
  // TODO(bkonyi): uncomment
  WidgetsFlutterBinding.ensureInitialized();

  IsolateNameServer.registerPortWithName(
    port.sendPort,
    isolateName,
  );
  prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(countKey)) {
    await prefs.setInt(countKey, 0);
  }
  runApp(MyApp());
}

//void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  TextEditingController controller = TextEditingController();
  var urlString = 'https://maximl.com/';
  FlutterWebviewPlugin flutterWebviewPlugin = FlutterWebviewPlugin();
  bool showloading = true;

  void updateLoading(bool ls) {
    this.setState(() {
      showloading = ls;
    });
  }

  void alarm() async {
    await AndroidAlarmManager.oneShot(
      const Duration(seconds: 5),
      // Ensure we have a unique alarm ID.
      Random().nextInt(pow(2, 31)),
      callback,
      exact: true,
      wakeup: true,
    );
  }

  launchUrl() {
    setState(() {
      alarm();
      urlString = controller.text;
      if (!urlString.startsWith("http://")) {
        urlString = "http://" + urlString;

        flutterWebviewPlugin.reloadUrl(urlString);
      } else {
        flutterWebviewPlugin.reloadUrl(urlString);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    AndroidAlarmManager.initialize();
    port.listen((_) async => await _incrementCounter());
  }

  Future<void> _incrementCounter() async {
    print('Increment counter!');

    // Ensure we've loaded the updated count from the background isolate.
    await prefs.reload();

    setState(() {
      _counter++;
    });
  }

  static SendPort uiSendPort;

  // The callback for our alarm
  static Future<void> callback() async {
    print('Alarm fired!');

    // Get the previous cached count and increment it.
    final prefs = await SharedPreferences.getInstance();
    int currentCount = prefs.getInt(countKey);
    await prefs.setInt(countKey, currentCount + 1);

    // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    uiSendPort?.send(null);
  }

  @override
  Widget build(BuildContext context) {
    return WebviewScaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: TextField(
          autofocus: false,
          autocorrect: false,
          controller: controller,
          cursorColor: Colors.white,
          cursorWidth: 0.3,
          textInputAction: TextInputAction.go,
          onSubmitted: (url) => launchUrl(),
          style: TextStyle(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Enter the Url',
            hintStyle: TextStyle(color: Colors.white),
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.navigate_next),
            onPressed: () => launchUrl(),
          ),
          (showloading)
              ? Center(
                  child: CircularProgressIndicator(),
                )
              : Center()
        ],
      ),
      url: urlString,
      withZoom: true,
    );
  }
}
