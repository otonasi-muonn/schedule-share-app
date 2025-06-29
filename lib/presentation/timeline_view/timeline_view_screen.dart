import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

class TimelineViewScreen extends StatefulWidget {
  const TimelineViewScreen({super.key});

  @override
  State<TimelineViewScreen> createState() => _TimelineViewScreenState();
}

class _TimelineViewScreenState extends State<TimelineViewScreen> {
  // --- NEW! スクロールコントローラーをグループ化して準備 ---
  late final LinkedScrollControllerGroup _scrollControllerGroup;
  late final ScrollController _timeRulerController;
  late final ScrollController _scheduleAreaController;

  final double _hourHeight = 60.0;
  final int _totalDays = 730; // 約2年分の日数を定義 (過去1年、未来1年)
  final int _initialDayIndex = 365; // リストの中での「今日」のインデックス

  @override
  void initState() {
    super.initState();
    // --- NEW! グループからコントローラーを作成 ---
    _scrollControllerGroup = LinkedScrollControllerGroup();
    _timeRulerController = _scrollControllerGroup.addAndGet();
    _scheduleAreaController = _scrollControllerGroup.addAndGet();

    // 画面が開いたときに、「今日」の位置までスクロールする
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 24時間 * 1時間あたりの高さ * 今日のインデックス
      final initialOffset = 24 * _hourHeight * _initialDayIndex;
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
          // --- 左側の時間軸 ---
          _buildTimeRuler(),

          // --- 右側の予定を描画するスクロールエリア ---
          Expanded(
            child: ListView.builder(
              controller: _scheduleAreaController, // こちらにコントローラーをセット
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
                          color: DateUtils.isSameDay(day, DateTime.now()) ? Colors.deepPurple : null,
                        ),
                      ),
                    ),
                  ),
                  // TODO: ここに後で、Stackを使って予定ブロックを重ねて描画します
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
        controller: _timeRulerController, // こちらにもコントローラーをセット
        itemBuilder: (context, index) {
          // 1日24時間なので、24で割った余りが時間になる
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
                // 0時だけは日付も表示する
                hour == 0 ? '' : '${hour.toString().padLeft(2, '0')}:00',
              ),
            ),
          );
        },
      ),
    );
  }
}