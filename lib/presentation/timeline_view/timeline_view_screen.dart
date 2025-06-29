import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class TimelineViewScreen extends StatefulWidget {
  const TimelineViewScreen({super.key});

  @override
  State<TimelineViewScreen> createState() => _TimelineViewScreenState();
}

class _TimelineViewScreenState extends State<TimelineViewScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('タイムラインビュー'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('schedules')
            .where('userId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('予定はまだありません。'));
          }

          final appointments = snapshot.data!.docs.map((doc) {
            final data = doc.data(); // as Map<String, dynamic>?;

            if (data is Map<String, dynamic> &&
                data['startTime'] is Timestamp &&
                data['endTime'] is Timestamp &&
                data['title'] is String) {
              try {
                return Appointment(
                  startTime: (data['startTime'] as Timestamp).toDate(),
                  endTime: (data['endTime'] as Timestamp).toDate(),
                  subject: data['title'],
                  isAllDay: data['isAllDay'] as bool? ?? false,
                );
              } catch (e) {
                print('ドキュメント変換エラー: ${doc.id}, $e');
                return null;
              }
            }
            return null;
          }).whereType<Appointment>().toList();

          return SfCalendar(
            view: CalendarView.timelineDay,
            dataSource: _ScheduleDataSource(appointments),
            timeSlotViewSettings: const TimeSlotViewSettings(
              timeFormat: 'H:mm',
              startHour: 0,
              endHour: 24,
            ),
          );
        },
      ),
    );
  }
}

class _ScheduleDataSource extends CalendarDataSource {
  _ScheduleDataSource(List<Appointment> source) {
    appointments = source;
  }
}