import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// Constants
const fetchBackground = "employeeLocationTask";
String frappeBaseUrl = "https://erp.yashgroupservices.com"; // Your ERP domain
String? globalSid;
String? globalEmployeeId;
String? globalUsername;

/// Background Task Dispatcher (Android Workmanager)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    //  if (task == fetchBackground) {
    try {
      final sid = inputData?["sid"];
      final empId = inputData?["employee_id"];

      if (sid == null || empId == null) return Future.value(false);

      // Get location
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Send location to Frappe
      final response = await http.post(
        Uri.parse("$frappeBaseUrl/api/resource/Employee Tracking Log"),
        headers: {
          "Content-Type": "application/json",
          "Cookie": "sid=$sid", // Authenticate with session
        },
        body: jsonEncode({
          "employee": empId,
          "latitude": pos.latitude,
          "longitude": pos.longitude,
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );

      print("✅ Background location sent => ${response.body}");
    } catch (e) {
      print("❌ Error in background tracking: $e");
    }
    //}
    return Future.value(true);
  });
}

@pragma('vm:entry-point')
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}

/// 🔹 Login Page
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  bool isLoading = false;

  Future<void> _login() async {
    setState(() => isLoading = true);

    final sid = await frappeLogin(userController.text, passController.text);
    if (sid != null) {
      globalSid = sid;
      globalUsername = userController.text;

      final empId = await getEmployeeId(sid, globalUsername!);
      if (empId != null) {
        globalEmployeeId = empId;

        // Start tracking (Android + iOS)
        await startTracking(sid, empId);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FrappeWebApp()),
        );
      } else {
        _showError("Failed to fetch employee ID");
      }
    } else {
      _showError("Invalid username or password");
    }

    setState(() => isLoading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "ERP Login",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: userController,
                decoration: const InputDecoration(labelText: "Username"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _login,
                child:
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 🔹 1. Login & Get SID
Future<String?> frappeLogin(String username, String password) async {
  final response = await http.post(
    Uri.parse("$frappeBaseUrl/api/method/login"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"usr": username, "pwd": password}),
  );

  if (response.statusCode == 200) {
    final cookies = response.headers['set-cookie'];
    if (cookies != null) {
      final sidMatch = RegExp(r'sid=([^;]+)').firstMatch(cookies);
      if (sidMatch != null) {
        return sidMatch.group(1); // return session ID
      }
    }
  }
  return null;
}

/// 🔹 2. Get Employee ID using REST API
Future<String?> getEmployeeId(String sid, String username) async {
  final url = Uri.parse(
    "$frappeBaseUrl/api/resource/Employee"
    "?filters=%5B%5B%22user_id%22%2C%22%3D%22%2C%22$username%22%5D%5D"
    "&fields=%5B%22name%22%2C%22employee_name%22%5D",
  );

  final response = await http.get(url, headers: {"Cookie": "sid=$sid"});

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print("Employee Data: $data");
    if (data["data"] != null && data["data"].isNotEmpty) {
      return data["data"][0]["name"]; // Employee ID (e.g. EMP-0001)
    }
  }
  return null;
}

/// 🔹 3. Start Background Location Tracking
Future<void> startTracking(String sid, String employeeId) async {
  // ✅ Android: Workmanager background job
  // await Workmanager().registerPeriodicTask(
  //   "trackLocation777777777777777",
  //   fetchBackground,
  //   frequency: const Duration(minutes: 15), // Android min = 15 min
  //   inputData: {"sid": sid, "employee_id": employeeId},
  // );
  Workmanager().registerPeriodicTask(
    "trackLocationTask",
    fetchBackground,
    frequency: const Duration(minutes: 15),
    initialDelay: const Duration(seconds: 10),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
    ),
    backoffPolicy: BackoffPolicy.linear,
    tag: "location-tracking"
  );
  // ✅ iOS (and as fallback): Timer inside app
  // Timer.periodic(const Duration(minutes: 15), (timer) async {
  //   try {
  //     Position pos = await Geolocator.getCurrentPosition(
  //       desiredAccuracy: LocationAccuracy.high,
  //     );
  //
  //     await http.post(
  //       Uri.parse("$frappeBaseUrl/api/resource/Employee Location Log"),
  //       headers: {
  //         "Content-Type": "application/json",
  //         "Cookie": "sid=$sid",
  //       },
  //       body: jsonEncode({
  //         "employee": employeeId,
  //         "latitude": pos.latitude,
  //         "longitude": pos.longitude,
  //         "timestamp": DateTime.now().toIso8601String(),
  //       }),
  //     );
  //
  //     print("📌 iOS/Foreground location sent");
  //   } catch (e) {
  //     print("❌ Error sending location: $e");
  //   }
  // });
  print("Foreground location sent");
}

/// 🔹 Webview Dashboard
class FrappeWebApp extends StatefulWidget {
  const FrappeWebApp({super.key});

  @override
  State<FrappeWebApp> createState() => _FrappeWebAppState();
}

class _FrappeWebAppState extends State<FrappeWebApp> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(frappeBaseUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Image.asset(
          'assets/images/yash-exp-logo-wide.png', // make sure the image is added in pubspec.yaml
          height: 35, // adjust size as needed
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black), // refresh icon
            onPressed: () {
              _controller?.reload();
            },
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// import 'package:workmanager/workmanager.dart';
// import 'package:http/http.dart' as http;
// import 'package:geolocator/geolocator.dart';
//
// // Constants
// const fetchBackground = "employeeLocationTask";
// String frappeBaseUrl = "https://erp.yashgroupservices.com"; // Your ERP domain
// String? globalSid;
// String? globalEmployeeId;
// String? globalUsername;
//
// // Background Task Dispatcher
// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     if (task == fetchBackground) {
//       try {
//         final sid = inputData?["sid"];
//         final empId = inputData?["employee_id"];
//
//         if (sid == null || empId == null) return Future.value(false);
//
//         // Get location
//         Position pos = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high,
//         );
//
//         // Send location to Frappe
//         final response = await http.post(
//           Uri.parse("$frappeBaseUrl/api/method/trackingLog"),
//           headers: {
//             "Content-Type": "application/json",
//             "Cookie": "sid=$sid", // Authenticate with session
//           },
//           body: jsonEncode({
//             "employee": empId,
//             "lat": pos.latitude,
//             "lng": pos.longitude,
//           }),
//         );
//
//         print("✅ Location sent => ${response.body}");
//       } catch (e) {
//         print("❌ Error in background tracking: $e");
//       }
//     }
//     return Future.value(true);
//   });
// }
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: LoginPage(),
//     );
//   }
// }
//
// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});
//
//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }
//
// class _LoginPageState extends State<LoginPage> {
//   final TextEditingController userController = TextEditingController();
//   final TextEditingController passController = TextEditingController();
//   bool isLoading = false;
//
//   Future<void> _login() async {
//     setState(() => isLoading = true);
//
//     final sid = await frappeLogin(userController.text, passController.text);
//     if (sid != null) {
//       globalSid = sid;
//       globalUsername = userController.text;
//
//       final empId = await getEmployeeId(sid, globalUsername!);
//       if (empId != null) {
//         globalEmployeeId = empId;
//
//         // Start tracking
//         await startTracking(sid, empId);
//
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => const FrappeWebApp()),
//         );
//       } else {
//         _showError("Failed to fetch employee ID");
//       }
//     } else {
//       _showError("Invalid username or password");
//     }
//
//     setState(() => isLoading = false);
//   }
//
//   void _showError(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(msg), backgroundColor: Colors.red),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Text("ERP Login",
//                   style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
//               const SizedBox(height: 20),
//               TextField(
//                 controller: userController,
//                 decoration: const InputDecoration(labelText: "Username"),
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 controller: passController,
//                 obscureText: true,
//                 decoration: const InputDecoration(labelText: "Password"),
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: isLoading ? null : _login,
//                 child: isLoading
//                     ? const CircularProgressIndicator(color: Colors.white)
//                     : const Text("Login"),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// /// 🔹 1. Login & Get SID
// Future<String?> frappeLogin(String username, String password) async {
//   final response = await http.post(
//     Uri.parse("$frappeBaseUrl/api/method/login"),
//     headers: {"Content-Type": "application/json"},
//     body: jsonEncode({"usr": username, "pwd": password}),
//   );
//
//   if (response.statusCode == 200) {
//     final cookies = response.headers['set-cookie'];
//     if (cookies != null) {
//       final sidMatch = RegExp(r'sid=([^;]+)').firstMatch(cookies);
//       if (sidMatch != null) {
//         return sidMatch.group(1); // return session ID
//       }
//     }
//   }
//   return null;
// }
//
// /// 🔹 2. Get Employee ID using REST API
// Future<String?> getEmployeeId(String sid, String username) async {
//   final url = Uri.parse(
//     "$frappeBaseUrl/api/resource/Employee"
//         "?filters=%5B%5B%22user_id%22%2C%22%3D%22%2C%22$username%22%5D%5D"
//         "&fields=%5B%22name%22%2C%22employee_name%22%5D",
//   );
//
//   final response = await http.get(
//     url,
//     headers: {
//       "Cookie": "sid=$sid",
//     },
//   );
//
//   if (response.statusCode == 200) {
//     final data = jsonDecode(response.body);
//     print(data);
//     if (data["data"] != null && data["data"].isNotEmpty) {
//       return data["data"][0]["name"]; // Employee ID (e.g. EMP-0001)
//     }
//   }
//   return null;
// }
//
// /// 🔹 3. Start Background Location Tracking
// Future<void> startTracking(String sid, String employeeId) async {
//   await Workmanager().registerPeriodicTask(
//     "trackLocation",
//     fetchBackground,
//     frequency: const Duration(minutes: 15), // Android min = 15 min
//     inputData: {"sid": sid, "employee_id": employeeId},
//   );
// }
//
// class FrappeWebApp extends StatefulWidget {
//   const FrappeWebApp({super.key});
//
//   @override
//   State<FrappeWebApp> createState() => _FrappeWebAppState();
// }
//
// class _FrappeWebAppState extends State<FrappeWebApp> {
//   late final WebViewController _controller;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..loadRequest(Uri.parse(frappeBaseUrl));
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("ERP Dashboard")),
//       body: WebViewWidget(controller: _controller),
//     );
//   }
// }

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// import 'package:workmanager/workmanager.dart';
// import 'package:http/http.dart' as http;
// import 'package:geolocator/geolocator.dart';
//
// const fetchBackground = "employeeLocationTask";
// String? globalEmployeeId; // will be set dynamically
// String frappeBaseUrl = "https://erp.yashgroupservices.com"; // change to your domain
// String apiKey = "150e3245b8132af"; // frappe api key
// String apiSecret = "e65221412c4395c"; // frappe api secret
//
// // Background task dispatcher
// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     if (task == fetchBackground && globalEmployeeId != null) {
//       try {
//         // Get location
//         Position pos = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high,
//         );
//
//         // Send to frappe
//         final response = await http.post(
//           Uri.parse(
//               "$frappeBaseUrl/api/method/frappe.create_emp.update_location"),
//           headers: {
//             "Content-Type": "application/json",
//             "Authorization": "token $apiKey:$apiSecret",
//           },
//           body: jsonEncode({
//             "employee": globalEmployeeId,
//             "lat": pos.latitude,
//             "lng": pos.longitude,
//           }),
//         );
//
//         print("✅ Location sent => ${response.body}");
//       } catch (e) {
//         print("❌ Error in background tracking: $e");
//       }
//     }
//     return Future.value(true);
//   });
// }
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: FrappeWebApp(),
//     );
//   }
// }
//
// class FrappeWebApp extends StatefulWidget {
//   const FrappeWebApp({super.key});
//
//   @override
//   State<FrappeWebApp> createState() => _FrappeWebAppState();
// }
//
// class _FrappeWebAppState extends State<FrappeWebApp> {
//   late final WebViewController _controller;
//   bool isTracking = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeWebView();
//   }
//
//   void _initializeWebView() {
//     _controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onPageFinished: (url) {
//             if (url.contains("/app")) {
//               _fetchEmployeeId(); // after login, fetch employee id
//             }
//           },
//         ),
//       )
//       ..loadRequest(Uri.parse(frappeBaseUrl));
//   }
//
//   Future<void> _fetchEmployeeId() async {
//     try {
//       final res = await http.get(
//         Uri.parse(
//             "$frappeBaseUrl/api/method/frappe.create_emp.get_employee_id"),
//         headers: {
//           "Authorization": "token $apiKey:$apiSecret",
//         },
//       );
//
//       final data = jsonDecode(res.body);
//       setState(() {
//         globalEmployeeId = data["message"]["employee_id"];
//       });
//
//       print("✅ Logged in as employee: $globalEmployeeId");
//     } catch (e) {
//       print("❌ Error fetching employee_id: $e");
//     }
//   }
//
//   Future<void> _startTracking() async {
//     if (globalEmployeeId == null) {
//       print("⚠️ Employee ID not set yet");
//       return;
//     }
//
//     await Workmanager().registerPeriodicTask(
//       "1",
//       fetchBackground,
//       frequency: const Duration(minutes: 15),
//       inputData: {"employee_id": globalEmployeeId},
//     );
//
//     setState(() => isTracking = true);
//   }
//
//   Future<void> _stopTracking() async {
//     await Workmanager().cancelAll();
//     setState(() => isTracking = false);
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
//               icon: const Icon(Icons.refresh, color: Colors.black),
//               onPressed: () {
//                 _controller.reload();
//               },
//             ),
//             IconButton(
//               icon: Icon(
//                 isTracking ? Icons.stop_circle : Icons.play_circle,
//                 color: isTracking ? Colors.red : Colors.green,
//               ),
//               onPressed: () {
//                 if (isTracking) {
//                   _stopTracking();
//                 } else {
//                   _startTracking();
//                 }
//               },
//             ),
//           ],
//         ),
//         body: WebViewWidget(controller: _controller),
//       ),
//     );
//   }
// }
//
//
