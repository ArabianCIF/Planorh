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

  ScheduleEvent({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.startMin,
    required this.endMin,
  });

  int get duration => endMin - startMin;

  ScheduleEvent clone() {
    return ScheduleEvent(
      id: id,
      title: title,
      icon: icon,
      color: color,
      startMin: startMin,
      endMin: endMin,
    );
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

  // 300ms以内の同一ブロックタップでダブルクリック判定
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

  @override
  Widget build(BuildContext context) {
    // ロジックの安全のため、常に時間順にソートしたコピー配列を使用
    final sortedEvents = List<ScheduleEvent>.from(events)
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    // ドラッグ中のブロックが他のブロックの下に隠れないように、描画順を最後に回す
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
                      // 背景のタイムライングリッド
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
                      // ブロックの描画
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
            children: const [
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
              // =========================================
              // メインの枠と背景
              // =========================================
              Positioned.fill(
                child: Container(
                  clipBehavior: Clip.hardEdge, // 【追加】はみ出した中身をここで切り取る
                  decoration: BoxDecoration(
                    color: event.color.withOpacity(0.15),
                    border: Border.all(color: event.color, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // 【変更】PaddingをContainerから移動し、SingleChildScrollViewで包む
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(), // スクロールはさせない
                    child: Padding(
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
                ),
              ),

              // =========================================
              // 中央エリア（全体移動用）
              // =========================================
              Positioned(
                top: 15, bottom: 15, left: 0, right: 0,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      draggingId = event.id;
                      dragStartGlobalY = details.globalPosition.dy;
                      preDragState = { for (var e in events) e.id: e.clone() };
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      int totalDelta = ((details.globalPosition.dy - dragStartGlobalY) / pixelsPerMinute).round();

                      if (isDoubleClickMode) {
                        // 【ダブルクリック】すり抜けとスナップ
                        int newStart = _snap(preDragState[event.id]!.startMin + totalDelta);
                        int dur = preDragState[event.id]!.duration;
                        
                        if (newStart < 0) newStart = 0;
                        if (newStart + dur > 1440) newStart = 1440 - dur;

                        int snapThreshold = 15; 
                        int bestSnapStart = newStart;
                        int minDiff = snapThreshold + 1;

                        for (var other in events) {
                          if (other.id == event.id) continue;

                          int diffToEnd = (newStart - other.endMin).abs();
                          if (diffToEnd < minDiff) {
                            minDiff = diffToEnd;
                            bestSnapStart = other.endMin;
                          }

                          int diffToStart = ((newStart + dur) - other.startMin).abs();
                          if (diffToStart < minDiff) {
                            minDiff = diffToStart;
                            bestSnapStart = other.startMin - dur;
                          }
                        }

                        if (bestSnapStart < 0) bestSnapStart = 0;
                        if (bestSnapStart + dur > 1440) bestSnapStart = 1440 - dur;

                        event.startMin = bestSnapStart;
                        event.endMin = bestSnapStart + dur;

                      } else {
                        // 【シングルクリック】連動移動・縮み
                        for (int i = 0; i < events.length; i++) {
                          events[i].startMin = preDragState[events[i].id]!.startMin;
                          events[i].endMin = preDragState[events[i].id]!.endMin;
                        }
                        events.sort((a, b) => a.startMin.compareTo(b.startMin));

                        int dragIndex = events.indexWhere((e) => e.id == draggingId);
                        if (dragIndex == -1) return;

                        ScheduleEvent dragged = events[dragIndex];
                        ScheduleEvent preDrag = preDragState[dragged.id]!;
                        
                        int newStart = _snap(preDrag.startMin + totalDelta);
                        int dur = preDrag.duration;

                        int minAllowed = dragIndex * globalMinDuration;
                        int maxAllowed = 1440 - (events.length - 1 - dragIndex) * globalMinDuration;

                        if (newStart < minAllowed) newStart = minAllowed;
                        if (newStart + dur > maxAllowed) newStart = maxAllowed - dur;

                        dragged.startMin = newStart;
                        dragged.endMin = newStart + dur;

                        if (totalDelta < 0) {
                          for (int i = dragIndex - 1; i >= 0; i--) {
                            if (events[i].endMin > events[i+1].startMin) {
                              events[i].endMin = events[i+1].startMin;
                              events[i].startMin = min(preDragState[events[i].id]!.startMin, events[i].endMin - globalMinDuration);
                            }
                          }
                        } else if (totalDelta > 0) {
                          for (int i = dragIndex + 1; i < events.length; i++) {
                            if (events[i].startMin < events[i-1].endMin) {
                              events[i].startMin = events[i-1].endMin;
                              events[i].endMin = max(preDragState[events[i].id]!.endMin, events[i].startMin + globalMinDuration);
                            }
                          }
                        }
                      }
                    });
                  },
                  onPanEnd: (_) {
                    setState(() {
                      if (isDoubleClickMode) {
                        // ====== 新機能：隙間に自動フィット＆縮小 ======
                        List<List<int>> freeGaps = [];
                        int currentMax = 0;
                        
                        // 自分以外のブロックを時間順に取得
                        final others = events.where((e) => e.id != event.id).toList()
                          ..sort((a, b) => a.startMin.compareTo(b.startMin));

                        // 1. 空き時間（ギャップ）をすべて洗い出す
                        for (var o in others) {
                          if (o.startMin > currentMax) {
                            freeGaps.add([currentMax, o.startMin]);
                          }
                          if (o.endMin > currentMax) {
                            currentMax = o.endMin;
                          }
                        }
                        if (1440 > currentMax) {
                          freeGaps.add([currentMax, 1440]);
                        }

                        // 2. ドロップされたブロックが属するターゲットギャップを特定
                        double dropCenter = event.startMin + event.duration / 2;
                        List<int>? targetGap;

                        // まずは中心点がどのギャップにあるか判定
                        for (var gap in freeGaps) {
                          if (dropCenter >= gap[0] && dropCenter <= gap[1]) {
                            targetGap = gap;
                            break;
                          }
                        }

                        // 中心点が他ブロックの真上だった場合、一番重なりが大きいギャップを探す
                        if (targetGap == null) {
                          int maxOverlap = 0;
                          for (var gap in freeGaps) {
                            int overlapStart = max(gap[0], event.startMin);
                            int overlapEnd = min(gap[1], event.endMin);
                            int overlap = max(0, overlapEnd - overlapStart);
                            if (overlap > maxOverlap) {
                              maxOverlap = overlap;
                              targetGap = gap;
                            }
                          }
                        }

                        // 3. ギャップにはめ込む処理
                        bool fitSuccess = false;
                        if (targetGap != null) {
                          int gStart = targetGap[0];
                          int gEnd = targetGap[1];
                          int gDur = gEnd - gStart;

                          // 隙間が最小時間以上ある場合のみはめ込む
                          if (gDur >= globalMinDuration) {
                            int origDur = preDragState[event.id]!.duration;
                            
                            int proposedStart = event.startMin;
                            if (proposedStart < gStart) proposedStart = gStart;
                            
                            int proposedEnd = proposedStart + origDur;
                            
                            // ブロックの終端がギャップをはみ出すなら縮小して収める
                            if (proposedEnd > gEnd) {
                               proposedEnd = gEnd;
                               proposedStart = max(gStart, proposedEnd - origDur);
                               
                               // 縮小されすぎて最小時間を下回る場合のガード
                               if (proposedEnd - proposedStart < globalMinDuration) {
                                   proposedStart = proposedEnd - globalMinDuration;
                               }
                            }
                            
                            event.startMin = proposedStart;
                            event.endMin = proposedEnd;
                            fitSuccess = true;
                          }
                        }

                        // 4. フィット失敗（隙間が狭すぎる、完全に他ブロックの上）の場合はキャンセルして戻す
                        if (!fitSuccess) {
                          event.startMin = preDragState[event.id]!.startMin;
                          event.endMin = preDragState[event.id]!.endMin;
                        }
                      }
                      
                      draggingId = null;
                      preDragState.clear();
                      events.sort((a, b) => a.startMin.compareTo(b.startMin));
                    });
                  },
                  onPanCancel: () => setState(() { draggingId = null; preDragState.clear(); }),
                  child: Container(color: Colors.transparent),
                ),
              ),

              // =========================================
              // ① 上端ハンドル（リサイズ用）
              // =========================================
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
                      events.sort((a, b) => a.startMin.compareTo(b.startMin));
                      
                      int dragIndex = events.indexWhere((e) => e.id == draggingId);
                      if (dragIndex == -1) return;
                      ScheduleEvent dragged = events[dragIndex];
                      ScheduleEvent preDrag = preDragState[dragged.id]!;
                      
                      int newStart = _snap(preDrag.startMin + totalDelta);
                      int minAllowed = dragIndex * globalMinDuration;
                      int maxAllowed = preDrag.endMin - globalMinDuration;

                      if (newStart < minAllowed) newStart = minAllowed;
                      if (newStart > maxAllowed) newStart = maxAllowed;

                      dragged.startMin = newStart;

                      for (int i = dragIndex - 1; i >= 0; i--) {
                        if (events[i].endMin > events[i+1].startMin) {
                          events[i].endMin = events[i+1].startMin;
                          events[i].startMin = min(preDragState[events[i].id]!.startMin, events[i].endMin - globalMinDuration);
                        }
                      }
                    });
                  },
                  onPanEnd: (_) => setState(() => draggingId = null),
                  onPanCancel: () => setState(() => draggingId = null),
                  child: Container(
                    color: Colors.transparent,
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(width: 10, height: 10, decoration: BoxDecoration(color: event.color, shape: BoxShape.circle)),
                  ),
                ),
              ),

              // =========================================
              // ② 下端ハンドル（リサイズ用）
              // =========================================
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
                      events.sort((a, b) => a.startMin.compareTo(b.startMin));
                      
                      int dragIndex = events.indexWhere((e) => e.id == draggingId);
                      if (dragIndex == -1) return;
                      ScheduleEvent dragged = events[dragIndex];
                      ScheduleEvent preDrag = preDragState[dragged.id]!;
                      
                      int newEnd = _snap(preDrag.endMin + totalDelta);
                      int maxAllowed = 1440 - (events.length - 1 - dragIndex) * globalMinDuration;
                      int minAllowed = preDrag.startMin + globalMinDuration;

                      if (newEnd > maxAllowed) newEnd = maxAllowed;
                      if (newEnd < minAllowed) newEnd = minAllowed;

                      dragged.endMin = newEnd;

                      for (int i = dragIndex + 1; i < events.length; i++) {
                        if (events[i].startMin < events[i-1].endMin) {
                          events[i].startMin = events[i-1].endMin;
                          events[i].endMin = max(preDragState[events[i].id]!.endMin, events[i].startMin + globalMinDuration);
                        }
                      }
                    });
                  },
                  onPanEnd: (_) => setState(() => draggingId = null),
                  onPanCancel: () => setState(() => draggingId = null),
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