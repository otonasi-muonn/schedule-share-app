import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class RenderableEvent {
  final DocumentSnapshot doc;
  final DateTime displayStart;
  final DateTime displayEnd;
  int column;
  int totalColumns;

  RenderableEvent({
    required this.doc,
    required this.displayStart,
    required this.displayEnd,
    this.column = 0,
    this.totalColumns = 1,
  });
}

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
  // --- MODIFIED! あなたの提案通り、表示期間を約2ヶ月に限定 ---
  final int _totalDays = 61; // 過去30日 + 今日 + 未来30日
  late final DateTime _startDate;
  late final int _initialDayIndex;

  @override
  void initState() {
    super.initState();
    _initialDayIndex = _totalDays ~/ 2;
    _startDate = DateUtils.dateOnly(widget.initialDate).subtract(Duration(days: _initialDayIndex));

    Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        final initialOffset = (_initialDayIndex * _hourHeight * 24) + (_hourHeight * 7);
        _scrollController.jumpTo(initialOffset);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _calculateTopOffset(DateTime time, DateTime dayStart) {
    return time.difference(dayStart).inMinutes / 60.0 * _hourHeight;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('タイムライン')),
      body: StreamBuilder<QuerySnapshot>(
        // --- MODIFIED! 読み込むデータも2ヶ月分に限定 ---
        stream: FirebaseFirestore.instance
            .collection('schedules')
            .where('userId', isEqualTo: user?.uid)
            .where('startTime', isGreaterThanOrEqualTo: _startDate)
            .where('startTime', isLessThan: _startDate.add(Duration(days: _totalDays)))
            .orderBy('startTime')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          final allDocs = snapshot.data?.docs ?? [];
          final allRenderableEvents = _calculateLayout(allDocs);

          return Stack(
            children: [
              _buildBackgroundGrid(),
              _buildEventLayer(allRenderableEvents),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final targetOffset = (_initialDayIndex * _hourHeight * 24) + (_hourHeight * 7);
          _scrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
        },
        tooltip: '指定日に移動',
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }

  Widget _buildBackgroundGrid() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _totalDays * 24,
      itemExtent: _hourHeight,
      itemBuilder: (context, index) {
        final dayIndex = index ~/ 24;
        final hour = index % 24;
        final day = _startDate.add(Duration(days: dayIndex));
        return Row(
          children: [
            SizedBox(
              width: 60,
              height: _hourHeight,
              child: Center(
                child: Text('${hour.toString().padLeft(2, '0')}:00', style: const TextStyle(fontSize: 12)),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200), left: BorderSide(color: Colors.grey.shade300))),
                child: hour == 0
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text('${day.month}/${day.day} (${DateFormat.E('ja').format(day)})',
                            style: TextStyle(fontWeight: FontWeight.bold, color: DateUtils.isSameDay(day, widget.initialDate) ? Colors.deepPurple : null),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }

  List<RenderableEvent> _calculateLayout(List<QueryDocumentSnapshot> allDocs) {
    List<RenderableEvent> renderableEvents = [];
    for (final doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final isAllDay = data['isAllDay'] as bool? ?? false;
      if (isAllDay) continue;
      final start = (data['startTime'] as Timestamp).toDate();
      final end = (data['endTime'] as Timestamp).toDate();
      var current = start;
      while (current.isBefore(end)) {
        final endOfCurrentDay = DateUtils.dateOnly(current).add(const Duration(days: 1));
        final blockEnd = end.isBefore(endOfCurrentDay) ? end : endOfCurrentDay;
        renderableEvents.add(RenderableEvent(doc: doc, displayStart: current, displayEnd: blockEnd));
        current = endOfCurrentDay;
      }
    }
    final groupedByDay = groupBy(renderableEvents, (e) => DateUtils.dateOnly(e.displayStart));
    groupedByDay.forEach((day, eventsOnDay) {
      eventsOnDay.sort((a, b) => a.displayStart.compareTo(b.displayStart));
      final List<List<RenderableEvent>> columns = [];
      for (final event in eventsOnDay) {
        bool placed = false;
        for (final col in columns) {
          if (!col.last.displayEnd.isAfter(event.displayStart)) {
            col.add(event); placed = true; break;
          }
        }
        if (!placed) { columns.add([event]); }
      }
      for(int i = 0; i < columns.length; i++) {
        for(final event in columns[i]) {
          event.column = i;
          event.totalColumns = columns.length;
        }
      }
    });
    return renderableEvents;
  }
  
  Widget _buildEventLayer(List<RenderableEvent> renderableEvents) {
    final scheduleAreaWidth = MediaQuery.of(context).size.width - 60;
    
    return IgnorePointer( // このレイヤーはタップ操作を無視するようにする
      child: AnimatedBuilder(
        animation: _scrollController,
        builder: (context, _) {
          return Stack(
            children: [
              ...renderableEvents.map((event) {
                final data = event.doc.data() as Map<String, dynamic>;
                final dayOfEvent = DateUtils.dateOnly(event.displayStart);
                final dayIndex = dayOfEvent.difference(_startDate).inDays;
                
                final top = (dayIndex * _hourHeight * 24) + _calculateTopOffset(event.displayStart, dayOfEvent);
                final height = event.displayEnd.difference(event.displayStart).inMinutes / 60.0 * _hourHeight;

                final columnWidth = scheduleAreaWidth / event.totalColumns;
                final left = 60 + (event.column * columnWidth);

                return Positioned(
                  top: top - _scrollController.offset,
                  left: left,
                  width: columnWidth,
                  height: height,
                  child: Container(
                    padding: const EdgeInsets.all(4), margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: Colors.blue.withAlpha(200), borderRadius: BorderRadius.circular(4)),
                    child: Text(data['title'], style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList(),
              _buildCurrentTimeIndicator(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final dayIndex = DateUtils.dateOnly(now).difference(_startDate).inDays;
    if (dayIndex < 0 || dayIndex >= _totalDays) return const SizedBox.shrink();

    final top = (dayIndex * _hourHeight * 24) + _calculateTopOffset(now, DateUtils.dateOnly(now));

    return Positioned(
      top: top - (_scrollController.hasClients ? _scrollController.offset : 0) - 1,
      left: 60 - 8,
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