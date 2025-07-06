import 'package:flutter/material.dart';

class FriendsHubScreen extends StatelessWidget {
  const FriendsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // タブの数
      child: Scaffold(
        appBar: AppBar(
          title: const Text('友達'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'ユーザーを探す',
              onPressed: () {
                // TODO: ユーザー検索画面に遷移する処理を後で追加
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '友達リスト'),
              Tab(text: '届いた申請'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TODO: 友達リストをここに表示する
            Center(child: Text('ここに友達リストが表示されます。')),
            
            // TODO: 届いた申請をここに表示する
            Center(child: Text('ここに届いた友達申請が表示されます。')),
          ],
        ),
      ),
    );
  }
}