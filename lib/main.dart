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
import 'service/firebaseServices.dart'; // Import your Firestore service
import 'package:location/location.dart'; // Add this import
import 'dart:convert'; // Add this import for JSON encoding/decoding
import 'package:http/http.dart' as http; // Add this import for HTTP requests

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  String accessToken =
      "pk.eyJ1IjoiYXJ0aHVybWV5ZnJvaWR0IiwiYSI6ImNtYTNseDMyajE2MzYyaXNmN2pxZmRqZ2EifQ.vV10oj7eLmsUgyAU9zb0sQ";
  MapboxOptions.setAccessToken(accessToken);

  runApp(const MyApp());
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
  Set<String> _notifiedOneDayAppointments =
      {}; // New list for 1-day notifications

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initialPage = _getInitialPage();
    _initializeNotifications();
    _requestNotificationPermissions(); // Request permissions here
    _startAppointmentFetchTimer();
  }

  @override
  void dispose() {
    _appointmentFetchTimer
        ?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
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
        DateTime startTime = (appointment['startTime'] as Timestamp).toDate();
        print("Leave time: ${leaveTime.toLocal()}");
        print("Current time: ${DateTime.now().toLocal()}");
        print(
          "Difference in minutes: ${leaveTime.toLocal().difference(DateTime.now().toLocal()).inMinutes}",
        );

        // Check if the appointment is less than 1 day away
        if (!_notifiedOneDayAppointments.contains(appointment['title']) &&
            startTime.difference(DateTime.now()).inHours < 24) {
          try {
            String formattedTime = DateFormat('HH:mm').format(startTime);

            // Send a notification for appointments less than 1 day away
            await flutterLocalNotificationsPlugin.show(
              appointment.hashCode, // Unique ID for the 1-day notification
              "Herinnering: ${appointment['title']} morgen om $formattedTime",
              'Je afspraak bij ${appointment['locationName']} is morgen. Vergeet niet te plannen!',
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'reminder_channel',
                  'Reminder Notifications',
                  channelDescription: 'Kanaal voor herinneringsmeldingen',
                  importance: Importance.max,
                  priority: Priority.high,
                  playSound: true,
                  enableVibration: true,
                ),
              ),
            );

            // Mark this appointment as notified for the 1-day reminder
            _notifiedOneDayAppointments.add(appointment['title']);
            print(
              "1-day reminder notification sent for ${appointment['title']}",
            );
          } catch (e) {
            print("Error sending 1-day reminder notification: $e");
          }
        }

        // Immediate notification for leaving
        if (!_notifiedAppointments.contains(appointment['title']) &&
            (leaveTime.toLocal().difference(DateTime.now().toLocal()).inMinutes)
                    .abs() <=
                1) {
          try {
            String formattedTime = DateFormat('HH:mm').format(startTime);

            Map<String, dynamic> filteredAppointment = {
              'TravelMode': appointment['TravelMode'],
              'latitude': appointment['latitude'],
              'locationName': appointment['locationName'],
              'longitude': appointment['longitude'],
            };

            await flutterLocalNotificationsPlugin.show(
              appointment.hashCode +
                  1, // Unique ID for the immediate notification
              "Afspraak ${appointment['title']} om $formattedTime",
              'Je moet nu vertrekken om ${appointment['locationName']} te bereiken voor je afspraak.',
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'test_channel',
                  'Test Notifications',
                  channelDescription: 'Kanaal voor testmeldingen',
                  importance: Importance.max,
                  priority: Priority.high,
                  playSound: true,
                  enableVibration: true,
                ),
              ),
              payload: jsonEncode(filteredAppointment),
            );

            // Mark this appointment as notified
            _notifiedAppointments.add(appointment['title']);
            print("Immediate notification sent for ${appointment['title']}");
          } catch (e) {
            print("Error sending immediate notification: $e");
          }
        }
      }
      print("Fetched ${upcomingAppointments.length} upcoming appointments.");
    } catch (e) {
      print("Error fetching upcoming appointments: $e");
    }
  }

  // Helper method to calculate travel time using OpenRouteService API
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
      final duration = segment['duration'] / 60; // Duration in minutes
      return duration;
    } else {
      print("Error fetching route: ${response.statusCode}");
      print(response.body);
      return 0.0; // Return 0.0 if the API call fails
    }
  }

  bool _areAppointmentsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    return a['title'] == b['title'] &&
        a['latitude'] == b['latitude'] &&
        a['longitude'] == b['longitude'] &&
        a['locationName'] == b['locationName'] &&
        a['TravelMode'] == b['TravelMode'] &&
        a['StartTime'] == b['StartTime'] &&
        a['EndTime'] == b['EndTime'];
  }

  Future<void> _initializeNotifications() async {
    // Define the notification channel for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Define iOS settings if needed
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // Combine platform-specific settings
    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    // Initialize the plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Extract appointment details from the notification payload
        if (details.payload != null) {
          final Map<String, dynamic> appointment = jsonDecode(details.payload!);

          // Navigate to the LocationPage
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

  Future<void> _requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), always request permission
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        final bool? granted =
            await await androidImplementation.requestNotificationsPermission();

        if (granted != null && granted) {
          print("Notification permissions granted.");
        } else {
          print("Notification permissions denied.");
        }
      } else {
        print("Android implementation not available.");
      }
    } else if (Platform.isIOS) {
      // For iOS, request permissions explicitly
      final bool? granted = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      if (granted != null && granted) {
        print("Notification permissions granted.");
      } else {
        print("Notification permissions denied.");
      }
    }
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

            // Wrap the home page with a notification test button if in debug mode
            if (snapshot.data is Planning) {
              return Scaffold(
                body: homePage,
                floatingActionButton: FloatingActionButton(
                  onPressed: showTestNotification,
                  tooltip: 'Test Notification',
                  child: Icon(Icons.notifications),
                ),
              );
            }

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
