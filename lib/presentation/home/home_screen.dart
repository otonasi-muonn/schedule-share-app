// table_calendarのインポート文は不要です。後ほど説明します。
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart'; // NEW!

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- NEW! カレンダーの状態を管理するための変数を追加 ---
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // (中略: メソッド群は一旦そのまま)
  // ... _addSchedule, _updateSchedule, _showScheduleDialog, etc. ...
  // これらは後でカレンダーと連携させます

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      // --- MODIFIED! bodyをColumnとTableCalendarに変更 ---
      body: Column(
        children: [
          TableCalendar(
            // localeを'ja_JP'にすることで、カレンダーが日本語表示になります
            locale: 'ja_JP',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            // 選択された日を判定するロジック
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            // 日付がタップされたときの処理
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay; // 選択された日にフォーカスも移動
              });
            },
            // カレンダーの見た目をカスタマイズ（任意）
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          // --- ここに、選択された日の予定リストが後で入ります ---
          Expanded(
            child: Center(
              child: Text(
                _selectedDay != null
                    ? '${DateFormat('yyyy年M月d日').format(_selectedDay!)} が選択されています'
                    : '日付を選択してください',
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: カレンダーと連動したダイアログ処理
        },
        tooltip: '予定を追加',
        child: const Icon(Icons.add),
      ),
    );
  }
}