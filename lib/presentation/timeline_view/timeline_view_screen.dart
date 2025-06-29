import 'package:flutter/material.dart';

class TimelineViewScreen extends StatefulWidget {
  const TimelineViewScreen({super.key});

  @override
  State<TimelineViewScreen> createState() => _TimelineViewScreenState();
}

class _TimelineViewScreenState extends State<TimelineViewScreen> {
  // --- MODIFIED! 2つのスクロールコントローラーを準備 ---
  final ScrollController _timeRulerController = ScrollController();
  final ScrollController _scheduleAreaController = ScrollController();
  final double _hourHeight = 60.0;
  final int _totalDays = 730; // 約2年分の日数を定義 (過去1年、未来1年)
  final int _initialDayIndex = 365; // リストの中での「今日」のインデックス

  @override
  void initState() {
    super.initState();
    // 2つのリストのスクロールを同期させる
    _timeRulerController.addListener(() {
      if (_scheduleAreaController.hasClients && _scheduleAreaController.offset != _timeRulerController.offset) {
        _scheduleAreaController.jumpTo(_timeRulerController.offset);
      }
    });
    _scheduleAreaController.addListener(() {
      if (_timeRulerController.hasClients && _timeRulerController.offset != _scheduleAreaController.offset) {
        _timeRulerController.jumpTo(_scheduleAreaController.offset);
      }
    });

    // --- NEW! 画面が開いたときに、「今日」の位置までスクロールする ---
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('タイムライン'),
      ),
      body: Row(
        children: [
          _buildTimeRuler(),
          Expanded(
            // --- MODIFIED! 過去の日付も表示できるようにロジックを変更 ---
            child: ListView.builder(
              controller: _scheduleAreaController,
              itemCount: _totalDays,
              itemBuilder: (context, index) {
                final startDate = DateTime.now().subtract(Duration(days: _initialDayIndex));
                final day = startDate.add(Duration(days: index));
                
                return Container(
                  height: _hourHeight * 24,
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        '${day.month}/${day.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          // 今日の日付を分かりやすくする
                          color: DateUtils.isSameDay(day, DateTime.now()) ? Colors.deepPurple : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRuler() {
    return SizedBox(
      width: 60,
      child: ListView.builder(
        controller: _timeRulerController,
        // --- MODIFIED! 時間軸も日数分生成する ---
        itemCount: 24 * _totalDays,
        itemBuilder: (context, index) {
          final hour = index % 24;
          return Container(
            height: _hourHeight,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Center(
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
              ),
            ),
          );
        },
      ),
    );
  }
}