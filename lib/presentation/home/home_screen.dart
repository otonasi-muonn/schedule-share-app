import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:schedule_share_app/presentation/timeline_view/timeline_view_screen.dart';
import 'package:schedule_share_app/presentation/widgets/schedule_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  Future<void> _deleteSchedule(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('schedules').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('予定を削除しました。')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除中にエラーが発生しました: $e')));
      }
    }
  }

  Future<void> _showDeleteConfirmDialog(String docId, String title) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('削除の確認'),
            content: Text('「$title」を本当に削除しますか？\nこの操作は元に戻せません。'),
            actions: [
              TextButton(child: const Text('キャンセル'), onPressed: () => Navigator.of(context).pop()),
              TextButton(child: const Text('削除', style: TextStyle(color: Colors.red)), onPressed: () {
                _deleteSchedule(docId);
                Navigator.of(context).pop();
              }),
            ],
          );
        });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('ホーム（月間）'), actions: [
        IconButton(icon: const Icon(Icons.timeline), tooltip: 'タイムラインビュー', onPressed: () { Navigator.of(context).push(MaterialPageRoute(builder: (context) => TimelineViewScreen(initialDate: _selectedDay ?? DateTime.now()))); }),
        IconButton(icon: const Icon(Icons.logout), tooltip: 'ログアウト', onPressed: _logout)
      ]),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('schedules').where('userId', isEqualTo: user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
          if (snapshot.hasError) { return Center(child: Text('エラーが発生しました: ${snapshot.error}')); }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { return buildCalendarAndList([]); }
          return buildCalendarAndList(snapshot.data!.docs);
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () { showScheduleDialog(context, initialDate: _selectedDay); }, tooltip: '予定を追加', child: const Icon(Icons.add)),
    );
  }

  Widget buildCalendarAndList(List<QueryDocumentSnapshot> allDocs) {
    final events = <DateTime, List<dynamic>>{};
    for (final doc in allDocs) {
      final data = doc.data();
      if (data is Map<String, dynamic>) {
        final startTime = data['startTime'] as Timestamp?;
        if (startTime != null) {
          final date = DateTime.utc(startTime.toDate().year, startTime.toDate().month, startTime.toDate().day);
          events.putIfAbsent(date, () => []).add(data['title'] ?? '');
        }
      }
    }

    final filteredDocs = allDocs.where((doc) {
      if (_selectedDay == null) { return true; }
      final data = doc.data();
      if (data is Map<String, dynamic>) {
        final startTime = data['startTime'] as Timestamp?;
        return startTime != null && isSameDay(startTime.toDate(), _selectedDay);
      }
      return false;
    }).toList()
      ..sort((a, b) {
        final aData = a.data() as Map<String, dynamic>; final bData = b.data() as Map<String, dynamic>;
        final aTime = aData['startTime'] as Timestamp?; final bTime = bData['startTime'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });

    return Column(children: [
      TableCalendar(
        locale: 'ja_JP', firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        headerStyle: const HeaderStyle(formatButtonVisible: false),
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            if (isSameDay(_selectedDay, selectedDay)) { _selectedDay = null; } 
            else { _selectedDay = selectedDay; _focusedDay = focusedDay; }
          });
        },
        calendarStyle: const CalendarStyle(todayDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle), selectedDecoration: BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle)),
        eventLoader: (day) { return events[DateTime.utc(day.year, day.month, day.day)] ?? []; },
      ),
      const SizedBox(height: 8.0),
      Expanded(
        child: filteredDocs.isEmpty 
            ? Center(child: Text(_selectedDay != null ? 'この日の予定はありません。' : 'すべての予定'))
            : ListView.builder(
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index]; final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] as String? ?? 'タイトルなし';
            final isAllDay = data['isAllDay'] as bool? ?? false;
            final startTime = data['startTime'] as Timestamp?; final endTime = data['endTime'] as Timestamp?;
            String timeText;
            if (isAllDay) { timeText = '終日'; } 
            else if (startTime != null && endTime != null) {
              if (!isSameDay(startTime.toDate(), endTime.toDate())) { timeText = '${DateFormat.Hm().format(startTime.toDate())} - ${DateFormat('M/d H:mm').format(endTime.toDate())}'; } 
              else { timeText = '${DateFormat.Hm().format(startTime.toDate())} - ${DateFormat.Hm().format(endTime.toDate())}'; }
            } else { timeText = '時刻未設定'; }
            final dateText = startTime != null ? DateFormat('M月d日').format(startTime.toDate()) : '日付未設定';
            return ListTile(
              leading: Text(dateText, style: const TextStyle(fontWeight: FontWeight.bold)),
              title: Text(title),
              subtitle: Text(timeText),
              onTap: () { showScheduleDialog(context, scheduleDoc: doc); },
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { _showDeleteConfirmDialog(doc.id, title); }),
            );
          },
        ),
      ),
    ]);
  }
}