import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserSelectionModal extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onUserSelected;
  final List<Map<String, dynamic>> initiallySelectedUsers;
  final String? uid;

  const UserSelectionModal({
    required this.onUserSelected,
    required this.initiallySelectedUsers,
    this.uid,
  });

  @override
  _UserSelectionModalState createState() => _UserSelectionModalState();
}

class _UserSelectionModalState extends State<UserSelectionModal> {
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> selectedUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    selectedUsers = List.from(widget.initiallySelectedUsers);
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      // Fetch all documents from the 'public_users' collection
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('public_users').get();

      List<Map<String, dynamic>> fetchedUsers = [];
      print("Fetched users: ${snapshot.docs.length}");

      for (var doc in snapshot.docs) {
        try {
          // Add the user details to the fetchedUsers list
          if (doc['userId'] == widget.uid) {
            continue; // Skip the current user's document
          }
          fetchedUsers.add({
            'id': doc['userId'], // Use the document ID as the user ID
            'name': doc['name'],
            'fcmToken': doc['fcmToken'],
          });
          print("Fetched user: ${doc['name']} (ID: ${doc.id})");
        } catch (e) {
          print("Error processing user details: $e");
        }
      }

      // Update the state with the fetched users
      setState(() {
        users = fetchedUsers;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching users: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _toggleUserSelection(Map<String, dynamic> user) {
    setState(() {
      // Check if the user is already selected
      if (selectedUsers.any(
        (selectedUser) => selectedUser['id'] == user['id'],
      )) {
        // If already selected, remove the user
        selectedUsers.removeWhere(
          (selectedUser) => selectedUser['id'] == user['id'],
        );
      } else {
        // If not selected, add the user
        selectedUsers.add(user);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select Users',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          isLoading
              ? Center(child: CircularProgressIndicator())
              : Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = selectedUsers.any(
                      (selectedUser) => selectedUser['id'] == user['id'],
                    );
                    return ListTile(
                      title: Text(user['name']),
                      trailing:
                          isSelected
                              ? Icon(Icons.check, color: Colors.green)
                              : null,
                      onTap: () => _toggleUserSelection(user),
                    );
                  },
                ),
              ),
          ElevatedButton(
            onPressed: () {
              widget.onUserSelected(selectedUsers);
              Navigator.pop(context);
            },
            child: Text('Done'),
          ),
        ],
      ),
    );
  }
}
