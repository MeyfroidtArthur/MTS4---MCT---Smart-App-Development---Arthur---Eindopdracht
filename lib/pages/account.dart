import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:newagendaapp/pages/planning.dart';
import 'package:newagendaapp/pages/month.dart';
import 'package:newagendaapp/pages/location.dart';
import 'package:newagendaapp/overlay/createplan.dart';
import 'package:newagendaapp/service/firebaseServices.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:newagendaapp/pages/auth/login.dart';
import 'package:newagendaapp/widigits/nav.dart';

class Account extends StatefulWidget {
  final String uid;

  const Account({Key? key, required this.uid}) : super(key: key);

  @override
  _AccountState createState() => _AccountState();
}

class _AccountState extends State<Account> {
  bool _isOverlayVisible = false;
  Map<String, dynamic>? _userData;
  final FirestoreAccess _firestoreAccess = FirestoreAccess();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() async {
    try {
      final data = await _firestoreAccess.getUserData(widget.uid);
      if (data != null) {
        setState(() {
          _userData = data;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  void _toggleOverlay() {
    setState(() {
      _isOverlayVisible = !_isOverlayVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[100],
          body: SafeArea(
            child: Center(
              child:
                  _userData != null
                      ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              _userData!['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _userData!['email'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _userData!['createdAt'] is Timestamp
                                  ? (_userData!['createdAt'] as Timestamp)
                                      .toDate()
                                      .toLocal()
                                      .toString()
                                      .split(' ')[0]
                                  : 'Invalid date',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black38,
                              ),
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await _firestoreAccess.signOutUser();
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginPage(),
                                  ),
                                  (route) => false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF003049),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Log Out',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      : const CircularProgressIndicator(),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'account_fab', // Single heroTag for all pages
            backgroundColor: const Color(0xFF003049),
            onPressed: _toggleOverlay,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: NavBar(
            currentIndex: 3, // Set the current index for Account
            uid: widget.uid, // Pass the user ID
            onFabPressed: _toggleOverlay, // Pass the FAB action
          ),
        ),
        if (_isOverlayVisible)
          CreatePlanOverlay(onClose: _toggleOverlay, uid: widget.uid),
      ],
    );
  }
}
