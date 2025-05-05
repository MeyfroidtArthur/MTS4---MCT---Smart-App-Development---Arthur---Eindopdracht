import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:newagendaapp/pages/location.dart';
import 'firebase_options.dart';
import 'pages/planning.dart';
import 'pages/auth/login.dart';
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'service/firebaseServices.dart';
import 'package:location/location.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  String accessToken =
      "pk.eyJ1IjoiYXJ0aHVybWV5ZnJvaWR0IiwiYSI6ImNtYTNseDMyajE2MzYyaXNmN2pxZmRqZ2EifQ.vV10oj7eLmsUgyAU9zb0sQ";
  MapboxOptions.setAccessToken(accessToken);

  runApp(const MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<Widget> _initialPage;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Timer? _appointmentFetchTimer;
  List<Map<String, dynamic>> _previousAppointments = [];
  double _currentLatitude = 0.0;
  double _currentLongitude = 0.0;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  Set<String> _notifiedAppointments = {}; // Track notified appointments

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initialPage = _getInitialPage();
    _initializeNotifications();
    _startAppointmentFetchTimer();
    _setupFirebaseMessaging();
  }

  @override
  void dispose() {
    _appointmentFetchTimer?.cancel();
    super.dispose();
  }

  void _setupFirebaseMessaging() async {
    NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }

    String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('public_users')
            .doc(user.uid)
            .set({'fcmToken': fcmToken}, SetOptions(merge: true));
        print('FCM Token saved: $fcmToken');
      }
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('public_users')
            .doc(user.uid)
            .set({'fcmToken': newToken}, SetOptions(merge: true));
        print('FCM Token updated: $newToken');
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
        'Received a message in the foreground: ${message.notification?.title}',
      );
      if (message.notification != null) {
        _showNotification(
          message.notification!.title ?? 'No Title',
          message.notification!.body ?? 'No Body',
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print(
        'Notification clicked and app opened: ${message.notification?.title}',
      );
    });
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'default_channel',
          'Default Notifications',
          channelDescription: 'Channel for default notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(0, title, body, platformDetails);
  }

  void _startAppointmentFetchTimer() {
    _appointmentFetchTimer = Timer.periodic(const Duration(minutes: 1), (
      timer,
    ) async {
      await _fetchUpcomingAppointments();
    });
  }

  Future<void> _fetchUpcomingAppointments() async {
    try {
      Location location = Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          print("Location services are disabled.");
          _currentLatitude = 0.0;
          _currentLongitude = 0.0;
          return;
        }
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          print("Location permissions are denied.");
          _currentLatitude = 0.0;
          _currentLongitude = 0.0;
          return;
        }
      }

      LocationData locationData = await location.getLocation();
      _currentLatitude = locationData.latitude ?? 0.0;
      _currentLongitude = locationData.longitude ?? 0.0;

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("No user logged in, skipping appointment fetch.");
        return;
      }

      String userId = user.uid;
      FirestoreAccess firestoreAccess = FirestoreAccess();
      List<Map<String, dynamic>> appointments = await firestoreAccess
          .getAppointments(userId);
      print("Fetched ${appointments.length} appointments.");

      DateTime now = DateTime.now();
      List<Map<String, dynamic>> upcomingAppointments =
          appointments.where((appointment) {
            DateTime startTime =
                (appointment['startTime'] as Timestamp).toDate();
            return startTime.isAfter(now);
          }).toList();

      List<Map<String, dynamic>> currentList = [];
      for (var appointment in upcomingAppointments) {
        print(
          "Coords: (${appointment['latitude']}, ${appointment['longitude']})",
        );
        print("Location Name: ${appointment['locationName']}");
        print("Travel Mode: ${appointment['TravelMode']}");

        double travelTime = await _calculateTravelTime(
          _currentLatitude,
          _currentLongitude,
          appointment['latitude'],
          appointment['longitude'],
          appointment['TravelMode'],
        );

        travelTime += 30;

        DateTime startTime = (appointment['startTime'] as Timestamp).toDate();
        DateTime leaveTime = startTime.subtract(
          Duration(minutes: travelTime.toInt()),
        );
        appointment['leaveTime'] = leaveTime;
        print("You need to leave at: ${appointment['leaveTime'].toLocal()}");

        currentList.add(appointment);
      }
      _previousAppointments = currentList;

      for (var appointment in currentList) {
        DateTime leaveTime = appointment['leaveTime'];
        print("Leave time: ${leaveTime.toLocal()}");
        print("Current time: ${DateTime.now().toLocal()}");
        print(
          "Difference in minutes: ${leaveTime.toLocal().difference(DateTime.now().toLocal()).inMinutes}",
        );

        // Check if the notification has already been sent
        if (!_notifiedAppointments.contains(appointment['title']) &&
            (leaveTime.toLocal().difference(DateTime.now().toLocal()).inMinutes)
                    .abs() <=
                1) {
          print(
            "Sending notification for appointment: ${appointment['title']}",
          );
          const AndroidNotificationDetails androidDetails =
              AndroidNotificationDetails(
                'test_channel',
                'Test Notifications',
                channelDescription: 'Channel for testing notifications',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
              );
          const NotificationDetails platformDetails = NotificationDetails(
            android: androidDetails,
          );

          try {
            DateTime startTime =
                (appointment['startTime'] as Timestamp).toDate();
            String formattedTime = DateFormat('HH:mm').format(startTime);

            Map<String, dynamic> filteredAppointment = {
              'TravelMode': appointment['TravelMode'],
              'latitude': appointment['latitude'],
              'locationName': appointment['locationName'],
              'longitude': appointment['longitude'],
            };

            await flutterLocalNotificationsPlugin.show(
              999,
              "Afspraak ${appointment['title']} om $formattedTime",
              'Je moet nu vertrekken om ${appointment['locationName']} te bereiken voor je afspraak.',
              platformDetails,
              payload: jsonEncode(filteredAppointment),
            );

            // Mark this appointment as notified
            _notifiedAppointments.add(appointment['title']);
            print("Notification sent successfully for ${appointment['title']}");
          } catch (e) {
            print("Error showing afspraak melding: $e");
          }
        }
      }
      print("Fetched ${upcomingAppointments.length} upcoming appointments.");
    } catch (e) {
      print("Error fetching upcoming appointments: $e");
    }
  }

  Future<double> _calculateTravelTime(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
    String travelMode,
  ) async {
    final String url =
        'https://api.openrouteservice.org/v2/directions/$travelMode/geojson';

    final body = jsonEncode({
      "coordinates": [
        [startLon, startLat],
        [endLon, endLat],
      ],
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization':
            '5b3ce3597851110001cf6248df8b8f5c778e4284921481a807469217',
        'Content-Type': 'application/json',
      },
      body: body,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final segment = data['features'][0]['properties']['segments'][0];
      final duration = segment['duration'] / 60;
      return duration;
    } else {
      print("Error fetching route: ${response.statusCode}");
      print(response.body);
      return 0.0;
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload != null) {
          final Map<String, dynamic> appointment = jsonDecode(details.payload!);
          Navigator.push(
            navigatorKey.currentContext!,
            MaterialPageRoute(
              builder:
                  (context) => LocationPage(
                    uid: FirebaseAuth.instance.currentUser?.uid ?? '',
                    initialLocationName: appointment['locationName'],
                    initialLatitude: appointment['latitude'],
                    initialLongitude: appointment['longitude'],
                    initialTransportMode: appointment['TravelMode'],
                  ),
            ),
          );
        } else {
          print("No payload found in the notification.");
        }
      },
    );

    print("Notification system initialized");
  }

  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Channel for testing notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await flutterLocalNotificationsPlugin.show(
        999,
        'Test Notification',
        'This is a test notification to check if notifications are working',
        platformDetails,
      );
      print("Test notification sent successfully");
    } catch (e) {
      print("Error showing test notification: $e");
    }
  }

  Future<Widget> _getInitialPage() async {
    User? user = FirebaseAuth.instance.currentUser;
    String userId = user?.uid ?? "null";
    return user != null ? Planning(uid: userId) : LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 0, 48, 73),
        ),
      ),
      home: FutureBuilder<Widget>(
        future: _initialPage,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            Widget homePage = snapshot.data!;
            return homePage;
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
    );
  }
}
