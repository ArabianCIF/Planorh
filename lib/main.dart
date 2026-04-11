import 'package:flutter/material.dart';

void main() {
  runApp(const ScheduleApp());
}

class ScheduleApp extends StatelessWidget {
  const ScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE2E8F0),
          foregroundColor: Colors.black87,
        ),
      ),
      home: InteractiveSchedule(),
    );
  }
}

class ScheduleEvent {
  final String id;
  String title;
  int startMin;
  int endMin;
  bool isOverlapping;

  ScheduleEvent({
    required this.id,
    required this.title,
    required this.startMin,
    required this.endMin,
    this.isOverlapping = false,
  });

  int get duration => endMin - startMin;
}

class InteractiveSchedule extends StatefulWidget {
  @override
  _InteractiveScheduleState createState() => _InteractiveScheduleState();
}

class _InteractiveScheduleState extends State<InteractiveSchedule> {
  final int snapInterval = 1; // 1分間隔
  final double pixelsPerMinute = 1.0;

  List<ScheduleEvent> events = [
    ScheduleEvent(id: '1', title: '🍽️ 朝食', startMin: 420, endMin: 480),
    ScheduleEvent(id: '2', title: '📖 勉強', startMin: 540, endMin: 660),
    ScheduleEvent(id: '3', title: '📦 荷物待ち', startMin: 840, endMin: 1020),
  ];

  @override
  void initState() {
    super.initState();
    _checkOverlaps();
  }

  void _checkOverlaps() {
    for (var event in events) {
      event.isOverlapping = false;
    }
    for (int i = 0; i < events.length; i++) {
      for (int j = i + 1; j < events.length; j++) {
        if (events[i].startMin < events[j].endMin && events[i].endMin > events[j].startMin) {
          events[i].isOverlapping = true;
          events[j].isOverlapping = true;
        }
      }
    }
  }

  int _snap(int minutes) => (minutes / snapInterval).round() * snapInterval;

  // 押し出し処理（上下の時間を伸ばした時のみ発動）
  void _resolvePushing(ScheduleEvent movingEvent, bool pushedForward) {
    events.sort((a, b) => a.startMin.compareTo(b.startMin));

    if (pushedForward) {
      for (int i = 0; i < events.length; i++) {
        for (int j = 0; j < events.length; j++) {
          if (events[i] == events[j]) continue;
          if (events[i].endMin > events[j].startMin && events[i].startMin < events[j].startMin) {
            int overlap = events[i].endMin - events[j].startMin;
            events[j].startMin += overlap;
            events[j].endMin += overlap;
          }
        }
      }
    } else {
      for (int i = events.length - 1; i >= 0; i--) {
        for (int j = events.length - 1; j >= 0; j--) {
          if (events[i] == events[j]) continue;
          if (events[i].startMin < events[j].endMin && events[i].endMin > events[j].endMin) {
            int overlap = events[j].endMin - events[i].startMin;
            events[j].startMin -= overlap;
            events[j].endMin -= overlap;
          }
        }
      }
    }
    
    for (var e in events) {
      if (e.startMin < 0) {
        int diff = -e.startMin;
        e.startMin += diff;
        e.endMin += diff;
      }
      if (e.endMin > 1440) {
        int diff = e.endMin - 1440;
        e.startMin -= diff;
        e.endMin -= diff;
      }
    }
    _checkOverlaps();
  }

  // ブロックを最前面に持ってくる処理
  void _bringToFront(ScheduleEvent event) {
    setState(() {
      events.remove(event);
      events.add(event);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('重なり・入れ替え対応版')),
      body: SingleChildScrollView(
        child: SizedBox(
          height: 24 * 60 * pixelsPerMinute,
          child: Stack(
            children: [
              for (int i = 0; i <= 24; i++)
                Positioned(
                  top: i * 60 * pixelsPerMinute,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      SizedBox(width: 60, child: Text('${i.toString().padLeft(2, '0')}:00', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 12))),
                      const Expanded(child: Divider(color: Colors.black12, height: 1)),
                    ],
                  ),
                ),
              // ウィジェットの再構築時にドラッグがキャンセルされないよう、map内で完結させる
              ...events.map((event) => _buildEventBlock(event)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventBlock(ScheduleEvent event) {
    const int minDuration = 5; 

    return Positioned(
      // ▼ 重要: リストの順番が変わってもFlutterが同一ウィジェットと認識できるようにKeyを設定
      key: ValueKey(event.id),
      top: event.startMin * pixelsPerMinute,
      left: 70,
      width: MediaQuery.of(context).size.width - 100,
      height: event.duration * pixelsPerMinute,
      // ▼ 追加: タッチした瞬間に最前面へ移動させるListener
      child: Listener(
        onPointerDown: (_) => _bringToFront(event),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade600]),
            borderRadius: BorderRadius.circular(12),
            border: event.isOverlapping ? Border.all(color: Colors.redAccent, width: 3) : null,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Column(
            children: [
              // ① 上端：開始時間を伸ばす（押し出しあり）
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    int newStart = _snap(event.startMin + (details.delta.dy / pixelsPerMinute).round());
                    if (newStart >= 0 && newStart <= event.endMin - minDuration) {
                      event.startMin = newStart;
                      _resolvePushing(event, false);
                    }
                  });
                },
                child: _buildHandle(isTop: true),
              ),
              
              // ② 中央：移動（押し出しなし・自由配置OK）
              Expanded(
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      int delta = (details.delta.dy / pixelsPerMinute).round();
                      int newStart = _snap(event.startMin + delta);
                      int dur = event.duration;
                      if (newStart >= 0 && newStart + dur <= 1440) {
                        event.startMin = newStart;
                        event.endMin = newStart + dur;
                        // 単純移動なので押し出しは行わず、重なり判定のみ更新
                        _checkOverlaps(); 
                      }
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    color: Colors.transparent,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            event.title, 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
                          ),
                          if (event.duration > 20) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${_formatTime(event.startMin)} - ${_formatTime(event.endMin)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ]
                        ],
                      )
                    ),
                  ),
                ),
              ),

              // ③ 下端：終了時間を伸ばす（押し出しあり）
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    int newEnd = _snap(event.endMin + (details.delta.dy / pixelsPerMinute).round());
                    if (newEnd <= 1440 && newEnd >= event.startMin + minDuration) {
                      event.endMin = newEnd;
                      _resolvePushing(event, true);
                    }
                  });
                },
                child: _buildHandle(isTop: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle({required bool isTop}) {
    return Container(
      height: 18,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black26, 
        borderRadius: isTop
            ? const BorderRadius.vertical(top: Radius.circular(12))
            : const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2)
          )
        )
      )
    );
  }

  String _formatTime(int minutes) {
    int h = minutes ~/ 60;
    int m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}