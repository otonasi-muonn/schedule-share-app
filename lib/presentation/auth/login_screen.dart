import 'package:firebase_auth/firebase_auth.dart'; // NEW! Firebase Authをインポート
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // NEW! 新規登録処理を行うメソッド
  Future<void> _signUp() async {
    // try-catchでエラー処理を実装
    try {
      final email = _emailController.text;
      final password = _passwordController.text;

      // Firebase Authにユーザーを新規登録
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 成功した場合のメッセージを画面に表示
      if (mounted) { // mountedプロパティでウィジェットが有効か確認
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザー登録が完了しました。')),
        );
      }
    } on FirebaseAuthException catch (e) {
      // エラーコードに応じたメッセージを画面に表示
      String errorMessage = 'エラーが発生しました。';
      if (e.code == 'weak-password') {
        errorMessage = 'パスワードが弱すぎます。';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'このメールアドレスは既に使用されています。';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'メールアドレスの形式が正しくありません。';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      // その他のエラー
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

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
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                hintText: 'test@example.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'パスワード',
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // TODO: ログイン処理は後でここに書く
              },
              child: const Text('ログイン'),
            ),
            TextButton(
              // NEW! 新規登録ボタンが押されたら_signUpメソッドを呼び出す
              onPressed: _signUp,
              child: const Text('新規登録はこちら'),
            ),
          ],
        ),
      ),
    );
  }
}