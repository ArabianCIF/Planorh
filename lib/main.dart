import 'package:flutter/material.dart';
import 'dart:math';

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
        scaffoldBackgroundColor: const Color(0xFF17181C),
        fontFamily: 'Roboto',
      ),
      home: const InteractiveSchedule(),
    );
  }
}

class ScheduleEvent {
  final String id;
  String title;
  IconData icon;
  Color color;
  int startMin;
  int endMin;
  
  // 入れ替え先を記憶する「スロット」の役割
  int baselineStartMin = 0;

  ScheduleEvent({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.startMin,
    required this.endMin,
  }) : baselineStartMin = startMin;

  int get duration => endMin - startMin;

  ScheduleEvent clone() {
    return ScheduleEvent(
      id: id,
      title: title,
      icon: icon,
      color: color,
      startMin: startMin,
      endMin: endMin,
    )..baselineStartMin = baselineStartMin;
  }
}

class InteractiveSchedule extends StatefulWidget {
  const InteractiveSchedule({super.key});

  @override
  State<InteractiveSchedule> createState() => _InteractiveScheduleState();
}

class _InteractiveScheduleState extends State<InteractiveSchedule> {
  final int snapInterval = 1; 
  final double pixelsPerMinute = 1.0;
  final int globalMinDuration = 10; 

  String? draggingId;
  bool isDoubleClickMode = false;
  
  DateTime? lastTapTime;
  String? lastTapEventId;

  Map<String, ScheduleEvent> preDragState = {};
  double dragStartGlobalY = 0.0;

  List<ScheduleEvent> events = [
    ScheduleEvent(id: '1', title: 'Morning Task (朝食)', icon: Icons.wb_sunny_outlined, color: const Color(0xFF4A89DC), startMin: 480, endMin: 600),
    ScheduleEvent(id: '2', title: 'Deep Work (勉強)', icon: Icons.psychology_outlined, color: const Color(0xFF8CC152), startMin: 660, endMin: 780),
    ScheduleEvent(id: '3', title: 'Meeting (荷物待ち)', icon: Icons.people_outline, color: const Color(0xFFF6BB42), startMin: 840, endMin: 930),
  ];

  int _snap(int minutes) => (minutes / snapInterval).round() * snapInterval;

  double get busyHours => events.fold(0, (sum, event) => sum + event.duration) / 60.0;
  double get freeHours => 24.0 - busyHours;

  void _onPointerDown(PointerDownEvent details, ScheduleEvent event) {
    final now = DateTime.now();
    if (lastTapTime != null && 
        now.difference(lastTapTime!) < const Duration(milliseconds: 300) &&
        lastTapEventId == event.id) {
      isDoubleClickMode = true;
    } else {
      isDoubleClickMode = false;
    }
    lastTapTime = now;
    lastTapEventId = event.id;
  }

  // ドラッグ終了時の後処理（配列の整合性を保つ）
  void _onDragEnd() {
    setState(() {
      events.sort((a, b) => a.startMin.compareTo(b.startMin));
      for (var e in events) {
        e.baselineStartMin = e.startMin;
      }
      draggingId = null;
      preDragState.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedEvents = List<ScheduleEvent>.from(events)
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    List<Widget> eventWidgets = [];
    Widget? draggingWidget;
    
    for (var event in sortedEvents) {
      if (event.id == draggingId) {
        draggingWidget = _buildEventBlock(event);
      } else {
        eventWidgets.add(_buildEventBlock(event));
      }
    }
    if (draggingWidget != null) eventWidgets.add(draggingWidget);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
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
                              SizedBox(
                                width: 60, 
                                child: Text(
                                  '${i.toString().padLeft(2, '0')}:00', 
                                  textAlign: TextAlign.center, 
                                  style: const TextStyle(color: Colors.white54, fontSize: 12)
                                )
                              ),
                              const Expanded(child: Divider(color: Colors.white10, height: 1)),
                            ],
                          ),
                        ),
                      ...eventWidgets,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10, width: 1))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Advanced Scheduler',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Row(
                children: [
                  _buildStatItem('BUSY TIME', '${busyHours.toStringAsFixed(1)} hrs'),
                  const SizedBox(width: 20),
                  _buildStatItem('FREE SPACE', '${freeHours.toStringAsFixed(1)} hrs'),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
            Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('シングルタップ: 連動移動(縮み)   |   ダブルタップ: 入れ替え(すり抜け)', 
                style: TextStyle(color: Colors.white54, fontSize: 12)
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60, letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildEventBlock(ScheduleEvent event) {
    bool isDragging = draggingId == event.id;

    return AnimatedPositioned(
      key: ValueKey(event.id),
      duration: isDragging ? Duration.zero : const Duration(milliseconds: 200), 
      curve: Curves.easeOutCubic,
      top: event.startMin * pixelsPerMinute,
      height: event.duration * pixelsPerMinute,
      left: 70,
      width: MediaQuery.of(context).size.width - 100,
      child: Listener(
        onPointerDown: (details) => _onPointerDown(details, event),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isDragging ? 0.7 : 1.0,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: event.color.withOpacity(0.15),
                    border: Border.all(color: event.color, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(event.icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event.title, 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (event.duration > 20) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_formatTime(event.startMin)} - ${_formatTime(event.endMin)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ]
                    ],
                  ),
                ),
              ),

              // 中央エリア（全体移動用）
              Positioned(
                top: 15, bottom: 15, left: 0, right: 0,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      draggingId = event.id;
                      dragStartGlobalY = details.globalPosition.dy;
                      for (var e in events) {
                        e.baselineStartMin = e.startMin;
                      }
                      preDragState = { for (var e in events) e.id: e.clone() };
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      int totalDelta = ((details.globalPosition.dy - dragStartGlobalY) / pixelsPerMinute).round();

                      if (isDoubleClickMode) {
                        // 【ダブルタップ並び替え】
                        int newStart = _snap(preDragState[event.id]!.startMin + totalDelta);
                        int dur = preDragState[event.id]!.duration;
                        
                        if (newStart < 0) newStart = 0;
                        if (newStart + dur > 1440) newStart = 1440 - dur;
                        
                        event.startMin = newStart;
                        event.endMin = newStart + dur;

                        double movingCenter = event.startMin + dur / 2;
                        
                        for (var other in events) {
                          if (other.id == event.id) continue;
                          double otherCenter = other.baselineStartMin + other.duration / 2;

                          // 相手の中間線を越えたら位置を入れ替える（全体の枠を崩さずに綺麗に収める）
                          if (movingCenter > otherCenter && event.baselineStartMin < other.baselineStartMin) {
                            int totalSpanStart = min(event.baselineStartMin, other.baselineStartMin);
                            int totalSpanEnd = max(event.baselineStartMin + dur, other.baselineStartMin + other.duration);

                            other.baselineStartMin = totalSpanStart;
                            other.startMin = other.baselineStartMin;
                            other.endMin = other.startMin + other.duration;

                            event.baselineStartMin = totalSpanEnd - dur;
                          } else if (movingCenter < otherCenter && event.baselineStartMin > other.baselineStartMin) {
                            int totalSpanStart = min(event.baselineStartMin, other.baselineStartMin);
                            int totalSpanEnd = max(event.baselineStartMin + dur, other.baselineStartMin + other.duration);

                            event.baselineStartMin = totalSpanStart;
                            
                            other.baselineStartMin = totalSpanEnd - other.duration;
                            other.startMin = other.baselineStartMin;
                            other.endMin = other.startMin + other.duration;
                          }
                        }

                      } else {
                        // 【シングルタップ通常移動】
                        for (int i = 0; i < events.length; i++) {
                          events[i].startMin = preDragState[events[i].id]!.startMin;
                          events[i].endMin = preDragState[events[i].id]!.endMin;
                        }

                        int dragIndex = events.indexWhere((e) => e.id == draggingId);
                        if (dragIndex == -1) return;

                        ScheduleEvent dragged = events[dragIndex];
                        ScheduleEvent preDrag = preDragState[dragged.id]!;
                        
                        int newStart = _snap(preDrag.startMin + totalDelta);
                        int dur = preDrag.duration;

                        if (newStart < 0) newStart = 0;
                        if (newStart + dur > 1440) newStart = 1440 - dur;

                        dragged.startMin = newStart;
                        dragged.endMin = newStart + dur;

                        // 上のブロック（B）を押し出し＆Cの壁で縮む処理
                        if (dragIndex > 0) {
                          var prev = events[dragIndex - 1];
                          var prePrev = preDragState[prev.id]!;
                          int minBound = (dragIndex > 1) ? events[dragIndex - 2].endMin : 0; // Cの壁
                          
                          if (dragged.startMin < prePrev.endMin) {
                            prev.endMin = min(prePrev.endMin, dragged.startMin);
                            int idealStart = min(prePrev.startMin, prev.endMin - globalMinDuration);
                            prev.startMin = max(idealStart, minBound);
                            if (prev.endMin - prev.startMin < globalMinDuration) {
                              prev.endMin = prev.startMin + globalMinDuration;
                            }
                          }
                        }

                        // 下のブロック（B）を押し出し＆Cの壁で縮む処理
                        if (dragIndex < events.length - 1) {
                          var next = events[dragIndex + 1];
                          var preNext = preDragState[next.id]!;
                          int maxBound = (dragIndex < events.length - 2) ? events[dragIndex + 2].startMin : 1440; // Cの壁
                          
                          if (dragged.endMin > preNext.startMin) {
                            next.startMin = max(preNext.startMin, dragged.endMin);
                            int idealEnd = max(preNext.endMin, next.startMin + globalMinDuration);
                            next.endMin = min(idealEnd, maxBound);
                            if (next.endMin - next.startMin < globalMinDuration) {
                              next.startMin = next.endMin - globalMinDuration;
                            }
                          }
                        }
                      }
                    });
                  },
                  onPanEnd: (_) {
                    setState(() {
                      if (isDoubleClickMode) {
                        event.startMin = event.baselineStartMin;
                        event.endMin = event.startMin + preDragState[event.id]!.duration;
                      }
                    });
                    _onDragEnd();
                  },
                  onPanCancel: _onDragEnd,
                  child: Container(color: Colors.transparent),
                ),
              ),

              // ① 上端ハンドル（リサイズ用）
              Positioned(
                top: -10, left: 0, right: 0, height: 30,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      draggingId = event.id;
                      dragStartGlobalY = details.globalPosition.dy;
                      preDragState = { for (var e in events) e.id: e.clone() };
                    });
                  },
                  onPanUpdate: (details) {
                    if (isDoubleClickMode) return; 
                    setState(() {
                      int totalDelta = ((details.globalPosition.dy - dragStartGlobalY) / pixelsPerMinute).round();
                      
                      for (int i = 0; i < events.length; i++) {
                        events[i].startMin = preDragState[events[i].id]!.startMin;
                        events[i].endMin = preDragState[events[i].id]!.endMin;
                      }
                      
                      int dragIndex = events.indexWhere((e) => e.id == draggingId);
                      if (dragIndex == -1) return;
                      ScheduleEvent dragged = events[dragIndex];
                      ScheduleEvent preDrag = preDragState[dragged.id]!;
                      
                      int newStart = _snap(preDrag.startMin + totalDelta);
                      int minAllowed = (dragIndex > 0) ? events[dragIndex - 1].endMin : 0;
                      int maxAllowed = preDrag.endMin - globalMinDuration;

                      if (newStart < minAllowed) newStart = minAllowed;
                      if (newStart > maxAllowed) newStart = maxAllowed;

                      dragged.startMin = newStart;
                    });
                  },
                  onPanEnd: (_) => _onDragEnd(),
                  onPanCancel: _onDragEnd,
                  child: Container(
                    color: Colors.transparent,
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(width: 10, height: 10, decoration: BoxDecoration(color: event.color, shape: BoxShape.circle)),
                  ),
                ),
              ),

              // ③ 下端ハンドル（リサイズ用）
              Positioned(
                bottom: -10, left: 0, right: 0, height: 30,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      draggingId = event.id;
                      dragStartGlobalY = details.globalPosition.dy;
                      preDragState = { for (var e in events) e.id: e.clone() };
                    });
                  },
                  onPanUpdate: (details) {
                    if (isDoubleClickMode) return; 
                    setState(() {
                      int totalDelta = ((details.globalPosition.dy - dragStartGlobalY) / pixelsPerMinute).round();
                      
                      for (int i = 0; i < events.length; i++) {
                        events[i].startMin = preDragState[events[i].id]!.startMin;
                        events[i].endMin = preDragState[events[i].id]!.endMin;
                      }
                      
                      int dragIndex = events.indexWhere((e) => e.id == draggingId);
                      if (dragIndex == -1) return;
                      ScheduleEvent dragged = events[dragIndex];
                      ScheduleEvent preDrag = preDragState[dragged.id]!;
                      
                      int newEnd = _snap(preDrag.endMin + totalDelta);
                      int maxAllowed = (dragIndex < events.length - 1) ? events[dragIndex + 1].startMin : 1440;
                      int minAllowed = preDrag.startMin + globalMinDuration;

                      if (newEnd > maxAllowed) newEnd = maxAllowed;
                      if (newEnd < minAllowed) newEnd = minAllowed;

                      dragged.endMin = newEnd;
                    });
                  },
                  onPanEnd: (_) => _onDragEnd(),
                  onPanCancel: _onDragEnd,
                  child: Container(
                    color: Colors.transparent,
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(width: 10, height: 10, decoration: BoxDecoration(color: event.color, shape: BoxShape.circle)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int minutes) {
    int h = minutes ~/ 60;
    int m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}