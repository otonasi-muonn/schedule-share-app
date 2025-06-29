import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class WeekViewScreen extends StatelessWidget {
  const WeekViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('週間ビュー'),
      ),
      body: SfCalendar(
        view: CalendarView.week,
        // TODO: ここに後で、Firestoreのデータを表示する処理を追加します
      ),
    );
  }
}