import 'package:cloud_firestore/cloud_firestore.dart'; // NEW!
import 'package:firebase_auth/firebase_auth.dart'; // NEW!
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _titleController = TextEditingController();

  // --- NEW! Firestoreにデータを書き込むメソッド ---
  Future<void> _addSchedule(String title) async {
    // 現在ログインしているユーザー情報を取得
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // もしユーザーがログインしていなかったら、何もしない
      return;
    }

    try {
      // 'schedules'コレクションに新しいドキュメントを追加
      await FirebaseFirestore.instance.collection('schedules').add({
        'title': title, // 予定のタイトル
        'userId': user.uid, // 誰の予定かを示すユーザーID
        'createdAt': FieldValue.serverTimestamp(), // 作成日時
        // TODO: is_all_day, start_time, end_timeなども後で追加
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('予定を追加しました。')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  Future<void> _showAddScheduleDialog() async {
    _titleController.clear();
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('予定の追加'),
          content: TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: "タイトルを入力"),
          ),
          actions: [
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('追加'),
              onPressed: () {
                final title = _titleController.text;
                if (title.isNotEmpty) {
                  // NEW! タイトルが空でなければ書き込み処理を呼び出す
                  _addSchedule(title);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // (buildメソッドの中身は変更なし)
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
      ),
      body: const Center(
        child: Text(
          'ここにスケジュール一覧が表示されます',
          style: TextStyle(fontSize: 18),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddScheduleDialog,
        tooltip: '予定を追加',
        child: const Icon(Icons.add),
      ),
    );
  }
}