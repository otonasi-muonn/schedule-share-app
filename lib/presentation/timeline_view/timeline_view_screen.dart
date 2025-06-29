import 'package:flutter/material.dart';

class TimelineViewScreen extends StatefulWidget {
  // ホーム画面から初期表示したい日付を受け取る
  final DateTime initialDate;

  const TimelineViewScreen({
    super.key,
    required this.initialDate,
  });

  @override
  State<TimelineViewScreen> createState() => _TimelineViewScreenState();
}

class _TimelineViewScreenState extends State<TimelineViewScreen> {
  late final ScrollController _scheduleAreaController;
  final double _hourHeight = 60.0;
  // --- MODIFIED! 表示する日数を限定する ---
  final int _numberOfDays = 5; // 表示する日数（今日、前後2日）

  @override
  void initState() {
    super.initState();
    // スクロールコントローラーを初期化
    _scheduleAreaController = ScrollController();

    // 画面が開いたときに、指定された日の位置までスクロールする
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 24時間 * 1時間あたりの高さ * 中央の日のインデックス
      final initialOffset = 24 * _hourHeight * 2; // 5日間のうちの中央(index 2)
      _scheduleAreaController.jumpTo(initialOffset);
    });
  }

  @override
  void dispose() {
    _scheduleAreaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('タイムライン'),
      ),
      // --- MODIFIED! 2つのリストを同期させるのではなく、Stackで重ねる ---
      body: StreamBuilder(
          // TODO: ここに後でFirestoreのStreamBuilderを復活させ、予定データを取得します
          stream: null, // 今はまだデータは表示しない
          builder: (context, snapshot) {
            return Stack(
              children: [
                // --- 右側の予定を描画するスクロールエリア ---
                _buildScheduleArea(),
                // --- 左側の時間軸 ---
                _buildTimeRuler(),
              ],
            );
          }),
    );
  }

  // --- 右側のメインエリア ---
  Widget _buildScheduleArea() {
    return Padding(
      // 時間軸の幅だけ左に余白を作る
      padding: const EdgeInsets.only(left: 60),
      child: ListView.builder(
        controller: _scheduleAreaController,
        // --- MODIFIED! 表示する日数を限定 ---
        itemCount: _numberOfDays,
        // --- NEW! あなたの提案通り、itemExtentで高さを固定し、パフォーマンスを向上 ---
        itemExtent: _hourHeight * 24,
        itemBuilder: (context, index) {
          final startDate = widget.initialDate.subtract(const Duration(days: 2));
          final day = startDate.add(Duration(days: index));

          // 1日ごとのコンテナと、時間ごとの区切り線を描画
          return Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Stack(
              children: [
                // 時間ごとの区切り線
                for (int hour = 1; hour < 24; hour++)
                  Positioned(
                    top: _hourHeight * hour,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: Colors.grey.shade200,
                    ),
                  ),
                // 日付の表示
                Align(
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
                // TODO: ここに予定ブロックを重ねて描画します
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 左側の時間軸 ---
  Widget _buildTimeRuler() {
    // スクロール状態を検知して、時間軸を再描画する
    return AnimatedBuilder(
      animation: _scheduleAreaController,
      builder: (context, child) {
        // 現在のスクロール位置から、表示すべき最初の時間を計算
        final topHour = _scheduleAreaController.hasClients
            ? (_scheduleAreaController.offset / _hourHeight).floor()
            : 0;

        return SizedBox(
          width: 60,
          child: Stack(
            children: [
              for (int i = 0; i < 24; i++)
                Positioned(
                  top: (i * _hourHeight) - (_scheduleAreaController.hasClients ? _scheduleAreaController.offset : 0) + (topHour * _hourHeight),
                  child: Container(
                    height: _hourHeight,
                    width: 60,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                        right: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${i.toString().padLeft(2, '0')}:00',
                      ),
                    ),
                  ),
                )
            ],
          ),
        );
      },
    );
  }
}