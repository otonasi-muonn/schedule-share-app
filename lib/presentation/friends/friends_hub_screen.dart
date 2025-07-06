import 'package:flutter/material.dart';
import 'package:schedule_share_app/presentation/friends/user_search_screen.dart'; // NEW!

class FriendsHubScreen extends StatelessWidget {
  const FriendsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('友達'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'ユーザーを探す',
              onPressed: () {
                // --- MODIFIED! ユーザー検索画面に遷移 ---
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const UserSearchScreen()),
                );
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
            Center(child: Text('ここに友達リストが表示されます。')),
            Center(child: Text('ここに届いた友達申請が表示されます。')),
          ],
        ),
      ),
    );
  }
}