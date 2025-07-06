import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _searchController = TextEditingController();
  Stream<QuerySnapshot>? _searchStream;

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchStream = null;
      });
      return;
    }
    setState(() {
      _searchStream = FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: query.trim())
          .limit(1)
          .snapshots();
    });
  }

  Future<void> _sendFriendRequest(String toUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final fromUserId = currentUser.uid;

    // 既に友達関係や申請が存在しないかチェック
    // (この部分は後ほど、より堅牢なロジックに改善します)

    // friendshipsコレクションに申請ドキュメントを作成
    await FirebaseFirestore.instance.collection('friendships').add({
      'users': [fromUserId, toUserId],
      'status': 'pending',
      'requestedBy': fromUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('友達申請を送信しました。')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ユーザーを探す'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'メールアドレスで検索',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onSearchChanged,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _searchStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('ユーザーが見つかりません。'));
                }
                
                final userDoc = snapshot.data!.docs.first;
                final userData = userDoc.data() as Map<String, dynamic>;
                final foundUserId = userDoc.id;
                final currentUser = FirebaseAuth.instance.currentUser;

                // 自分自身は表示しない
                if (foundUserId == currentUser?.uid) {
                  return const Center(child: Text('自分自身です。'));
                }

                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(userData['email'] ?? 'メールアドレスなし'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      _sendFriendRequest(foundUserId);
                    },
                    child: const Text('申請'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}