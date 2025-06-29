import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../week_view/week_view_screen.dart'; // NEW!

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Future<void> _addSchedule({
    required String title,
    required DateTime date,
    required bool isAllDay,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { return; }
    final startDateTime = isAllDay ? DateTime(date.year, date.month, date.day) : DateTime(date.year, date.month, date.day, startTime?.hour ?? TimeOfDay.now().hour, startTime?.minute ?? TimeOfDay.now().minute);
    final endDateTime = isAllDay ? DateTime(date.year, date.month, date.day) : DateTime(date.year, date.month, date.day, endTime?.hour ?? TimeOfDay.now().hour, endTime?.minute ?? TimeOfDay.now().minute);
    try {
      await FirebaseFirestore.instance.collection('schedules').add({
        'title': title, 'userId': user.uid, 'isAllDay': isAllDay, 'startTime': Timestamp.fromDate(startDateTime), 'endTime': Timestamp.fromDate(endDateTime), 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('予定を追加しました。'))); }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e'))); }
    }
  }

  Future<void> _updateSchedule({
    required String docId,
    required String title,
    required DateTime date,
    required bool isAllDay,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) async {
    final startDateTime = isAllDay ? DateTime(date.year, date.month, date.day) : DateTime(date.year, date.month, date.day, startTime!.hour, startTime.minute);
    final endDateTime = isAllDay ? DateTime(date.year, date.month, date.day) : DateTime(date.year, date.month, date.day, endTime!.hour, endTime.minute);
    try {
      await FirebaseFirestore.instance.collection('schedules').doc(docId).update({
        'title': title, 'isAllDay': isAllDay, 'startTime': Timestamp.fromDate(startDateTime), 'endTime': Timestamp.fromDate(endDateTime), 'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('予定を更新しました。'))); }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新中にエラーが発生しました: $e'))); }
    }
  }

  Future<void> _showScheduleDialog({DocumentSnapshot? scheduleDoc}) async {
    final isEditing = scheduleDoc != null;
    Map<String, dynamic>? initialData;
    if (isEditing) { initialData = scheduleDoc.data() as Map<String, dynamic>; }
    
    final titleController = TextEditingController(text: isEditing ? initialData!['title'] : '');
    DateTime selectedDate = isEditing ? (initialData!['startTime'] as Timestamp).toDate() : _selectedDay ?? DateTime.now();
    TimeOfDay? startTime = isEditing && !(initialData!['isAllDay'] as bool) ? TimeOfDay.fromDateTime((initialData['startTime'] as Timestamp).toDate()) : null;
    TimeOfDay? endTime = isEditing && !(initialData!['isAllDay'] as bool) ? TimeOfDay.fromDateTime((initialData['endTime'] as Timestamp).toDate()) : null;
    bool isAllDay = isEditing ? initialData!['isAllDay'] : false;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? '予定の編集' : '予定の追加'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleController, decoration: const InputDecoration(hintText: "タイトルを入力")),
                  const SizedBox(height: 20),
                  Row(children: [ const Text('終日:'), Checkbox(value: isAllDay, onChanged: (value) { setState(() { isAllDay = value ?? false; }); }), ]),
                  Row(children: [ const Text('日付: '), TextButton(child: Text(DateFormat('yyyy年M月d日').format(selectedDate), style: const TextStyle(fontSize: 16)), onPressed: () async { final newDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030)); if (newDate != null) { setState(() { selectedDate = newDate; }); } },), ]),
                  if (!isAllDay)
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ TextButton(child: Text(startTime?.format(context) ?? '開始時刻'), onPressed: () async { final newTime = await showTimePicker(context: context, initialTime: startTime ?? TimeOfDay.now()); if (newTime != null) { setState(() { startTime = newTime; }); } },), const Text('〜'), TextButton(child: Text(endTime?.format(context) ?? '終了時刻'), onPressed: () async { final newTime = await showTimePicker(context: context, initialTime: endTime ?? startTime ?? TimeOfDay.now()); if (newTime != null) { setState(() { endTime = newTime; }); } },), ]),
                ],
              ),
              actions: [
                TextButton(child: const Text('キャンセル'), onPressed: () => Navigator.of(context).pop()),
                ElevatedButton(
                  child: Text(isEditing ? '更新' : '追加'),
                  onPressed: () {
                    final title = titleController.text;
                    if (title.isNotEmpty) {
                      if (isEditing) {
                        _updateSchedule(docId: scheduleDoc.id, title: title, date: selectedDate, isAllDay: isAllDay, startTime: startTime, endTime: endTime);
                      } else {
                        _addSchedule(title: title, date: selectedDate, isAllDay: isAllDay, startTime: startTime, endTime: endTime);
                      }
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

  Future<void> _deleteSchedule(String docId) async { try { await FirebaseFirestore.instance.collection('schedules').doc(docId).delete(); } catch (e) { if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除中にエラーが発生しました: $e'))); } } }
  Future<void> _showDeleteConfirmDialog(String docId, String title) async { return showDialog(context: context, builder: (context) { return AlertDialog(title: const Text('削除の確認'), content: Text('「$title」を本当に削除しますか？\nこの操作は元に戻せません。'), actions: [ TextButton(child: const Text('キャンセル'), onPressed: () => Navigator.of(context).pop()), TextButton(child: const Text('削除', style: TextStyle(color: Colors.red)), onPressed: () { _deleteSchedule(docId); Navigator.of(context).pop(); }), ],); }); }
  Future<void> _logout() async { await FirebaseAuth.instance.signOut(); }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム（月間）'), // タイトルを少し変更
        actions: [
          // --- NEW! 週間ビューに切り替えるボタン ---
          IconButton(
            icon: const Icon(Icons.view_week),
            tooltip: '週間ビュー',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const WeekViewScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: _logout,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('schedules').where('userId', isEqualTo: user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
          if (snapshot.hasError) { return Center(child: Text('エラーが発生しました: ${snapshot.error}')); }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // データがない場合でもカレンダーは表示したいので、空のリストでUIを構築
            return buildCalendarAndList([]);
          }
          // データがある場合は、そのデータでUIを構築
          return buildCalendarAndList(snapshot.data!.docs);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () { _showScheduleDialog(); },
        tooltip: '予定を追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- NEW! カレンダーとリストのUIを構築する部分をメソッドとして分離 ---
  Widget buildCalendarAndList(List<QueryDocumentSnapshot> allDocs) {
    // --- NEW! 予定データをカレンダーが扱える形式に変換 ---
    final Map<DateTime, List<dynamic>> events = {};
    for (var doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final startTime = data['startTime'] as Timestamp?;
      if (startTime != null) {
        final date = DateTime.utc(startTime.toDate().year, startTime.toDate().month, startTime.toDate().day);
        if (events[date] == null) {
          events[date] = [];
        }
        events[date]!.add(data['title']); // マーカー用にイベントを追加
      }
    }

    // 選択された日に合致するドキュメントだけをフィルタリング
    final filteredDocs = allDocs.where((doc) {
      if (_selectedDay == null) { return true; }
      final data = doc.data() as Map<String, dynamic>;
      final startTime = data['startTime'] as Timestamp?;
      if (startTime == null) { return false; }
      return isSameDay(startTime.toDate(), _selectedDay);
    }).toList()
    ..sort((a, b) { // フィルタリング後もstartTimeでソート
      final aTime = (a.data() as Map<String, dynamic>)['startTime'] as Timestamp?;
      final bTime = (b.data() as Map<String, dynamic>)['startTime'] as Timestamp?;
      return aTime?.compareTo(bTime ?? aTime) ?? 0;
    });

    return Column(
      children: [
        TableCalendar(
          locale: 'ja_JP',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          headerStyle: const HeaderStyle(formatButtonVisible: false),
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              if (isSameDay(_selectedDay, selectedDay)) {
                _selectedDay = null;
              } else {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              }
            });
          },
          calendarStyle: const CalendarStyle(todayDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle), selectedDecoration: BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle)),
          // --- NEW! 予定がある日にマーカーを表示するための設定 ---
          eventLoader: (day) {
            return events[DateTime.utc(day.year, day.month, day.day)] ?? [];
          },
        ),
        const SizedBox(height: 8.0),
        Expanded(
          child: filteredDocs.isEmpty 
              ? Center(child: Text(_selectedDay != null ? 'この日の予定はありません。' : '予定はまだありません。'))
              : ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] as String? ?? 'タイトルなし';
              final isAllDay = data['isAllDay'] as bool? ?? false;
              final startTime = data['startTime'] as Timestamp?;
              final endTime = data['endTime'] as Timestamp?;

              String timeText;
              if (isAllDay) { timeText = '終日'; } 
              else if (startTime != null && endTime != null) { timeText = '${DateFormat.Hm().format(startTime.toDate())} - ${DateFormat.Hm().format(endTime.toDate())}'; } 
              else { timeText = '時刻未設定'; }

              final dateText = startTime != null ? DateFormat('M月d日').format(startTime.toDate()) : '日付未設定';

              return ListTile(
                leading: Text(dateText, style: const TextStyle(fontWeight: FontWeight.bold)),
                title: Text(title),
                subtitle: Text(timeText),
                onTap: () { _showScheduleDialog(scheduleDoc: doc); },
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { _showDeleteConfirmDialog(doc.id, title); }),
              );
            },
          ),
        ),
      ],
    );
  }
}