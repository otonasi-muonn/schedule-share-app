import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../home/home_screen.dart'; // ホーム画面をインポート

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // コントローラにリスナーを追加して、文字の変更を検知
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
  }

  // --- ログイン処理を行うメソッド ---
  Future<void> _login() async {
    try {
      final email = _emailController.text;
      final password = _passwordController.text;

      // Firebase Authでメールとパスワードでログイン
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ログインが成功したら、ホーム画面に遷移
      if (mounted) {
        // pushReplacementで、ログイン画面に戻れないようにする
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'エラーが発生しました。';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'メールアドレスまたはパスワードが間違っています。';
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
    }
  }

  // --- 新規登録ダイアログを表示するメソッド ---
  Future<void> _showSignUpDialog() async {
    final dialogEmailController = TextEditingController();
    final dialogPasswordController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('新規登録'),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dialogEmailController,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dialogPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'パスワード'),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await _signUp(
                  dialogEmailController.text,
                  dialogPasswordController.text,
                );
              },
              child: const Text('登録する'),
            ),
          ],
        );
      },
    );
  }

  // --- 新規登録処理を行うメソッド ---
  Future<void> _signUp(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザー登録が完了しました。')),
        );
      }
    } on FirebaseAuthException catch (e) {
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
              decoration: InputDecoration(
                labelText: 'メールアドレス',
                suffixIcon: _emailController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _emailController.clear();
                        },
                      )
                    : null,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'パスワード',
                suffixIcon: _passwordController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _passwordController.clear();
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _login,
              child: const Text('ログイン'),
            ),
            TextButton(
              onPressed: _showSignUpDialog,
              child: const Text('新規登録はこちら'),
            ),
          ],
        ),
      ),
    );
  }
}