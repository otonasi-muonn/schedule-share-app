import 'package:flutter/material.dart';

// StatelessWidgetからStatefulWidgetに変更します
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 予定追加ダイアログで使うためのコントローラ
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // 予定追加ダイアログを表示するメソッド
  Future<void> _showAddScheduleDialog() async {
    // ダイアログが表示されるたびに入力欄をクリアする
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
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('追加'),
              onPressed: () {
                final title = _titleController.text;
                print('追加する予定のタイトル: $title');
                // TODO: ここでFirestoreへの書き込み処理を呼び出す
                Navigator.of(context).pop(); // ダイアログを閉じる
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        // TODO: ログアウトボタンを後でここに追加します
      ),
      body: const Center(
        child: Text(
          'ここにスケジュール一覧が表示されます', // メッセージを少し変更
          style: TextStyle(fontSize: 18),
        ),
      ),
      // 画面右下にフローティングアクションボタンを追加
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddScheduleDialog,
        tooltip: '予定を追加', // ボタンを長押しした時に表示される説明
        child: const Icon(Icons.add),
      ),
    );
  }
}