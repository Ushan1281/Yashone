// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_background/flutter_background.dart';
// import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:webview_flutter/webview_flutter.dart';
//
// void main() {
//   runApp(MaterialApp(debugShowCheckedModeBanner: false, home: FrappeWebApp()));
// }
//
// class FrappeWebApp extends StatefulWidget {
//   @override
//   _FrappeWebAppState createState() => _FrappeWebAppState();
// }
//
// class _FrappeWebAppState extends State<FrappeWebApp> {
//   late final WebViewController _controller;
//   StreamSubscription<Position>? _positionStream;
//
//   @override
//   void initState() {
//     super.initState();
//     _enableBackgroundExecution();
//     _requestLocationPermission();
//     _initializeWebView();
//     _startLocationUpdates();
//   }
//
//   /// Enable background execution
//   void _enableBackgroundExecution() async {
//     bool hasPermission = await FlutterBackground.hasPermissions;
//     if (!hasPermission) {
//       await FlutterBackground.initialize();
//       await FlutterBackground.enableBackgroundExecution();
//     }
//   }
//
//   /// Request location permission
//   Future<void> _requestLocationPermission() async {
//     PermissionStatus status = await Permission.location.request();
//     if (status.isGranted) {
//       _startLocationUpdates();
//     } else {
//       print("Location permission denied");
//     }
//   }
//
//   /// Initialize WebView
//   void _initializeWebView() {
//     _controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setBackgroundColor(const Color(0xFFFFFFFF))
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onPageStarted: (url) async {
//             Position position = await Geolocator.getCurrentPosition();
//             _injectLocationScript(position);
//           },
//         ),
//       )
//       ..loadRequest(
//         Uri.parse(
//           'https://erp.yashgroupservices.com/',
//         ),
//       );
//   }
//
//   /// Start background location updates
//   void _startLocationUpdates() async {
//     LocationSettings settings = LocationSettings(
//       accuracy: LocationAccuracy.high,
//       distanceFilter: 10, // Updates every 10 meters
//     );
//
//     _positionStream = Geolocator.getPositionStream(
//       locationSettings: settings,
//     ).listen((Position position) {
//       print("Background Location: ${position.latitude}, ${position.longitude}");
//       _injectLocationScript(position);
//     });
//
//     _startForegroundService(); // Ensure app runs in the background
//   }
//
//   /// Start Foreground Service (Android)
//   void _startForegroundService() async {
//     await FlutterForegroundTask.startService(
//       notificationTitle: 'Tracking Location',
//       notificationText: 'Location tracking is running in the background',
//       callback: _foregroundTaskCallback,
//     );
//   }
//
//   /// Foreground Task Callback
//   void _foregroundTaskCallback() {
//     Geolocator.getPositionStream().listen((position) {
//       print("Background Location: ${position.latitude}, ${position.longitude}");
//     });
//   }
//
//   /// Inject JavaScript to override `navigator.geolocation`
//   void _injectLocationScript(Position position) {
//     String jsCode = """
//       navigator.geolocation.getCurrentPosition = function(success, error) {
//         success({
//           coords: {
//             latitude: ${position.latitude},
//             longitude: ${position.longitude},
//             accuracy: ${position.accuracy}
//           }
//         });
//       };
//     """;
//     _controller.runJavaScript(jsCode);
//   }
//
//   @override
//   void dispose() {
//     _positionStream?.cancel(); // Stop location updates
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: () async {
//         if (await _controller.canGoBack()) {
//           _controller.goBack();
//           return false; // Don't exit app
//         }
//         return true; // Exit app
//       },
//       child: Scaffold(
//         appBar: AppBar(
//           backgroundColor: Colors.white,
//           title: Image.asset(
//             'assets/images/yash-exp-logo-wide.png',
//             height: 35,
//           ),
//           actions: [
//             IconButton(
//               icon: Icon(Icons.refresh, color: Colors.black),
//               onPressed: () {
//                 _controller.reload();
//               },
//             ),
//           ],
//         ),
//         body: WebViewWidget(controller: _controller),
//       ),
//     );
//   }
// }

// import 'dart:async';
//
// import 'package:flutter/material.dart';
// import 'package:flutter_background/flutter_background.dart';
// import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:webview_flutter/webview_flutter.dart';
//
// void main() {
//   runApp(MaterialApp(debugShowCheckedModeBanner: false, home: FrappeWebApp()));
// }
//
// class FrappeWebApp extends StatefulWidget {
//   @override
//   _FrappeWebAppState createState() => _FrappeWebAppState();
// }
//
// class _FrappeWebAppState extends State<FrappeWebApp> {
//   late final WebViewController _controller;
//   StreamSubscription<Position>? _positionStream;
//
//   @override
//   void initState() {
//     super.initState();
//     _enableBackgroundExecution();
//     _requestLocationPermission();
//     _initializeWebView();
//     _startLocationUpdates();
//   }
//
//   /// Enable background execution
//   void _enableBackgroundExecution() async {
//     bool hasPermission = await FlutterBackground.hasPermissions;
//     if (!hasPermission) {
//       await FlutterBackground.initialize();
//       await FlutterBackground.enableBackgroundExecution();
//     }
//   }
//
//   /// Request location permission
//   Future<void> _requestLocationPermission() async {
//     PermissionStatus status = await Permission.location.request();
//     if (status.isGranted) {
//       _startLocationUpdates();
//     } else {
//       print("Location permission denied");
//     }
//   }
//
//   /// Initialize WebView
//   void _initializeWebView() {
//     _controller =
//         WebViewController()
//           ..setJavaScriptMode(JavaScriptMode.unrestricted)
//           ..setBackgroundColor(const Color(0xFFFFFFFF))
//           ..setNavigationDelegate(
//             NavigationDelegate(
//               onPageStarted: (url) async {
//                 Position position = await Geolocator.getCurrentPosition();
//                 _injectLocationScript(position);
//               },
//             ),
//           )
//           ..loadRequest(
//             Uri.parse(
//               'https://erp.yashgroupservices.com/',
//             ),
//           );
//   }
//
//   /// Start background location updates
//   void _startLocationUpdates() async {
//     LocationSettings settings = LocationSettings(
//       accuracy: LocationAccuracy.high,
//       distanceFilter: 10, // Updates every 10 meters
//     );
//
//     _positionStream = Geolocator.getPositionStream(
//       locationSettings: settings,
//     ).listen((Position position) {
//       print("Background Location: ${position.latitude}, ${position.longitude}");
//       _injectLocationScript(position);
//     });
//
//     _startForegroundService(); // Ensure app runs in the background
//   }
//
//   /// Start Foreground Service (Android)
//   void _startForegroundService() async {
//     await FlutterForegroundTask.startService(
//       notificationTitle: 'Tracking Location',
//       notificationText: 'Location tracking is running in the background',
//       callback: _foregroundTaskCallback,
//     );
//   }
//
//   /// Foreground Task Callback
//   void _foregroundTaskCallback() {
//     Geolocator.getPositionStream().listen((position) {
//       print("Background Location: ${position.latitude}, ${position.longitude}");
//     });
//   }
//
//   /// Inject JavaScript to override `navigator.geolocation`
//   void _injectLocationScript(Position position) {
//     String jsCode = """
//       navigator.geolocation.getCurrentPosition = function(success, error) {
//         success({
//           coords: {
//             latitude: ${position.latitude},
//             longitude: ${position.longitude},
//             accuracy: ${position.accuracy}
//           }
//         });
//       };
//     """;
//     _controller.runJavaScript(jsCode);
//   }
//
//   @override
//   void dispose() {
//     _positionStream?.cancel(); // Stop location updates
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         title: Image.asset(
//           'assets/images/yash-exp-logo-wide.png', // make sure the image is added in pubspec.yaml
//           height: 35, // adjust size as needed
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh, color: Colors.black), // refresh icon
//             onPressed: () {
//               _controller?.reload();
//             },
//           ),
//         ],
//       ),
//       body: WebViewWidget(controller: _controller),
//     );
//   }
// }
