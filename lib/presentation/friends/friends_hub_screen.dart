import 'package:flutter/material.dart';
import 'package:schedule_share_app/presentation/friends/user_search_screen.dart';
import 'package:schedule_share_app/presentation/friends/friend_requests_list.dart';
import 'package:schedule_share_app/presentation/friends/friends_list.dart'; // NEW!

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
        body: const TabBarView(
          children: [
            // --- MODIFIED! 友達リストウィジェットを配置 ---
            FriendsList(),
            
            FriendRequestsList(),
          ],
        ),
      ),
    );
  }
}