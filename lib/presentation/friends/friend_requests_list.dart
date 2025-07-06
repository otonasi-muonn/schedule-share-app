import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendRequestsList extends StatefulWidget {
  const FriendRequestsList({super.key});

  @override
  State<FriendRequestsList> createState() => _FriendRequestsListState();
}

class _FriendRequestsListState extends State<FriendRequestsList> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  Future<DocumentSnapshot> _getUserData(String userId) {
    return FirebaseFirestore.instance.collection('users').doc(userId).get();
  }

  Future<void> _acceptRequest(String docId) async {
    await FirebaseFirestore.instance.collection('friendships').doc(docId).update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _declineRequest(String docId) async {
    await FirebaseFirestore.instance.collection('friendships').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(child: Text('ログインしていません。'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friendships')
          .where('users', arrayContains: _currentUser!.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('エラー: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('届いている友達申請はありません。'));
        }

        // --- MODIFIED! `!`を削除 ---
        final requests = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['requestedBy'] != _currentUser.uid;
        }).toList();

        if (requests.isEmpty) {
          return const Center(child: Text('届いている友達申請はありません。'));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestDoc = requests[index];
            final requestData = requestDoc.data() as Map<String, dynamic>;
            final fromUserId = requestData['requestedBy'];

            return FutureBuilder<DocumentSnapshot>(
              future: _getUserData(fromUserId),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const ListTile(title: Text('読み込み中...'));
                }
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(userData['email'] ?? '不明なユーザー'),
                  subtitle: const Text('友達申請が届いています。'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => _acceptRequest(requestDoc.id),
                        child: const Text('承認'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _declineRequest(requestDoc.id),
                        child: const Text('拒否'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}