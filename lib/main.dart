import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'firebase_options.dart';
import 'pages/planning.dart';
import 'pages/auth/login.dart';

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

  @override
  void initState() {
    super.initState();
    _initialPage = _getInitialPage();
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
            return snapshot.data!;
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
