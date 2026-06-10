import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        // Sets the background of the screen to white
        backgroundColor: Colors.white, 
        body: Center(
          child: Text(
            'Hello World',
            style: TextStyle(
              // Sets the text color to black
              color: Colors.black, 
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}