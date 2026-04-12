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
  bool isPinned;

  ScheduleEvent({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.startMin,
    required this.endMin,
    this.isPinned = false,
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
      isPinned: isPinned,
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
  ScheduleEvent? selectedEvent; // 【追加】現在選択されている（詳細表示する）イベント
  
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

  int _getFloor(int index) {
    int floor = 0;
    int unpinnedSum = 0;
    for (int i = index - 1; i >= 0; i--) {
      if (events[i].isPinned) {
        floor = preDragState[events[i].id]!.endMin;
        break;
      } else {
        unpinnedSum += globalMinDuration; 
      }
    }
    return floor + unpinnedSum;
  }

  int _getCeil(int index) {
    int ceil = 1440;
    int unpinnedSum = 0;
    for (int i = index + 1; i < events.length; i++) {
      if (events[i].isPinned) {
        ceil = preDragState[events[i].id]!.startMin;
        break;
      } else {
        unpinnedSum += globalMinDuration; 
      }
    }
    return ceil - unpinnedSum;
  }

  void _pushUpwards(int dragIndex) {
    for (int i = dragIndex - 1; i >= 0; i--) {
      if (events[i].isPinned) {
        events[i].startMin = preDragState[events[i].id]!.startMin;
        events[i].endMin = preDragState[events[i].id]!.endMin;
      } else {
        events[i].endMin = min(preDragState[events[i].id]!.endMin, events[i+1].startMin);
        events[i].startMin = max(_getFloor(i), events[i].endMin - preDragState[events[i].id]!.duration);
        if (events[i].endMin - events[i].startMin < globalMinDuration) {
          events[i].startMin = events[i].endMin - globalMinDuration;
        }
      }
    }
  }

  void _pushDownwards(int dragIndex) {
    for (int i = dragIndex + 1; i < events.length; i++) {
      if (events[i].isPinned) {
        events[i].startMin = preDragState[events[i].id]!.startMin;
        events[i].endMin = preDragState[events[i].id]!.endMin;
      } else {
        events[i].startMin = max(preDragState[events[i].id]!.startMin, events[i-1].endMin);
        events[i].endMin = min(_getCeil(i), events[i].startMin + preDragState[events[i].id]!.duration);
        if (events[i].endMin - events[i].startMin < globalMinDuration) {
          events[i].endMin = events[i].startMin + globalMinDuration;
        }
      }
    }
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
        // 【変更】横並びのレイアウトにアップグレード
        child: Row(
          children: [
            // ======================================
            // 左側：メインスケジュール領域
            // ======================================
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    // 【追加】LayoutBuilderで正確な横幅を取得
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: SizedBox(
                            height: 24 * 60 * pixelsPerMinute,
                            width: constraints.maxWidth, // 親の幅いっぱいに設定
                            child: Stack(
                              children: [
                                // 【追加】背景タップで詳細パネルを閉じる
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        selectedEvent = null;
                                      });
                                    },
                                  ),
                                ),
                                // 背景グリッド
                                for (int i = 0; i <= 24; i++)
                                  Positioned(
                                    top: i * 60 * pixelsPerMinute,
                                    left: 0, right: 0,
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
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
            
            // ======================================
            // 右側：詳細パネル領域（タップ時のみ表示）
            // ======================================
            if (selectedEvent != null)
              Expanded(
                flex: 1,
                child: _buildDetailPanel(),
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

  // 【追加】詳細パネルの構築メソッド
  Widget _buildDetailPanel() {
    final event = selectedEvent!;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E2024), // メイン背景より少し明るい色でレイヤー感を出す
        border: Border(left: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // パネルヘッダー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10, width: 1))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('スケジュール詳細', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                GestureDetector(
                  onTap: () => setState(() => selectedEvent = null),
                  child: const Icon(Icons.close, color: Colors.white54),
                )
              ],
            ),
          ),
          // パネルボディ
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: event.color.withOpacity(0.2), shape: BoxShape.circle),
                        child: Icon(event.icon, color: event.color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(event.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  _buildDetailRow(Icons.access_time, '予定時間', '${_formatTime(event.startMin)} - ${_formatTime(event.endMin)}'),
                  const SizedBox(height: 24),
                  _buildDetailRow(Icons.hourglass_bottom, '所要時間', '${event.duration} 分'),
                  const SizedBox(height: 24),
                  _buildDetailRow(Icons.push_pin, 'ピン留め（ロック）', event.isPinned ? '有効' : '無効'),
                  const SizedBox(height: 40),
                  // モック用の操作ボタン
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('編集する'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A89DC),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('削除する'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 【追加】詳細パネル内の行構築ヘルパー
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white54, size: 24),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildEventBlock(ScheduleEvent event) {
    bool isDragging = draggingId == event.id;
    bool isSelected = selectedEvent?.id == event.id;

    return AnimatedPositioned(
      key: ValueKey(event.id),
      duration: isDragging ? Duration.zero : const Duration(milliseconds: 200), 
      curve: Curves.easeOutCubic,
      top: event.startMin * pixelsPerMinute,
      height: event.duration * pixelsPerMinute,
      left: 70,
      // 【変更】固定幅（width）をやめ、右側の余白（right）を指定することで自動リサイズ化
      right: 30, 
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
                  clipBehavior: Clip.hardEdge, 
                  decoration: BoxDecoration(
                    color: event.color.withOpacity(0.15),
                    // 選択中は枠線を少し太くして強調
                    border: Border.all(color: event.color, width: isSelected ? 3 : 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(), 
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
                              const SizedBox(width: 30), 
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
              // 中央エリア（全体移動用 兼 タップ判定）
              // =========================================
              Positioned(
                top: 15, bottom: 15, left: 0, right: 0,
                child: GestureDetector(
                  // 【追加】タップされたら詳細表示用にセット
                  onTap: () {
                    setState(() {
                      selectedEvent = event;
                    });
                  },
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

                        int minAllowed = _getFloor(dragIndex);
                        int maxAllowed = _getCeil(dragIndex) - dur;

                        if (newStart < minAllowed) newStart = minAllowed;
                        if (newStart > maxAllowed) newStart = maxAllowed;

                        dragged.startMin = newStart;
                        dragged.endMin = newStart + dur;

                        _pushUpwards(dragIndex);
                        _pushDownwards(dragIndex);
                      }
                    });
                  },
                  onPanEnd: (_) {
                    setState(() {
                      if (isDoubleClickMode) {
                        List<List<int>> freeGaps = [];
                        int currentMax = 0;
                        
                        final others = events.where((e) => e.id != event.id).toList()
                          ..sort((a, b) => a.startMin.compareTo(b.startMin));

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

                        double dropCenter = event.startMin + event.duration / 2;
                        List<int>? targetGap;

                        for (var gap in freeGaps) {
                          if (dropCenter >= gap[0] && dropCenter <= gap[1]) {
                            targetGap = gap;
                            break;
                          }
                        }

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

                        bool fitSuccess = false;
                        if (targetGap != null) {
                          int gStart = targetGap[0];
                          int gEnd = targetGap[1];
                          int gDur = gEnd - gStart;

                          if (gDur >= globalMinDuration) {
                            int origDur = preDragState[event.id]!.duration;
                            int proposedStart = event.startMin;
                            if (proposedStart < gStart) proposedStart = gStart;
                            
                            int proposedEnd = proposedStart + origDur;
                            if (proposedEnd > gEnd) {
                               proposedEnd = gEnd;
                               proposedStart = max(gStart, proposedEnd - origDur);
                               if (proposedEnd - proposedStart < globalMinDuration) {
                                   proposedStart = proposedEnd - globalMinDuration;
                               }
                            }
                            
                            event.startMin = proposedStart;
                            event.endMin = proposedEnd;
                            fitSuccess = true;
                          }
                        }

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
                      
                      int minAllowed = _getFloor(dragIndex);
                      int maxAllowed = preDrag.endMin - globalMinDuration;

                      if (newStart < minAllowed) newStart = minAllowed;
                      if (newStart > maxAllowed) newStart = maxAllowed;

                      dragged.startMin = newStart;
                      _pushUpwards(dragIndex);
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
                      
                      int maxAllowed = _getCeil(dragIndex);
                      int minAllowed = preDrag.startMin + globalMinDuration;

                      if (newEnd > maxAllowed) newEnd = maxAllowed;
                      if (newEnd < minAllowed) newEnd = minAllowed;

                      dragged.endMin = newEnd;
                      _pushDownwards(dragIndex);
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

              // =========================================
              // ④ ピン留めボタン
              // =========================================
              Positioned(
                top: 4, right: 6,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      event.isPinned = !event.isPinned;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    color: Colors.transparent, 
                    child: Icon(
                      event.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: event.isPinned ? Colors.white : Colors.white54,
                      size: 20,
                    ),
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