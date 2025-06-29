import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- 修正点1: コントローラを準備 ---
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // --- 修正点2: コントローラを破棄する処理を追加 ---
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログイン'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              // --- 修正点3: TextFieldにコントローラを接続 ---
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                hintText: 'test@example.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              // --- 修正点3: TextFieldにコントローラを接続 ---
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'パスワード',
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              // --- 修正点4: ボタンを押したときの動作を追加 ---
              onPressed: () {
                // コントローラから入力値を取得して、コンソールに表示
                final email = _emailController.text;
                final password = _passwordController.text;
                print('Email: $email, Password: $password');
              },
              child: const Text('ログイン'),
            ),
            TextButton(
              onPressed: () {
                // TODO: 新規登録画面への遷移は後でここに書く
              },
              child: const Text('新規登録はこちら'),
            ),
          ],
        ),
      ),
    );
  }
}