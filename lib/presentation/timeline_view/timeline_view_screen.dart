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
  final DateTime originalStart;
  final DateTime originalEnd;
  int column;
  int totalColumns;

  RenderableEvent({
    required this.doc,
    required this.displayStart,
    required this.displayEnd,
    required this.originalStart,
    required this.originalEnd,
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
  static double? _lastScrollPosition; // スクロール位置を保持

  @override
  void initState() {
    super.initState();
    _initialDayIndex = _totalDays ~/ 2;
    _startDate = DateUtils.dateOnly(widget.initialDate).subtract(Duration(days: _initialDayIndex));

    // 初期位置へのスクロール（以前のスクロール位置があれば復元）
    Timer(const Duration(milliseconds: 100), () {
      if (mounted && _scrollController.hasClients) {
        if (_lastScrollPosition != null) {
          _scrollController.jumpTo(_lastScrollPosition!);
        } else {
          final initialOffset = (_initialDayIndex * _hourHeight * 24) + (_hourHeight * 7); // 朝7時あたりにスクロール
          _scrollController.jumpTo(initialOffset);
        }
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
    // スクロール位置を保存
    if (_scrollController.hasClients) {
      _lastScrollPosition = _scrollController.offset;
    }
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
          
          return _buildTimelineView(allRenderableEvents);
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

  Widget _buildTimelineView(List<RenderableEvent> allRenderableEvents) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Container(
        height: _totalDays * 24 * _hourHeight,
        child: Stack(
          children: [
            // 背景の時間グリッド
            ..._buildTimeGrid(),
            // 現在時刻のインジケーター
            ..._buildCurrentTimeIndicator(),
            // 予定ブロック（連続表示）
            ...allRenderableEvents.map((event) => _buildContinuousEventBlock(event)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTimeGrid() {
    List<Widget> gridWidgets = [];
    
    for (int dayIndex = 0; dayIndex < _totalDays; dayIndex++) {
      final day = _startDate.add(Duration(days: dayIndex));
      final dayTop = dayIndex * 24 * _hourHeight;
      
      // 日付ヘッダー
      gridWidgets.add(
        Positioned(
          top: dayTop,
          left: 0,
          right: 0,
          height: _hourHeight,
          child: Container(
            decoration: BoxDecoration(
              color: DateUtils.isSameDay(day, widget.initialDate) 
                  ? Colors.deepPurple.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.05),
              border: Border(
                top: BorderSide(color: Colors.grey.shade400, width: 1),
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Center(
                    child: Text(
                      '00:00',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      '${day.month}/${day.day} (${DateFormat.E('ja').format(day)})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: DateUtils.isSameDay(day, widget.initialDate)
                            ? Colors.deepPurple
                            : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
      // 時間ラベルとグリッド線
      for (int hour = 1; hour < 24; hour++) {
        final hourTop = dayTop + (hour * _hourHeight);
        
        gridWidgets.add(
          Positioned(
            top: hourTop,
            left: 0,
            right: 0,
            height: _hourHeight,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                  left: BorderSide(color: Colors.grey.shade300),
                ),
              ),
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
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        );
      }
    }
    
    return gridWidgets;
  }

  List<Widget> _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final dayIndex = DateUtils.dateOnly(now).difference(_startDate).inDays;
    
    if (dayIndex < 0 || dayIndex >= _totalDays) {
      return [];
    }
    
    final dayTop = dayIndex * 24 * _hourHeight;
    final minutesFromDayStart = (now.hour * 60) + now.minute;
    final topOffset = dayTop + (minutesFromDayStart / 60.0) * _hourHeight;
    
    return [
      Positioned(
        top: topOffset,
        left: 52,
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

  Widget _buildContinuousEventBlock(RenderableEvent event) {
    final data = event.doc.data() as Map<String, dynamic>;
    
    final startDayIndex = DateUtils.dateOnly(event.displayStart).difference(_startDate).inDays;
    final endDayIndex = DateUtils.dateOnly(event.displayEnd).difference(_startDate).inDays;
    
    if (startDayIndex < 0 || startDayIndex >= _totalDays) {
      return const SizedBox.shrink();
    }
    
    // 開始位置の計算
    final startDayTop = startDayIndex * 24 * _hourHeight;
    final startMinutesFromDayStart = (event.displayStart.hour * 60) + event.displayStart.minute;
    final topOffset = startDayTop + (startMinutesFromDayStart / 60.0) * _hourHeight;
    
    // 終了位置の計算
    final endDayTop = endDayIndex * 24 * _hourHeight;
    final endMinutesFromDayStart = (event.displayEnd.hour * 60) + event.displayEnd.minute;
    final bottomOffset = endDayTop + (endMinutesFromDayStart / 60.0) * _hourHeight;
    
    final height = bottomOffset - topOffset;
    
    if (height <= 0) return const SizedBox.shrink();

    final availableWidth = MediaQuery.of(context).size.width - 60;
    final columnWidth = availableWidth / event.totalColumns;
    final leftOffset = 60 + (event.column * columnWidth);

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
            border: Border.all(color: Colors.blue.shade300),
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
                maxLines: 2,
              ),
              if (height > 40) // 高さが十分にある場合のみ時間を表示
                Text(
                  data['isAllDay'] == true 
                      ? '終日'
                      : '${DateFormat.Hm().format(event.originalStart)} - ${DateFormat.Hm().format(event.originalEnd)}',
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

      DateTime displayStart, displayEnd;

      if (isAllDay) {
        displayStart = DateTime(start.year, start.month, start.day);
        displayEnd = DateTime(start.year, start.month, start.day, 23, 59, 59);
      } else {
        displayStart = start;
        displayEnd = end;
        
        // 開始時刻と終了時刻が同じ場合、最低30分の高さで表示
        if (start.isAtSameMomentAs(end)) {
          displayEnd = start.add(const Duration(minutes: 30));
        }
      }

      renderableEvents.add(RenderableEvent(
        doc: doc,
        displayStart: displayStart,
        displayEnd: displayEnd,
        originalStart: start,
        originalEnd: end,
      ));
    }

    // 日ごとにグループ化してレイアウトを計算
    final groupedByDay = <DateTime, List<RenderableEvent>>{};
    
    for (final event in renderableEvents) {
      final startDay = DateUtils.dateOnly(event.displayStart);
      final endDay = DateUtils.dateOnly(event.displayEnd);
      
      // 日をまたぐ場合は複数の日に追加
      DateTime currentDay = startDay;
      while (currentDay.isBefore(endDay.add(const Duration(days: 1)))) {
        groupedByDay.putIfAbsent(currentDay, () => []).add(event);
        currentDay = currentDay.add(const Duration(days: 1));
      }
    }
    
    groupedByDay.forEach((day, eventsOnDay) {
      // 同じ日に表示されるイベントをスタート時間でソート
      eventsOnDay.sort((a, b) => a.displayStart.compareTo(b.displayStart));
      
      final List<List<RenderableEvent>> columns = [];
      
      for (final event in eventsOnDay) {
        bool placed = false;
        
        // 既存のカラムに配置できるかチェック
        for (final col in columns) {
          final lastEventInColumn = col.last;
          if (!lastEventInColumn.displayEnd.isAfter(event.displayStart)) {
            col.add(event);
            placed = true;
            break;
          }
        }
        
        // 新しいカラムを作成
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