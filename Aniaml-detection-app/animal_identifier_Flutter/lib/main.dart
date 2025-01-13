import 'package:flutter/material.dart';
import 'StartPage.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Animal Recognition App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Startpage(),
    );
  }
}
