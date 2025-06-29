import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // メイン画面の入力欄を管理するコントローラ
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // --- 新規登録ダイアログを表示するメソッド ---
  Future<void> _showSignUpDialog() async {
    // ダイアログ専用のコントローラを準備
    final dialogEmailController = TextEditingController();
    final dialogPasswordController = TextEditingController();

    // メイン画面の入力欄をクリアする
    _emailController.clear();
    _passwordController.clear();

    // ダイアログを表示
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('新規登録'),
              // 右上の「×」ボタン
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min, // 内容に合わせて高さを調整
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
            // 登録ボタン
            ElevatedButton(
              onPressed: () async {
                // ダイアログから入力値を取得して、新規登録処理を実行
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
        // 成功したらダイアログを閉じる
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
              decoration: const InputDecoration(labelText: 'メールアドレス'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'パスワード'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // TODO: ログイン処理を実装する
              },
              child: const Text('ログイン'),
            ),
            TextButton(
              // ボタンが押されたら、ダイアログを表示するメソッドを呼び出す
              onPressed: _showSignUpDialog,
              child: const Text('新規登録はこちら'),
            ),
          ],
        ),
      ),
    );
  }
}