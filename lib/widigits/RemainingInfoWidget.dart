import 'package:flutter/material.dart';

class RemainingInfoWidget extends StatelessWidget {
  final double remainingTime;
  final double remainingDistance;

  const RemainingInfoWidget({
    Key? key,
    required this.remainingTime,
    required this.remainingDistance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF003049).withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${remainingTime.toStringAsFixed(1)} min',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${remainingDistance.toStringAsFixed(2)} km',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
