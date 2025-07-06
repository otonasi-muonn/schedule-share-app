import 'package:flutter/material.dart';

class FriendsList extends StatefulWidget {
  const FriendsList({super.key});

  @override
  State<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  @override
  Widget build(BuildContext context) {
    // TODO: ここに、承認済みの友達をFirestoreから取得して表示するロジックを追加します
    return const Center(
      child: Text('ここに友達リストが表示されます。'),
    );
  }
}