import 'dart:async'; // Timerを使うためにインポート
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class TimelineViewScreen extends StatefulWidget {
  final DateTime initialDate;

  const TimelineViewScreen({
    super.key,
    required this.initialDate,
  });

  @override
  State<TimelineViewScreen> createState() => _TimelineViewScreenState();
}

class _TimelineViewScreenState extends State<TimelineViewScreen> {
  final ScrollController _scrollController = ScrollController();
  final double _hourHeight = 80.0;
  final int _totalDays = 365; // 表示する合計日数（約1年分）
  late final DateTime _startDate;
  late final int _initialDayIndex;

  @override
  void initState() {
    super.initState();
    _initialDayIndex = _totalDays ~/ 2;
    _startDate = DateUtils.dateOnly(widget.initialDate).subtract(Duration(days: _initialDayIndex));

    // --- MODIFIED! タイミング問題を解決するため、Timerで少し遅らせて実行 ---
    Timer(const Duration(milliseconds: 1), () {
      if (mounted) {
        final initialOffset = _initialDayIndex * _hourHeight * 24;
        _scrollController.jumpTo(initialOffset);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 時刻から、その日の0時を基準としたY座標オフセットを計算する
  double _calculateTopOffset(DateTime time) {
    return time.hour * _hourHeight + time.minute / 60.0 * _hourHeight;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('タイムライン'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('schedules')
            .where('userId', isEqualTo: user?.uid)
            .where('startTime', isGreaterThanOrEqualTo: _startDate)
            .where('startTime', isLessThan: _startDate.add(Duration(days: _totalDays)))
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }

          final allDocs = snapshot.data?.docs ?? [];
          
          // --- MODIFIED! タイムライン全体をStackで構築し、その上に予定ブロックを描画する ---
          return Stack(
            children: [
              // 背景グリッドと時間軸
              _buildBackgroundGrid(),
              // 予定ブロック
              ..._buildAllScheduleBlocks(allDocs),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final targetOffset = _initialDayIndex * _hourHeight * 24;
          _scrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
        },
        tooltip: '指定日に移動',
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }

  // --- MODIFIED! 1つのListViewで時間軸と背景グリッドを描画する方式に変更 ---
  Widget _buildBackgroundGrid() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _totalDays * 24, // 1時間ごとに1アイテム
      itemExtent: _hourHeight,
      itemBuilder: (context, index) {
        final dayIndex = index ~/ 24;
        final hour = index % 24;
        final day = _startDate.add(Duration(days: dayIndex));

        return Row(
          children: [
            // 左側の時間軸
            SizedBox(
              width: 60,
              height: _hourHeight,
              child: Center(
                // 0時の場合は日付を表示
                child: hour == 0
                    ? Text('${day.month}/${day.day}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
                    : Text('${hour.toString().padLeft(2, '0')}:00'),
              ),
            ),
            // 右側の罫線
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200), left: BorderSide(color: Colors.grey.shade300))),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // --- MODIFIED! 日またぎを考慮して、すべての予定ブロックを一度に生成する ---
  List<Widget> _buildAllScheduleBlocks(List<QueryDocumentSnapshot> allDocs) {
    final scheduleAreaWidth = MediaQuery.of(context).size.width - 60;
    
    // 日付ごとに予定をグループ化
    final groupedSchedules = groupBy(allDocs, (QueryDocumentSnapshot doc) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['startTime'] as Timestamp;
      return DateUtils.dateOnly(timestamp.toDate());
    });

    final List<Widget> positionedEvents = [];
    groupedSchedules.forEach((day, docs) {
      // --- 重なり計算ロジック (以前と同じ) ---
      final events = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return { 'doc': doc, 'start': (data['startTime'] as Timestamp).toDate(), 'end': (data['endTime'] as Timestamp).toDate() };
      }).toList()..sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));

      final List<List<Map<String, dynamic>>> columns = [];
      for (final event in events) {
        bool placed = false;
        for (final col in columns) {
          if (!(col.last['end'] as DateTime).isAfter(event['start'] as DateTime)) {
            col.add(event);
            placed = true;
            break;
          }
        }
        if (!placed) { columns.add([event]); }
      }
      
      final columnWidth = scheduleAreaWidth / columns.length;
      for (int i = 0; i < columns.length; i++) {
        final col = columns[i];
        for (final event in col) {
          final data = event['doc'].data() as Map<String, dynamic>;
          if (data['isAllDay'] as bool? ?? false) continue; // 終日はタイムラインに表示しない

          final startDateTime = event['start'] as DateTime;
          final endDateTime = event['end'] as DateTime;
          
          final dayIndex = DateUtils.dateOnly(startDateTime).difference(_startDate).inDays;
          final top = (dayIndex * _hourHeight * 24) + _calculateTopOffset(startDateTime);
          final height = endDateTime.difference(startDateTime).inMinutes / 60.0 * _hourHeight;
          final left = 60 + (i * columnWidth);

          positionedEvents.add(
            Positioned(
              top: top, left: left, width: columnWidth, height: height,
              child: Container(
                padding: const EdgeInsets.all(4), margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: Colors.blue.withAlpha(200), borderRadius: BorderRadius.circular(4)),
                child: Text(data['title'], style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
              ),
            ),
          );
        }
      }
    });

    // 現在時刻の線は、他のすべての要素より手前に表示するために最後に追加
    final now = DateTime.now();
    final dayIndex = DateUtils.dateOnly(now).difference(_startDate).inDays;
    if (dayIndex >= 0 && dayIndex < _totalDays) {
      final top = (dayIndex * _hourHeight * 24) + _calculateTopOffset(now);
      positionedEvents.add(
        Positioned(
          top: top - 1, left: 60 - 8, right: 0,
          child: Row(
            children: [
              Icon(Icons.circle, color: Colors.red[700], size: 12),
              Expanded(child: Container(height: 2, color: Colors.red[700])),
            ],
          ),
        ),
      );
    }
    
    return positionedEvents;
  }
}