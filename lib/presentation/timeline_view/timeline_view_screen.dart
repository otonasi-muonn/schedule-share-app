import 'package:flutter/material.dart';

class TimelineViewScreen extends StatefulWidget {
  const TimelineViewScreen({super.key});

  @override
  State<TimelineViewScreen> createState() => _TimelineViewScreenState();
}

class _TimelineViewScreenState extends State<TimelineViewScreen> {
  final ScrollController _scrollController = ScrollController();
  final double _hourHeight = 60.0; // 1時間あたりの高さを定義

  @override
  void dispose() {
    _scrollController.dispose();
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
              controller: _scrollController,
              itemCount: 7, // とりあえず7日分表示
              itemBuilder: (context, index) {
                final day = DateTime.now().add(Duration(days: index));
                return Container(
                  height: _hourHeight * 24, // 1日分の高さ
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        '${day.month}/${day.day}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

  // --- 時間軸を生成するウィジェット ---
  Widget _buildTimeRuler() {
    return SizedBox(
      width: 60, // 時間軸の幅
      child: ListView.builder(
        // 右側のリストとスクロールを同期させる
        controller: _scrollController,
        itemCount: 24, // 24時間分
        itemBuilder: (context, index) {
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
                '${index.toString().padLeft(2, '0')}:00', // 13:00のような24時間表記
              ),
            ),
          );
        },
      ),
    );
  }
}