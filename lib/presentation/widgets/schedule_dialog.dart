import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// どの画面からでも呼び出せる、予定の追加・編集ダイアログ
Future<void> showScheduleDialog(BuildContext context, {DocumentSnapshot? scheduleDoc, DateTime? initialDate}) async {
  final isEditing = scheduleDoc != null;
  final initialData = isEditing ? scheduleDoc.data() as Map<String, dynamic> : null;

  final titleController = TextEditingController(text: initialData?['title'] as String? ?? '');
  final initialStartTimeStamp = initialData?['startTime'] as Timestamp?;
  final initialEndTimeStamp = initialData?['endTime'] as Timestamp?;
  
  // 開始日時と終了日時を分けて管理
  DateTime selectedStartDate = initialStartTimeStamp?.toDate() ?? initialDate ?? DateTime.now();
  DateTime selectedEndDate = initialEndTimeStamp?.toDate() ?? initialDate ?? DateTime.now();
  
  bool isAllDay = initialData?['isAllDay'] as bool? ?? false;
  
  TimeOfDay? startTime;
  if (!isAllDay && initialStartTimeStamp != null) { 
    startTime = TimeOfDay.fromDateTime(initialStartTimeStamp.toDate()); 
  }
  
  TimeOfDay? endTime;
  if (!isAllDay && initialEndTimeStamp != null) { 
    endTime = TimeOfDay.fromDateTime(initialEndTimeStamp.toDate()); 
  }
  
  String? titleErrorText;

  return showDialog(context: context, builder: (context) {
    return StatefulBuilder(builder: (context, setState) {
      return AlertDialog(
        title: Text(isEditing ? '予定の編集' : '予定の追加'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: InputDecoration(hintText: "タイトルを入力", errorText: titleErrorText)),
              const SizedBox(height: 20),
              Row(children: [ 
                const Text('終日:'), 
                Checkbox(value: isAllDay, onChanged: (value) { 
                  setState(() { 
                    isAllDay = value ?? false; 
                    if (isAllDay) {
                      // 終日にする場合は終了日を開始日と同じにする
                      selectedEndDate = selectedStartDate;
                    }
                  }); 
                }), 
              ]),
              // 開始日時
              Row(children: [ 
                const Text('開始: '), 
                TextButton(
                  child: Text(DateFormat('yyyy年M月d日').format(selectedStartDate), style: const TextStyle(fontSize: 16)), 
                  onPressed: () async { 
                    final newDate = await showDatePicker(
                      context: context, 
                      initialDate: selectedStartDate, 
                      firstDate: DateTime(2020), 
                      lastDate: DateTime(2030)
                    ); 
                    if (newDate != null) { 
                      setState(() { 
                        selectedStartDate = newDate; 
                        // 終了日が開始日より前の場合は同じ日に設定
                        if (selectedEndDate.isBefore(selectedStartDate)) {
                          selectedEndDate = selectedStartDate;
                        }
                      }); 
                    } 
                  },
                ), 
              ]),
              if (!isAllDay)
                Row(children: [
                  const Text('開始時刻: '),
                  TextButton(
                    child: Text(startTime?.format(context) ?? '未設定'), 
                    onPressed: () async { 
                      final newTime = await showTimePicker(
                        context: context, 
                        initialTime: startTime ?? TimeOfDay.now()
                      ); 
                      if (newTime != null) { 
                        setState(() { 
                          startTime = newTime; 
                        }); 
                      } 
                    },
                  ),
                ]),
              // 終了日時
              if (!isAllDay) ...[
                Row(children: [ 
                  const Text('終了: '), 
                  TextButton(
                    child: Text(DateFormat('yyyy年M月d日').format(selectedEndDate), style: const TextStyle(fontSize: 16)), 
                    onPressed: () async { 
                      final newDate = await showDatePicker(
                        context: context, 
                        initialDate: selectedEndDate, 
                        firstDate: selectedStartDate, // 開始日以降のみ選択可能
                        lastDate: DateTime(2030)
                      ); 
                      if (newDate != null) { 
                        setState(() { 
                          selectedEndDate = newDate; 
                        }); 
                      } 
                    },
                  ), 
                ]),
                Row(children: [
                  const Text('終了時刻: '),
                  TextButton(
                    child: Text(endTime?.format(context) ?? '未設定'), 
                    onPressed: () async { 
                      final newTime = await showTimePicker(
                        context: context, 
                        initialTime: endTime ?? startTime ?? TimeOfDay.now()
                      ); 
                      if (newTime != null) { 
                        setState(() { 
                          endTime = newTime; 
                        }); 
                      } 
                    },
                  ),
                ]),
              ],
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
                setState(() { titleErrorText = 'タイトルを入力してください'; });
                return;
              }
              if (isEditing) {
                _updateSchedule(
                  docId: scheduleDoc.id, 
                  title: title, 
                  startDate: selectedStartDate,
                  endDate: selectedEndDate,
                  isAllDay: isAllDay, 
                  startTime: startTime, 
                  endTime: endTime
                )
                    .then((_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('予定を更新しました。'))))
                    .catchError((e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新中にエラーが発生しました: $e'))));
              } else {
                _addSchedule(
                  title: title, 
                  startDate: selectedStartDate,
                  endDate: selectedEndDate,
                  isAllDay: isAllDay, 
                  startTime: startTime, 
                  endTime: endTime
                )
                    .then((_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('予定を追加しました。'))))
                    .catchError((e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e'))));
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    });
  });
}

Future<void> _addSchedule({ 
  required String title, 
  required DateTime startDate,
  required DateTime endDate,
  required bool isAllDay, 
  TimeOfDay? startTime, 
  TimeOfDay? endTime,
}) async {
  final user = FirebaseAuth.instance.currentUser; 
  if (user == null) { return; }
  
  DateTime startDateTime, endDateTime;
  
  if (isAllDay) { 
    startDateTime = DateTime(startDate.year, startDate.month, startDate.day); 
    endDateTime = DateTime(startDate.year, startDate.month, startDate.day, 23, 59, 59); 
  } else {
    final effectiveStartTime = startTime ?? TimeOfDay.now();
    final effectiveEndTime = endTime ?? effectiveStartTime;
    
    startDateTime = DateTime(startDate.year, startDate.month, startDate.day, effectiveStartTime.hour, effectiveStartTime.minute);
    endDateTime = DateTime(endDate.year, endDate.month, endDate.day, effectiveEndTime.hour, effectiveEndTime.minute);
    
    // 終了時刻が開始時刻より前の場合の調整は不要（日付で管理するため）
  }
  
  await FirebaseFirestore.instance.collection('schedules').add({
    'title': title, 
    'userId': user.uid, 
    'isAllDay': isAllDay, 
    'startTime': Timestamp.fromDate(startDateTime), 
    'endTime': Timestamp.fromDate(endDateTime), 
    'createdAt': FieldValue.serverTimestamp(), 
    'updatedAt': FieldValue.serverTimestamp()
  });
}

Future<void> _updateSchedule({ 
  required String docId, 
  required String title, 
  required DateTime startDate,
  required DateTime endDate,
  required bool isAllDay, 
  TimeOfDay? startTime, 
  TimeOfDay? endTime, 
}) async {
  DateTime startDateTime, endDateTime;
  
  if (isAllDay) { 
    startDateTime = DateTime(startDate.year, startDate.month, startDate.day); 
    endDateTime = DateTime(startDate.year, startDate.month, startDate.day, 23, 59, 59); 
  } else {
    final effectiveStartTime = startTime ?? TimeOfDay.now();
    final effectiveEndTime = endTime ?? effectiveStartTime;
    
    startDateTime = DateTime(startDate.year, startDate.month, startDate.day, effectiveStartTime.hour, effectiveStartTime.minute);
    endDateTime = DateTime(endDate.year, endDate.month, endDate.day, effectiveEndTime.hour, effectiveEndTime.minute);
    
    // 終了時刻が開始時刻より前の場合の調整は不要（日付で管理するため）
  }
  
  await FirebaseFirestore.instance.collection('schedules').doc(docId).update({
    'title': title, 
    'isAllDay': isAllDay, 
    'startTime': Timestamp.fromDate(startDateTime), 
    'endTime': Timestamp.fromDate(endDateTime), 
    'updatedAt': FieldValue.serverTimestamp()
  });
}