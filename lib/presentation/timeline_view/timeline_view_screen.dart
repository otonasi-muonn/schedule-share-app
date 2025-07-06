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
  final DateTime originalStart;
  final DateTime originalEnd;
  final DateTime displayStart;
  final DateTime displayEnd;
  int column;
  int totalColumns;
  final bool isAllDay;

  RenderableEvent({
    required this.doc,
    required this.originalStart,
    required this.originalEnd,
    required this.displayStart,
    required this.displayEnd,
    this.column = 0,
    this.totalColumns = 1,
    this.isAllDay = false,
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
  final int _initialLoadDays = 7; // 初期読み込み日数（前後）
  final int _loadMoreDays = 7; // 追加読み込み日数
  
  // 動的に読み込むための状態管理
  List<DateTime> _loadedDays = [];
  bool _isLoadingTop = false;
  bool _isLoadingBottom = false;
  late final ValueNotifier<DateTime> _appBarDateNotifier;
  Timer? _currentTimeTimer;
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    _appBarDateNotifier = ValueNotifier(widget.initialDate);
    
    // 初期表示の日付範囲を設定（指定日の前後7日）
    final baseDate = DateUtils.dateOnly(widget.initialDate);
    for (int i = -_initialLoadDays; i <= _initialLoadDays; i++) {
      _loadedDays.add(baseDate.add(Duration(days: i)));
    }
    
    // 画面が開いたときに、指定された日の位置までスクロール
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToInitialPosition();
    });

    // スクロールを監視して、動的にデータを読み込む
    _scrollController.addListener(_scrollListener);

    // 現在時刻線を1分ごとに更新
    _currentTimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) { 
        setState(() {});
      }
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

  void _scrollToInitialPosition() {
    if (!mounted || !_scrollController.hasClients) return;
    
    final initialDayIndex = _loadedDays.indexWhere(
      (day) => DateUtils.isSameDay(day, widget.initialDate)
    );
    
    if (initialDayIndex != -1) {
      // 指定された日の朝7時の位置にスクロール
      final initialOffset = (initialDayIndex * _hourHeight * 24) + (_hourHeight * 7);
      _scrollController.jumpTo(initialOffset);
      _initialScrollDone = true;
    }
  }

  void _scrollListener() {
    if (!mounted || !_scrollController.hasClients) return;
    
    // アプリバーの日付を更新
    _updateAppBarDate();
    
    // 一番下近くまでスクロールしたら、未来のデータを読み込む
    if (!_isLoadingBottom && 
        _scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 2000) {
      _loadMoreDays(isTop: false);
    }

    // 一番上近くまでスクロールしたら、過去のデータを読み込む
    if (!_isLoadingTop && _scrollController.position.pixels <= 2000) {
      _loadMoreDays(isTop: true);
    }
  }

  void _updateAppBarDate() {
    if (!mounted) return;
    
    final centerOffset = _scrollController.offset + (MediaQuery.of(context).size.height / 3);
    final centerDayIndex = (centerOffset / (_hourHeight * 24)).floor();
    
    if (centerDayIndex >= 0 && centerDayIndex < _loadedDays.length) {
      final newDate = _loadedDays[centerDayIndex];
      if (!DateUtils.isSameDay(_appBarDateNotifier.value, newDate)) {
        _appBarDateNotifier.value = newDate;
      }
    }
  }

  Future<void> _loadMoreDays({required bool isTop}) async {
    if (isTop) {
      setState(() { _isLoadingTop = true; });
    } else {
      setState(() { _isLoadingBottom = true; });
    }

    // 少し遅延を入れて、スムーズなスクロール体験を提供
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    setState(() {
      if (isTop) {
        // 過去のデータを読み込み
        final firstDay = _loadedDays.first;
        final newDays = [
          for (int i = _loadMoreDays; i >= 1; i--) 
            firstDay.subtract(Duration(days: i))
        ];
        _loadedDays.insertAll(0, newDays);
        _isLoadingTop = false;
        
        // スクロール位置を調整して、ガクンとなるのを防ぐ
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.offset + (_loadMoreDays * _hourHeight * 24)
            );
          }
        });
      } else {
        // 未来のデータを読み込み
        final lastDay = _loadedDays.last;
        for (int i = 1; i <= _loadMoreDays; i++) {
          _loadedDays.add(lastDay.add(Duration(days: i)));
        }
        _isLoadingBottom = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<DateTime>(
          valueListenable: _appBarDateNotifier,
          builder: (context, value, child) => Text(
            DateFormat('yyyy年 M月d日 (E)', 'ja').format(value)
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: '今日に移動',
            onPressed: _scrollToToday,
          ),
        ],
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
          
          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  if (_isLoadingTop)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildTimeSlot(index, allRenderableEvents),
                      childCount: _loadedDays.length * 24,
                    ),
                  ),
                  if (_isLoadingBottom)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
              // 現在時刻の表示
              _buildCurrentTimeDisplay(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showScheduleDialog(context, initialDate: _appBarDateNotifier.value);
        },
        tooltip: '予定を追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCurrentTimeDisplay() {
    final now = DateTime.now();
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red[700],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          DateFormat('HH:mm').format(now),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _scrollToToday() {
    final today = DateUtils.dateOnly(DateTime.now());
    final todayIndex = _loadedDays.indexWhere((day) => DateUtils.isSameDay(day, today));
    
    if (todayIndex != -1) {
      final targetOffset = (todayIndex * _hourHeight * 24) + (_hourHeight * DateTime.now().hour);
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildTimeSlot(int index, List<RenderableEvent> allRenderableEvents) {
    final dayIndex = index ~/ 24;
    final hour = index % 24;
    if (dayIndex >= _loadedDays.length) return const SizedBox.shrink();
    
    final day = _loadedDays[dayIndex];
    final slotStart = DateTime(day.year, day.month, day.day, hour);
    final slotEnd = slotStart.add(const Duration(hours: 1));
    
    // この時間スロットに表示される予定を抽出
    final eventsInSlot = allRenderableEvents.where((event) {
      return !event.isAllDay && 
             event.displayStart.isBefore(slotEnd) && 
             event.displayEnd.isAfter(slotStart);
    }).toList();

    return SizedBox(
      height: _hourHeight,
      child: Row(
        children: [
          // 時刻表示部分
          SizedBox(
            width: 60,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Center(
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: hour == 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          // タイムライン部分
          Expanded(
            child: Stack(
              children: [
                // 背景のグリッド
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: hour == 0 ? Colors.grey.shade400 : Colors.grey.shade200,
                        width: hour == 0 ? 1.5 : 0.5,
                      ),
                    ),
                  ),
                ),
                // 予定ブロック
                ..._buildEventBlocks(eventsInSlot, slotStart, slotEnd),
                // 現在時刻の線
                ..._buildCurrentTimeIndicator(slotStart, slotEnd),
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
    
    final topOffset = (now.difference(slotStart).inMinutes / 60.0) * _hourHeight;
    
    return [
      Positioned(
        top: topOffset - 1,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  shape: BoxShape.circle,
                ),
              ),
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

  List<Widget> _buildEventBlocks(List<RenderableEvent> events, DateTime slotStart, DateTime slotEnd) {
    final availableWidth = MediaQuery.of(context).size.width - 60;
    
    return events.map((event) {
      final data = event.doc.data() as Map<String, dynamic>;
      
      // このスロット内での実際の開始・終了時刻を計算
      final blockStart = event.displayStart.isAfter(slotStart) ? event.displayStart : slotStart;
      final blockEnd = event.displayEnd.isBefore(slotEnd) ? event.displayEnd : slotEnd;
      
      final topOffset = (blockStart.difference(slotStart).inMinutes / 60.0) * _hourHeight;
      final height = (blockEnd.difference(blockStart).inMinutes / 60.0) * _hourHeight;
      
      if (height <= 0) return const SizedBox.shrink();

      final columnWidth = availableWidth / event.totalColumns;
      final leftOffset = event.column * columnWidth;

      // 角丸の判定
      final isTopRounded = event.displayStart.isAtSameMomentAs(blockStart);
      final isBottomRounded = event.displayEnd.isAtSameMomentAs(blockEnd);
      
      // タイトル表示の判定
      final shouldShowTitle = event.originalStart.isAtSameMomentAs(blockStart);

      return Positioned(
        top: topOffset,
        left: leftOffset + 2,
        width: columnWidth - 4,
        height: height,
        child: GestureDetector(
          onTap: () => showScheduleDialog(context, scheduleDoc: event.doc),
          child: Container(
            decoration: BoxDecoration(
              color: _getEventColor(data),
              border: Border.all(
                color: Colors.white.withOpacity(0.8), 
                width: 0.5
              ),
              borderRadius: BorderRadius.vertical(
                top: isTopRounded ? const Radius.circular(6) : Radius.zero,
                bottom: isBottomRounded ? const Radius.circular(6) : Radius.zero,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (shouldShowTitle) ...[
                    Text(
                      data['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (height > 24) // 高さが十分ある場合のみ時刻を表示
                      Text(
                        _formatEventTime(event.originalStart, event.originalEnd),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Color _getEventColor(Map<String, dynamic> data) {
    // 予定の種類やカテゴリに応じて色を変える（将来的な拡張用）
    return Colors.blue.shade600;
  }

  String _formatEventTime(DateTime start, DateTime end) {
    if (DateUtils.isSameDay(start, end)) {
      return '${DateFormat.Hm().format(start)} - ${DateFormat.Hm().format(end)}';
    } else {
      return '${DateFormat.Hm().format(start)} - ${DateFormat('M/d H:mm').format(end)}';
    }
  }

  List<RenderableEvent> _calculateLayout(List<QueryDocumentSnapshot> allDocs) {
    List<RenderableEvent> renderableEvents = [];
    
    final sortedDocs = List<QueryDocumentSnapshot>.from(allDocs)
      ..sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aStart = aData['startTime'] as Timestamp?;
        final bStart = bData['startTime'] as Timestamp?;
        if (aStart == null && bStart == null) return 0;
        if (aStart == null) return 1;
        if (bStart == null) return -1;
        return aStart.compareTo(bStart);
      });
    
    for (final doc in sortedDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final isAllDay = data['isAllDay'] as bool? ?? false;
      
      final startTimestamp = data['startTime'] as Timestamp?;
      final endTimestamp = data['endTime'] as Timestamp?;
      
      if (startTimestamp == null || endTimestamp == null) continue;
      
      final start = startTimestamp.toDate();
      final end = endTimestamp.toDate();
      
      // 同じ時刻の場合は30分間のブロックとして扱う
      final effectiveEnd = start.isAtSameMomentAs(end) ? 
        start.add(const Duration(minutes: 30)) : end;
      
      if (isAllDay) {
        // 終日イベントは現在はスキップ（将来的には別途表示）
        continue;
      }
      
      // 複数日にまたがるイベントを日ごとに分割
      var current = start;
      
      while (current.isBefore(effectiveEnd)) {
        final endOfCurrentDay = DateUtils.dateOnly(current).add(const Duration(days: 1));
        final blockEnd = effectiveEnd.isBefore(endOfCurrentDay) ? effectiveEnd : endOfCurrentDay;
        
        renderableEvents.add(
          RenderableEvent(
            doc: doc,
            originalStart: start,
            originalEnd: effectiveEnd,
            displayStart: current,
            displayEnd: blockEnd,
            isAllDay: isAllDay,
          ),
        );
        
        current = endOfCurrentDay;
      }
    }

    // 日ごとにグループ化してカラムレイアウトを計算
    final groupedByDay = groupBy(renderableEvents, (e) => DateUtils.dateOnly(e.displayStart));
    
    groupedByDay.forEach((day, eventsOnDay) {
      eventsOnDay.sort((a, b) => a.displayStart.compareTo(b.displayStart));
      
      final List<List<RenderableEvent>> columns = [];
      
      for (final event in eventsOnDay) {
        bool placed = false;
        
        // 既存のカラムで重複しないものを探す
        for (final col in columns) {
          if (!col.last.displayEnd.isAfter(event.displayStart)) {
            col.add(event);
            placed = true;
            break;
          }
        }
        
        // 重複しないカラムが見つからなければ新しいカラムを作成
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