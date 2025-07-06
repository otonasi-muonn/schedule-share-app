import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> showScheduleDialog(
  BuildContext context, {
  DocumentSnapshot? scheduleDoc,
  DateTime? initialDate,
}) async {
  final isEditing = scheduleDoc != null;
  final initialData = isEditing ? scheduleDoc.data() as Map<String, dynamic> : null;

  final titleController = TextEditingController(text: initialData?['title'] as String? ?? '');
  final initialStartTimeStamp = initialData?['startTime'] as Timestamp?;
  DateTime selectedDate = initialStartTimeStamp?.toDate() ?? initialDate ?? DateTime.now();
  bool isAllDay = initialData?['isAllDay'] as bool? ?? false;
  
  TimeOfDay? startTime;
  if (!isAllDay && initialStartTimeStamp != null) {
    startTime = TimeOfDay.fromDateTime(initialStartTimeStamp.toDate());
  }
  
  TimeOfDay? endTime;
  final initialEndTimeStamp = initialData?['endTime'] as Timestamp?;
  if (!isAllDay && initialEndTimeStamp != null) {
    endTime = TimeOfDay.fromDateTime(initialEndTimeStamp.toDate());
  }
  
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
                    decoration: InputDecoration(
                      hintText: "タイトルを入力",
                      errorText: titleErrorText,
                    ),
                    onChanged: (value) {
                      if (titleErrorText != null && value.isNotEmpty) {
                        setState(() {
                          titleErrorText = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('終日:'),
                      Checkbox(
                        value: isAllDay,
                        onChanged: (value) {
                          setState(() {
                            isAllDay = value ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('日付: '),
                      TextButton(
                        child: Text(
                          DateFormat('yyyy年M月d日').format(selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                        onPressed: () async {
                          final newDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (newDate != null) {
                            setState(() {
                              selectedDate = newDate;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (!isAllDay)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          child: Text(startTime?.format(context) ?? '開始時刻'),
                          onPressed: () async {
                            final newTime = await showTimePicker(
                              context: context,
                              initialTime: startTime ?? TimeOfDay.now(),
                            );
                            if (newTime != null) {
                              setState(() {
                                startTime = newTime;
                              });
                            }
                          },
                        ),
                        const Text('〜'),
                        TextButton(
                          child: Text(endTime?.format(context) ?? '終了時刻'),
                          onPressed: () async {
                            final newTime = await showTimePicker(
                              context: context,
                              initialTime: endTime ?? startTime ?? TimeOfDay.now(),
                            );
                            if (newTime != null) {
                              setState(() {
                                endTime = newTime;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('キャンセル'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              ElevatedButton(
                child: Text(isEditing ? '更新' : '追加'),
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    setState(() {
                      titleErrorText = 'タイトルを入力してください';
                    });
                    return;
                  }
                  
                  // 終日でない場合の時刻検証
                  if (!isAllDay && startTime != null && endTime != null) {
                    final startDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      startTime!.hour,
                      startTime!.minute,
                    );
                    final endDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      endTime!.hour,
                      endTime!.minute,
                    );
                    
                    // 同じ日で開始時刻が終了時刻より後の場合は終了時刻を