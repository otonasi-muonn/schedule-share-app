import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:schedule_share_app/presentation/widgets/schedule_dialog.dart';

// 描画イベントのヘルパークラス
class RenderableEvent {
  final DocumentSnapshot doc;
  final DateTime displayStart;
  final DateTime displayEnd;
  int column;
  int totalColumns;
  final bool isFirstPart;
  final bool isLastPart;

  RenderableEvent({
    required this.doc,
    required this.displayStart,
    required this.displayEnd,
    this.column = 0,
    this.totalColumns = 1,
    required this.isFirstPart,
    required this.isLastPart,
  });
}

class TimelineViewScreen extends StatefulWidget {
  final DateTime initialDate;
  const TimelineViewScreen({super.key, required this.initialDate});

  @override
  State<TimelineViewScreen> createState() => _TimelineViewScreenState();
}

class _TimelineViewScreenState extends State<TimelineViewScreen> {
  final ScrollController _scrollController = ScrollController();
  final double _hourHeight = 80.0;
  
  // 動的に読み込むための状態管理
  List<DateTime> _loadedDays = [];
  bool _isLoadingTop = false;
  bool _isLoadingBottom = false;
  late final ValueNotifier<DateTime> _appBarDateNotifier;
  Timer? _currentTimeTimer;

  @override
  void initState() {
    super.initState();
    _appBarDateNotifier = ValueNotifier(widget.initialDate);
    
    // 初期表示の日付範囲を設定
    for (int i = -7; i <= 7; i++) {
      _loadedDays.add(DateUtils.dateOnly(widget.initialDate).add(Duration(days: i)));
    }
    
    // 画面が開いたときに、指定された日の位置までスクロール
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        final initialDayIndex = _loadedDays.indexWhere((day) => DateUtils.isSameDay(day, widget.initialDate));
        if (initialDayIndex != -1) {
          final initialOffset = (initialDayIndex * _hourHeight * 24) + (_hourHeight * 7);
          _scrollController.jumpTo(initialOffset);
        }
      }
    });

    // スクロールを監視して、動的にデータを読み込む
    _scrollController.addListener(_scrollListener);

    // 現在時刻線を1分ごとに更新
    _currentTimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) { setState(() {}); }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _appBarDateNotifier.dispose();
    _currentTimeTimer?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    if (!mounted || !_scrollController.hasClients) return;
    
    // アプリバーの日付を更新
    final centerOffset = _scrollController.offset + (MediaQuery.of(context).size.height / 3);
    final centerDayIndex = (centerOffset / (_hourHeight * 24)).floor();
    if (centerDayIndex >= 0 && centerDayIndex < _loadedDays.length) {
      final newDate = _loadedDays[centerDayIndex];
      if (!DateUtils.isSameDay(_appBarDateNotifier.value, newDate)) {
        _appBarDateNotifier.value = newDate;
      }
    }

    // 一番下近くまでスクロールしたら、未来のデータを読み込む
    if (!_isLoadingBottom && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 2000) {
      setState(() { _isLoadingBottom = true; });
      final lastDay = _loadedDays.last;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            for (int i = 1; i <= 7; i++) {
              _loadedDays.add(lastDay.add(Duration(days: i)));
            }
            _isLoadingBottom = false;
          });
        }
      });
    }

    // 一番上近くまでスクロールしたら、過去のデータを読み込む
    if (!_isLoadingTop && _scrollController.position.pixels <= 2000) {
      setState(() { _isLoadingTop = true; });
      final firstDay = _loadedDays.first;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final newDays = [for (int i = 7; i >= 1; i--) firstDay.subtract(Duration(days: i))];
          setState(() {
            _loadedDays.insertAll(0, newDays);
            _isLoadingTop = false;
          });
          // 読み込んだ分だけスクロール位置を調整して、ガクンとなるのを防ぐ
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.offset + (7 * _hourHeight * 24));
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<DateTime>(
          valueListenable: _appBarDateNotifier,
          builder: (context, value, child) => Text(DateFormat('yyyy年 M月d日 (E)', 'ja').format(value)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('schedules')
            .where('userId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _loadedDays.isEmpty) {
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
                  childCount: _loadedDays.length * 24,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final initialDayIndex = _loadedDays.indexWhere((day) => DateUtils.isSameDay(day, widget.initialDate));
          if (initialDayIndex != -1) {
            final targetOffset = (initialDayIndex * _hourHeight * 24) + (_hourHeight * 7);
            _scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
          }
        },
        tooltip: '指定日に移動',
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }

  Widget _buildTimeSlot(int index, List<RenderableEvent> allRenderableEvents) {
    final dayIndex = index ~/ 24;
    final hour = index % 24;
    if (dayIndex >= _loadedDays.length) return const SizedBox.shrink();
    
    final day = _loadedDays[dayIndex];
    final slotStart = DateTime(day.year, day.month, day.day, hour);
    
    final eventsInSlot = allRenderableEvents.where((event) {
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
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: hour == 0 ? Colors.grey.shade400 : Colors.grey.shade200,
                        width: hour == 0 ? 1.5 : 1.0,
                      ),
                      left: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                ..._buildEventBlocks(eventsInSlot, slotStart),
                ..._buildCurrentTimeIndicator(slotStart),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCurrentTimeIndicator(DateTime slotStart) {
    final now = DateTime.now();
    final slotEnd = slotStart.add(const Duration(hours: 1));
    
    if (now.isBefore(slotStart) || now.isAfter(slotEnd)) {
      return [];
    }
    
    final topOffset = (now.difference(slotStart).inMinutes / 60.0) * _hourHeight;
    
    return [
      Positioned(
        top: topOffset,
        left: -8,
        right: 0,
        child: IgnorePointer(
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
      ),
    ];
  }

  List<Widget> _buildEventBlocks(List<RenderableEvent> events, DateTime slotStart) {
    final availableWidth = MediaQuery.of(context).size.width - 60;
    
    return events.map((event) {
      final data = event.doc.data() as Map<String, dynamic>;
      final eventStart = event.displayStart.isAfter(slotStart) ? event.displayStart : slotStart;
      final eventEnd = event.displayEnd.isBefore(slotStart.add(const Duration(hours: 1))) 
          ? event.displayEnd 
          : slotStart.add(const Duration(hours: 1));
      
      final topOffset = (eventStart.difference(slotStart).inMinutes / 60.0) * _hourHeight;
      final height = (eventEnd.difference(eventStart).inMinutes / 60.0) * _hourHeight;
      
      if (height <= 0) return const SizedBox.shrink();

      final columnWidth = availableWidth / event.totalColumns;
      final leftOffset = event.column * columnWidth;

      return Positioned(
        top: topOffset,
        left: leftOffset,
        width: columnWidth,
        height: height,
        child: GestureDetector(
          onTap: () => showScheduleDialog(context, scheduleDoc: event.doc),
          child: Container(
            padding: const EdgeInsets.all(4),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.blue,
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.5),
              borderRadius: BorderRadius.vertical(
                top: event.isFirstPart ? const Radius.circular(4) : Radius.zero,
                bottom: event.isLastPart ? const Radius.circular(4) : Radius.zero,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.isFirstPart)
                  Text(
                    data['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<RenderableEvent> _calculateLayout(List<QueryDocumentSnapshot> allDocs) {
    List<RenderableEvent> renderableEvents = [];
    
    final sortedDocs = List<QueryDocumentSnapshot>.from(allDocs)
      ..sort((a, b) {
        final aStart = a['startTime'] as Timestamp?;
        final bStart = b['startTime'] as Timestamp?;
        if (aStart == null && bStart == null) return 0;
        if (aStart == null) return 1;
        if (bStart == null) return -1;
        return aStart.compareTo(bStart);
      });
    
    for (final doc in sortedDocs) {
      final data = doc.data() as Map<String, dynamic>;
      
      // 終日イベントはスキップ
      if (data['isAllDay'] as bool? ?? false) continue;
      
      final startTimestamp = data['startTime'] as Timestamp?;
      final endTimestamp = data['endTime'] as Timestamp?;
      
      if (startTimestamp == null || endTimestamp == null) continue;
      
      final start = startTimestamp.toDate();
      final end = endTimestamp.toDate();
      
      // 同じ時刻の場合は30分間のブロックとして扱う
      if (start.isAtSameMomentAs(end)) {
        renderableEvents.add(
          RenderableEvent(
            doc: doc,
            displayStart: start,
            displayEnd: start.add(const Duration(minutes: 30)),
            isFirstPart: true,
            isLastPart: true,
          ),
        );
        continue;
      }
      
      // 複数日にまたがるイベントを日ごとに分割
      var current = start;
      bool isFirst = true;
      
      while (current.isBefore(end)) {
        final endOfCurrentDay = DateUtils.dateOnly(current).add(const Duration(days: 1));
        final blockEnd = end.isBefore(endOfCurrentDay) ? end : endOfCurrentDay;
        
        renderableEvents.add(
          RenderableEvent(
            doc: doc,
            displayStart: current,
            displayEnd: blockEnd,
            isFirstPart: isFirst,
            isLastPart: !end.isAfter(blockEnd),
          ),
        );
        
        current = endOfCurrentDay;
        isFirst = false;
      }
    }

    // 日ごとにグループ化してカラムレイアウトを計算
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
      
      // カラム情報を設定
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