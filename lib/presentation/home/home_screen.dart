import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _titleController = TextEditingController();

  // (中略: _addSchedule, _showAddScheduleDialog, dispose メソッドは変更なし)
  Future<void> _addSchedule(String title) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { return; }
    try {
      await FirebaseFirestore.instance.collection('schedules').add({
        'title': title, 'userId': user.uid, 'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('予定を追加しました。'))); }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e'))); }
    }
  }
  Future<void> _showAddScheduleDialog() async {
    _titleController.clear();
    return showDialog(context: context, builder: (context) {
        return AlertDialog(title: const Text('予定の追加'), content: TextField(controller: _titleController, decoration: const InputDecoration(hintText: "タイトルを入力")),
          actions: [
            TextButton(child: const Text('キャンセル'), onPressed: () => Navigator.of(context).pop()),
            ElevatedButton(child: const Text('追加'), onPressed: () {
                final title = _titleController.text;
                if (title.isNotEmpty) { _addSchedule(title); }
                Navigator.of(context).pop();
            }),
          ],
        );
    });
  }
  @override
  void dispose() { _titleController.dispose(); super.dispose(); }


  // --- buildメソッドを大幅に書き換えます ---
  @override
  Widget build(BuildContext context) {
    // 現在のユーザー情報を取得
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        // TODO: ログアウトボタンを後でここに追加します
      ),
      // --- NEW! ここから下がStreamBuilderを使ったリスト表示部分 ---
      body: StreamBuilder<QuerySnapshot>(
        // 表示するデータストリーム: ログイン中のユーザーの予定を、作成日時の新しい順に取得
        stream: FirebaseFirestore.instance
            .collection('schedules')
            .where('userId', isEqualTo: user?.uid) // 自分の予定だけをフィルタリング
            .orderBy('createdAt', descending: true) // 新しいものが上に来るように並び替え
            .snapshots(), // リアルタイムで監視
        
        // データストリームの状態に応じてUIを構築
        builder: (context, snapshot) {
          // データ取得中の場合は、くるくる回るローディング表示
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // エラーが発生した場合
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          // データがまだない、またはドキュメントが0件の場合
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('予定はまだありません。'));
          }

          // データがある場合は、リストとして表示
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] as String? ?? 'タイトルなし'; // 安全にタイトルを取得

              // ListTileを使って、各予定をリストの一項目として表示
              return ListTile(
                title: Text(title),
                // TODO: ここに削除ボタンや編集ボタンを追加していく
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddScheduleDialog,
        tooltip: '予定を追加',
        child: const Icon(Icons.add),
      ),
    );
  }
}