import 'package:flutter/material.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Auth Screen (Login / Signup)',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}