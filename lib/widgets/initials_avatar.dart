import 'package:flutter/material.dart';

/// A circle avatar showing the first letter of a name — this exact widget
/// was being rebuilt separately for partner cards, member tiles, and due
/// tiles. One shared version now.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double radius;

  const InitialsAvatar({
    super.key,
    required this.name,
    required this.color,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(0.15),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: radius * 0.8),
      ),
    );
  }
}