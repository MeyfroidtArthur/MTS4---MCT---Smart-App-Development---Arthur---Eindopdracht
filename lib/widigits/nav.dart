import 'package:flutter/material.dart';
import 'package:newagendaapp/pages/planning.dart';
import 'package:newagendaapp/pages/month.dart';
import 'package:newagendaapp/pages/location.dart';
import 'package:newagendaapp/pages/account.dart';

class NavBar extends StatelessWidget {
  final int currentIndex;
  final String uid;
  final VoidCallback onFabPressed;

  const NavBar({
    Key? key,
    required this.currentIndex,
    required this.uid,
    required this.onFabPressed,
  }) : super(key: key);

  void _onTabSelected(BuildContext context, int index) {
    if (index == currentIndex)
      return; // Do nothing if the current page is selected

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Planning(uid: uid)),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Month(uid: uid)),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LocationPage(uid: uid)),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Account(uid: uid)),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context,
            icon: Icons.checklist,
            index: 0,
            isActive: currentIndex == 0,
          ),
          _buildNavItem(
            context,
            icon: Icons.calendar_month,
            index: 1,
            isActive: currentIndex == 1,
          ),
          const SizedBox(width: 48), // Space for FAB
          _buildNavItem(
            context,
            icon: Icons.location_on,
            index: 2,
            isActive: currentIndex == 2,
          ),
          _buildNavItem(
            context,
            icon: Icons.account_circle,
            index: 3,
            isActive: currentIndex == 3,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required int index,
    required bool isActive,
  }) {
    return Container(
      decoration:
          isActive
              ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.black, width: 2.0),
                ),
              )
              : null,
      child: IconButton(
        icon: Icon(icon),
        color: isActive ? Colors.black : Colors.grey,
        onPressed:
            isActive
                ? null // Disable the button if it's the active page
                : () => _onTabSelected(context, index),
      ),
    );
  }
}
