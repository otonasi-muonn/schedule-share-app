import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
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
  late final LinkedScrollControllerGroup _controllers;
  late final ScrollController _timeRulerController;
  late final ScrollController _scheduleAreaController;

  final double _hourHeight = 80.0;
  final int _totalDays = 365 * 2; // 過去1年、未来1年の約2年分
  late final int _initialDayIndex;
  late final DateTime _startDate;

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _timeRulerController = _controllers.addAndGet();
    _scheduleAreaController = _controllers.addAndGet();

    // 最初に表示する日付が、全日程の中の何番目かを計算
    _initialDayIndex = _totalDays ~/ 2;
    _startDate = DateUtils.dateOnly(widget.initialDate).subtract(Duration(days: _initialDayIndex));

    // 画面が開いたときに、指定された日の位置までスクロールする
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialOffset = _initialDayIndex * _hourHeight * 24;
      _scheduleAreaController.jumpTo(initialOffset);
    });
  }

  @override
  void dispose() {
    _timeRulerController.dispose();
    _scheduleAreaController.dispose();
    super.dispose();
  }

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
          final groupedSchedules = groupBy(allDocs, (QueryDocumentSnapshot doc) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['startTime'] as Timestamp;
            return DateUtils.dateOnly(timestamp.toDate());
          });

          return Row(
            children: [
              _buildTimeRuler(),
              Expanded(child: _buildScheduleArea(groupedSchedules)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final targetOffset = _initialDayIndex * _hourHeight * 24;
          _scheduleAreaController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        },
        tooltip: '指定日に移動',
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }

  Widget _buildTimeRuler() {
    return SizedBox(
      width: 60,
      child: ListView.builder(
        controller: _timeRulerController,
        itemCount: 24 * _totalDays,
        itemExtent: _hourHeight, // パフォーマンス向上のため高さを固定
        itemBuilder: (context, index) {
          final hour = index % 24;
          return Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Center(
              child: hour == 0 ? null : Text('${hour.toString().padLeft(2, '0')}:00'),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildScheduleArea(Map<DateTime, List<QueryDocumentSnapshot>> groupedSchedules) {
    return ListView.builder(
      controller: _scheduleAreaController,
      itemCount: _totalDays,
      itemExtent: _hourHeight * 24, // パフォーマンス向上のため高さを固定
      itemBuilder: (context, dayIndex) {
        final day = _startDate.add(Duration(days: dayIndex));
        final schedulesForDay = groupedSchedules[day] ?? [];

        return Container(
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade200))),
          child: Stack(
            children: [
              // 背景の罫線と日付ヘッダー
              for (int hour = 0; hour < 24; hour++)
                Positioned(
                  top: _hourHeight * hour, left: 0, right: 0,
                  child: Container(height: 1, color: Colors.grey.shade200),
                ),
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    '${day.month}/${day.day} (${DateFormat.E('ja').format(day)})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: DateUtils.isSameDay(day, widget.initialDate) ? Colors.deepPurple : null,
                    ),
                  ),
                ),
              ),
              // 予定ブロック
              ..._buildScheduleBlocksForDay(schedulesForDay),
              // 現在時刻線
              if (DateUtils.isSameDay(day, DateTime.now()))
                _buildCurrentTimeIndicator(),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildScheduleBlocksForDay(List<QueryDocumentSnapshot> docs) {
    // TODO: 次のステップで、予定が重なった場合に横に並べるロジックをここに追加します
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final startTime = (data['startTime'] as Timestamp).toDate();
      final endTime = (data['endTime'] as Timestamp).toDate();
      final isAllDay = data['isAllDay'] as bool? ?? false;

      if (isAllDay) return const SizedBox.shrink();

      final top = _calculateTopOffset(startTime);
      final height = endTime.difference(startTime).inMinutes / 60.0 * _hourHeight;

      return Positioned(
        top: top,
        left: 0,
        right: 10,
        height: height,
        child: Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.only(left: 4),
          color: Colors.blue.withOpacity(0.8),
          child: Text(data['title'], style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      );
    }).toList();
  }

  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final top = _calculateTopOffset(now);
    return Positioned(
      top: top,
      left: -8,
      right: 0,
      child: Row(
        children: [
          Icon(Icons.circle, color: Colors.red[700], size: 12),
          Expanded(child: Container(height: 2, color: Colors.red[700])),
        ],
      ),
    );
  }
}