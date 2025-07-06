import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> showScheduleDialog(BuildContext context, {DocumentSnapshot? scheduleDoc, DateTime? initialDate}) async {
  final isEditing = scheduleDoc != null;
  final initialData = isEditing ? scheduleDoc!.data() as Map<String, dynamic> : null;

  final titleController = TextEditingController(text: initialData?['title'] as String? ?? '');
  final initialStartTimeStamp = initialData?['startTime'] as Timestamp?;
  DateTime selectedDate = initialStartTimeStamp?.toDate() ?? initialDate ?? DateTime.now();
  bool isAllDay = initialData?['isAllDay'] as bool? ?? false;
  
  TimeOfDay? startTime;
  if (!isAllDay && initialStartTimeStamp != null) { startTime = TimeOfDay.fromDateTime(initialStartTimeStamp.toDate()); }
  TimeOfDay? endTime;
  final initialEndTimeStamp = initialData?['endTime'] as Timestamp?;
  if (!isAllDay && initialEndTimeStamp != null) { endTime = TimeOfDay.fromDateTime(initialEndTimeStamp.toDate()); }
  
  String? titleErrorText;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEditing ? '予定の編集' : '予定の追加'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(hintText: "タイトルを入力", errorText: titleErrorText),
                    onChanged: (value) { if (titleErrorText != null && value.isNotEmpty) { setState(() { titleErrorText = null; }); } },
                  ),
                  const SizedBox(height: 20),
                  Row(children: [ const Text('終日:'), Checkbox(value: isAllDay, onChanged: (value) { setState(() { isAllDay = value ?? false; }); }) ]),
                  Row(children: [ const Text('日付: '), TextButton(child: Text(DateFormat('yyyy年M月d日').format(selectedDate), style: const TextStyle(fontSize: 16)), onPressed: () async { final newDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030)); if (newDate != null) { setState(() { selectedDate = newDate; }); } }) ]),
                  if (!isAllDay)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(child: Text(startTime?.format(context) ?? '開始時刻'), onPressed: () async { final newTime = await showTimePicker(context: context, initialTime: startTime ?? TimeOfDay.now()); if (newTime != null) { setState(() { startTime = newTime; }); } }),
                        const Text('〜'),
                        TextButton(child: Text(endTime?.format(context) ?? '終了時刻'), onPressed: () async { final newTime = await showTimePicker(context: context, initialTime: endTime ?? startTime ?? TimeOfDay.now()); if (newTime != null) { setState(() { endTime = newTime; }); } }),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(child: const Text('キャンセル'), onPressed: () => Navigator.of(dialogContext).pop()),
              ElevatedButton(
                child: Text(isEditing ? '更新' : '追加'),
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    setState(() { titleErrorText = 'タイトルを入力してください'; });
                    return;
                  }
                  
                  try {
                    if (isEditing) {
                      await _updateSchedule(docId: scheduleDoc!.id, title: title, date: selectedDate, isAllDay: isAllDay, startTime: startTime, endTime: endTime);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('予定を更新しました。')));
                    } else {
                      await _addSchedule(title: title, date: selectedDate, isAllDay: isAllDay, startTime: startTime, endTime: endTime);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('予定を追加しました。')));
                    }
                    if(dialogContext.mounted) Navigator.of(dialogContext).pop();
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _addSchedule({ required String title, required DateTime date, required bool isAllDay, TimeOfDay? startTime, TimeOfDay? endTime,}) async {
  final user = FirebaseAuth.instance.currentUser; if (user == null) { return; }
  final effectiveStartTime = startTime ?? TimeOfDay.now();
  final effectiveEndTime = endTime ?? effectiveStartTime;
  var startDateTime = DateTime(date.year, date.month, date.day, effectiveStartTime.hour, effectiveStartTime.minute);
  var endDateTime = DateTime(date.year, date.month, date.day, effectiveEndTime.hour, effectiveEndTime.minute);
  if (!isAllDay && endDateTime.isBefore(startDateTime)) { endDateTime = endDateTime.add(const Duration(days: 1)); }
  if (isAllDay) { startDateTime = DateTime(date.year, date.month, date.day); endDateTime = DateTime(date.year, date.month, date.day, 23, 59); }
  await FirebaseFirestore.instance.collection('schedules').add({'title': title, 'userId': user.uid, 'isAllDay': isAllDay, 'startTime': Timestamp.fromDate(startDateTime), 'endTime': Timestamp.fromDate(endDateTime), 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
}

Future<void> _updateSchedule({ required String docId, required String title, required DateTime date, required bool isAllDay, TimeOfDay? startTime, TimeOfDay? endTime, }) async {
  final effectiveStartTime = startTime ?? TimeOfDay.now();
  final effectiveEndTime = endTime ?? effectiveStartTime;
  var startDateTime = DateTime(date.year, date.month, date.day, effectiveStartTime.hour, effectiveStartTime.minute);
  var endDateTime = DateTime(date.year, date.month, date.day, effectiveEndTime.hour, effectiveEndTime.minute);
  if (!isAllDay && endDateTime.isBefore(startDateTime)) { endDateTime = endDateTime.add(const Duration(days: 1)); }
  if (isAllDay) { startDateTime = DateTime(date.year, date.month, date.day); endDateTime = DateTime(date.year, date.month, date.day, 23, 59); }
  await FirebaseFirestore.instance.collection('schedules').doc(docId).update({'title': title, 'isAllDay': isAllDay, 'startTime': Timestamp.fromDate(startDateTime), 'endTime': Timestamp.fromDate(endDateTime), 'updatedAt': FieldValue.serverTimestamp()});
}