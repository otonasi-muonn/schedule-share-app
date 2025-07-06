import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:schedule_share_app/presentation/widgets/schedule_dialog.dart';

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
  final int _totalDays = 61;
  late final DateTime _startDate;
  late final int _initialDayIndex;
  DateTime _appBarDate = DateTime.now();
  // --- MODIFIED! 1分ごとに更新するタイマーを削除 ---
  // Timer? _currentTimeTimer; 

  @override
  void initState() {
    super.initState();
    _initialDayIndex = _totalDays ~/ 2;
    _startDate = DateUtils.dateOnly(widget.initialDate).subtract(Duration(days: _initialDayIndex));
    _appBarDate = widget.initialDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        final initialOffset = (_initialDayIndex * _hourHeight * 24) + (_hourHeight * 7);
        _scrollController.jumpTo(initialOffset);
      }
    });

    _scrollController.addListener(() {
      if (!mounted || !_scrollController.hasClients) return;
      final centerOffset = _scrollController.offset + (context.size?.height ?? 0) / 2;
      final centerDayIndex = (centerOffset / (_hourHeight * 24)).floor();
      final newDate = _startDate.add(Duration(days: centerDayIndex));
      if (!DateUtils.isSameDay(_appBarDate, newDate)) {
        setState(() {
          _appBarDate = newDate;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // _currentTimeTimer?.cancel(); // タイマーを削除したので、これも不要
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text(DateFormat('yyyy年 M月d日 (E)', 'ja').format(_appBarDate))),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('schedules').where('userId', isEqualTo: user?.uid).where('startTime', isGreaterThanOrEqualTo: _startDate).where('startTime', isLessThan: _startDate.add(Duration(days: _totalDays))).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          final allDocs = snapshot.data?.docs ?? [];
          final allRenderableEvents = _calculateLayout(allDocs);
          
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildTimeSlot(index, allRenderableEvents),
                  childCount: _totalDays * 24,
                ),
              ),
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

  Widget _buildTimeSlot(int index, List<RenderableEvent> allRenderableEvents) {
    final hour = index % 24;
    
    final eventsInSlot = allRenderableEvents.where((event) {
      final dayIndex = index ~/ 24;
      final day = _startDate.add(Duration(days: dayIndex));
      final slotStart = DateTime(day.year, day.month, day.day, hour);
      final slotEnd = slotStart.add(const Duration(hours: 1));
      return event.displayStart.isBefore(slotEnd) && event.displayEnd.isAfter(slotStart);
    }).toList();

    return SizedBox(
      height: _hourHeight,
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Center(
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200), left: BorderSide(color: Colors.grey.shade300)))),
                // --- MODIFIED! タイムライン内の日付表示を削除 ---
                ..._buildEventBlocks(eventsInSlot, hour),
                ..._buildCurrentTimeIndicator(hour),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCurrentTimeIndicator(int hour) {
    final now = DateTime.now();
    final slotStart = DateUtils.dateOnly(now).add(Duration(hours: hour));
    final slotEnd = slotStart.add(const Duration(hours: 1));
    if (now.isBefore(slotStart) || now.isAfter(slotEnd)) return [];

    final topOffset = (now.difference(slotStart).inMinutes / 60.0) * _hourHeight;
    return [Positioned(top: topOffset, left: -8, right: 0, child: IgnorePointer(child: Row(children: [Icon(Icons.circle, color: Colors.red[700], size: 12), Expanded(child: Container(height: 2, color: Colors.red[700]))])))];
  }

  List<Widget> _buildEventBlocks(List<RenderableEvent> events, int hour) {
    final availableWidth = MediaQuery.of(context).size.width - 60;
    return events.map((event) {
      final data = event.doc.data() as Map<String, dynamic>;
      final slotStart = DateUtils.dateOnly(event.displayStart).add(Duration(hours: hour));
      
      final eventStart = event.displayStart.isAfter(slotStart) ? event.displayStart : slotStart;
      final eventEnd = event.displayEnd.isBefore(slotStart.add(const Duration(hours: 1))) ? event.displayEnd : slotStart.add(const Duration(hours: 1));
      
      final topOffset = (eventStart.difference(slotStart).inMinutes / 60.0) * _hourHeight;
      final height = (eventEnd.difference(eventStart).inMinutes / 60.0) * _hourHeight;
      if (height <= 0) return const SizedBox.shrink();

      final columnWidth = availableWidth / event.totalColumns;
      final leftOffset = event.column * columnWidth;

      final originalStart = (data['startTime'] as Timestamp).toDate();
      final bool isFirstPart = DateUtils.isSameDay(event.displayStart, originalStart) && event.displayStart.hour == originalStart.hour && event.displayStart.minute == originalStart.minute;
      
      return Positioned(
        top: topOffset, left: leftOffset, width: columnWidth, height: height,
        child: GestureDetector(
          onTap: () => showScheduleDialog(context, scheduleDoc: event.doc),
          child: Container(
            padding: const EdgeInsets.all(4), margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(200),
              borderRadius: BorderRadius.vertical(
                top: isFirstPart ? const Radius.circular(4) : Radius.zero,
                bottom: (event.displayEnd.hour == 23 && event.displayEnd.minute == 59) || DateUtils.isSameDay(event.displayEnd, (data['endTime'] as Timestamp).toDate()) ? const Radius.circular(4) : Radius.zero,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFirstPart) Text(data['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<RenderableEvent> _calculateLayout(List<QueryDocumentSnapshot> allDocs) {
    List<RenderableEvent> renderableEvents = [];
    allDocs.sort((a, b) => (a['startTime'] as Timestamp).compareTo(b['startTime'] as Timestamp));
    
    for (final doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isAllDay'] as bool? ?? false) continue;
      
      final start = (data['startTime'] as Timestamp).toDate();
      final end = (data['endTime'] as Timestamp).toDate();
      
      if (start.isAtSameMomentAs(end)) {
        renderableEvents.add(RenderableEvent(doc: doc, displayStart: start, displayEnd: start.add(const Duration(minutes: 30))));
        continue;
      }
      
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
}