import 'package:flutter/material.dart';

// アプリのエントリーポイント
void main() {
  runApp(const ScheduleApp());
}

class ScheduleApp extends StatelessWidget {
  const ScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Interactive Schedule',
      // モダンなダーク・ブルー系のテーマ設定
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE2E8F0),
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
      ),
      home: InteractiveSchedule(),
    );
  }
}

// --- ① スケジュールのデータモデル ---
class ScheduleEvent {
  final String id;
  String title;
  int startMin; // 0:00からの経過分 (例: 9:00 = 540)
  int endMin;   // 0:00からの経過分
  bool isOverlapping; // 重複フラグ

  ScheduleEvent({
    required this.id,
    required this.title,
    required this.startMin,
    required this.endMin,
    this.isOverlapping = false,
  });

  // 予定の長さ（分 = ピクセル）
  int get duration => endMin - startMin;
}

// --- メインのUIウィジェット ---
class InteractiveSchedule extends StatefulWidget {
  @override
  _InteractiveScheduleState createState() => _InteractiveScheduleState();
}

class _InteractiveScheduleState extends State<InteractiveSchedule> {
  // テスト用の初期データ
  List<ScheduleEvent> events = [
    ScheduleEvent(id: '1', title: '🍽️ 食事', startMin: 420, endMin: 480), // 7:00 - 8:00
    ScheduleEvent(id: '2', title: '📖 勉強', startMin: 540, endMin: 690), // 9:00 - 11:30
    ScheduleEvent(id: '3', title: '📦 荷物受け取り', startMin: 840, endMin: 1020), // 14:00 - 17:00
  ];

  final double pixelsPerMinute = 1.0; // 1分 = 1ピクセル

  @override
  void initState() {
    super.initState();
    _checkOverlaps();
  }

  // --- ② 重複チェックのロジック ---
  void _checkOverlaps() {
    for (var event in events) {
      event.isOverlapping = false;
    }

    for (int i = 0; i < events.length; i++) {
      for (int j = i + 1; j < events.length; j++) {
        var e1 = events[i];
        var e2 = events[j];
        
        // 重複判定
        if (e1.startMin < e2.endMin && e1.endMin > e2.startMin) {
          e1.isOverlapping = true;
          e2.isOverlapping = true;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('スケジュール調整')),
      // 縦スクロール
      body: SingleChildScrollView(
        child: SizedBox(
          height: 24 * 60 * pixelsPerMinute, // 24時間分の高さ
          child: Stack(
            children: [
              // --- 背景：時間軸の線 ---
              for (int i = 0; i <= 24; i++)
                Positioned(
                  top: i * 60 * pixelsPerMinute,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${i.toString().padLeft(2, '0')}:00',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ),
                      const Expanded(
                        child: Divider(color: Colors.black12, height: 1),
                      ),
                    ],
                  ),
                ),

              // --- 前景：予定ブロックの描画 ---
              ...events.map((event) => _buildEventBlock(event)),
            ],
          ),
        ),
      ),
    );
  }

  // --- ③ 予定ブロックのウィジェット（伸縮対応版） ---
  Widget _buildEventBlock(ScheduleEvent event) {
    const int minDuration = 15; // 最小の予定時間（15分）

    return Positioned(
      top: event.startMin * pixelsPerMinute,
      left: 70, // 時間軸テキストの右側に配置
      width: MediaQuery.of(context).size.width - 100, // 画面幅に合わせて伸縮
      height: event.duration * pixelsPerMinute,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade300, Colors.blue.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ],
          border: event.isOverlapping
              ? Border.all(color: Colors.redAccent, width: 3)
              : Border.all(color: Colors.white.withOpacity(0.5), width: 1),
        ),
        // Columnを使って、上部・中央・下部の3つのエリアに分ける
        child: Column(
          children: [
            // ==========================================
            // ① 上部の伸縮ハンドル（開始時間の変更）
            // ==========================================
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  int deltaMin = (details.delta.dy / pixelsPerMinute).round();
                  int newStart = event.startMin + deltaMin;

                  // 0:00より前に行かない ＆ 最小時間(15分)を保つガード
                  if (newStart >= 0 && (event.endMin - newStart) >= minDuration) {
                    event.startMin = newStart;
                    _checkOverlaps();
                  }
                });
              },
              child: Container(
                height: 15,
                color: Colors.transparent, // タッチ判定用
                child: Center(
                  // 視覚的な「つまみ」のUI
                  child: Container(
                    width: 30, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2)
                    ),
                  ),
                ),
              ),
            ),

            // ==========================================
            // ② 中央エリア（全体の移動）
            // ==========================================
            Expanded(
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    int deltaMin = (details.delta.dy / pixelsPerMinute).round();
                    int newStart = event.startMin + deltaMin;
                    int newEnd = event.endMin + deltaMin;

                    // 0:00〜24:00の範囲外に出ないようにガード
                    if (newStart >= 0 && newEnd <= 1440) {
                      event.startMin = newStart;
                      event.endMin = newEnd;
                      _checkOverlaps();
                    }
                  });
                },
                child: Container(
                  width: double.infinity,
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis, // はみ出し防止
                      ),
                      // ブロックが小さすぎるときは時間を非表示にする配慮
                      if (event.duration > 30) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${_formatTime(event.startMin)} - ${_formatTime(event.endMin)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),

            // ==========================================
            // ③ 下部の伸縮ハンドル（終了時間の変更）
            // ==========================================
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  int deltaMin = (details.delta.dy / pixelsPerMinute).round();
                  int newEnd = event.endMin + deltaMin;

                  // 24:00を超えない ＆ 最小時間(15分)を保つガード
                  if (newEnd <= 1440 && (newEnd - event.startMin) >= minDuration) {
                    event.endMin = newEnd;
                    _checkOverlaps();
                  }
                });
              },
              child: Container(
                height: 15,
                color: Colors.transparent, // タッチ判定用
                child: Center(
                  // 視覚的な「つまみ」のUI
                  child: Container(
                    width: 30, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2)
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 分(int)を "HH:MM" 形式の文字列に変換するヘルパー関数
  String _formatTime(int minutes) {
    int h = minutes ~/ 60;
    int m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}