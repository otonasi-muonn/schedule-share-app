import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _titleController = TextEditingController();

  // --- MODIFIED! タイムスタンプを保存するように変更 ---
  Future<void> _addSchedule({
    required String title,
    required DateTime date,
    required bool isAllDay,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { return; }

    // isAllDayがtrueの場合、時刻は00:00とする
    // isAllDayがfalseの場合、指定された時刻を使う。もし時刻がnullなら、現在時刻を使う
    final startDateTime = isAllDay
        ? DateTime(date.year, date.month, date.day)
        : DateTime(date.year, date.month, date.day, startTime?.hour ?? TimeOfDay.now().hour, startTime?.minute ?? TimeOfDay.now().minute);
    
    final endDateTime = isAllDay
        ? DateTime(date.year, date.month, date.day)
        : DateTime(date.year, date.month, date.day, endTime?.hour ?? TimeOfDay.now().hour, endTime?.minute ?? TimeOfDay.now().minute);


    try {
      await FirebaseFirestore.instance.collection('schedules').add({
        'title': title,
        'userId': user.uid,
        'isAllDay': isAllDay, // NEW!
        'startTime': Timestamp.fromDate(startDateTime), // MODIFIED!
        'endTime': Timestamp.fromDate(endDateTime),   // NEW!
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('予定を追加しました。')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    }
  }
  
  // --- MODIFIED! ダイアログの中身を大幅に変更 ---
  Future<void> _showAddScheduleDialog() async {
    _titleController.clear();
    DateTime selectedDate = DateTime.now();
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    bool isAllDay = false;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('予定の追加'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: _titleController, decoration: const InputDecoration(hintText: "タイトルを入力")),
                  const SizedBox(height: 20),
                  // --- 「終日」チェックボックス ---
                  Row(
                    children: [
                      const Text('終日:'),
                      Checkbox(
                        value: isAllDay,
                        onChanged: (value) {
                          setState(() { isAllDay = value ?? false; });
                        },
                      ),
                    ],
                  ),
                  // --- 日付選択 ---
                  Row(
                    children: [
                      const Text('日付: '),
                      TextButton(
                        child: Text(DateFormat('yyyy年M月d日').format(selectedDate), style: const TextStyle(fontSize: 16)),
                        onPressed: () async {
                          final newDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                          if (newDate != null) { setState(() { selectedDate = newDate; }); }
                        },
                      ),
                    ],
                  ),
                  // --- 時刻選択 (終日でない場合のみ表示) ---
                  if (!isAllDay)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          child: Text(startTime?.format(context) ?? '開始時刻'),
                          onPressed: () async {
                            final newTime = await showTimePicker(context: context, initialTime: startTime ?? TimeOfDay.now());
                            if (newTime != null) { setState(() { startTime = newTime; }); }
                          },
                        ),
                        const Text('〜'),
                        TextButton(
                          child: Text(endTime?.format(context) ?? '終了時刻'),
                          onPressed: () async {
                            final newTime = await showTimePicker(context: context, initialTime: endTime ?? startTime ?? TimeOfDay.now());
                            if (newTime != null) { setState(() { endTime = newTime; }); }
                          },
                        ),
                      ],
                    ),
                ],
              ),
              actions: [
                TextButton(child: const Text('キャンセル'), onPressed: () => Navigator.of(context).pop()),
                ElevatedButton(
                  child: const Text('追加'),
                  onPressed: () {
                    final title = _titleController.text;
                    if (title.isNotEmpty) {
                      _addSchedule(title: title, date: selectedDate, isAllDay: isAllDay, startTime: startTime, endTime: endTime);
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // (中略: _deleteSchedule, _showDeleteConfirmDialog, _logout, disposeメソッドは変更なし)
  // ... これらのメソッドは以前のコードと同じものをここに置いてください ...
  Future<void> _deleteSchedule(String docId) async { try { await FirebaseFirestore.instance.collection('schedules').doc(docId).delete(); } catch (e) { if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除中にエラーが発生しました: $e'))); } } }
  Future<void> _showDeleteConfirmDialog(String docId, String title) async { return showDialog(context: context, builder: (context) { return AlertDialog(title: const Text('削除の確認'), content: Text('「$title」を本当に削除しますか？\nこの操作は元に戻せません。'), actions: [ TextButton(child: const Text('キャンセル'), onPressed: () => Navigator.of(context).pop()), TextButton(child: const Text('削除', style: TextStyle(color: Colors.red)), onPressed: () { _deleteSchedule(docId); Navigator.of(context).pop(); }), ],); }); }
  Future<void> _logout() async { await FirebaseAuth.instance.signOut(); }
  @override
  void dispose() { _titleController.dispose(); super.dispose(); }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('ホーム'), actions: [ IconButton(icon: const Icon(Icons.logout), onPressed: _logout) ]),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('schedules')
            .where('userId', isEqualTo: user?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
          if (snapshot.hasError) { return Center(child: Text('エラーが発生しました: ${snapshot.error}')); }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { return const Center(child: Text('予定はまだありません。')); }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] as String? ?? 'タイトルなし';
              
              // --- MODIFIED! タイムスタンプと終日フラグを読み込んで表示を整形 ---
              final isAllDay = data['isAllDay'] as bool? ?? false;
              final startTime = data['startTime'] as Timestamp?;
              final endTime = data['endTime'] as Timestamp?;

              String timeText;
              if (isAllDay) {
                timeText = '終日';
              } else if (startTime != null && endTime != null) {
                timeText = '${DateFormat.Hm().format(startTime.toDate())} - ${DateFormat.Hm().format(endTime.toDate())}';
              } else {
                timeText = '時刻未設定';
              }

              final dateText = startTime != null
                  ? DateFormat('M月d日').format(startTime.toDate())
                  : '日付未設定';

              return ListTile(
                leading: Text(dateText, style: const TextStyle(fontWeight: FontWeight.bold)),
                title: Text(title),
                subtitle: Text(timeText), // サブタイトルに時間を表示
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () { _showDeleteConfirmDialog(doc.id, title); },
                ),
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