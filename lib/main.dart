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
  
  int preDragStartMin = 0;
  int preDragEndMin = 0;

  ScheduleEvent({
    required this.id,
    required this.title,
    required this.startMin,
    required this.endMin,
  });

  int get duration => endMin - startMin;
}

class InteractiveSchedule extends StatefulWidget {
  @override
  _InteractiveScheduleState createState() => _InteractiveScheduleState();
}

class _InteractiveScheduleState extends State<InteractiveSchedule> {
  final int snapInterval = 1;
  final double pixelsPerMinute = 1.0;

  String? draggingId;

  List<ScheduleEvent> events = [
    ScheduleEvent(id: '1', title: '🍽️ 朝食', startMin: 420, endMin: 480),
    ScheduleEvent(id: '2', title: '📖 勉強', startMin: 540, endMin: 660),
    ScheduleEvent(id: '3', title: '📦 荷物待ち', startMin: 840, endMin: 1020),
  ];

  int _snap(int minutes) => (minutes / snapInterval).round() * snapInterval;

  // ▼ 完全修正版：押し出しロジック ▼
  void _resolvePushing(ScheduleEvent movingEvent, bool pushedForward) {
    if (pushedForward) {
      // 下に伸ばす時：開始時間の早い順（上から下）に連鎖させる
      events.sort((a, b) => a.startMin.compareTo(b.startMin));
      for (int i = 0; i < events.length; i++) {
        for (int j = i + 1; j < events.length; j++) {
          if (events[i].endMin > events[j].startMin) {
            int overlap = events[i].endMin - events[j].startMin;
            events[j].startMin += overlap;
            events[j].endMin += overlap;
          }
        }
      }
    } else {
      // 上に伸ばす時：終了時間の遅い順（下から上）に連鎖させる
      // ※上に伸ばしても終了時間は変わらないので、計算順序が途中で狂わない！
      events.sort((a, b) => b.endMin.compareTo(a.endMin));
      for (int i = 0; i < events.length; i++) {
        for (int j = i + 1; j < events.length; j++) {
          if (events[i].startMin < events[j].endMin) {
            int overlap = events[j].endMin - events[i].startMin;
            events[j].startMin -= overlap;
            events[j].endMin -= overlap;
          }
        }
      }
    }
    
    // 0:00 〜 24:00 を超えないための壁ガード
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
  }

  // 自動回避ロジック（そのまま）
  int? _findFreeSpaceAbove(ScheduleEvent event) {
    int targetEnd = event.startMin;
    int dur = event.duration;

    var others = events.where((e) => e.id != event.id).toList();
    others.sort((a, b) => b.endMin.compareTo(a.endMin));

    while (targetEnd - dur >= 0) {
      int proposedStart = targetEnd - dur;
      int proposedEnd = targetEnd;
      bool conflict = false;

      for (var e in others) {
        if (proposedStart < e.endMin && proposedEnd > e.startMin) {
          conflict = true;
          targetEnd = e.startMin;
          break;
        }
      }
      if (!conflict) return proposedStart;
    }
    return null;
  }

  void _bringToFront(ScheduleEvent event) {
    setState(() {
      events.remove(event);
      events.add(event);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('上下の完全連鎖アップデート')),
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
              ...events.map((event) => _buildEventBlock(event)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventBlock(ScheduleEvent event) {
    const int minDuration = 5; 
    bool isDragging = draggingId == event.id;

    return Positioned(
      key: ValueKey(event.id),
      top: event.startMin * pixelsPerMinute,
      left: 70,
      width: MediaQuery.of(context).size.width - 100,
      height: event.duration * pixelsPerMinute,
      child: Listener(
        onPointerDown: (_) => _bringToFront(event),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isDragging ? 0.6 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade600]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Column(
              children: [
                // ① 上端：開始時間を伸ばす
                GestureDetector(
                  onPanStart: (_) => setState(() => draggingId = event.id),
                  onPanEnd: (_) => setState(() => draggingId = null),
                  onPanCancel: () => setState(() => draggingId = null),
                  onPanUpdate: (details) {
                    setState(() {
                      int newStart = _snap(event.startMin + (details.delta.dy / pixelsPerMinute).round());
                      if (newStart >= 0 && newStart <= event.endMin - minDuration) {
                        event.startMin = newStart;
                        _resolvePushing(event, false); // 上への連鎖呼び出し
                      }
                    });
                  },
                  child: _buildHandle(isTop: true),
                ),
                
                // ② 中央：移動（ドロップ時の自動回避）
                Expanded(
                  child: GestureDetector(
                    onPanStart: (_) {
                      setState(() {
                        draggingId = event.id;
                        event.preDragStartMin = event.startMin;
                        event.preDragEndMin = event.endMin;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        int delta = (details.delta.dy / pixelsPerMinute).round();
                        int newStart = _snap(event.startMin + delta);
                        int dur = event.duration;
                        if (newStart >= 0 && newStart + dur <= 1440) {
                          event.startMin = newStart;
                          event.endMin = newStart + dur;
                        }
                      });
                    },
                    onPanEnd: (_) {
                      setState(() {
                        draggingId = null;
                        bool overlaps = events.any((e) => 
                          e.id != event.id && event.startMin < e.endMin && event.endMin > e.startMin
                        );

                        if (overlaps) {
                          int? newStart = _findFreeSpaceAbove(event);
                          if (newStart != null) {
                            event.startMin = newStart;
                            event.endMin = newStart + event.duration;
                          } else {
                            event.startMin = event.preDragStartMin;
                            event.endMin = event.preDragEndMin;
                          }
                        }
                      });
                    },
                    onPanCancel: () => setState(() => draggingId = null),
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

                // ③ 下端：終了時間を伸ばす
                GestureDetector(
                  onPanStart: (_) => setState(() => draggingId = event.id),
                  onPanEnd: (_) => setState(() => draggingId = null),
                  onPanCancel: () => setState(() => draggingId = null),
                  onPanUpdate: (details) {
                    setState(() {
                      int newEnd = _snap(event.endMin + (details.delta.dy / pixelsPerMinute).round());
                      if (newEnd <= 1440 && newEnd >= event.startMin + minDuration) {
                        event.endMin = newEnd;
                        _resolvePushing(event, true); // 下への連鎖呼び出し
                      }
                    });
                  },
                  child: _buildHandle(isTop: false),
                ),
              ],
            ),
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