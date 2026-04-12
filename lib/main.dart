import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

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
  String location;
  String notes;

  ScheduleEvent({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.startMin,
    required this.endMin,
    this.isPinned = false,
    this.location = '未設定',
    this.notes = '',
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
      location: location,
      notes: notes,
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
  
  double pixelsPerMinute = 1.0; 
  
  final int globalMinDuration = 10; 

  String? draggingId;
  bool isDoubleClickMode = false;
  ScheduleEvent? selectedEvent; 
  bool _isCreatingNew = false; 
  
  Color? previewColor;

  // 【追加】削除中のイベントIDを保持する変数（アニメーション用）
  String? deletingEventId;

  DateTime? lastTapTime;
  String? lastTapEventId;
  Timer? _singleTapTimer; 

  Map<String, ScheduleEvent> preDragState = {};
  double dragStartGlobalY = 0.0;

  List<ScheduleEvent> events = [
    ScheduleEvent(id: '1', title: 'Morning Task (朝食)', icon: Icons.wb_sunny_outlined, color: const Color(0xFF4A89DC), startMin: 480, endMin: 600, location: '自宅 ダイニング', notes: '今日のタスク整理とメールチェックを済ませる。ゆっくりコーヒーを飲む。'),
    ScheduleEvent(id: '2', title: 'Deep Work (勉強)', icon: Icons.psychology_outlined, color: const Color(0xFF8CC152), startMin: 660, endMin: 780, location: '駅前のカフェ', notes: 'FlutterのUI実装と状態管理の復習。参考書の第3章を終わらせる。'),
    ScheduleEvent(id: '3', title: 'Meeting (荷物待ち)', icon: Icons.people_outline, color: const Color(0xFFF6BB42), startMin: 840, endMin: 930, location: '自宅', notes: '14:00〜16:00の間に宅配便が届くので待機する。'),
  ];

  final List<ScheduleEvent> templates = [
    ScheduleEvent(id: 'tpl_1', title: '運動 (ジム)', icon: Icons.fitness_center, color: const Color(0xFFFC6E51), startMin: 0, endMin: 60),
    ScheduleEvent(id: 'tpl_2', title: '読書', icon: Icons.menu_book, color: const Color(0xFF48CFAD), startMin: 0, endMin: 45),
    ScheduleEvent(id: 'tpl_3', title: '集中ワーク', icon: Icons.computer, color: const Color(0xFF5D9CEC), startMin: 0, endMin: 90),
    ScheduleEvent(id: 'tpl_4', title: '食事', icon: Icons.restaurant, color: const Color(0xFFFFCE54), startMin: 0, endMin: 60),
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
      _singleTapTimer?.cancel(); 
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

  void _updateEvent(ScheduleEvent updatedEvent) {
    setState(() {
      int index = events.indexWhere((e) => e.id == updatedEvent.id);
      if (index != -1) {
        events[index] = updatedEvent;
        events.sort((a, b) => a.startMin.compareTo(b.startMin));
        selectedEvent = updatedEvent; 
        _isCreatingNew = false;
        previewColor = null; 
      }
    });
  }

  // 【変更】削除時にアニメーションを挟むように改修
  void _deleteEvent(String eventId) {
    setState(() {
      deletingEventId = eventId; // アニメーション開始トリガー
      if (selectedEvent?.id == eventId) {
        selectedEvent = null; 
        _isCreatingNew = false;
        previewColor = null; 
      }
    });

    // 350ミリ秒（アニメーション時間）待ってからリストから完全に削除する
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          events.removeWhere((e) => e.id == eventId);
          if (deletingEventId == eventId) {
            deletingEventId = null;
          }
        });
      }
    });
  }

  void _cancelNewEvent() {
    setState(() {
      events.removeWhere((e) => e.id == selectedEvent?.id);
      selectedEvent = null;
      _isCreatingNew = false;
      previewColor = null; 
    });
  }

  void _addEventAt(int startMin, {ScheduleEvent? template}) {
    int maxAllowed = 1440;
    for (var e in events) {
      if (e.startMin >= startMin && e.startMin < maxAllowed) {
        maxAllowed = e.startMin;
      }
    }

    int desiredDur = template != null ? template.duration : 60;
    int endMin = min(startMin + desiredDur, maxAllowed);

    if (endMin - startMin < globalMinDuration) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('予定を配置する十分な空き時間がありません')),
      );
      return;
    }

    var newEvent = ScheduleEvent(
      id: 'new_${DateTime.now().millisecondsSinceEpoch}',
      title: template != null ? template.title : '新規予定',
      icon: template != null ? template.icon : Icons.event_note,
      color: template != null ? template.color : const Color(0xFF967ADC), 
      startMin: startMin,
      endMin: endMin,
      location: template != null ? template.location : '',
      notes: template != null ? template.notes : '',
    );

    setState(() {
      events.add(newEvent);
      events.sort((a, b) => a.startMin.compareTo(b.startMin));
      selectedEvent = newEvent;
      _isCreatingNew = template == null; 
      previewColor = null; 
    });
  }

  void _showTemplateMenu(BuildContext context, int tappedMin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2024),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('予定を追加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('${_formatTime(tappedMin)} から', style: const TextStyle(fontSize: 14, color: Colors.white54)),
                  ],
                ),
                const SizedBox(height: 16),
                
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                  title: const Text('＋ 新規作成（白紙から）', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _addEventAt(tappedMin);
                  },
                ),
                
                const Divider(color: Colors.white10, height: 32),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: Text('テンプレートから選ぶ', style: TextStyle(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.bold)),
                ),
                
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: templates.map((tpl) => ActionChip(
                    avatar: Icon(tpl.icon, color: tpl.color, size: 18),
                    label: Text(tpl.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    backgroundColor: tpl.color.withOpacity(0.1),
                    side: BorderSide(color: tpl.color.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    onPressed: () {
                      Navigator.pop(context);
                      _addEventAt(tappedMin, template: tpl);
                    },
                  )).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      }
    );
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
        child: LayoutBuilder(
          builder: (context, screenConstraints) {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: SizedBox(
                                height: 24 * 60 * pixelsPerMinute,
                                width: constraints.maxWidth, 
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTapUp: (details) {
                                          if (selectedEvent != null) {
                                            setState(() {
                                              if (_isCreatingNew) _cancelNewEvent(); 
                                              selectedEvent = null;
                                              previewColor = null; 
                                            });
                                            return;
                                          }

                                          int tappedMin = (details.localPosition.dy / pixelsPerMinute).round();
                                          tappedMin = (tappedMin / 10).round() * 10;

                                          bool isOverlapping = events.any((e) => tappedMin >= e.startMin && tappedMin < e.endMin);
                                          if (isOverlapping) return;

                                          _showTemplateMenu(context, tappedMin);
                                        },
                                      ),
                                    ),
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
                AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  child: selectedEvent != null
                      ? SizedBox(
                          width: screenConstraints.maxWidth * 0.5,
                          child: EventDetailPanel(
                            event: selectedEvent!.clone(),
                            allEvents: events,
                            isCreatingNew: _isCreatingNew, // 【変更】親の確実な状態を渡す
                            startInEditMode: _isCreatingNew, 
                            onClose: () {
                              if (_isCreatingNew) {
                                _cancelNewEvent();
                              } else {
                                setState(() {
                                  selectedEvent = null;
                                  previewColor = null; 
                                });
                              }
                            },
                            onSave: _updateEvent,
                            onDelete: () => _deleteEvent(selectedEvent!.id),
                            onCancelNew: _cancelNewEvent, 
                            onColorPreview: (color) {
                              setState(() {
                                previewColor = color;
                              });
                            },
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          }
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
                'Planorh', 
                style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Row(
                children: [
                  _buildStatItem('BUSY TIME', '${busyHours.toStringAsFixed(1)} hrs'),
                  const SizedBox(width: 20),
                  _buildStatItem('FREE time', '${freeHours.toStringAsFixed(1)} hrs'),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.zoom_out, color: Colors.white54, size: 16),
                  SizedBox(
                    width: 200, 
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.0, 
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0), 
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0), 
                        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.0), 
                        activeTickMarkColor: Colors.white54,
                        inactiveTickMarkColor: Colors.white24,
                      ),
                      child: Slider(
                        value: pixelsPerMinute,
                        min: 0.75, 
                        max: 2.0,  
                        divisions: 5, 
                        activeColor: const Color(0xFF4A89DC),
                        inactiveColor: Colors.white24,
                        onChanged: (val) {
                          setState(() {
                            pixelsPerMinute = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const Icon(Icons.zoom_in, color: Colors.white54, size: 16),
                  const SizedBox(width: 8),
                  Text('${(pixelsPerMinute * 100).toInt()}%', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              const Text('空白タップ: 追加メニュー表示  |  ブロックタップ: 詳細  |  ドラッグ: 調整', 
                style: TextStyle(color: Colors.white54, fontSize: 11)
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
    bool isSelected = selectedEvent?.id == event.id;
    bool isDeleting = deletingEventId == event.id; // 【追加】削除中かどうか

    Color displayColor = (isSelected && previewColor != null) ? previewColor! : event.color;

    double blockHeight = event.duration * pixelsPerMinute;
    double centerMargin = blockHeight > 30 ? 15.0 : 0.0;
    double handleHeight = blockHeight < 30 ? 24.0 : 30.0;
    double handleOffset = blockHeight < 30 ? -16.0 : -10.0;

    return AnimatedPositioned(
      key: ValueKey(event.id),
      duration: isDragging ? Duration.zero : const Duration(milliseconds: 200), 
      curve: Curves.easeOutCubic,
      top: event.startMin * pixelsPerMinute,
      height: blockHeight,
      left: 70,
      right: 30, 
      // 【変更】削除時と追加時の両方に対応するアニメーション設定
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: isDeleting ? 0.0 : 1.0),
        duration: const Duration(milliseconds: 350),
        curve: isDeleting ? Curves.easeInBack : Curves.easeOutBack, 
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Listener(
          onPointerDown: (details) => _onPointerDown(details, event),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: isDragging ? 0.7 : 1.0,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    clipBehavior: Clip.hardEdge, 
                    decoration: BoxDecoration(
                      color: displayColor.withOpacity(0.15), 
                      border: Border.all(color: displayColor, width: isSelected ? 3 : 2), 
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
                            if (blockHeight > 45) ...[
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

                Positioned(
                  top: centerMargin, bottom: centerMargin, left: 0, right: 0,
                  child: GestureDetector(
                    onTap: () {
                      if (isDoubleClickMode) return;
                      _singleTapTimer?.cancel();
                      _singleTapTimer = Timer(const Duration(milliseconds: 250), () {
                        if (mounted && !isDoubleClickMode && draggingId == null) {
                          setState(() {
                            if (_isCreatingNew && selectedEvent?.id != event.id) {
                              _cancelNewEvent(); 
                            }
                            selectedEvent = event;
                            previewColor = null; 
                          });
                        }
                      });
                    },
                    onPanStart: (details) {
                      setState(() {
                        if (_isCreatingNew && selectedEvent?.id != event.id) {
                           _cancelNewEvent();
                        }
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

                Positioned(
                  top: handleOffset, left: 0, right: 0, height: handleHeight,
                  child: GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        if (_isCreatingNew && selectedEvent?.id != event.id) _cancelNewEvent();
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
                      child: Container(width: 10, height: 10, decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle)), 
                    ),
                  ),
                ),

                Positioned(
                  bottom: handleOffset, left: 0, right: 0, height: handleHeight,
                  child: GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        if (_isCreatingNew && selectedEvent?.id != event.id) _cancelNewEvent();
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
                      child: Container(width: 10, height: 10, decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle)), 
                    ),
                  ),
                ),

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
      ),
    );
  }

  String _formatTime(int minutes) {
    int h = minutes ~/ 60;
    int m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

// =========================================================================
// 詳細パネル用ウィジェット
// =========================================================================
class EventDetailPanel extends StatefulWidget {
  final ScheduleEvent event;
  final List<ScheduleEvent> allEvents; 
  // 【変更】親から確実な状態を受け取るためプロパティを追加
  final bool isCreatingNew; 
  final bool startInEditMode; 
  final VoidCallback onClose;
  final ValueChanged<ScheduleEvent> onSave;
  final VoidCallback onDelete;
  final VoidCallback onCancelNew; 
  final ValueChanged<Color?> onColorPreview;

  const EventDetailPanel({
    super.key,
    required this.event,
    required this.allEvents,
    required this.isCreatingNew, // 【変更】
    this.startInEditMode = false,
    required this.onClose,
    required this.onSave,
    required this.onDelete,
    required this.onCancelNew,
    required this.onColorPreview, 
  });

  @override
  State<EventDetailPanel> createState() => _EventDetailPanelState();
}

class _EventDetailPanelState extends State<EventDetailPanel> {
  late bool _isEditing;
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;
  
  late Color _editColor; 

  int _editStartMin = 0;
  int _editEndMin = 0;
  String? _timeError;

  final List<Color> _colorPalette = [
    const Color(0xFF5D9CEC), // Blue
    const Color(0xFF48CFAD), // Mint
    const Color(0xFF8CC152), // Green
    const Color(0xFFFFCE54), // Yellow
    const Color(0xFFF6BB42), // Orange
    const Color(0xFFFC6E51), // Red-Orange
    const Color(0xFFED5565), // Red
    const Color(0xFF967ADC), // Purple
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.startInEditMode; 
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant EventDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.event.id != widget.event.id) {
      _isEditing = widget.startInEditMode; 
      _initControllers();
    } else {
      if (oldWidget.event.startMin != widget.event.startMin || 
          oldWidget.event.endMin != widget.event.endMin) {
        
        _editStartMin = widget.event.startMin;
        _editEndMin = widget.event.endMin;
        
        _timeError = null; 
      }
    }
  }

  void _initControllers() {
    _titleController = TextEditingController(text: widget.isCreatingNew ? '' : widget.event.title); // 【変更】判定ロジックの修正
    _locationController = TextEditingController(text: widget.isCreatingNew ? '' : widget.event.location); // 【変更】判定ロジックの修正
    _notesController = TextEditingController(text: widget.event.notes);
    _editStartMin = widget.event.startMin;
    _editEndMin = widget.event.endMin;
    _editColor = widget.event.color;
    _timeError = null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final initialTime = TimeOfDay(
      hour: (isStart ? _editStartMin : _editEndMin) ~/ 60,
      minute: (isStart ? _editStartMin : _editEndMin) % 60,
    );
    
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: _editColor, 
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        int pickedMin = picked.hour * 60 + picked.minute;
        if (isStart) {
          _editStartMin = pickedMin;
          if (_editStartMin >= _editEndMin) {
            _editEndMin = _editStartMin + 10;
          }
        } else {
          _editEndMin = pickedMin;
          if (_editEndMin <= _editStartMin) {
            _editStartMin = _editEndMin - 10;
            if (_editStartMin < 0) _editStartMin = 0;
          }
        }
        _timeError = null; 
      });
    }
  }

  void _saveChanges() {
    bool hasOverlap = false;
    for (var other in widget.allEvents) {
      if (other.id == widget.event.id) continue; 
      if (_editStartMin < other.endMin && _editEndMin > other.startMin) {
        hasOverlap = true;
        break;
      }
    }

    if (hasOverlap) {
      setState(() {
        _timeError = '※指定した時間は他のスケジュールと重複しています。';
      });
      return; 
    }

    ScheduleEvent updatedEvent = widget.event.clone();
    updatedEvent.title = _titleController.text.trim().isEmpty ? '名称未設定の予定' : _titleController.text;
    updatedEvent.location = _locationController.text;
    updatedEvent.notes = _notesController.text;
    updatedEvent.startMin = _editStartMin;
    updatedEvent.endMin = _editEndMin;
    updatedEvent.color = _editColor;
    
    widget.onSave(updatedEvent);
    setState(() {
      _isEditing = false;
    });
  }

  String _formatTime(int minutes) {
    int h = minutes ~/ 60;
    int m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E2024), 
        border: Border(left: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10, width: 1))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'スケジュール編集' : 'スケジュール詳細', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                ),
                GestureDetector(
                  onTap: () {
                    // 【変更】確実な状態で判定する
                    if (widget.isCreatingNew) {
                      widget.onCancelNew();
                    } else {
                      widget.onClose();
                    }
                  },
                  child: const Icon(Icons.close, color: Colors.white54),
                )
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: _isEditing ? _buildEditMode(context) : _buildViewMode(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: widget.event.color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(widget.event.icon, color: widget.event.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(widget.event.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 40),
        _buildDetailRow(Icons.access_time, '予定時間', '${_formatTime(widget.event.startMin)} - ${_formatTime(widget.event.endMin)}'),
        const SizedBox(height: 24),
        _buildDetailRow(Icons.hourglass_bottom, '所要時間', '${widget.event.duration} 分'),
        const SizedBox(height: 24),
        _buildDetailRow(Icons.location_on_outlined, '場所', widget.event.location),
        const SizedBox(height: 32),
        _buildNotesArea(widget.event.notes),
        
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
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
                onPressed: widget.onDelete, 
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
    );
  }

  Widget _buildEditMode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('タイトル', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          decoration: _inputDecoration('タスク名を入力'),
          autofocus: widget.isCreatingNew, // 【変更】確実な状態で判定する
        ),
        
        const SizedBox(height: 24),

        const Text('カラー', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colorPalette.map((color) {
            bool isSelected = _editColor.value == color.value;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _editColor = color;
                });
                widget.onColorPreview(color); 
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('予定時間', style: TextStyle(color: Colors.white54, fontSize: 12)),
            Text('${_editEndMin - _editStartMin} 分', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectTime(context, true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(_formatTime(_editStartMin), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('-', style: TextStyle(color: Colors.white54, fontSize: 18)),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _selectTime(context, false),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(_formatTime(_editEndMin), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_timeError != null) ...[
          const SizedBox(height: 8),
          Text(_timeError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
        ],

        const SizedBox(height: 24),
        const Text('場所', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: _locationController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _inputDecoration('場所を入力 (例: 会議室A)'),
        ),

        const SizedBox(height: 24),
        const Text('詳細・メモ', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 6,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          decoration: _inputDecoration('メモを入力...'),
        ),

        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveChanges, 
                icon: const Icon(Icons.check, size: 18),
                label: const Text('保存する'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8CC152), 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  // 【変更】確実な状態で判定する
                  if (widget.isCreatingNew) {
                    widget.onCancelNew();
                  } else {
                    setState(() {
                      _isEditing = false;
                      _initControllers(); 
                    });
                    widget.onColorPreview(null);
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('キャンセル'),
              ),
            ),
          ],
        )
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _editColor, width: 1.5), 
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white54, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesArea(String notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.subject, color: Colors.white54, size: 24),
            SizedBox(width: 16),
            Text('詳細・メモ', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            notes.isNotEmpty ? notes : '詳細がありません',
            style: TextStyle(
              color: notes.isNotEmpty ? Colors.white70 : Colors.white38, 
              fontSize: 14, 
              height: 1.6
            ),
          ),
        ),
      ],
    );
  }
}