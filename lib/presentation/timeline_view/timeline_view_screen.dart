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
  final int _totalDays = 61; // 約2ヶ月分
  late final DateTime _startDate;
  late final int _initialDayIndex;
  Timer? _currentTimeTimer;

  @override
  void initState() {
    super.initState();
    _initialDayIndex = _totalDays ~/ 2;
    _startDate = DateUtils.dateOnly(widget.initialDate).subtract(Duration(days: _initialDayIndex));

    // 初期位置へのスクロール
    Timer(const Duration(milliseconds: 100), () {
      if (mounted && _scrollController.hasClients) {
        final initialOffset = (_initialDayIndex * _hourHeight * 24) + (_hourHeight * 7); // 朝7時あたりにスクロール
        _scrollController.jumpTo(initialOffset);
      }
    });

    // 現在時刻のインジケーターを1分ごとに更新
    _currentTimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _currentTimeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('タイムライン'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: '今日に移動',
            onPressed: () {
              final now = DateTime.now();
              final todayIndex = DateUtils.dateOnly(now).difference(_startDate).inDays;
              if (todayIndex >= 0 && todayIndex < _totalDays) {
                final targetOffset = (todayIndex * _hourHeight * 24) + (_hourHeight * now.hour);
                _scrollController.animateTo(
                  targetOffset,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                );
              }
            },
          ),
        ],
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
          // クライアントサイドでソート
          allDocs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['startTime'] as Timestamp;
            final bTime = (b.data() as Map<String, dynamic>)['startTime'] as Timestamp;
            return aTime.compareTo(bTime);
          });
          
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
          _scrollController.animateTo(
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

  Widget _buildTimeSlot(int index, List<RenderableEvent> allRenderableEvents) {
    final dayIndex = index ~/ 24;
    final hour = index % 24;
    final day = _startDate.add(Duration(days: dayIndex));
    final slotStart = DateTime(day.year, day.month, day.day, hour);
    final slotEnd = slotStart.add(const Duration(hours: 1));
    
    // この時間スロットに表示すべきイベントを取得
    final eventsInSlot = allRenderableEvents.where((event) {
      return event.displayStart.isBefore(slotEnd) && event.displayEnd.isAfter(slotStart);
    }).toList();

    return Container(
      height: _hourHeight,
      child: Row(
        children: [
          // 時間ラベル
          SizedBox(
            width: 60,
            child: Center(
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          // メインエリア
          Expanded(
            child: Stack(
              children: [
                // 背景
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                      left: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: hour == 0
                      ? Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              '${day.month}/${day.day} (${DateFormat.E('ja').format(day)})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: DateUtils.isSameDay(day, widget.initialDate)
                                    ? Colors.deepPurple
                                    : null,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                // 現在時刻のインジケーター
                ..._buildCurrentTimeIndicator(slotStart, slotEnd),
                // イベントブロック
                ...eventsInSlot.map((event) => _buildEventBlock(event, slotStart, slotEnd)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCurrentTimeIndicator(DateTime slotStart, DateTime slotEnd) {
    final now = DateTime.now();
    if (now.isBefore(slotStart) || now.isAfter(slotEnd)) {
      return [];
    }

    final minutesFromSlotStart = now.difference(slotStart).inMinutes;
    final topOffset = (minutesFromSlotStart / 60.0) * _hourHeight;

    return [
      Positioned(
        top: topOffset,
        left: -8,
        right: 0,
        child: Row(
          children: [
            Icon(Icons.circle, color: Colors.red[700], size: 12),
            Expanded(
              child: Container(
                height: 2,
                color: Colors.red[700],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildEventBlock(RenderableEvent event, DateTime slotStart, DateTime slotEnd) {
    final data = event.doc.data() as Map<String, dynamic>;
    final eventStart = event.displayStart.isAfter(slotStart) ? event.displayStart : slotStart;
    final eventEnd = event.displayEnd.isBefore(slotEnd) ? event.displayEnd : slotEnd;
    
    final topOffset = eventStart.difference(slotStart).inMinutes / 60.0 * _hourHeight;
    final height = eventEnd.difference(eventStart).inMinutes / 60.0 * _hourHeight;
    
    if (height <= 0) return const SizedBox.shrink();

    final availableWidth = MediaQuery.of(context).size.width - 60;
    final columnWidth = availableWidth / event.totalColumns;
    final leftOffset = event.column * columnWidth;

    return Positioned(
      top: topOffset,
      left: leftOffset,
      width: columnWidth,
      height: height,
      child: GestureDetector(
        onTap: () {
          showScheduleDialog(context, scheduleDoc: event.doc);
        },
        child: Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha(200),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['title'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (height > 30) // 高さが十分にある場合のみ時間を表示
                Text(
                  '${DateFormat.Hm().format(event.displayStart)} - ${DateFormat.Hm().format(event.displayEnd)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<RenderableEvent> _calculateLayout(List<QueryDocumentSnapshot> allDocs) {
    List<RenderableEvent> renderableEvents = [];
    
    for (final doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final start = (data['startTime'] as Timestamp).toDate();
      final end = (data['endTime'] as Timestamp).toDate();
      final isAllDay = data['isAllDay'] as bool? ?? false;

      // 終日イベントの場合
      if (isAllDay) {
        final dayStart = DateTime(start.year, start.month, start.day);
        final dayEnd = DateTime(start.year, start.month, start.day, 23, 59, 59);
        renderableEvents.add(RenderableEvent(
          doc: doc,
          displayStart: dayStart,
          displayEnd: dayEnd,
        ));
        continue;
      }

      // 開始時刻と終了時刻が同じ場合、最低30分の高さで表示
      if (start.isAtSameMomentAs(end)) {
        renderableEvents.add(RenderableEvent(
          doc: doc,
          displayStart: start,
          displayEnd: start.add(const Duration(minutes: 30)),
        ));
        continue;
      }

      // 日をまたぐイベントを日ごとに分割
      var current = start;
      while (current.isBefore(end)) {
        final endOfCurrentDay = DateTime(current.year, current.month, current.day, 23, 59, 59);
        final blockEnd = end.isBefore(endOfCurrentDay) ? end : endOfCurrentDay;
        
        renderableEvents.add(RenderableEvent(
          doc: doc,
          displayStart: current,
          displayEnd: blockEnd,
        ));
        
        current = DateTime(current.year, current.month, current.day).add(const Duration(days: 1));
      }
    }

    // 日ごとにグループ化してレイアウトを計算
    final groupedByDay = groupBy(renderableEvents, (e) => DateUtils.dateOnly(e.displayStart));
    
    groupedByDay.forEach((day, eventsOnDay) {
      eventsOnDay.sort((a, b) => a.displayStart.compareTo(b.displayStart));
      
      final List<List<RenderableEvent>> columns = [];
      
      for (final event in eventsOnDay) {
        bool placed = false;
        
        for (final col in columns) {
          if (!col.last.displayEnd.isAfter(event.displayStart)) {
            col.add(event);
            placed = true;
            break;
          }
        }
        
        if (!placed) {
          columns.add([event]);
        }
      }
      
      // 各イベントのカラム情報を設定
      for (int i = 0; i < columns.length; i++) {
        for (final event in columns[i]) {
          event.column = i;
          event.totalColumns = columns.length;
        }
      }
    });

    return renderableEvents;
  }
}