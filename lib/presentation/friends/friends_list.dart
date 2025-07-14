import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FriendsList extends StatelessWidget {
  const FriendsList({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('ログインしていません'));
    }

    return StreamBuilder<QuerySnapshot>(
      // 自分が関係者で、ステータスが'accepted'のドキュメントを取得
      stream: FirebaseFirestore.instance
          .collection('friendships')
          .where('users', arrayContains: currentUser.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('エラー: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('まだ友達がいません。'));
        }

        final friendshipDocs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: friendshipDocs.length,
          itemBuilder: (context, index) {
            final doc = friendshipDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final List<String> userIds = List<String>.from(data['users']);
            
            // 自分ではない方のユーザーIDを取得
            final friendId = userIds.firstWhere((id) => id != currentUser.uid);

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const ListTile(title: Text('...'));
                }
                final friendData = userSnapshot.data!.data() as Map<String, dynamic>;
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(friendData['email'] ?? '不明なユーザー'),
                  // TODO: ここに友達とのアクションボタン（チャット、予定共有など）を追加
                );
              },
            );
          },
        );
      },
    );
  }
}