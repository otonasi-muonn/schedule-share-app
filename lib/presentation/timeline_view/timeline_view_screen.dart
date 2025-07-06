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

  RenderableEvent({
    required this.doc,
    required this.originalStart,
    required this.originalEnd,
    required this.displayStart,
    required this.displayEnd,
    this.column = 0,
    this.totalColumns = 1,
  });

  bool get isFirstPart => displayStart.isAtSameMomentAs(originalStart);
  bool get isLastPart => displayEnd.isAtSameMomentAs(originalEnd);
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
  List<DateTime> _loadedDays = [];
  bool _isLoadingTop = false;
  bool _isLoadingBottom = false;
  late final ValueNotifier<DateTime> _appBarDateNotifier;
  Timer? _currentTimeTimer;

  @override
  void initState() {
    super.initState();
    _appBarDateNotifier = ValueNotifier(widget.initialDate);
    _loadInitialDays();

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToInitialPosition());

    _scrollController.addListener(_scrollListener);

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

  void _loadInitialDays() {
    _loadedDays.clear();
    final baseDate = DateUtils.dateOnly(widget.initialDate);
    // 初期表示を約1ヶ月に
    for (int i = -15; i <= 15; i++) {
      _loadedDays.add(baseDate.add(Duration(days: i)));
    }
  }

  void _scrollToInitialPosition() {
    if (!mounted || !_scrollController.hasClients) return;
    final initialDayIndex = _loadedDays.indexWhere((day) => DateUtils.isSameDay(day, widget.initialDate));
    if (initialDayIndex != -1) {
      final initialOffset = (initialDayIndex * _hourHeight * 24) + (_hourHeight * 7);
      _scrollController.jumpTo(initialOffset);
    }
  }

  void _scrollListener() {
    if (!mounted || !_scrollController.hasClients) return;
    _updateAppBarDate();
    if (!_isLoadingBottom && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 1000) {
      _loadMoreDays(isTop: false);
    }
    if (!_isLoadingTop && _scrollController.position.pixels <= 1000) {
      _loadMoreDays(isTop: true);
    }
  }

  void _updateAppBarDate() {
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
    if (isTop ? _isLoadingTop : _isLoadingBottom) return;
    setState(() {
      if (isTop) _isLoadingTop = true;
      else _isLoadingBottom = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      if (isTop) {
        final firstDay = _loadedDays.first;
        final newDays = [for (int i = 7; i >= 1; i--) firstDay.subtract(Duration(days: i))];
        _loadedDays.insertAll(0, newDays);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.offset + (7 * _hourHeight * 24));
          }
        });
        _isLoadingTop = false;
      } else {
        final lastDay = _loadedDays.last;
        for (int i = 1; i <= 7; i++) {
          _loadedDays.add(lastDay.add(Duration(days: i)));
        }
        _isLoadingBottom = false;
      }
    });
  }
  
  void _scrollToToday() {
    final today = DateUtils.dateOnly(DateTime.now());
    final todayIndex = _loadedDays.indexWhere((day) => DateUtils.isSameDay(day, today));
    if (todayIndex != -1) {
      final targetOffset = (todayIndex * _hourHeight * 24) + (_hourHeight * DateTime.now().hour);
      _scrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
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
        actions: [IconButton(icon: const Icon(Icons.today), tooltip: '今日に移動', onPressed: _scrollToToday)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('schedules').where('userId', isEqualTo: user?.uid).snapshots(),
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
              if (_isLoadingTop) const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildTimeSlot(index, allRenderableEvents),
                  childCount: _loadedDays.length * 24,
                ),
              ),
              if (_isLoadingBottom) const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showScheduleDialog(context, initialDate: _appBarDateNotifier.value),
        tooltip: '予定を追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTimeSlot(int index, List<RenderableEvent> allRenderableEvents) {
    final dayIndex = index ~/ 24;
    final hour = index % 24;
    if (dayIndex >= _loadedDays.length) return const SizedBox.shrink();
    
    final day = _loadedDays[dayIndex];
    final slotStart = DateTime(day.year, day.month, day.day, hour);
    final slotEnd = slotStart.add(const Duration(hours: 1));
    
    final eventsInSlot = allRenderableEvents.where((event) => event.displayStart.isBefore(slotEnd) && event.displayEnd.isAfter(slotStart)).toList();

    return SizedBox(
      height: _hourHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, height: _hourHeight, child: Center(child: Text('${hour.toString().padLeft(2, '0')}:00', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)))),
          Expanded(
            child: Stack(
              children: [
                Container(decoration: BoxDecoration(border: Border(top: BorderSide(color: hour == 0 ? Colors.grey.shade400 : Colors.grey.shade200, width: hour == 0 ? 1.5 : 0.5), left: BorderSide(color: Colors.grey.shade300)))),
                ..._buildEventBlocks(eventsInSlot, slotStart, slotEnd),
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
    if (now.isBefore(slotStart) || now.isAfter(slotEnd)) return [];
    final topOffset = (now.difference(slotStart).inMinutes / 60.0) * _hourHeight;
    return [Positioned(top: topOffset - 1, left: -8, right: 0, child: IgnorePointer(child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.red[700], shape: BoxShape.circle)), Expanded(child: Container(height: 2, color: Colors.red[700]))])))];
  }

  List<Widget> _buildEventBlocks(List<RenderableEvent> events, DateTime slotStart, DateTime slotEnd) {
    final availableWidth = MediaQuery.of(context).size.width - 60;
    return events.map((event) {
      final data = event.doc.data() as Map<String, dynamic>;
      final blockStart = event.displayStart.isAfter(slotStart) ? event.displayStart : slotStart;
      final blockEnd = event.displayEnd.isBefore(slotEnd) ? event.displayEnd : slotEnd;
      final topOffset = (blockStart.difference(slotStart).inMinutes / 60.0) * _hourHeight;
      final height = (blockEnd.difference(blockStart).inMinutes / 60.0) * _hourHeight;
      if (height <= 0) return const SizedBox.shrink();

      final columnWidth = availableWidth / event.totalColumns;
      final leftOffset = event.column * columnWidth;

      final isTopRounded = event.isFirstPart && event.displayStart.isAtSameMomentAs(blockStart);
      final isBottomRounded = event.isLastPart && event.displayEnd.isAtSameMomentAs(blockEnd);
      
      // 修正: タイトルを表示するかどうかの判定を改善
      // 元の予定の最初の部分かつ、現在の表示ブロックが実際に予定の開始時刻を含んでいる場合のみ表示
      final shouldShowTitle = event.isFirstPart && event.displayStart.isAtSameMomentAs(blockStart);

      return Positioned(
        top: topOffset, left: leftOffset, width: columnWidth, height: height,
        child: GestureDetector(
          onTap: () => showScheduleDialog(context, scheduleDoc: event.doc),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.vertical(
                top: isTopRounded ? const Radius.circular(6) : Radius.zero,
                bottom: isBottomRounded ? const Radius.circular(6) : Radius.zero,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: shouldShowTitle
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
                        if (height > 30) Text('${DateFormat.Hm().format(event.originalStart)} - ${DateFormat.Hm().format(event.originalEnd)}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 10), overflow: TextOverflow.ellipsis, maxLines: 1),
                      ],
                    )
                  : null,
            ),
          ),
        ),
      );
    }).toList();
  }
  
  List<RenderableEvent> _calculateLayout(List<QueryDocumentSnapshot> allDocs) {
    List<RenderableEvent> renderableEvents = [];
    final timeEvents = allDocs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final isAllDay = data['isAllDay'] as bool? ?? false;
      final start = data['startTime'] as Timestamp?;
      final end = data['endTime'] as Timestamp?;
      if (isAllDay || start == null || end == null) return null;
      return {'doc': doc, 'start': start.toDate(), 'end': end.toDate()};
    }).whereType<Map<String, dynamic>>().toList();
    
    timeEvents.sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));

    for (final event in timeEvents) {
      final start = event['start'] as DateTime;
      final end = event['end'] as DateTime;
      final effectiveEnd = start.isAtSameMomentAs(end) ? start.add(const Duration(minutes: 30)) : end;
      
      var current = start;
      while (current.isBefore(effectiveEnd)) {
        final endOfCurrentDay = DateUtils.dateOnly(current).add(const Duration(days: 1));
        final blockEnd = effectiveEnd.isBefore(endOfCurrentDay) ? effectiveEnd : endOfCurrentDay;
        renderableEvents.add(RenderableEvent(doc: event['doc'], originalStart: start, originalEnd: effectiveEnd, displayStart: current, displayEnd: blockEnd));
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