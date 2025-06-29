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
  final int _totalDays = 365 * 2;
  late final int _initialDayIndex;
  late final DateTime _startDate;

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _timeRulerController = _controllers.addAndGet();
    _scheduleAreaController = _controllers.addAndGet();

    _initialDayIndex = _totalDays ~/ 2;
    _startDate = DateUtils.dateOnly(widget.initialDate).subtract(Duration(days: _initialDayIndex));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final initialOffset = _initialDayIndex * _hourHeight * 24;
        _scheduleAreaController.jumpTo(initialOffset);
      }
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
        itemExtent: _hourHeight,
        itemBuilder: (context, index) {
          final hour = index % 24;
          return Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200), right: BorderSide(color: Colors.grey.shade300))),
            child: Center(child: hour == 0 ? null : Text('${hour.toString().padLeft(2, '0')}:00')),
          );
        },
      ),
    );
  }

  Widget _buildScheduleArea(Map<DateTime, List<QueryDocumentSnapshot>> groupedSchedules) {
    final availableWidth = MediaQuery.of(context).size.width - 60;

    return ListView.builder(
      controller: _scheduleAreaController,
      itemCount: _totalDays,
      itemExtent: _hourHeight * 24,
      itemBuilder: (context, dayIndex) {
        final day = _startDate.add(Duration(days: dayIndex));
        final schedulesForDay = groupedSchedules[day] ?? [];

        return Container(
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade200))),
          child: Stack(
            children: [
              for (int hour = 0; hour < 24; hour++) Positioned(top: _hourHeight * hour, left: 0, right: 0, child: Container(height: 1, color: Colors.grey.shade200)),
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text('${day.month}/${day.day} (${DateFormat.E('ja').format(day)})', style: TextStyle(fontWeight: FontWeight.bold, color: DateUtils.isSameDay(day, widget.initialDate) ? Colors.deepPurple : null)),
                ),
              ),
              // --- MODIFIED! メソッド名のタイプミスを修正 ---
              ..._buildLayoutEventsForDay(schedulesForDay, availableWidth),
              if (DateUtils.isSameDay(day, DateTime.now())) _buildCurrentTimeIndicator(day),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildLayoutEventsForDay(List<QueryDocumentSnapshot> docs, double availableWidth) {
    if (docs.isEmpty) return [];

    final events = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return { 'doc': doc, 'start': (data['startTime'] as Timestamp).toDate(), 'end': (data['endTime'] as Timestamp).toDate() };
    }).toList()
      // --- MODIFIED! 安全なソート処理に修正 ---
      ..sort((a, b) {
        final aTime = a['start'] as DateTime?;
        final bTime = b['start'] as DateTime?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });

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

    final List<Widget> positionedEvents = [];
    final columnWidth = availableWidth / columns.length;
    for (int i = 0; i < columns.length; i++) {
      final col = columns[i];
      for (final event in col) {
        final top = _calculateTopOffset(event['start'] as DateTime);
        final height = (event['end'] as DateTime).difference(event['start'] as DateTime).inMinutes / 60.0 * _hourHeight;
        final left = i * columnWidth;

        final data = event['doc'].data() as Map<String, dynamic>;
        final isAllDay = data['isAllDay'] as bool? ?? false;
        if(isAllDay) continue;

        positionedEvents.add(
          Positioned(
            top: top, left: left, width: columnWidth, height: height,
            child: Container(
              padding: const EdgeInsets.all(4), margin: const EdgeInsets.only(left: 2, right: 2),
              // --- MODIFIED! 非推奨のwithOpacityを修正 ---
              decoration: BoxDecoration(color: Colors.blue.withAlpha(200), borderRadius: BorderRadius.circular(4)),
              child: Text(data['title'], style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
            ),
          ),
        );
      }
    }
    return positionedEvents;
  }

  Widget _buildCurrentTimeIndicator(DateTime day) {
    final now = DateTime.now();
    if (!DateUtils.isSameDay(now, day)) return const SizedBox.shrink();
    
    final top = _calculateTopOffset(now);
    return Positioned(
      top: top - 1, left: -8, right: 0,
      child: Row(
        children: [
          Icon(Icons.circle, color: Colors.red[700], size: 12),
          Expanded(child: Container(height: 2, color: Colors.red[700])),
        ],
      ),
    );
  }
}