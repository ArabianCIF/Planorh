import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  // アプリ全体で共通して使う16色のカラーパレット
  static const List<Color> colorPalette = [
    Color(0xFF5D9CEC), Color(0xFF4FC1E9), Color(0xFF48CFAD), Color(0xFF8CC152), 
    Color(0xFFFFCE54), Color(0xFFF6BB42), Color(0xFFFC6E51), Color(0xFFED5565), 
    Color(0xFFDA4453), Color(0xFFD770AD), Color(0xFF967ADC), Color(0xFFAAB2BD), 
    Color(0xFFEC87C0), Color(0xFF5C97BF), Color(0xFF2ECC71), Color(0xFFE67E22), 
  ];

  static const Map<int, IconData> _iconMap = {
    0xe24d: Icons.event_note,
    0xe595: Icons.wb_sunny_outlined,
    0xe4f7: Icons.psychology_outlined,
    0xe4ef: Icons.people_outline,
    0xe281: Icons.fitness_center,
    0xe3f3: Icons.menu_book,
    0xe1ad: Icons.computer,
    0xe556: Icons.restaurant,
    0xf0171: Icons.shopping_cart_outlined,
    0xe675: Icons.train,
    0xe10f: Icons.local_cafe_outlined,
    0xe4e2: Icons.phone_in_talk_outlined,
    0xe405: Icons.music_note_outlined,
    0xe402: Icons.movie_creation_outlined,
    0xe318: Icons.home_outlined,
    0xe6ee: Icons.work_outline,
    0xef13: Icons.bedtime,
    0xe1c4: Icons.directions_car,
    0xe1e1: Icons.directions_walk,
  };

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
      id: id, title: title, icon: icon, color: color,
      startMin: startMin, endMin: endMin, isPinned: isPinned,
      location: location, notes: notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'iconCode': icon.codePoint,
      'colorValue': color.value,
      'startMin': startMin,
      'endMin': endMin,
      'isPinned': isPinned,
      'location': location,
      'notes': notes,
    };
  }

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) {
    final int code = json['iconCode'];
    return ScheduleEvent(
      id: json['id'],
      title: json['title'],
      icon: _iconMap[code] ?? Icons.event_note, 
      color: Color(json['colorValue']),
      startMin: json['startMin'],
      endMin: json['endMin'],
      isPinned: json['isPinned'] ?? false,
      location: json['location'] ?? '未設定',
      notes: json['notes'] ?? '',
    );
  }
}

class InteractiveSchedule extends StatefulWidget {
  const InteractiveSchedule({super.key});

  @override
  State<InteractiveSchedule> createState() => _InteractiveScheduleState();
}

class _InteractiveScheduleState extends State<InteractiveSchedule> {
  final int snapInterval = 10; 
  double pixelsPerMinute = 1.0; 
  final int globalMinDuration = 10; 

  String? draggingId;
  int? draggingIndex; 
  bool isDoubleClickMode = false;
  ScheduleEvent? selectedEvent; 
  bool _isCreatingNew = false; 
  
  List<Map<String, String>> eventHistory = [];
  List<Map<String, dynamic>> _savedSchedules = [];

  Color? previewColor;
  IconData? previewIcon; 
  int? previewStartMin;
  int? previewEndMin;

  String? deletingEventId; 

  int? dragCreateStartMin;
  int? dragCreateCurrentMin;

  int _currentMinute = 0;
  Timer? _timeTimer;

  DateTime? lastTapTime;
  String? lastTapEventId;
  Timer? _singleTapTimer; 

  Map<String, ScheduleEvent> preDragState = {};
  double dragStartGlobalY = 0.0;

  List<ScheduleEvent> events = [];

  final List<ScheduleEvent> templates = [
    ScheduleEvent(id: 'tpl_sleep', title: '睡眠', icon: Icons.bedtime, color: const Color(0xFF967ADC), startMin: 0, endMin: 480),
    ScheduleEvent(id: 'tpl_commute', title: '移動', icon: Icons.directions_car, color: const Color(0xFFAAB2BD), startMin: 0, endMin: 30),
    ScheduleEvent(id: 'tpl_break', title: '休憩', icon: Icons.local_cafe_outlined, color: const Color(0xFFFFCE54), startMin: 0, endMin: 15),
    ScheduleEvent(id: 'tpl_work', title: '集中ワーク', icon: Icons.computer, color: const Color(0xFF5D9CEC), startMin: 0, endMin: 90),
    ScheduleEvent(id: 'tpl_meal', title: '食事', icon: Icons.restaurant, color: const Color(0xFFF6BB42), startMin: 0, endMin: 60),
    ScheduleEvent(id: 'tpl_gym', title: '運動', icon: Icons.fitness_center, color: const Color(0xFFFC6E51), startMin: 0, endMin: 60),
    ScheduleEvent(id: 'tpl_book', title: '読書', icon: Icons.menu_book, color: const Color(0xFF48CFAD), startMin: 0, endMin: 45),
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _updateCurrentTime();
    _timeTimer = Timer.periodic(const Duration(minutes: 1), (_) => _updateCurrentTime());
  }

  void _updateCurrentTime() {
    final now = DateTime.now();
    if (mounted) setState(() => _currentMinute = now.hour * 60 + now.minute);
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _singleTapTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? eventsJson = prefs.getString('schedule_events');
    if (eventsJson != null) {
      final List<dynamic> decoded = jsonDecode(eventsJson);
      setState(() => events = decoded.map((e) => ScheduleEvent.fromJson(e)).toList()..sort((a, b) => a.startMin.compareTo(b.startMin)));
    }
    final String? savedSchedulesJson = prefs.getString('saved_schedules');
    if (savedSchedulesJson != null) {
      setState(() => _savedSchedules = List<Map<String, dynamic>>.from(jsonDecode(savedSchedulesJson)));
    }
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString('schedule_events', encoded);
  }

  Future<void> _saveSchedulesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_schedules', jsonEncode(_savedSchedules));
  }

  int _snap(int minutes) {
    int gridSnap = (minutes / snapInterval).round() * snapInterval;
    int snapToCurrent = 8; 
    if ((minutes - _currentMinute).abs() <= snapToCurrent) {
      return _currentMinute;
    }
    return gridSnap;
  }

  double get busyHours => events.fold<int>(0, (sum, event) => sum + event.duration) / 60.0;
  double get freeHours => 24.0 - busyHours;

  void _addToHistory(String title, String location, String notes) {
    if (title.isEmpty || title == '新規予定') return;
    setState(() {
      eventHistory.removeWhere((item) => item['title'] == title);
      eventHistory.insert(0, {'title': title, 'location': location, 'notes': notes});
      if (eventHistory.length > 5) eventHistory.removeLast();
    });
  }

  void _showResetConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        title: const Text('スケジュールのリセット'),
        content: const Text('すべての予定を削除して白紙に戻しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              setState(() { events.clear(); selectedEvent = null; });
              _saveEvents();
              Navigator.pop(context);
            },
            child: const Text('リセット', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showClipboardDialog() {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2024),
              title: const Row(
                children: [
                  Icon(Icons.content_paste, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('クリップボード', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              hintText: '現在の状態を保存 (名前)',
                              hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                              filled: true, fillColor: Colors.white10,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (nameController.text.trim().isEmpty) return;
                            setState(() {
                              _savedSchedules.add({
                                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                'name': nameController.text.trim(),
                                'events': events.map((e) => e.toJson()).toList(),
                              });
                              _saveSchedulesToPrefs();
                            });
                            setStateDialog((){});
                            nameController.clear();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A89DC)),
                          child: const Text('保存'),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                    _savedSchedules.isEmpty
                        ? const Padding(padding: EdgeInsets.all(16.0), child: Text('保存されたスケジュールはありません', style: TextStyle(color: Colors.white54)))
                        : Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _savedSchedules.length,
                              itemBuilder: (context, index) {
                                final item = _savedSchedules[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item['name'], style: const TextStyle(color: Colors.white)),
                                  subtitle: Text('${(item['events'] as List).length} 件の予定', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.restore, color: Color(0xFF48CFAD)), tooltip: '復元する',
                                        onPressed: () {
                                          setState(() {
                                            events = (item['events'] as List).map((e) => ScheduleEvent.fromJson(e)).toList();
                                            selectedEvent = null; _isCreatingNew = false;
                                          });
                                          _saveEvents();
                                          Navigator.pop(context);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent), tooltip: '削除する',
                                        onPressed: () {
                                          setState(() { _savedSchedules.removeAt(index); _saveSchedulesToPrefs(); });
                                          setStateDialog((){});
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ],
                ),
              ),
              actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')) ],
            );
          }
        );
      }
    );
  }

  void _onPointerDown(PointerDownEvent details, ScheduleEvent event) {
    final now = DateTime.now();
    if (lastTapTime != null && 
        now.difference(lastTapTime!) < const Duration(milliseconds: 200) &&
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
      } else { unpinnedSum += globalMinDuration; }
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
      } else { unpinnedSum += globalMinDuration; }
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
        previewColor = null; previewIcon = null; previewStartMin = null; previewEndMin = null;   
        _addToHistory(updatedEvent.title, updatedEvent.location, updatedEvent.notes);
      }
    });
    _saveEvents();
  }

  void _deleteEvent(String eventId) {
    setState(() {
      final target = events.firstWhere((e) => e.id == eventId);
      _addToHistory(target.title, target.location, target.notes);
      deletingEventId = eventId; 
      if (selectedEvent?.id == eventId) {
        selectedEvent = null; _isCreatingNew = false;
      }
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          events.removeWhere((e) => e.id == eventId);
          if (deletingEventId == eventId) deletingEventId = null;
        });
        _saveEvents();
      }
    });
  }

  void _cancelNewEvent() {
    if (selectedEvent == null) return;
    final String targetId = selectedEvent!.id;
    setState(() {
      deletingEventId = targetId; selectedEvent = null; _isCreatingNew = false;
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          events.removeWhere((e) => e.id == targetId);
          if (deletingEventId == targetId) deletingEventId = null;
        });
        _saveEvents();
      }
    });
  }

  void _addEventAt(int startMin, {ScheduleEvent? template, int? specificDuration}) {
    int maxAllowed = 1440;
    for (var e in events) {
      if (e.startMin >= startMin && e.startMin < maxAllowed) maxAllowed = e.startMin;
    }
    int desiredDur = specificDuration ?? (template != null ? template.duration : 60);
    int endMin = min(startMin + desiredDur, maxAllowed);
    if (endMin - startMin < globalMinDuration) return;

    Color randomColor = ScheduleEvent.colorPalette[Random().nextInt(ScheduleEvent.colorPalette.length)];

    var newEvent = ScheduleEvent(
      id: 'new_${DateTime.now().millisecondsSinceEpoch}',
      title: template != null ? template.title : '新規予定',
      icon: template != null ? template.icon : Icons.event_note,
      color: template != null ? template.color : randomColor, 
      startMin: startMin, endMin: endMin,
      location: template != null ? template.location : '',
      notes: template != null ? template.notes : '',
    );

    setState(() {
      events.add(newEvent);
      events.sort((a, b) => a.startMin.compareTo(b.startMin));
      selectedEvent = newEvent;
      _isCreatingNew = template == null; 
    });
    _saveEvents();
  }

  void _showTemplateMenu(BuildContext context, int tappedMin) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: const Color(0xFF1E2024),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width > 600 ? 900 : double.infinity,
      ),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext context) {
        return SafeArea(
          child: SingleChildScrollView( 
            child: Padding(
              padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isWide = constraints.maxWidth > 500;

                  Widget templatesSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('テンプレート', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12, runSpacing: 12,
                        children: templates.map((tpl) => ActionChip(
                          avatar: Icon(tpl.icon, color: tpl.color, size: 18),
                          label: Text(tpl.title),
                          onPressed: () { Navigator.pop(context); _addEventAt(tappedMin, template: tpl); },
                        )).toList(),
                      ),
                    ],
                  );

                  Widget historySection = eventHistory.isNotEmpty ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('最近の予定から追加', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: eventHistory.map((hist) => ActionChip(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          label: Text(hist['title'] ?? '', style: const TextStyle(color: Colors.white70)),
                          onPressed: () {
                            Navigator.pop(context);
                            Color randomColor = ScheduleEvent.colorPalette[Random().nextInt(ScheduleEvent.colorPalette.length)];
                            var newEvent = ScheduleEvent(
                              id: 'new_${DateTime.now().millisecondsSinceEpoch}',
                              title: hist['title'] ?? '新規予定',
                              icon: Icons.event_note, color: randomColor,
                              startMin: tappedMin, endMin: tappedMin + 60,
                              location: hist['location'] ?? '', notes: hist['notes'] ?? '',
                            );
                            setState(() {
                              events.add(newEvent);
                              events.sort((a, b) => a.startMin.compareTo(b.startMin));
                              selectedEvent = newEvent;
                              _isCreatingNew = true;
                            });
                            _saveEvents();
                          },
                        )).toList(),
                      ),
                    ],
                  ) : const SizedBox.shrink();

                  return Column(
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
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.add, color: Colors.white),
                        title: const Text('＋ 新規作成（白紙から）', style: TextStyle(color: Colors.white)),
                        onTap: () { Navigator.pop(context); _addEventAt(tappedMin); },
                      ),
                      const Divider(color: Colors.white10, height: 32),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: templatesSection),
                            if (eventHistory.isNotEmpty) ...[
                              const SizedBox(width: 24),
                              Expanded(child: historySection),
                            ]
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            templatesSection,
                            if (eventHistory.isNotEmpty) ...[
                              const Divider(color: Colors.white10, height: 32),
                              historySection,
                            ]
                          ],
                        )
                    ],
                  );
                }
              ),
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> eventWidgets = [];
    Widget? draggingWidget;
    for (var event in events) {
      if (event.id == draggingId) draggingWidget = _buildEventBlock(event);
      else eventWidgets.add(_buildEventBlock(event));
    }
    if (draggingWidget != null) eventWidgets.add(draggingWidget);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, outerConstraints) {
            double targetWidth = max(400.0, outerConstraints.maxWidth);
            double targetHeight = max(500.0, outerConstraints.maxHeight);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(), 
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical, 
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: targetWidth, height: targetHeight,
                  child: LayoutBuilder(
                    builder: (context, screenConstraints) {
                      bool isMobile = screenConstraints.maxWidth < 600;
                      Widget calendarSection = Column(
                        children: [
                          _buildHeader(isMobile),
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
                                                if (_isCreatingNew) _cancelNewEvent();
                                                else setState(() => selectedEvent = null);
                                              }
                                              int tappedMin = _snap((details.localPosition.dy / pixelsPerMinute).round());
                                              if (events.any((e) => tappedMin >= e.startMin && tappedMin < e.endMin)) return;
                                              _showTemplateMenu(context, tappedMin);
                                            },
                                            onVerticalDragStart: (details) {
                                              if (selectedEvent != null) {
                                                if (_isCreatingNew) _cancelNewEvent();
                                                else setState(() => selectedEvent = null);
                                              }
                                              int minTime = _snap((details.localPosition.dy / pixelsPerMinute).round());
                                              if (events.any((e) => minTime >= e.startMin && minTime < e.endMin)) return;
                                              setState(() { dragCreateStartMin = minTime; dragCreateCurrentMin = minTime; });
                                            },
                                            onVerticalDragUpdate: (details) {
                                              if (dragCreateStartMin == null) return;
                                              int pointerMin = _snap((details.localPosition.dy / pixelsPerMinute).round());
                                              int snapThreshold = 15;
                                              for (var e in events) {
                                                if ((pointerMin - e.startMin).abs() <= snapThreshold) pointerMin = e.startMin;
                                                else if ((pointerMin - e.endMin).abs() <= snapThreshold) pointerMin = e.endMin;
                                              }
                                              if (pointerMin > dragCreateStartMin!) {
                                                int limit = 1440;
                                                for (var e in events) if (e.startMin >= dragCreateStartMin! && e.startMin < limit) limit = e.startMin;
                                                if (pointerMin > limit) pointerMin = limit;
                                              } else {
                                                int limit = 0;
                                                for (var e in events) if (e.endMin <= dragCreateStartMin! && e.endMin > limit) limit = e.endMin;
                                                if (pointerMin < limit) pointerMin = limit;
                                              }
                                              setState(() { dragCreateCurrentMin = pointerMin; });
                                            },
                                            onVerticalDragEnd: (details) {
                                              if (dragCreateStartMin == null || dragCreateCurrentMin == null) return;
                                              int start = min(dragCreateStartMin!, dragCreateCurrentMin!);
                                              int end = max(dragCreateStartMin!, dragCreateCurrentMin!);
                                              setState(() { dragCreateStartMin = null; dragCreateCurrentMin = null; });
                                              if (end - start < globalMinDuration) return;
                                              _addEventAt(start, specificDuration: end - start);
                                            },
                                          ),
                                        ),
                                        for (int i = 0; i <= 24; i++)
                                          Positioned(
                                            top: i * 60 * pixelsPerMinute,
                                            left: 0, right: 0,
                                            child: Row(
                                              children: [
                                                SizedBox(width: 60, child: Text('${i.toString().padLeft(2, '0')}:00', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12))),
                                                const Expanded(child: Divider(color: Colors.white10, height: 1)),
                                              ],
                                            ),
                                          ),

                                        Positioned(
                                          top: _currentMinute * pixelsPerMinute - 8,
                                          left: 0, right: 0, height: 16,
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 60, 
                                                child: Text(_formatTime(_currentMinute), 
                                                textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))
                                              ),
                                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                                              const Expanded(child: Divider(color: Colors.redAccent, height: 2, thickness: 1.5)),
                                            ],
                                          ),
                                        ),

                                        ...eventWidgets,
                                        if (dragCreateStartMin != null && dragCreateCurrentMin != null)
                                          Positioned(
                                            top: min(dragCreateStartMin!, dragCreateCurrentMin!) * pixelsPerMinute,
                                            height: max(globalMinDuration, (dragCreateCurrentMin! - dragCreateStartMin!).abs()) * pixelsPerMinute,
                                            left: 70, right: 30,
                                            child: Container(decoration: BoxDecoration(color: const Color(0xFF967ADC).withOpacity(0.2), border: Border.all(color: const Color(0xFF967ADC), width: 2), borderRadius: BorderRadius.circular(8))),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            ),
                          ),
                        ],
                      );

                      Widget detailSection = selectedEvent != null
                          ? EventDetailPanel(
                              event: selectedEvent!.clone(),
                              allEvents: events, history: eventHistory, isCreatingNew: _isCreatingNew, startInEditMode: _isCreatingNew, isMobile: isMobile, 
                              onClose: () {
                                if (_isCreatingNew) _cancelNewEvent();
                                else setState(() { selectedEvent = null; previewColor = null; previewIcon = null; previewStartMin = null; previewEndMin = null; });
                              },
                              onSave: _updateEvent, onDelete: () => _deleteEvent(selectedEvent!.id), onCancelNew: _cancelNewEvent, 
                              onColorPreview: (color) => setState(() => previewColor = color),
                              onIconPreview: (icon) => setState(() => previewIcon = icon),
                              onTimePreview: (times) => setState(() {
                                if (times != null) { previewStartMin = times[0]; previewEndMin = times[1]; }
                                else { previewStartMin = null; previewEndMin = null; }
                              }),
                            ) : const SizedBox.shrink();

                      if (isMobile) {
                        return Stack(
                          children: [
                            calendarSection, 
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic,
                              top: 0, bottom: 0, left: selectedEvent != null ? 0 : screenConstraints.maxWidth, right: selectedEvent != null ? 0 : -screenConstraints.maxWidth,
                              child: Container(color: const Color(0xFF1E2024), child: detailSection),
                            ),
                          ],
                        );
                      } else {
                        return Row(
                          children: [
                            Expanded(child: calendarSection),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic,
                              child: selectedEvent != null ? SizedBox(width: screenConstraints.maxWidth * 0.5, child: detailSection) : const SizedBox.shrink(),
                            ),
                          ],
                        );
                      }
                    }
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      width: double.infinity, 
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 20),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10, width: 1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text('Planorh', style: TextStyle(fontSize: isMobile ? 26 : 35, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(onTap: _showResetConfirmation, child: const Icon(Icons.delete_sweep_outlined, color: Colors.white, size: 28)),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _showClipboardDialog,
                    child: Icon(Icons.content_paste, color: Colors.white, size: isMobile ? 24 : 28),
                  ),
                  SizedBox(width: isMobile ? 12 : 24),
                  _buildStatItem('BUSY TIME', '${busyHours.toStringAsFixed(1)} hrs'),
                  SizedBox(width: isMobile ? 8 : 16),
                  _buildStatItem('FREE time', '${freeHours.toStringAsFixed(1)} hrs'),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.zoom_out, color: Colors.white54, size: 16),
              Expanded(
                flex: 2,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.0, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    activeTickMarkColor: Colors.white54, inactiveTickMarkColor: Colors.white24,
                  ),
                  child: Slider(
                    value: pixelsPerMinute, min: 0.75, max: 2.0, divisions: 5, activeColor: const Color(0xFF4A89DC),
                    onChanged: (val) => setState(() => pixelsPerMinute = val),
                  ),
                ),
              ),
              const Icon(Icons.zoom_in, color: Colors.white54, size: 16),
              if (!isMobile) ...[
                const SizedBox(width: 8),
                Text('${(pixelsPerMinute * 100).toInt()}%', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('空白ドラッグ: 追加 | タップ: 詳細', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ],
          )
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
    bool isDeleting = deletingEventId == event.id;

    Color displayColor = (isSelected && previewColor != null) ? previewColor! : event.color;
    IconData displayIcon = (isSelected && previewIcon != null) ? previewIcon! : event.icon; 
    
    int displayStartMin = (isSelected && previewStartMin != null) ? previewStartMin! : event.startMin;
    int displayEndMin = (isSelected && previewEndMin != null) ? previewEndMin! : event.endMin;
    int displayDuration = displayEndMin - displayStartMin;

    double blockHeight = displayDuration * pixelsPerMinute;
    double centerMargin = blockHeight > 30 ? 15.0 : 0.0;
    double handleHeight = blockHeight < 30 ? 24.0 : 30.0;
    double handleOffset = blockHeight < 30 ? -16.0 : -10.0;
    double verticalPadding = blockHeight < 40 ? 4.0 : 8.0;

    return AnimatedPositioned(
      key: ValueKey(event.id),
      duration: draggingId != null ? Duration.zero : const Duration(milliseconds: 200), 
      curve: Curves.easeOutCubic,
      top: displayStartMin * pixelsPerMinute, 
      height: blockHeight, left: 70, right: 30, 
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: isDeleting ? 0.0 : 1.0),
        duration: const Duration(milliseconds: 300),
        curve: isDeleting ? Curves.easeIn : Curves.easeOutBack, 
        builder: (context, value, child) {
          return Transform.scale(
            scale: isDeleting ? (0.95 + 0.05 * value) : value, 
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child)
          );
        },
        child: Dismissible(
          key: Key('dismiss_${event.id}'),
          direction: DismissDirection.startToEnd, 
          background: Container(
            alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20.0),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ),
          confirmDismiss: (direction) async {
            setState(() {
              deletingEventId = event.id;
              if (selectedEvent?.id == event.id) { selectedEvent = null; _isCreatingNew = false; }
            });
            await Future.delayed(const Duration(milliseconds: 300));
            return true;
          },
          onDismissed: (direction) {
            final target = events.firstWhere((e) => e.id == event.id);
            _addToHistory(target.title, target.location, target.notes);
            setState(() {
              events.removeWhere((e) => e.id == event.id);
              if (deletingEventId == event.id) deletingEventId = null;
            });
            _saveEvents();
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
                      clipBehavior: Clip.antiAlias, 
                      decoration: BoxDecoration(
                        color: displayColor.withOpacity(0.15), 
                        border: Border.all(color: displayColor, width: isSelected ? 3 : 2), 
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: verticalPadding),
                        child: SingleChildScrollView( 
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (blockHeight > 25)
                                Row(
                                  children: [
                                    Icon(displayIcon, color: Colors.white, size: 18), 
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              if (blockHeight > 50) ...[
                                const SizedBox(height: 4),
                                Text('${_formatTime(displayStartMin)} - ${_formatTime(displayEndMin)}', style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                        _singleTapTimer = Timer(const Duration(milliseconds: 150), () {
                          if (mounted && !isDoubleClickMode && draggingId == null) {
                            setState(() {
                              if (selectedEvent?.id == event.id) selectedEvent = null;
                              else selectedEvent = event;
                            });
                          }
                        });
                      },
                      onVerticalDragStart: (details) {
                        setState(() {
                          if (_isCreatingNew && selectedEvent?.id != event.id) _cancelNewEvent();
                          draggingId = event.id;
                          dragStartGlobalY = details.globalPosition.dy;
                          preDragState = { for (var e in events) e.id: e.clone() };
                          draggingIndex = events.indexWhere((e) => e.id == event.id);
                        });
                      },
                      onVerticalDragUpdate: (details) {
                        setState(() {
                          int totalDelta = ((details.globalPosition.dy - dragStartGlobalY) / pixelsPerMinute).round();
                          int dragIndex = draggingIndex!;
                          if (dragIndex == -1) return;
                          
                          ScheduleEvent dragged = events[dragIndex];
                          int dur = preDragState[dragged.id]!.duration;
                          int newStart = _snap(preDragState[dragged.id]!.startMin + totalDelta);
                          
                          if (isDoubleClickMode) {
                            dragged.startMin = newStart.clamp(0, 1440 - dur);
                            dragged.endMin = dragged.startMin + dur;
                          } else {
                            dragged.startMin = newStart.clamp(_getFloor(dragIndex), _getCeil(dragIndex) - dur);
                            dragged.endMin = dragged.startMin + dur;
                            _pushUpwards(dragIndex); _pushDownwards(dragIndex);
                          }
                        });
                      },
                      onVerticalDragEnd: (details) {
                        setState(() {
                          if (isDoubleClickMode) {
                            List<List<int>> freeGaps = [];
                            int currentMax = 0;
                            final others = events.where((e) => e.id != event.id).toList()
                              ..sort((a, b) => a.startMin.compareTo(b.startMin));
                            for (var o in others) {
                              if (o.startMin > currentMax) freeGaps.add([currentMax, o.startMin]);
                              if (o.endMin > currentMax) currentMax = o.endMin;
                            }
                            if (1440 > currentMax) freeGaps.add([currentMax, 1440]);

                            double dropCenter = event.startMin + event.duration / 2;
                            List<int>? targetGap;
                            for (var gap in freeGaps) { if (dropCenter >= gap[0] && dropCenter <= gap[1]) { targetGap = gap; break; } }
                            if (targetGap == null) {
                              int maxOverlap = 0;
                              for (var gap in freeGaps) {
                                int overlap = max(0, min(gap[1], event.endMin) - max(gap[0], event.startMin));
                                if (overlap > maxOverlap) { maxOverlap = overlap; targetGap = gap; }
                              }
                            }
                            bool fitSuccess = false;
                            if (targetGap != null) {
                              int gStart = targetGap[0], gEnd = targetGap[1], gDur = gEnd - gStart;
                              if (gDur >= globalMinDuration) {
                                int origDur = preDragState[event.id]!.duration;
                                int proposedStart = event.startMin.clamp(gStart, gEnd - globalMinDuration);
                                int proposedEnd = min(gEnd, proposedStart + origDur);
                                if (proposedEnd - proposedStart < globalMinDuration) proposedStart = proposedEnd - globalMinDuration;
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
                          draggingId = null; draggingIndex = null;
                          preDragState.clear();
                          events.sort((a, b) => a.startMin.compareTo(b.startMin));
                        });
                        _saveEvents();
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),

                  Positioned(
                    top: handleOffset, left: 0, right: 0, height: handleHeight,
                    child: GestureDetector(
                      onVerticalDragStart: (details) {
                        setState(() {
                          draggingId = event.id; dragStartGlobalY = details.globalPosition.dy;
                          preDragState = { for (var e in events) e.id: e.clone() };
                          draggingIndex = events.indexWhere((e) => e.id == event.id);
                        });
                      },
                      onVerticalDragUpdate: (details) {
                        if (isDoubleClickMode) return; 
                        setState(() {
                          int totalDelta = ((details.globalPosition.dy - dragStartGlobalY) / pixelsPerMinute).round();
                          int dragIndex = draggingIndex!;
                          if (dragIndex == -1) return;
                          int newStart = _snap(preDragState[events[dragIndex].id]!.startMin + totalDelta);
                          events[dragIndex].startMin = newStart.clamp(_getFloor(dragIndex), preDragState[events[dragIndex].id]!.endMin - globalMinDuration);
                          _pushUpwards(dragIndex);
                        });
                      },
                      onVerticalDragEnd: (_) { setState(() { draggingId = null; draggingIndex = null; }); _saveEvents(); },
                      child: Container(color: Colors.transparent, alignment: Alignment.topCenter, padding: const EdgeInsets.only(top: 6), child: Container(width: 8, height: 8, decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle))),
                    ),
                  ),

                  Positioned(
                    bottom: handleOffset, left: 0, right: 0, height: handleHeight,
                    child: GestureDetector(
                      onVerticalDragStart: (details) {
                        setState(() {
                          draggingId = event.id; dragStartGlobalY = details.globalPosition.dy;
                          preDragState = { for (var e in events) e.id: e.clone() };
                          draggingIndex = events.indexWhere((e) => e.id == event.id);
                        });
                      },
                      onVerticalDragUpdate: (details) {
                        if (isDoubleClickMode) return; 
                        setState(() {
                          int totalDelta = ((details.globalPosition.dy - dragStartGlobalY) / pixelsPerMinute).round();
                          int dragIndex = draggingIndex!;
                          if (dragIndex == -1) return;
                          int newEnd = _snap(preDragState[events[dragIndex].id]!.endMin + totalDelta);
                          events[dragIndex].endMin = newEnd.clamp(preDragState[events[dragIndex].id]!.startMin + globalMinDuration, _getCeil(dragIndex));
                          _pushDownwards(dragIndex);
                        });
                      },
                      onVerticalDragEnd: (_) { setState(() { draggingId = null; draggingIndex = null; }); _saveEvents(); },
                      child: Container(color: Colors.transparent, alignment: Alignment.bottomCenter, padding: const EdgeInsets.only(bottom: 6), child: Container(width: 8, height: 8, decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle))),
                    ),
                  ),

                  Positioned(
                    top: 4, right: 6,
                    child: GestureDetector(
                      onTap: () { setState(() => event.isPinned = !event.isPinned); _saveEvents(); },
                      child: Container(padding: const EdgeInsets.all(6), child: Icon(event.isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: event.isPinned ? Colors.white : Colors.white54, size: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(int minutes) {
    int h = minutes ~/ 60; int m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class CustomTimePicker extends StatefulWidget {
  final int value;
  final int minMinute;
  final int maxMinute;
  final ValueChanged<int> onChanged;
  const CustomTimePicker({super.key, required this.value, required this.minMinute, required this.maxMinute, required this.onChanged });
  @override
  State<CustomTimePicker> createState() => _CustomTimePickerState();
}

class _CustomTimePickerState extends State<CustomTimePicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  final int _baseMinute = 100000 * 60; 
  @override
  void initState() {
    super.initState();
    int safeValue = widget.value.clamp(widget.minMinute, widget.maxMinute);
    _hourController = FixedExtentScrollController(initialItem: safeValue ~/ 60);
    _minuteController = FixedExtentScrollController(initialItem: _baseMinute + safeValue);
  }
  @override
  void didUpdateWidget(covariant CustomTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      int targetHour = widget.value ~/ 60;
      int targetMinIndex = _baseMinute + widget.value;
      if (_hourController.hasClients && _hourController.selectedItem != targetHour) _hourController.jumpToItem(targetHour);
      if (_minuteController.hasClients && _minuteController.selectedItem != targetMinIndex) _minuteController.jumpToItem(targetMinIndex);
    }
  }
  @override
  void dispose() { _hourController.dispose(); _minuteController.dispose(); super.dispose(); }
  void _updateFromMinute(int index) {
    int newTotal = (index - _baseMinute).clamp(widget.minMinute, widget.maxMinute);
    if (newTotal != widget.value) widget.onChanged(newTotal);
  }
  void _updateFromHour(int index) {
    int currentMin = widget.value % 60;
    int newTotal = (index * 60 + currentMin).clamp(widget.minMinute, widget.maxMinute);
    if (newTotal != widget.value) widget.onChanged(newTotal);
  }
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CupertinoPicker.builder(
            scrollController: _hourController, itemExtent: 44, childCount: 25, 
            selectionOverlay: CupertinoPickerDefaultSelectionOverlay(background: Colors.white.withOpacity(0.08)),
            onSelectedItemChanged: _updateFromHour,
            itemBuilder: (context, index) => (index >= 0 && index <= 24) ? Center(child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontSize: 26))) : null,
          ),
        ),
        const Text(':', style: TextStyle(color: Colors.white54, fontSize: 26, fontWeight: FontWeight.bold)),
        Expanded(
          child: CupertinoPicker.builder(
            scrollController: _minuteController, itemExtent: 44, childCount: 60 * 1000000, 
            selectionOverlay: CupertinoPickerDefaultSelectionOverlay(background: Colors.white.withOpacity(0.08)),
            onSelectedItemChanged: _updateFromMinute,
            itemBuilder: (context, index) {
              int val = index - _baseMinute;
              return (val >= 0 && val <= 1440) ? Center(child: Text((val % 60).toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontSize: 26))) : null;
            },
          ),
        ),
      ],
    );
  }
}

class EventDetailPanel extends StatefulWidget {
  final ScheduleEvent event;
  final List<ScheduleEvent> allEvents; 
  final List<Map<String, String>> history; 
  final bool isCreatingNew; 
  final bool startInEditMode; 
  final bool isMobile; 
  final VoidCallback onClose;
  final ValueChanged<ScheduleEvent> onSave;
  final VoidCallback onDelete;
  final VoidCallback onCancelNew; 
  final ValueChanged<Color?> onColorPreview;
  final ValueChanged<IconData?> onIconPreview; 
  final ValueChanged<List<int>?> onTimePreview; 

  const EventDetailPanel({
    super.key, required this.event, required this.allEvents, required this.history, required this.isCreatingNew, 
    this.startInEditMode = false, required this.isMobile, required this.onClose, required this.onSave, required this.onDelete,
    required this.onCancelNew, required this.onColorPreview, required this.onIconPreview, required this.onTimePreview, 
  });

  @override
  State<EventDetailPanel> createState() => _EventDetailPanelState();
}

class _EventDetailPanelState extends State<EventDetailPanel> {
  late bool _isEditing;
  late TextEditingController _titleController, _locationController, _notesController;
  late Color _editColor; late IconData _editIcon; 
  int _editStartMin = 0, _editEndMin = 0;
  String? _timeError;

  final List<IconData> _iconPalette = [
    Icons.event_note, Icons.wb_sunny_outlined, Icons.bedtime,
    Icons.psychology_outlined, Icons.people_outline, Icons.fitness_center,
    Icons.menu_book, Icons.computer, Icons.restaurant, 
    Icons.shopping_cart_outlined, Icons.train, Icons.directions_car, Icons.directions_walk,
    Icons.local_cafe_outlined, Icons.phone_in_talk_outlined, Icons.music_note_outlined, 
    Icons.movie_creation_outlined, Icons.home_outlined, Icons.work_outline,
  ];

  @override
  void initState() { super.initState(); _isEditing = widget.startInEditMode; _initControllers(); }

  @override
  void didUpdateWidget(covariant EventDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id) { _isEditing = widget.startInEditMode; _initControllers(); }
    else if (oldWidget.event.startMin != widget.event.startMin || oldWidget.event.endMin != widget.event.endMin) {
      _editStartMin = widget.event.startMin; _editEndMin = widget.event.endMin; _timeError = null; 
    }
  }

  void _initControllers() {
    _titleController = TextEditingController(text: widget.isCreatingNew ? '' : widget.event.title); 
    _locationController = TextEditingController(text: widget.isCreatingNew ? '' : widget.event.location); 
    _notesController = TextEditingController(text: widget.event.notes);
    _editStartMin = widget.event.startMin; _editEndMin = widget.event.endMin; _editColor = widget.event.color; _editIcon = widget.event.icon; _timeError = null;
  }

  @override
  void dispose() { _titleController.dispose(); _locationController.dispose(); _notesController.dispose(); super.dispose(); }

  void _applyHistory(Map<String, String> data) {
    setState(() { _titleController.text = data['title'] ?? ''; _locationController.text = data['location'] ?? ''; _notesController.text = data['notes'] ?? ''; });
  }

  int _getGapStart() {
    int start = 0;
    for (var o in widget.allEvents) { if (o.id != widget.event.id && o.endMin <= widget.event.startMin) start = max(start, o.endMin); }
    return start;
  }

  int _getGapEnd() {
    int end = 1440;
    for (var o in widget.allEvents) { if (o.id != widget.event.id && o.startMin >= widget.event.endMin) end = min(end, o.startMin); }
    return end;
  }

  void _updateTimeState(int pickedMin, bool isStart) {
    setState(() {
      if (isStart) { _editStartMin = pickedMin; if (_editStartMin > _editEndMin - 10) _editEndMin = _editStartMin + 10; }
      else { _editEndMin = pickedMin; if (_editEndMin < _editStartMin + 10) _editStartMin = _editEndMin - 10; }
      _timeError = null; 
    });
    widget.onTimePreview([_editStartMin, _editEndMin]);
  }

  void _showTimePickerModal(BuildContext context, bool isStart) {
    int minLimit = isStart ? _getGapStart() : _getGapStart() + 10;
    int maxLimit = isStart ? _getGapEnd() - 10 : _getGapEnd();
    showDialog(
      context: context, barrierColor: Colors.transparent, 
      builder: (ctx) => StatefulBuilder(
        builder: (context, setS) => Align(
          alignment: widget.isMobile ? Alignment.center : Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * (widget.isMobile ? 0.9 : 0.45), margin: EdgeInsets.only(right: widget.isMobile ? 0 : 16),
              decoration: BoxDecoration(color: const Color(0xFF2A2D35), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    TextButton.icon(onPressed: () async {
                      Navigator.pop(ctx);
                      final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: (isStart ? _editStartMin : _editEndMin) ~/ 60, minute: (isStart ? _editStartMin : _editEndMin) % 60), initialEntryMode: TimePickerEntryMode.input);
                      if (picked != null) _updateTimeState(picked.hour * 60 + picked.minute, isStart);
                    }, icon: const Icon(Icons.keyboard), label: const Text('手入力')),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('完了')),
                  ]),
                  SizedBox(height: 200, child: CustomTimePicker(value: isStart ? _editStartMin : _editEndMin, minMinute: minLimit, maxMinute: maxLimit, onChanged: (v) => setS(() => _updateTimeState(v, isStart)))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _saveChanges() {
    if (widget.allEvents.any((o) => o.id != widget.event.id && _editStartMin < o.endMin && _editEndMin > o.startMin)) {
      setState(() { _timeError = '※指定した時間は重複しています。'; }); return;
    }
    ScheduleEvent updated = widget.event.clone();
    updated.title = _titleController.text.trim().isEmpty ? '名称未設定の予定' : _titleController.text;
    updated.location = _locationController.text; updated.notes = _notesController.text;
    updated.startMin = _editStartMin; updated.endMin = _editEndMin; updated.color = _editColor; updated.icon = _editIcon;
    widget.onSave(updated); setState(() { _isEditing = false; });
  }

  String _formatTime(int mins) => '${(mins ~/ 60).toString().padLeft(2, '0')}:${(mins % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF1E2024), border: Border(left: BorderSide(color: Colors.white10))),
      child: Column(children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 16 : 24, vertical: 20),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
          child: Row(children: [
            Expanded(child: Text(_isEditing ? 'スケジュール編集' : 'スケジュール詳細', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            GestureDetector(onTap: widget.isCreatingNew ? widget.onCancelNew : widget.onClose, child: const Icon(Icons.close, color: Colors.white54)),
          ]),
        ),
        Expanded(child: SingleChildScrollView(padding: EdgeInsets.all(widget.isMobile ? 20 : 32), child: _isEditing ? _buildEditMode() : _buildViewMode())),
      ]),
    );
  }

  Widget _buildViewMode() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: widget.event.color.withOpacity(0.2), shape: BoxShape.circle), child: Icon(widget.event.icon, color: widget.event.color, size: 28)),
        const SizedBox(width: 16),
        Expanded(child: Text(widget.event.title, style: TextStyle(fontSize: widget.isMobile ? 20 : 24, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 40),
      _buildDetailRow(Icons.access_time, '予定時間', '${_formatTime(widget.event.startMin)} - ${_formatTime(widget.event.endMin)}'),
      const SizedBox(height: 24),
      _buildDetailRow(Icons.hourglass_bottom, '所要時間', '${widget.event.duration} 分'),
      const SizedBox(height: 24),
      _buildDetailRow(Icons.location_on_outlined, '場所', widget.event.location),
      const SizedBox(height: 32),
      _buildNotesArea(widget.event.notes),
      const SizedBox(height: 40),
      Row(children: [
        Expanded(child: ElevatedButton.icon(onPressed: () => setState(() => _isEditing = true), icon: const Icon(Icons.edit, size: 18), label: const Text('編集する'))),
        const SizedBox(width: 16),
        Expanded(child: OutlinedButton.icon(onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline, size: 18), label: const Text('削除する'), style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)))),
      ]),
    ]);
  }

  Widget _buildEditMode() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.history.isNotEmpty) ...[
        const Text('以前の予定からコピー', style: TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 10),
        SizedBox(height: 36, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: widget.history.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (ctx, i) => ActionChip(label: Text(widget.history[i]['title']!, style: const TextStyle(fontSize: 12)), onPressed: () => _applyHistory(widget.history[i])))),
        const SizedBox(height: 24),
      ],
      const Text('タイトル', style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 8),
      TextField(controller: _titleController, style: const TextStyle(fontWeight: FontWeight.bold), decoration: _inputDecoration('タスク名を入力'), autofocus: widget.isCreatingNew),
      const SizedBox(height: 24),
      const Text('アイコン', style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, children: _iconPalette.map((i) => GestureDetector(onTap: () { setState(() => _editIcon = i); widget.onIconPreview(i); }, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: _editIcon == i ? _editColor.withOpacity(0.2) : Colors.white.withOpacity(0.05), shape: BoxShape.circle, border: _editIcon == i ? Border.all(color: _editColor, width: 2) : null), child: Icon(i, color: _editIcon == i ? _editColor : Colors.white54, size: 20)))).toList()),
      const SizedBox(height: 24),
      const Text('カラー', style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, children: ScheduleEvent.colorPalette.map((c) => GestureDetector(onTap: () { setState(() => _editColor = c); widget.onColorPreview(c); }, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: _editColor.value == c.value ? Border.all(color: Colors.white, width: 3) : null), child: _editColor.value == c.value ? const Icon(Icons.check, color: Colors.white, size: 20) : null))).toList()),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('予定時間', style: TextStyle(color: Colors.white54, fontSize: 12)), Text('${_editEndMin - _editStartMin} 分')]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: InkWell(onTap: () => _showTimePickerModal(context, true), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Center(child: Text(_formatTime(_editStartMin), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('-', style: TextStyle(color: Colors.white54, fontSize: 18))),
        Expanded(child: InkWell(onTap: () => _showTimePickerModal(context, false), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Center(child: Text(_formatTime(_editEndMin), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))))),
      ]),
      if (_timeError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_timeError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold))),
      const SizedBox(height: 24),
      const Text('場所', style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 8),
      TextField(controller: _locationController, decoration: _inputDecoration('場所を入力')),
      const SizedBox(height: 24),
      const Text('詳細・メモ', style: TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 8),
      TextField(controller: _notesController, maxLines: 6, decoration: _inputDecoration('メモを入力...')),
      const SizedBox(height: 40),
      Row(children: [
        Expanded(child: ElevatedButton.icon(onPressed: _saveChanges, icon: const Icon(Icons.check, size: 18), label: const Text('保存する'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8CC152)))),
        const SizedBox(width: 16),
        Expanded(child: OutlinedButton(onPressed: () { if (widget.isCreatingNew) widget.onCancelNew(); else { setState(() { _isEditing = false; _initControllers(); }); widget.onColorPreview(null); widget.onIconPreview(null); widget.onTimePreview(null); } }, child: const Text('キャンセル'))),
      ]),
    ]);
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: Colors.white.withOpacity(0.05), contentPadding: const EdgeInsets.all(16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _editColor, width: 1.5)));
  Widget _buildDetailRow(IconData i, String l, String v) => Row(children: [Icon(i, color: Colors.white54, size: 24), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 4), Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))]))]);
  Widget _buildNotesArea(String n) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.subject, color: Colors.white54, size: 24), SizedBox(width: 16), Text('詳細・メモ', style: TextStyle(color: Colors.white54, fontSize: 12))]), const SizedBox(height: 12), Container(width: double.infinity, constraints: const BoxConstraints(minHeight: 120), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)), child: Text(n.isNotEmpty ? n : '詳細がありません', style: TextStyle(color: n.isNotEmpty ? Colors.white70 : Colors.white38, fontSize: 14, height: 1.6)))]);
}