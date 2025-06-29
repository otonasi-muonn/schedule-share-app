import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:schedule_share_app/presentation/timeline_view/timeline_view_screen.dart';

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

  Future<void> _showScheduleDialog({DocumentSnapshot? scheduleDoc}) async {
    final isEditing = scheduleDoc != null;
    final initialData = isEditing ? scheduleDoc!.data() as Map<String, dynamic> : null;
    final titleController = TextEditingController(text: initialData?['title'] as String? ?? '');
    final initialStartTimeStamp = initialData?['startTime'] as Timestamp?;
    DateTime selectedDate = initialStartTimeStamp?.toDate() ?? _selectedDay ?? DateTime.now();
    bool isAllDay = initialData?['isAllDay'] as bool? ?? false;
    TimeOfDay? startTime;
    if (!isAllDay && initialStartTimeStamp != null) { startTime = TimeOfDay.fromDateTime(initialStartTimeStamp.toDate()); }
    TimeOfDay? endTime;
    final initialEndTimeStamp = initialData?['endTime'] as Timestamp?;
    if (!isAllDay && initialEndTimeStamp != null) { endTime = TimeOfDay.fromDateTime(initialEndTimeStamp.toDate()); }
    
    String? titleErrorText;

    return showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: Text(isEditing ? '予定の編集' : '予定の追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: "タイトルを入力",
                    errorText: titleErrorText,
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [ const Text('終日:'), Checkbox(value: isAllDay, onChanged: (value) { setState(() { isAllDay = value ?? false; }); }), ]),
                Row(children: [ const Text('日付: '), TextButton(child: Text(DateFormat('yyyy年M月d日').format(selectedDate), style: const TextStyle(fontSize: 16)), onPressed: () async { final newDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030)); if (newDate != null) { setState(() { selectedDate = newDate; }); } },), ]),
                if (!isAllDay)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ TextButton(child: Text(startTime?.format(context) ?? '開始時刻'), onPressed: () async { final newTime = await showTimePicker(context: context, initialTime: startTime ?? TimeOfDay.now()); if (newTime != null) { setState(() { startTime = newTime; }); } },), const Text('〜'), TextButton(child: Text(endTime?.format(context) ?? '終了時刻'), onPressed: () async { final newTime = await showTimePicker(context: context, initialTime: endTime ?? startTime ?? TimeOfDay.now()); if (newTime != null) { setState(() { endTime = newTime; }); } },), ]),
              ],
            ),
          ),
          actions: [
            TextButton(child: const Text('キャンセル'), onPressed: () => Navigator.of(context).pop()),
            ElevatedButton(
              child: Text(isEditing ? '更新' : '追加'),
              onPressed: () {
                final title = titleController.text;
                if (title.isEmpty) {
                  setState(() {
                    titleErrorText = 'タイトルを入力してください';
                  });
                  return;
                }
                
                if (isEditing) {
                  _updateSchedule(docId: scheduleDoc!.id, title: title, date: selectedDate, isAllDay: isAllDay, startTime: startTime, endTime: endTime);
                } else {
                  _addSchedule(title: title, date: selectedDate, isAllDay: isAllDay, startTime: startTime, endTime: endTime);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      });
    });
  }

  Future<void> _addSchedule({ required String title, required DateTime date, required bool isAllDay, TimeOfDay? startTime, TimeOfDay? endTime,}) async {
    final user = FirebaseAuth.instance.currentUser; if (user == null) { return; }
    final effectiveStartTime = startTime ?? TimeOfDay.now();
    final effectiveEndTime = endTime ?? effectiveStartTime;
    var startDateTime = DateTime(date.year, date.month, date.day, effectiveStartTime.hour, effectiveStartTime.minute);
    var endDateTime = DateTime(date.year, date.month, date.day, effectiveEndTime.hour, effectiveEndTime.minute);
    if (!isAllDay && endDateTime.isBefore(startDateTime)) { endDateTime = endDateTime.add(const Duration(days: 1)); }
    if (isAllDay) { startDateTime = DateTime(date.year, date.month, date.day); endDateTime = DateTime(date.year, date.month, date.day); }
    try {
      await FirebaseFirestore.instance.collection('schedules').add({'title': title, 'userId': user.uid, 'isAllDay': isAllDay, 'startTime': Timestamp.fromDate(startDateTime), 'endTime': Timestamp.fromDate(endDateTime), 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),});
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('予定を追加しました。'))); }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e'))); }
    }
  }

  Future<void> _updateSchedule({ required String docId, required String title, required DateTime date, required bool isAllDay, TimeOfDay? startTime, TimeOfDay? endTime, }) async {
    final effectiveStartTime = startTime ?? TimeOfDay.now();
    final effectiveEndTime = endTime ?? effectiveStartTime;
    var startDateTime = DateTime(date.year, date.month, date.day, effectiveStartTime.hour, effectiveStartTime.minute);
    var endDateTime = DateTime(date.year, date.month, date.day, effectiveEndTime.hour, effectiveEndTime.minute);
    if (!isAllDay && endDateTime.isBefore(startDateTime)) { endDateTime = endDateTime.add(const Duration(days: 1)); }
    if (isAllDay) { startDateTime = DateTime(date.year, date.month, date.day); endDateTime = DateTime(date.year, date.month, date.day); }
    try {
      await FirebaseFirestore.instance.collection('schedules').doc(docId).update({'title': title, 'isAllDay': isAllDay, 'startTime': Timestamp.fromDate(startDateTime), 'endTime': Timestamp.fromDate(endDateTime), 'updatedAt': FieldValue.serverTimestamp(),});
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('予定を更新しました。'))); }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新中にエラーが発生しました: $e'))); }
    }
  }

  Future<void> _deleteSchedule(String docId) async { try { await FirebaseFirestore.instance.collection('schedules').doc(docId).delete(); } catch (e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除中にエラーが発生しました: $e'))); } } }
  Future<void> _showDeleteConfirmDialog(String docId, String title) async { return showDialog(context: context, builder: (context) { return AlertDialog(title: const Text('削除の確認'), content: Text('「$title」を本当に削除しますか？\nこの操作は元に戻せません。'), actions: [ TextButton(child: const Text('キャンセル'), onPressed: () => Navigator.of(context).pop()), TextButton(child: const Text('削除', style: TextStyle(color: Colors.red)), onPressed: () { _deleteSchedule(docId); Navigator.of(context).pop(); }), ],); }); }
  Future<void> _logout() async { await FirebaseAuth.instance.signOut(); }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('ホーム（月間）'), actions: [ IconButton(icon: const Icon(Icons.timeline), tooltip: 'タイムラインビュー', onPressed: () { Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TimelineViewScreen())); }), IconButton(icon: const Icon(Icons.logout), tooltip: 'ログアウト', onPressed: _logout) ]),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('schedules').where('userId', isEqualTo: user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
          if (snapshot.hasError) { return Center(child: Text('エラーが発生しました: ${snapshot.error}')); }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { return buildCalendarAndList([]); }
          return buildCalendarAndList(snapshot.data!.docs);
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () { _showScheduleDialog(); }, tooltip: '予定を追加', child: const Icon(Icons.add)),
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
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aTime = aData['startTime'] as Timestamp?;
        final bTime = bData['startTime'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
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
          eventLoader: (day) { return events[DateTime.utc(day.year, day.month, day.day)] ?? []; },
        ),
        const SizedBox(height: 8.0),
        Expanded(
          child: filteredDocs.isEmpty 
              ? Center(child: Text(_selectedDay != null ? 'この日の予定はありません。' : 'すべての予定'))
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
              else if (startTime != null && endTime != null) {
                if (!isSameDay(startTime.toDate(), endTime.toDate())) {
                  timeText = '${DateFormat.Hm().format(startTime.toDate())} - ${DateFormat('M/d H:mm').format(endTime.toDate())}';
                } else {
                  timeText = '${DateFormat.Hm().format(startTime.toDate())} - ${DateFormat.Hm().format(endTime.toDate())}';
                }
              } 
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