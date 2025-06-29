import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
      ),
      body: const Center(
        child: Text(
          'ログイン成功！ようこそ！',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}