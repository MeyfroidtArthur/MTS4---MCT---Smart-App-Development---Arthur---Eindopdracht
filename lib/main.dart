import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import 'firebase_options.dart';
import 'pages/planning.dart';
import 'pages/auth/login.dart';
import 'pages/location.dart';
import 'service/firebaseServices.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set Mapbox access token
  MapboxOptions.setAccessToken(Config.mapboxAccessToken);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<Widget> _initialPage;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  Timer? _appointmentFetchTimer;
  List<Map<String, dynamic>> _previousAppointments = [];
  Set<String> _notifiedAppointments = {};
  Set<String> _notifiedOneDayAppointments = {};
  double _currentLatitude = 0.0;
  double _currentLongitude = 0.0;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initialPage = _getInitialPage();
    _initializeNotifications();
    _requestNotificationPermissions();
    _startAppointmentFetchTimer();
  }

  @override
  void dispose() {
    _appointmentFetchTimer?.cancel();
    super.dispose();
  }

  /// Starts a periodic timer to fetch upcoming appointments.
  void _startAppointmentFetchTimer() {
    _appointmentFetchTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _fetchUpcomingAppointments(),
    );
  }

  /// Fetches upcoming appointments and handles notifications.
  Future<void> _fetchUpcomingAppointments() async {
    try {
      await _updateCurrentLocation();
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      FirestoreAccess firestoreAccess = FirestoreAccess();
      List<Map<String, dynamic>> appointments = await firestoreAccess
          .getAppointments(user.uid);

      DateTime now = DateTime.now();
      List<Map<String, dynamic>> upcomingAppointments =
          appointments.where((appointment) {
            DateTime startTime =
                (appointment['startTime'] as Timestamp).toDate();
            return startTime.isAfter(now);
          }).toList();

      _processAppointments(upcomingAppointments);
    } catch (e) {
      print("Error fetching appointments: $e");
    }
  }

  /// Updates the current location of the user.
  Future<void> _updateCurrentLocation() async {
    Location location = Location();

    if (!await location.serviceEnabled() && !await location.requestService()) {
      print("Location services are disabled.");
      _currentLatitude = 0.0;
      _currentLongitude = 0.0;
      return;
    }

    if (await location.hasPermission() == PermissionStatus.denied &&
        await location.requestPermission() != PermissionStatus.granted) {
      print("Location permissions are denied.");
      _currentLatitude = 0.0;
      _currentLongitude = 0.0;
      return;
    }

    LocationData locationData = await location.getLocation();
    _currentLatitude = locationData.latitude ?? 0.0;
    _currentLongitude = locationData.longitude ?? 0.0;
  }

  /// Processes appointments and sends notifications.
  void _processAppointments(List<Map<String, dynamic>> appointments) async {
    for (var appointment in appointments) {
      double travelTime = await _calculateTravelTime(
        _currentLatitude,
        _currentLongitude,
        appointment['latitude'],
        appointment['longitude'],
        appointment['TravelMode'],
      );

      travelTime += 30; // Add buffer time
      DateTime startTime = (appointment['startTime'] as Timestamp).toDate();
      DateTime leaveTime = startTime.subtract(
        Duration(minutes: travelTime.toInt()),
      );
      appointment['leaveTime'] = leaveTime;

      _sendNotifications(appointment, leaveTime, startTime);
    }
    _previousAppointments = appointments;
  }

  /// Sends notifications for appointments.
  void _sendNotifications(
    Map<String, dynamic> appointment,
    DateTime leaveTime,
    DateTime startTime,
  ) async {
    String title = appointment['title'];
    String locationName = appointment['locationName'];

    // 1-day reminder notification
    if (!_notifiedOneDayAppointments.contains(title) &&
        startTime.difference(DateTime.now()).inHours < 24) {
      await _showNotification(
        id: appointment.hashCode,
        title:
            "Herinnering: $title morgen om ${DateFormat('HH:mm').format(startTime)}",
        body:
            'Je afspraak bij $locationName is morgen. Vergeet niet te plannen!',
        channelId: 'reminder_channel',
        channelName: 'Reminder Notifications',
      );
      _notifiedOneDayAppointments.add(title);
    }

    // Immediate notification for leaving
    if (!_notifiedAppointments.contains(title) &&
        leaveTime.difference(DateTime.now()).inMinutes.abs() <= 1) {
      await _showNotification(
        id: appointment.hashCode + 1,
        title: "Afspraak $title om ${DateFormat('HH:mm').format(startTime)}",
        body:
            'Je moet nu vertrekken om $locationName te bereiken voor je afspraak.',
        channelId: 'test_channel',
        channelName: 'Test Notifications',
        payload: jsonEncode({
          'TravelMode': appointment['TravelMode'],
          'latitude': appointment['latitude'],
          'longitude': appointment['longitude'],
          'locationName': locationName,
        }),
      );
      _notifiedAppointments.add(title);
    }
  }

  /// Shows a notification.
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Kanaal voor testmeldingen',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      print("Error showing notification: $e");
    }
  }

  /// Calculates travel time using OpenRouteService API.
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
        'Authorization': Config.openRouteServiceApiKey,
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['features'][0]['properties']['segments'][0]['duration'] / 60;
    } else {
      print("Error fetching route: ${response.statusCode}");
      return 0.0;
    }
  }

  /// Initializes the notification system.
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          final appointment = jsonDecode(details.payload!);
          Navigator.push(
            _navigatorKey.currentContext!,
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
        }
      },
    );
  }

  /// Requests notification permissions.
  Future<void> _requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      await androidImplementation?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      final iosImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
      await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Determines the initial page based on user authentication.
  Future<Widget> _getInitialPage() async {
    User? user = FirebaseAuth.instance.currentUser;
    return user != null ? Planning(uid: user.uid) : LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF003049)),
      ),
      home: FutureBuilder<Widget>(
        future: _initialPage,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return snapshot.data!;
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
    );
  }
}
