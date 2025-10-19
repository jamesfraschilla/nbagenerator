import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui show Codec, Image, instantiateImageCodec;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'edit_scenario_screen.dart';
import 'scenario_generator.dart';

void main() {
  runApp(const ScenarioApp());
}

class ScenarioApp extends StatefulWidget {
  const ScenarioApp({super.key});

  @override
  State<ScenarioApp> createState() => _ScenarioAppState();
}

class _ScenarioAppState extends State<ScenarioApp> {
  ThemeMode _mode = ThemeMode.dark;
  static const _themeFileName = 'theme_mode.txt';

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final file = await _themeFile();
      if (await file.exists()) {
        final value = (await file.readAsString()).trim();
        if (!mounted) return;
        setState(() {
          _mode = value == 'light'
              ? ThemeMode.light
              : value == 'dark'
                  ? ThemeMode.dark
                  : ThemeMode.dark;
        });
      }
    } catch (e) {
      debugPrint('Failed to load theme preference: $e');
    }
  }

  Future<void> _toggleTheme() async {
    final next = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setState(() => _mode = next);
    try {
      final file = await _themeFile();
      await file.writeAsString(next == ThemeMode.light ? 'light' : 'dark');
    } catch (e) {
      debugPrint('Failed to save theme preference: $e');
    }
  }

  Future<File> _themeFile() async {
    final dir = Directory('${Directory.systemTemp.path}/clutch_scenarios');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/$_themeFileName');
  }

  @override
  Widget build(BuildContext context) {
    const baseSeed = Colors.blue;
    final lightScheme = ColorScheme.fromSeed(
      seedColor: baseSeed,
      brightness: Brightness.light,
    );
    const darkSurface = Color.fromARGB(255, 21, 33, 57);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: baseSeed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: darkSurface,
      surfaceContainerHighest: darkSurface,
      surfaceTint: Colors.transparent,
      primaryContainer: darkSurface.withValues(alpha: 0.85),
    );
    return MaterialApp(
      title: 'Clutch Time Scenario Generator',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.transparent,
            elevation: 0,
            side: const BorderSide(color: Colors.orange, width: 2),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.black),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        scaffoldBackgroundColor: darkSurface,
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.transparent,
            elevation: 0,
            side: const BorderSide(color: Colors.orange, width: 2),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
      ),
      home: HomeScreen(
        isDarkMode: _mode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

/// -------- Simple in-memory history store --------
class ScenarioLogEntry {
  final DateTime createdAt;
  final Scenario scenario;
  final String notes;
  ScenarioLogEntry(
      {required this.createdAt, required this.scenario, required this.notes});
}

class HistoryStore {
  HistoryStore._();
  static final HistoryStore instance = HistoryStore._();
  final ValueNotifier<List<ScenarioLogEntry>> entries =
      ValueNotifier<List<ScenarioLogEntry>>([]);
  void add(Scenario s, String notes) {
    final list = List<ScenarioLogEntry>.from(entries.value);
    list.insert(0,
        ScenarioLogEntry(createdAt: DateTime.now(), scenario: s, notes: notes));
    entries.value = list;
  }
}

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final Future<void> Function() onToggleTheme;
  const HomeScreen(
      {super.key, required this.isDarkMode, required this.onToggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScenarioController controller = ScenarioController();
  static const _animationFadeDuration = Duration(milliseconds: 400);
  static const _prefsDirName = 'clutch_scenarios';
  static const _competitionFileName = 'competition.txt';

  bool _isAnimating = false;
  bool _showAnimation = false;
  bool _animationFadeOut = false;
  int _animationRun = 0;
  Completer<void>? _animationCompleter;
  bool _hideShotClock = false;
  bool _forceHideShotClock = false;

  Future<void> _loadCompetition() async {
    try {
      final file = await _competitionFile();
      if (!await file.exists()) return;
      final value = (await file.readAsString()).trim();
      final selected = Competition.values.firstWhere(
        (c) => c.name == value,
        orElse: () => controller.settings.competition,
      );
      if (!mounted) return;
      setState(() {
        controller.setCompetition(selected);
      });
    } catch (e) {
      debugPrint('Failed to load competition preference: $e');
    }
  }

  Future<void> _saveCompetition(Competition competition) async {
    try {
      final file = await _competitionFile();
      await file.writeAsString(competition.name);
    } catch (e) {
      debugPrint('Failed to save competition preference: $e');
    }
  }

  Future<File> _competitionFile() async {
    final dir = await _prefsDir();
    return File('${dir.path}/$_competitionFileName');
  }

  Future<Directory> _prefsDir() async {
    final dir = Directory('${Directory.systemTemp.path}/$_prefsDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  void initState() {
    super.initState();
    _loadCompetition();
  }

  @override
  Widget build(BuildContext context) {
    final has = controller.hasScenario;
    final s = controller.scenario;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clutch Time Scenario'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            tooltip: widget.isDarkMode
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
            onPressed: () {
              widget.onToggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Competition dropdown
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                  child: Align(
                    alignment: Alignment.center,
                    child: IntrinsicWidth(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Competition',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Competition>(
                            value: controller.settings.competition,
                            isExpanded: false,
                            items: Competition.values
                                .map((c) => DropdownMenuItem<Competition>(
                                      value: c,
                                      child: Text(competitionLabel(c)),
                                    ))
                                .toList(),
                            onChanged: (c) {
                              if (c != null) {
                                setState(() => controller.setCompetition(c));
                                _saveCompetition(c);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                _RangeSelector(
                  controller: controller,
                  onChanged: () => setState(() {}),
                  onReset: _handleRangeReset,
                  hideShotClock: _hideShotClock,
                  onHideShotClockChanged: _toggleHideShotClock,
                ),
                const SizedBox(height: 8),

                // Scoreboard
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        widthFactor: 0.98,
                        child: AspectRatio(
                          aspectRatio: 16 / 18,
                          child: _Scoreboard(
                            controller: controller,
                            onEditTeamName: _editTeamName,
                            onEditScore: _editScore,
                            onEditFouls: _editFouls,
                            onEditTimeouts: _editTimeouts,
                            onEditGameClock: _editGameClock,
                            onEditShotClock: _editShotClock,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Outside info
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _OutsideMeta(controller: controller),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isAnimating ? null : () => _handleGenerate(),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(has ? 'Regenerate' : 'Generate'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: has && !_isAnimating
                              ? () async {
                                  final updated = await Navigator.of(context)
                                      .push<Scenario>(
                                    MaterialPageRoute(
                                        builder: (_) => EditScenarioScreen(
                                              initial: s,
                                              competition: controller
                                                  .settings.competition,
                                            )),
                                  );
                                  if (updated != null) {
                                    setState(() {
                                  if (controller.settings.competition ==
                                          Competition.highSchool) {
                                        controller
                                            .setForceHideShotClockHighSchool(
                                                updated.hideShotClock);
                                      } else {
                                        controller
                                            .setForceHideShotClockHighSchool(
                                                false);
                                      }
                                      controller.setScenario(updated);
                                      _forceHideShotClock = updated.hideShotClock;
                                      _hideShotClock = updated.hideShotClock;
                                    });
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit Scenario'),
                        ),
                      ),
                    ],
                  ),
                ),

              ],
            ),
            if (_showAnimation)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: AnimatedOpacity(
                    opacity: _animationFadeOut ? 0 : 1,
                    duration: _animationFadeDuration,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: FractionallySizedBox(
                        widthFactor: 0.75,
                        child: _OneShotGif(
                          key: ValueKey(_animationRun),
                          assetPath: 'assets/clock_bg_transparent_minimal.png',
                          fit: BoxFit.contain,
                          onFinished: _onAnimationFinished,
                        ),
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

  void _handleRangeReset() {
    setState(() {
      _forceHideShotClock = false;
      _hideShotClock = false;
    });
  }

  void _toggleHideShotClock(bool value) {
    setState(() {
      _forceHideShotClock = value;
      _hideShotClock = value;
    });
    if (controller.hasScenario) {
      controller.setScenario(
        controller.scenario.copyWith(hideShotClock: value),
      );
    }
  }

  Future<void> _editTeamName(TeamSide side) async {
    final current =
        side == TeamSide.home ? controller.homeTeamName : controller.guestTeamName;
    final result = await _promptText(
      title: side == TeamSide.home ? 'Edit Home Team' : 'Edit Guest Team',
      initial: current,
      hint: 'Enter team name',
    );
    if (result == null) return;
    if (side == TeamSide.home) {
      controller.setHomeTeamName(result);
    } else {
      controller.setGuestTeamName(result);
    }
    setState(() {});
  }

  Future<void> _editScore(TeamSide side) async {
    if (!controller.hasScenario) return;
    final scenario = controller.scenario;
    final current = side == TeamSide.home ? scenario.homeScore : scenario.guestScore;
    final result = await _promptInt(
      title: side == TeamSide.home ? 'Edit Home Score' : 'Edit Guest Score',
      initialValue: current,
      min: 0,
      max: 150,
    );
    if (result == null) return;
    if (side == TeamSide.home) {
      controller.updateHomeScore(result);
    } else {
      controller.updateGuestScore(result);
    }
    setState(() {});
  }

  Future<void> _editFouls(TeamSide side) async {
    if (!controller.hasScenario) return;
    final rules = controller.currentRules;
    final scenario = controller.scenario;
    final current = side == TeamSide.home ? scenario.homeFouls : scenario.guestFouls;
    final result = await _promptInt(
      title: side == TeamSide.home ? 'Edit Home Fouls' : 'Edit Guest Fouls',
      initialValue: current,
      min: rules.foulMin,
      max: rules.foulMax,
    );
    if (result == null) return;
    if (side == TeamSide.home) {
      controller.updateHomeFouls(result);
    } else {
      controller.updateGuestFouls(result);
    }
    setState(() {});
  }

  Future<void> _editTimeouts(TeamSide side) async {
    if (!controller.hasScenario) return;
    final rules = controller.currentRules;
    final scenario = controller.scenario;
    final current =
        side == TeamSide.home ? scenario.homeTimeouts : scenario.guestTimeouts;
    final result = await _promptInt(
      title: side == TeamSide.home ? 'Edit Home Timeouts' : 'Edit Guest Timeouts',
      initialValue: current,
      min: rules.timeoutMin,
      max: rules.timeoutMax,
    );
    if (result == null) return;
    if (side == TeamSide.home) {
      controller.updateHomeTimeouts(result);
    } else {
      controller.updateGuestTimeouts(result);
    }
    setState(() {});
  }

  Future<void> _editGameClock() async {
    if (!controller.hasScenario) return;
    final currentTenths = controller.scenario.gameClockTenths;
    final result = await _promptClock(
      title: 'Edit Game Clock',
      initialTenths: currentTenths,
    );
    if (result == null) return;
    controller.updateGameClockTenths(result);
    setState(() {});
  }

  Future<void> _editShotClock() async {
    if (!controller.hasScenario) return;
    final rules = controller.currentRules;
    final currentSeconds = controller.scenario.shotClockSeconds;
    final result = await _promptInt(
      title: 'Edit Shot Clock',
      initialValue: currentSeconds,
      min: 0,
      max: rules.shotClockMax,
    );
    if (result == null) return;
    controller.updateShotClock(seconds: result, hide: _hideShotClock);
    setState(() {});
  }

  Future<String?> _promptText({
    required String title,
    required String initial,
    String? hint,
    int maxLength = 18,
  }) async {
    final textController = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: textController,
            maxLength: maxLength,
            autofocus: true,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(textController.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<int?> _promptInt({
    required String title,
    required int initialValue,
    required int min,
    required int max,
  }) async {
    final textController = TextEditingController(text: initialValue.toString());
    String? error;
    return showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: textController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '$min – $max',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final parsed = int.tryParse(textController.text.trim());
                    if (parsed == null) {
                      setLocalState(() => error = 'Enter a number');
                      return;
                    }
                    if (parsed < min || parsed > max) {
                      setLocalState(
                        () => error = 'Enter a value between $min and $max.',
                      );
                      return;
                    }
                    Navigator.of(context).pop(parsed);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<int?> _promptClock({
    required String title,
    required int initialTenths,
  }) async {
    final initialText =
        initialTenths > 0 ? formatGameClockTenths(initialTenths) : '';
    final textController = TextEditingController(text: initialText);
    String? error;
    return showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'm:ss or s.t',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final parsed = _parseClockInput(textController.text);
                    if (parsed == null) {
                      setLocalState(() => error = 'Use m:ss or s.t format');
                      return;
                    }
                    if (parsed < 0 || parsed > 1800) {
                      setLocalState(() => error = 'Keep it within 0–3:00');
                      return;
                    }
                    Navigator.of(context).pop(parsed);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int? _parseClockInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      if (parts.length != 2) return null;
      final mins = int.tryParse(parts[0]);
      final secs = int.tryParse(parts[1]);
      if (mins == null || secs == null) return null;
      if (mins < 0 || secs < 0 || secs > 59) return null;
      return (mins * 60 + secs) * 10;
    }
    if (trimmed.contains('.')) {
      final parts = trimmed.split('.');
      if (parts.length != 2) return null;
      final secs = int.tryParse(parts[0]);
      final tenths = int.tryParse(parts[1]);
      if (secs == null || tenths == null) return null;
      if (secs < 0 || tenths < 0 || tenths > 9) return null;
      return secs * 10 + tenths;
    }
    final secs = int.tryParse(trimmed);
    if (secs == null) return null;
    if (secs < 0) return null;
    return secs * 10;
  }

  Future<void> _handleGenerate() async {
    if (_isAnimating) return;

    final generated = controller.generateScenario();

    final completer = Completer<void>();
    _animationCompleter = completer;

    setState(() {
      _isAnimating = true;
      _showAnimation = true;
      _animationFadeOut = false;
      _animationRun++;
    });

    await completer.future;
    if (!context.mounted) return;

    final autoHide = generated.hideShotClock;
    final shouldHide = _forceHideShotClock ? true : autoHide;
    final applied = generated.copyWith(hideShotClock: shouldHide);

    controller.setScenario(applied);
    setState(() {
      _animationFadeOut = true;
      _hideShotClock = shouldHide;
    });

    await Future.delayed(_animationFadeDuration);
    if (!context.mounted) return;

    setState(() {
      _showAnimation = false;
      _isAnimating = false;
    });

    _animationCompleter = null;
  }

  void _onAnimationFinished() {
    final completer = _animationCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

}

/// -------- History Screen with filters --------
enum TimeFilter { all, last24h, last7d, last30d }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final store = HistoryStore.instance;
  static const List<IntRange> _scoreFilterOptions = <IntRange>[
    IntRange(0, 12, 'Any'),
    IntRange(0, 0, 'Tie only'),
    IntRange(1, 3, '1-3'),
    IntRange(4, 6, '4-6'),
    IntRange(1, 6, '1-6'),
    IntRange(7, 9, '7-9'),
    IntRange(10, 12, '10-12'),
    IntRange(7, 12, '7-12'),
  ];

  // Filters
  TimeFilter _timeFilter = TimeFilter.all;
  StartType? _startType; // null = all
  IntRange _scoreRange = const IntRange(0, 12, 'Any');
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            // Filters
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _timeDropdown()),
                      const SizedBox(width: 8),
                      Expanded(child: _startTypeDropdown()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _scoreRangeDropdown()),
                      const SizedBox(width: 8),
                      Expanded(child: _searchField()),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Results
            Expanded(
              child: ValueListenableBuilder<List<ScenarioLogEntry>>(
                valueListenable: store.entries,
                builder: (context, list, _) {
                  final filtered = _applyFilters(list);
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No matching entries.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        _HistoryCard(entry: filtered[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ScenarioLogEntry> _applyFilters(List<ScenarioLogEntry> list) {
    final now = DateTime.now();

    bool inTime(DateTime ts) {
      switch (_timeFilter) {
        case TimeFilter.all:
          return true;
        case TimeFilter.last24h:
          return ts.isAfter(now.subtract(const Duration(hours: 24)));
        case TimeFilter.last7d:
          return ts.isAfter(now.subtract(const Duration(days: 7)));
        case TimeFilter.last30d:
          return ts.isAfter(now.subtract(const Duration(days: 30)));
      }
    }

    int absDiff(Scenario s) => (s.homeScore - s.guestScore).abs();
    bool inScore(Scenario s) =>
        absDiff(s) >= _scoreRange.min && absDiff(s) <= _scoreRange.max;

    return list.where((e) {
      if (!inTime(e.createdAt)) return false;
      if (_startType != null && e.scenario.startType != _startType)
        return false;
      if (!inScore(e.scenario)) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!e.notes.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Widget _timeDropdown() {
    return InputDecorator(
      decoration: const InputDecoration(
          labelText: 'Time Range', border: OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TimeFilter>(
          value: _timeFilter,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: TimeFilter.all, child: Text('All time')),
            DropdownMenuItem(
                value: TimeFilter.last24h, child: Text('Last 24 hours')),
            DropdownMenuItem(
                value: TimeFilter.last7d, child: Text('Last 7 days')),
            DropdownMenuItem(
                value: TimeFilter.last30d, child: Text('Last 30 days')),
          ],
          onChanged: (v) => setState(() => _timeFilter = v ?? TimeFilter.all),
        ),
      ),
    );
  }

  Widget _startTypeDropdown() {
    final items = <DropdownMenuItem<StartType?>>[
      const DropdownMenuItem<StartType?>(
          value: null, child: Text('All start types')),
      ...StartType.values.map((st) => DropdownMenuItem<StartType?>(
          value: st, child: Text(startTypeLabel(st)))),
    ];
    return InputDecorator(
      decoration: const InputDecoration(
          labelText: 'Start Type', border: OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<StartType?>(
          value: _startType,
          isExpanded: true,
          items: items,
          onChanged: (v) => setState(() => _startType = v),
        ),
      ),
    );
  }

  Widget _scoreRangeDropdown() {
    final items = _scoreFilterOptions
        .map((r) => DropdownMenuItem<IntRange>(value: r, child: Text(r.label)))
        .toList();
    return InputDecorator(
      decoration: const InputDecoration(
          labelText: 'Score Differential', border: OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<IntRange>(
          value: _scoreRange,
          isExpanded: true,
          items: items,
          onChanged: (v) => setState(() => _scoreRange = v ?? _scoreRange),
        ),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      decoration: const InputDecoration(
        labelText: 'Search notes',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (v) => setState(() => _query = v),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ScenarioLogEntry entry;
  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final s = entry.scenario;
    final time = entry.createdAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final timestamp =
        '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(timestamp, style: Theme.of(context).textTheme.labelMedium),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.secondaryContainer,
                  ),
                  child: Text('Start Type: ${startTypeLabel(s.startType)}',
                      style: Theme.of(context).textTheme.labelSmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _kv('Game', formatGameClockTenths(s.gameClockTenths)),
                _kv('Shot', (s.hideShotClock ? '––' : '${s.shotClockSeconds}')),
                _kv('Period', periodLabel(s.period)),
                _kv('Possession',
                    s.possession == TeamSide.home ? 'Home' : 'Guest'),
                _kv('Score', '${s.homeScore} - ${s.guestScore}'),
                _kv('Fouls (H/G)', '${s.homeFouls}/${s.guestFouls}'),
                _kv('TOL (H/G)', '${s.homeTimeouts}/${s.guestTimeouts}'),
              ],
            ),
            const SizedBox(height: 10),
            Text(entry.notes, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(v),
        ],
      ),
    );
  }
}

/// --------- Range selector and filters ---------
class _RangeSelector extends StatefulWidget {
  final ScenarioController controller;
  final VoidCallback onChanged;
  final VoidCallback? onReset;
  final bool hideShotClock;
  final ValueChanged<bool> onHideShotClockChanged;
  const _RangeSelector({
    required this.controller,
    required this.onChanged,
    this.onReset,
    required this.hideShotClock,
    required this.onHideShotClockChanged,
  });

  @override
  State<_RangeSelector> createState() => _RangeSelectorState();
}

class _RangeSelectorState extends State<_RangeSelector> {
  static const List<int?> _scoreOptions = <int?>[
    null,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
  ];

  late final List<int?> _clockMinOptions;
  late final List<int?> _clockMaxOptions;

  int? _scoreMin;
  int? _scoreMax;
  bool _scoreTie = false;

  int? _clockMin;
  int? _clockMax;

  final Set<StartType> _selectedStarts = <StartType>{};

  IntRange? _foulRange;
  IntRange? _timeoutRange;
  PossessionPreference? _possessionPreference;

  static const IntRange _nbaFoulRange = IntRange(3, 5, '3-5');
  static const IntRange _fibaFoulRange = IntRange(2, 4, '2-4');
  static const IntRange _hsFoulRange = IntRange(3, 5, '3-5');
  static const IntRange _ncaaFoulRange = IntRange(4, 10, '4-10');

  static const IntRange _nbaTimeoutRange = IntRange(0, 2, '0-2');
  static const IntRange _defaultTimeoutRange = IntRange(0, 3, '0-3');

  @override
  void initState() {
    super.initState();
    _clockMinOptions = _buildClockMinOptions();
    _clockMaxOptions = _buildClockMaxOptions();

    final scoreSelection = widget.controller.settings.scoreDiff;
    _scoreMin = scoreSelection.min;
    _scoreMax = scoreSelection.max;
    _scoreTie = scoreSelection.tie;

    final clockSelection = widget.controller.settings.clock;
    _clockMin = clockSelection.minTenths;
    _clockMax = clockSelection.maxTenths;

    final startTypes = widget.controller.settings.startTypes;
    if (startTypes != null) {
      _selectedStarts
        ..clear()
        ..addAll(startTypes);
    }

    _foulRange = widget.controller.settings.foulRange;
    _timeoutRange = widget.controller.settings.timeoutRange;
    _possessionPreference = widget.controller.settings.possessionPreference;
  }

  List<int?> _buildClockMinOptions() {
    final values = <int?>[null, 1];
    for (var second = 1; second <= 180; second++) {
      values.add(second * 10);
    }
    return values;
  }

  List<int?> _buildClockMaxOptions() {
    final values = <int?>[null];
    for (var second = 1; second <= 180; second++) {
      values.add(second * 10);
    }
    return values;
  }

  bool get _hasAdvancedFilters =>
      _foulRange != null || _timeoutRange != null || _possessionPreference != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _filterField(
                  context,
                  label: 'Score',
                  value: _scoreLabel(),
                  onTap: _showScoreSelector,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _filterField(
                  context,
                  label: 'Clock',
                  value: _clockLabel(),
                  onTap: _showClockSelector,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _filterField(
                  context,
                  label: 'Start',
                  value: _startLabel(),
                  onTap: _showStartSelector,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: _openMoreFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _hasAdvancedFilters ? scheme.primary : null,
                  side: BorderSide(
                    color: _hasAdvancedFilters
                        ? scheme.primary
                        : scheme.outlineVariant,
                    width: 1.4,
                  ),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: const Text('MORE'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _resetFilters,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: const Text('RESET'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        visualDensity: VisualDensity.compact,
                        value: widget.hideShotClock,
                        onChanged: (value) =>
                            widget.onHideShotClockChanged(value ?? false),
                      ),
                      const SizedBox(width: 4),
                      const Text('Hide Shot Clock'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _filterField(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ).copyWith(labelText: label, alignLabelWithHint: true),
            child: InkWell(
              onTap: onTap,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showScoreSelector() async {
    final result = await showModalBottomSheet<ScoreDiffSelection>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        int? tempMin = _scoreMin;
        int? tempMax = _scoreMax;
        bool tie = _scoreTie;
        final minController =
            FixedExtentScrollController(initialItem: _scoreOptionIndex(tempMin));
        final maxController =
            FixedExtentScrollController(initialItem: _scoreOptionIndex(tempMax));

        return SafeArea(
          child: StatefulBuilder(
            builder: (context, sheetSetState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Score Differential',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text('MIN',
                                  style: Theme.of(context).textTheme.labelMedium),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 160,
                                child: CupertinoPicker(
                                  scrollController: minController,
                                  itemExtent: 32,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  onSelectedItemChanged: (index) {
                                    sheetSetState(() => tempMin = _scoreOptions[index]);
                                  },
                                  children: _scoreOptions
                                      .map((value) => Center(
                                            child: Text(_scoreOptionLabel(value)),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              Text('MAX',
                                  style: Theme.of(context).textTheme.labelMedium),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 160,
                                child: CupertinoPicker(
                                  scrollController: maxController,
                                  itemExtent: 32,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  onSelectedItemChanged: (index) {
                                    sheetSetState(() => tempMax = _scoreOptions[index]);
                                  },
                                  children: _scoreOptions
                                      .map((value) => Center(
                                            child: Text(_scoreOptionLabel(value)),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      value: tie,
                      onChanged: (value) => sheetSetState(() => tie = value ?? false),
                      title: const Text('Tied'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            sheetSetState(() {
                              tie = false;
                              tempMin = null;
                              tempMax = null;
                              minController.jumpToItem(0);
                              maxController.jumpToItem(0);
                            });
                          },
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(
                              ScoreDiffSelection(
                                min: tie ? null : tempMin,
                                max: tie ? null : tempMax,
                                tie: tie,
                              ),
                            );
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (result != null) {
      _applyScoreSelection(result);
    }
  }
  Future<void> _showClockSelector() async {
    final result = await showModalBottomSheet<ClockSelection>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        int? tempMin = _clockMin;
        int? tempMax = _clockMax;
        final minController = FixedExtentScrollController(
          initialItem: _clockMinOptionIndex(tempMin),
        );
        final maxController = FixedExtentScrollController(
          initialItem: _clockMaxOptionIndex(tempMax),
        );

        return SafeArea(
          child: StatefulBuilder(
            builder: (context, sheetSetState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Game Clock',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text('MIN',
                                  style: Theme.of(context).textTheme.labelMedium),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 180,
                                child: CupertinoPicker(
                                  scrollController: minController,
                                  itemExtent: 32,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  onSelectedItemChanged: (index) {
                                    sheetSetState(() => tempMin = _clockMinOptions[index]);
                                  },
                                  children: _clockMinOptions
                                      .map((value) => Center(
                                            child: Text(_formatClockOptionLabel(value)),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              Text('MAX',
                                  style: Theme.of(context).textTheme.labelMedium),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 180,
                                child: CupertinoPicker(
                                  scrollController: maxController,
                                  itemExtent: 32,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  onSelectedItemChanged: (index) {
                                    sheetSetState(() => tempMax = _clockMaxOptions[index]);
                                  },
                                  children: _clockMaxOptions
                                      .map((value) => Center(
                                            child: Text(_formatClockOptionLabel(value)),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            sheetSetState(() {
                              tempMin = null;
                              tempMax = null;
                              minController.jumpToItem(0);
                              maxController.jumpToItem(0);
                            });
                          },
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(
                              ClockSelection(
                                minTenths: tempMin,
                                maxTenths: tempMax,
                              ),
                            );
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (result != null) {
      _applyClockSelection(result);
    }
  }

  Future<void> _showStartSelector() async {
    final result = await showModalBottomSheet<Set<StartType>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: _StartTypeSheet(
            initialSelection: Set<StartType>.from(_selectedStarts),
            onApply: (selection) =>
                Navigator.of(context).pop(Set<StartType>.from(selection)),
          ),
        );
      },
    );

    if (result != null) {
      _applyStartSelection(result);
    }
  }
  Future<void> _openMoreFilters() async {
    final competition = widget.controller.settings.competition;
    final foulBounds = _foulBoundsForCompetition(competition);
    final timeoutBounds = _timeoutBoundsForCompetition(competition);

    int? foulsMin = _clampOrNull(_foulRange?.min, foulBounds);
    int? foulsMax = _clampOrNull(_foulRange?.max, foulBounds);
    int? timeoutsMin = _clampOrNull(_timeoutRange?.min, timeoutBounds);
    int? timeoutsMax = _clampOrNull(_timeoutRange?.max, timeoutBounds);
    PossessionPreference? possession = _possessionPreference;

    final foulMinOptions = _buildNumericOptions(foulBounds);
    final foulMaxOptions = _buildNumericOptions(foulBounds);
    final timeoutMinOptions = _buildNumericOptions(timeoutBounds);
    final timeoutMaxOptions = _buildNumericOptions(timeoutBounds);

    final foulMinController =
        FixedExtentScrollController(initialItem: _optionIndex(foulMinOptions, foulsMin));
    final foulMaxController =
        FixedExtentScrollController(initialItem: _optionIndex(foulMaxOptions, foulsMax));
    final timeoutMinController = FixedExtentScrollController(
        initialItem: _optionIndex(timeoutMinOptions, timeoutsMin));
    final timeoutMaxController = FixedExtentScrollController(
        initialItem: _optionIndex(timeoutMaxOptions, timeoutsMax));

    final result = await showModalBottomSheet<_MoreFiltersResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, sheetSetState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'More Filters',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _rangeWheelSection(
                      context: context,
                      title: 'Fouls',
                      currentMin: foulsMin,
                      currentMax: foulsMax,
                      minController: foulMinController,
                      maxController: foulMaxController,
                      minOptions: foulMinOptions,
                      maxOptions: foulMaxOptions,
                      onMinChanged: (value) {
                        sheetSetState(() => foulsMin = value);
                      },
                      onMaxChanged: (value) {
                        sheetSetState(() => foulsMax = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    _rangeWheelSection(
                      context: context,
                      title: 'Timeouts',
                      currentMin: timeoutsMin,
                      currentMax: timeoutsMax,
                      minController: timeoutMinController,
                      maxController: timeoutMaxController,
                      minOptions: timeoutMinOptions,
                      maxOptions: timeoutMaxOptions,
                      onMinChanged: (value) {
                        sheetSetState(() => timeoutsMin = value);
                      },
                      onMaxChanged: (value) {
                        sheetSetState(() => timeoutsMax = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ).copyWith(labelText: 'Possession', alignLabelWithHint: true),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PossessionPreference?>(
                          value: possession,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem<PossessionPreference?>(
                                value: null, child: Text('ANY')),
                            DropdownMenuItem<PossessionPreference?>(
                                value: PossessionPreference.winning,
                                child: Text('Winning Team')),
                            DropdownMenuItem<PossessionPreference?>(
                                value: PossessionPreference.losing,
                                child: Text('Losing Team')),
                          ],
                          onChanged: (value) => sheetSetState(() => possession = value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            sheetSetState(() {
                              foulsMin = null;
                              foulsMax = null;
                              timeoutsMin = null;
                              timeoutsMax = null;
                              possession = null;
                              foulMinController.jumpToItem(0);
                              foulMaxController.jumpToItem(0);
                              timeoutMinController.jumpToItem(0);
                              timeoutMaxController.jumpToItem(0);
                            });
                          },
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            IntRange? foulsRange;
                            if (foulsMin != null || foulsMax != null) {
                              final minValue = foulsMin ?? foulBounds.min;
                              final maxValue = foulsMax ?? foulBounds.max;
                              final lo = math.min(minValue, maxValue);
                              final hi = math.max(minValue, maxValue);
                              foulsRange = IntRange(lo, hi, '$lo-$hi');
                            }
                            IntRange? timeoutRange;
                            if (timeoutsMin != null || timeoutsMax != null) {
                              final minValue = timeoutsMin ?? timeoutBounds.min;
                              final maxValue = timeoutsMax ?? timeoutBounds.max;
                              final lo = math.min(minValue, maxValue);
                              final hi = math.max(minValue, maxValue);
                              timeoutRange = IntRange(lo, hi, '$lo-$hi');
                            }
                            Navigator.of(context).pop(
                              _MoreFiltersResult(
                                fouls: foulsRange,
                                timeouts: timeoutRange,
                                possession: possession,
                              ),
                            );
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (result != null) {
      _applyMoreFilters(
        fouls: result.fouls,
        timeouts: result.timeouts,
        possession: result.possession,
      );
    }
  }

  void _applyScoreSelection(ScoreDiffSelection selection) {
    setState(() {
      _scoreMin = selection.tie ? null : selection.min;
      _scoreMax = selection.tie ? null : selection.max;
      _scoreTie = selection.tie;
    });
    widget.controller.setScoreDiffSelection(selection);
    widget.onChanged();
  }

  void _applyClockSelection(ClockSelection selection) {
    setState(() {
      _clockMin = selection.minTenths;
      _clockMax = selection.maxTenths;
    });
    widget.controller.setClockSelection(selection);
    widget.onChanged();
  }

  void _applyStartSelection(Set<StartType> selection) {
    setState(() {
      _selectedStarts
        ..clear()
        ..addAll(selection);
    });
    widget.controller.setStartTypes(selection);
    widget.onChanged();
  }

  void _applyMoreFilters({
    IntRange? fouls,
    IntRange? timeouts,
    PossessionPreference? possession,
  }) {
    setState(() {
      _foulRange = fouls;
      _timeoutRange = timeouts;
      _possessionPreference = possession;
    });
    widget.controller.setFoulRange(fouls);
    widget.controller.setTimeoutRange(timeouts);
    widget.controller.setPossessionPreference(possession);
    widget.onChanged();
  }

  void _resetFilters() {
    setState(() {
      _scoreMin = null;
      _scoreMax = null;
      _scoreTie = false;
      _clockMin = null;
      _clockMax = null;
      _selectedStarts.clear();
      _foulRange = null;
      _timeoutRange = null;
      _possessionPreference = null;
    });
    widget.controller.resetFilters();
    widget.controller.clearScenario();
    widget.onChanged();
    widget.onHideShotClockChanged(false);
    widget.onReset?.call();
  }
  String _scoreLabel() {
    if (_scoreTie) return 'TIED';
    final min = _scoreMin;
    final max = _scoreMax;
    if (min == null && max == null) return 'ANY';
    if (min == null) return '≤ $max';
    if (max == null) return '$min+';
    if (min == max) return '$min';
    return '$min-$max';
  }

  String _clockLabel() {
    final min = _clockMin;
    final max = _clockMax;
    if (min == null && max == null) return 'ANY';
    if (min == null) {
      final int maxValue = max!;
      return '≤ ${_formatClockValue(maxValue)}';
    }
    if (max == null) {
      final int minValue = min;
      return '${_formatClockValue(minValue)}+';
    }
    final int minValue = min;
    final int maxValue = max;
    if (minValue == maxValue) return _formatClockValue(minValue);
    return '${_formatClockValue(minValue)} - ${_formatClockValue(maxValue)}';
  }

  String _startLabel() {
    if (_selectedStarts.isEmpty) {
      return 'ANY';
    }
    if (_selectedStarts.length == StartType.values.length) {
      return 'ALL';
    }
    return _selectedStarts.map(startTypeLabel).join(', ');
  }

  String _scoreOptionLabel(int? value) {
    if (value == null) return 'ANY';
    return value.toString();
  }

  int _scoreOptionIndex(int? value) {
    final index = _scoreOptions.indexOf(value);
    return index >= 0 ? index : 0;
  }

  int _clockMinOptionIndex(int? value) {
    final index = _clockMinOptions.indexOf(value);
    return index >= 0 ? index : 0;
  }

  int _clockMaxOptionIndex(int? value) {
    final index = _clockMaxOptions.indexOf(value);
    return index >= 0 ? index : 0;
  }

  String _formatClockOptionLabel(int? tenths) {
    if (tenths == null) return 'ANY';
    return _formatClockValue(tenths);
  }

  String _formatClockValue(int tenths) {
    if (tenths <= 1) return '< :01';
    final totalSeconds = tenths ~/ 10;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
    return ':${seconds.toString().padLeft(2, '0')}';
  }

  Widget _rangeWheelSection({
    required BuildContext context,
    required String title,
    required int? currentMin,
    required int? currentMax,
    required FixedExtentScrollController minController,
    required FixedExtentScrollController maxController,
    required List<int?> minOptions,
    required List<int?> maxOptions,
    required ValueChanged<int?> onMinChanged,
    required ValueChanged<int?> onMaxChanged,
  }) {
    final theme = Theme.of(context);
    final summary = (currentMin == null && currentMax == null)
        ? 'ANY'
        : '${_numericOptionLabel(currentMin)} - ${_numericOptionLabel(currentMax)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title ($summary)',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text('MIN', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: CupertinoPicker(
                      scrollController: minController,
                      itemExtent: 32,
                      useMagnifier: true,
                      magnification: 1.08,
                      onSelectedItemChanged: (index) =>
                          onMinChanged(minOptions[index]),
                      children: minOptions
                          .map((value) => Center(
                                child: Text(_numericOptionLabel(value)),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  Text('MAX', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: CupertinoPicker(
                      scrollController: maxController,
                      itemExtent: 32,
                      useMagnifier: true,
                      magnification: 1.08,
                      onSelectedItemChanged: (index) =>
                          onMaxChanged(maxOptions[index]),
                      children: maxOptions
                          .map((value) => Center(
                                child: Text(_numericOptionLabel(value)),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  IntRange _foulBoundsForCompetition(Competition competition) {
    switch (competition) {
      case Competition.nba:
        return _nbaFoulRange;
      case Competition.fiba:
        return _fibaFoulRange;
      case Competition.highSchool:
        return _hsFoulRange;
      case Competition.ncaa:
        return _ncaaFoulRange;
    }
  }

  IntRange _timeoutBoundsForCompetition(Competition competition) {
    switch (competition) {
      case Competition.nba:
        return _nbaTimeoutRange;
      case Competition.fiba:
      case Competition.highSchool:
      case Competition.ncaa:
        return _defaultTimeoutRange;
    }
  }


  List<int?> _buildNumericOptions(IntRange bounds) {
    final values = <int?>[null];
    for (var value = bounds.min; value <= bounds.max; value++) {
      values.add(value);
    }
    return values;
  }

  int _optionIndex(List<int?> options, int? value) {
    final index = options.indexOf(value);
    return index >= 0 ? index : 0;
  }

  int? _clampOrNull(int? value, IntRange bounds) {
    if (value == null) return null;
    if (value < bounds.min) return bounds.min;
    if (value > bounds.max) return bounds.max;
    return value;
  }

  String _numericOptionLabel(int? value) => value?.toString() ?? 'ANY';
}

class _MoreFiltersResult {
  final IntRange? fouls;
  final IntRange? timeouts;
  final PossessionPreference? possession;

  const _MoreFiltersResult({
    this.fouls,
    this.timeouts,
    this.possession,
  });
}

class _StartTypeSheet extends StatefulWidget {
  final Set<StartType> initialSelection;
  final ValueChanged<Set<StartType>> onApply;

  const _StartTypeSheet({
    required this.initialSelection,
    required this.onApply,
  });

  @override
  State<_StartTypeSheet> createState() => _StartTypeSheetState();
}

class _StartTypeSheetState extends State<_StartTypeSheet> {
  late Set<StartType> _selection;

  @override
  void initState() {
    super.initState();
    _selection = Set<StartType>.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Start Types', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _selection.isEmpty,
            onChanged: (value) {
              if (value == true) {
                setState(() => _selection.clear());
              }
            },
            title: const Text('ANY'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const Divider(height: 1),
          ...StartType.values.map(
            (type) => CheckboxListTile(
              value: _selection.contains(type),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selection.add(type);
                  } else {
                    _selection.remove(type);
                  }
                });
              },
              title: Text(startTypeLabel(type)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          const Divider(height: 1),
          CheckboxListTile(
            value: _selection.length == StartType.values.length,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selection
                    ..clear()
                    ..addAll(StartType.values);
                } else {
                  _selection.clear();
                }
              });
            },
            title: const Text('ALL'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _selection.clear()),
                child: const Text('Clear'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () =>
                    widget.onApply(Set<StartType>.from(_selection)),
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClockBoxStyle {
  final double width;
  final double height;
  final double borderRadius;
  final Color backgroundColor;
  final Color? textColorOverride;
  final double horizontalPadding;

  const _ClockBoxStyle({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.backgroundColor,
    required this.textColorOverride,
    required this.horizontalPadding,
  });
}

class _BoxedClockTight extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final _ClockBoxStyle? styleOverrides;
  const _BoxedClockTight(
      {required this.text, this.textStyle, this.styleOverrides});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = styleOverrides ??
        const _ClockBoxStyle(
          width: 150,
          height: 70,
          borderRadius: 12,
          backgroundColor: Colors.transparent,
          textColorOverride: null,
          horizontalPadding: 0,
        );

    final effectiveStyle = textStyle?.copyWith(
      color: style.textColorOverride ?? textStyle?.color,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = constraints.maxWidth.isFinite
            ? math.min(style.width, constraints.maxWidth)
            : style.width;
        final effectiveHeight = constraints.maxHeight.isFinite
            ? math.min(style.height, constraints.maxHeight)
            : style.height;

        return Center(
          child: Container(
            width: effectiveWidth,
            height: effectiveHeight,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: style.horizontalPadding),
            decoration: BoxDecoration(
              color: style.backgroundColor,
              borderRadius: BorderRadius.circular(style.borderRadius),
              border: Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.25), width: 2),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(text,
                  style: effectiveStyle, textAlign: TextAlign.center),
            ),
          ),
        );
      },
    );
  }
}

class _Scoreboard extends StatelessWidget {
  final ScenarioController controller;
  final Future<void> Function(TeamSide side)? onEditTeamName;
  final Future<void> Function(TeamSide side)? onEditScore;
  final Future<void> Function(TeamSide side)? onEditFouls;
  final Future<void> Function(TeamSide side)? onEditTimeouts;
  final Future<void> Function()? onEditGameClock;
  final Future<void> Function()? onEditShotClock;
  const _Scoreboard({
    required this.controller,
    this.onEditTeamName,
    this.onEditScore,
    this.onEditFouls,
    this.onEditTimeouts,
    this.onEditGameClock,
    this.onEditShotClock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = controller.scenario;
    final has = controller.hasScenario;
    final rules = controller.currentRules;
    final showArrow = rules.showPossessionArrow && has;
    final homeName = controller.homeTeamName;
    final guestName = controller.guestTeamName;

    final gameClockText = has ? formatGameClockTenths(s.gameClockTenths) : '––';
    final periodText = has ? periodLabel(s.period) : '––';
    final shotClockHidden = has && s.hideShotClock;
    final shotClockText =
        (has && !shotClockHidden) ? '${s.shotClockSeconds}' : '—';
    const backgroundColor = Color(0xFF111111);
    const insetColor = Color(0xFF1E1E1E);
    final borderColor = Colors.white.withOpacity(0.22);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final horizontalPadding = compact ? 12.0 : 22.0;
        final verticalPadding = compact ? 18.0 : 32.0;
        final middleSpacing = compact ? 10.0 : 22.0;
        final gameClockStyle = _ClockBoxStyle(
          width: compact ? 150 : 180,
          height: compact ? 50 : 60,
          borderRadius: 0,
          backgroundColor: insetColor,
          textColorOverride: Colors.white,
          horizontalPadding: compact ? 8 : 12,
        );

        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(compact ? 22 : 28),
            border: Border.all(color: borderColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: verticalPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEditGameClock == null ? null : () => onEditGameClock!(),
                child: _BoxedClockTight(
                  text: gameClockText,
                  textStyle: theme.textTheme.displayMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
                    fontFamily: 'TimesSquare',
                    fontSize: (theme.textTheme.displayMedium?.fontSize ?? 40) +
                        (compact ? -2 : 0),
                  ),
                  styleOverrides: gameClockStyle,
                ),
              ),
              SizedBox(height: compact ? 10 : 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _TeamPanel(
                        side: TeamSide.home,
                        teamName: homeName,
                        scoreText: has ? '${s.homeScore}' : '––',
                        foulsText: has ? '${s.homeFouls}' : '––',
                        timeouts: has ? s.homeTimeouts : null,
                        showPossessionIndicator: showArrow,
                        hasPossession:
                            has && s.possessionArrow == TeamSide.home,
                        panelColor: insetColor,
                        borderColor: borderColor,
                        compact: compact,
                        onEditName: onEditTeamName == null
                            ? null
                            : () => onEditTeamName!(TeamSide.home),
                        onEditScore: onEditScore == null || !has
                            ? null
                            : () => onEditScore!(TeamSide.home),
                        onEditFouls: onEditFouls == null || !has
                            ? null
                            : () => onEditFouls!(TeamSide.home),
                        onEditTimeouts: onEditTimeouts == null || !has
                            ? null
                            : () => onEditTimeouts!(TeamSide.home),
                      ),
                    ),
                    SizedBox(width: middleSpacing / 3),
                    Flexible(
                      flex: compact ? 1 : 2,
                      child: _CenterPanel(
                        periodText: periodText,
                        shotClockText: shotClockText,
                        dimShotClock: shotClockHidden,
                        backgroundColor: insetColor,
                        borderColor: borderColor,
                        compact: compact,
                        onEditShotClock:
                            onEditShotClock == null || !has ? null : onEditShotClock,
                      ),
                    ),
                    SizedBox(width: middleSpacing / 3),
                    Expanded(
                      child: _TeamPanel(
                        side: TeamSide.guest,
                        teamName: guestName,
                        scoreText: has ? '${s.guestScore}' : '––',
                        foulsText: has ? '${s.guestFouls}' : '––',
                        timeouts: has ? s.guestTimeouts : null,
                        showPossessionIndicator: showArrow,
                        hasPossession:
                            has && s.possessionArrow == TeamSide.guest,
                        panelColor: insetColor,
                        borderColor: borderColor,
                        compact: compact,
                        onEditName: onEditTeamName == null
                            ? null
                            : () => onEditTeamName!(TeamSide.guest),
                        onEditScore: onEditScore == null || !has
                            ? null
                            : () => onEditScore!(TeamSide.guest),
                        onEditFouls: onEditFouls == null || !has
                            ? null
                            : () => onEditFouls!(TeamSide.guest),
                        onEditTimeouts: onEditTimeouts == null || !has
                            ? null
                            : () => onEditTimeouts!(TeamSide.guest),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TeamPanel extends StatelessWidget {
  final TeamSide side;
  final String teamName;
  final String scoreText;
  final String foulsText;
  final int? timeouts;
  final bool showPossessionIndicator;
  final bool hasPossession;
  final Color panelColor;
  final Color borderColor;
  final bool compact;
  final Future<void> Function()? onEditName;
  final Future<void> Function()? onEditScore;
  final Future<void> Function()? onEditFouls;
  final Future<void> Function()? onEditTimeouts;

  const _TeamPanel({
    required this.side,
    required this.teamName,
    required this.scoreText,
    required this.foulsText,
    required this.timeouts,
    this.showPossessionIndicator = false,
    this.hasPossession = false,
    required this.panelColor,
    required this.borderColor,
    this.compact = false,
    this.onEditName,
    this.onEditScore,
    this.onEditFouls,
    this.onEditTimeouts,
  });

  @override
  Widget build(BuildContext context) {
    final baseLabel = side == TeamSide.home ? 'HOME' : 'GUEST';
    final trimmedName = teamName.trim();
    final displayName = trimmedName.isEmpty ? baseLabel : trimmedName;
    final theme = Theme.of(context);
    final showArrow = showPossessionIndicator && hasPossession;
    final arrowIcon = Icon(
      side == TeamSide.home
          ? Icons.arrow_back_ios_new_rounded
          : Icons.arrow_forward_ios_rounded,
      color: theme.colorScheme.primary,
      size: compact ? 16 : 18,
    );
    final labelStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 1.0,
      color: Colors.white,
    );
    final labelWidget = showArrow
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: side == TeamSide.home
                ? [
                    arrowIcon,
                    const SizedBox(width: 4),
                    Text(displayName, style: labelStyle)
                  ]
                : [
                    Text(displayName, style: labelStyle),
                    const SizedBox(width: 4),
                    arrowIcon
                  ],
          )
        : Text(displayName, style: labelStyle);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onEditName == null ? null : () => onEditName!(),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: SizedBox(key: ValueKey(showArrow), child: labelWidget),
          ),
        ),
        SizedBox(height: compact ? 4 : 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final baseFont = theme.textTheme.displayLarge?.fontSize ?? 60;
              final widthPadding = constraints.maxWidth * 0.035;
              final heightPadding = constraints.maxHeight * 0.08;
              final usableWidth = constraints.maxWidth - (widthPadding * 2);
              final fontSize = math.min(
                constraints.maxHeight * 0.7,
                usableWidth * 0.5,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEditScore == null ? null : () => onEditScore!(),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: panelColor,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: borderColor, width: 2.5),
                  boxShadow: const [],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: widthPadding,
                  vertical: heightPadding,
                ),
                child: Center(
                  child: _BalancedScoreText(
                    text: scoreText,
                    baseFont: baseFont,
                    targetFontSize:
                        math.max(fontSize, baseFont + (compact ? 12 : 32)),
                    color: Colors.white,
                  ),
                ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: compact ? 12 : 20),
        compact
            ? Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onEditFouls == null ? null : () => onEditFouls!(),
                    child: _StatPill(
                      title: 'FLS',
                      value: foulsText,
                      foreground: Colors.white,
                      background: panelColor,
                      borderColorOverride: borderColor,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap:
                        onEditTimeouts == null ? null : () => onEditTimeouts!(),
                    child: _TimeoutPill(
                      foreground: Colors.white,
                      background: panelColor,
                      borderColor: borderColor,
                      compact: true,
                      timeouts: timeouts,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onEditFouls == null ? null : () => onEditFouls!(),
                    child: _StatPill(
                      title: 'FLS',
                      value: foulsText,
                      foreground: Colors.white,
                      background: panelColor,
                      borderColorOverride: borderColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap:
                        onEditTimeouts == null ? null : () => onEditTimeouts!(),
                    child: _TimeoutPill(
                      foreground: Colors.white,
                      background: panelColor,
                      borderColor: borderColor,
                      timeouts: timeouts,
                    ),
                  ),
                ],
              ),
      ],
    );
  }
}

class _CenterPanel extends StatelessWidget {
  final String periodText;
  final String shotClockText;
  final Color backgroundColor;
  final Color borderColor;
  final bool compact;
  final bool dimShotClock;
  final Future<void> Function()? onEditShotClock;
  const _CenterPanel({
    required this.periodText,
    required this.shotClockText,
    required this.backgroundColor,
    required this.borderColor,
    this.compact = false,
    this.dimShotClock = false,
    this.onEditShotClock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final periodLabelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: Colors.white,
    );
    final shotClockLabelStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
      color: Colors.white,
    );
    final shotClockSide = compact ? 72.0 : 96.0;
    final shotClockStyle = _ClockBoxStyle(
      width: shotClockSide,
      height: shotClockSide,
      borderRadius: 0,
      backgroundColor: backgroundColor,
      textColorOverride: null,
      horizontalPadding: compact ? 8 : 12,
    );
    final shotClockColor =
        dimShotClock ? Colors.white.withOpacity(0.35) : Colors.red;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('PERIOD', style: periodLabelStyle),
        SizedBox(height: compact ? 4 : 8),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: compact ? 4 : 8,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              periodText,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'TimesSquare',
                fontSize: (theme.textTheme.headlineSmall?.fontSize ?? 32) +
                    (compact ? -4 : -2),
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 22 : 28),
        Text('SHOT CLOCK', style: shotClockLabelStyle),
        SizedBox(height: compact ? 3 : 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onEditShotClock == null ? null : () => onEditShotClock!(),
          child: _BoxedClockTight(
            text: shotClockText,
            textStyle: theme.textTheme.displaySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w900,
              color: shotClockColor,
              fontFamily: 'TimesSquare',
              letterSpacing: -0.4,
              fontSize: (theme.textTheme.displayMedium?.fontSize ?? 36) +
                  (compact ? -2 : 2),
            ),
            styleOverrides: shotClockStyle,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String title;
  final String value;
  final Color? foreground;
  final Color? background;
  final Color? borderColorOverride;
  final bool compact;
  const _StatPill({
    required this.title,
    required this.value,
    this.foreground,
    this.background,
    this.borderColorOverride,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = foreground ?? theme.colorScheme.onSurfaceVariant;
    final boxColor = background ?? theme.colorScheme.surface;
    final outlineColor =
        borderColorOverride ?? theme.colorScheme.outlineVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: textColor.withOpacity(0.8),
          ),
        ),
        SizedBox(height: compact ? 2 : 4),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: outlineColor, width: 2),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w700,
                color: textColor,
                fontFamily: 'TimesSquare',
                fontSize: (theme.textTheme.headlineSmall?.fontSize ?? 32) +
                    (compact ? -4 : -2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalancedScoreText extends StatelessWidget {
  final String text;
  final double baseFont;
  final double targetFontSize;
  final Color color;
  const _BalancedScoreText({
    required this.text,
    required this.baseFont,
    required this.targetFontSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final digits = text.length;
    final adjustments = {2: 1.0, 3: 0.9, 4: 0.8};
    final scale = adjustments[digits] ?? 0.75;
    final fontSize = targetFontSize * scale;

    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.displayLarge?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -2.5,
        fontFamily: 'TimesSquare',
        fontSize: math.max(fontSize, baseFont * scale),
      ),
    );
  }
}

class _TimeoutPill extends StatelessWidget {
  final int? timeouts;
  final Color foreground;
  final Color background;
  final Color borderColor;
  final bool compact;
  const _TimeoutPill({
    required this.timeouts,
    required this.foreground,
    required this.background,
    required this.borderColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: foreground.withOpacity(0.8),
    );
    final int active = (timeouts ?? 0).clamp(0, 5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('T.O.L.', style: labelStyle),
        SizedBox(height: compact ? 4 : 6),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: borderColor, width: 2),
          ),
          constraints: BoxConstraints(maxWidth: compact ? 58 : 78),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _TimeoutDots(
              activeCount: active,
              totalCount: 5,
              activeColor: foreground,
              inactiveColor: foreground.withOpacity(0.25),
              dotSize: compact ? 4.5 : 6.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeoutDots extends StatelessWidget {
  final int activeCount;
  final int totalCount;
  final Color activeColor;
  final Color inactiveColor;
  final double dotSize;
  const _TimeoutDots({
    required this.activeCount,
    required this.totalCount,
    required this.activeColor,
    required this.inactiveColor,
    required this.dotSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalCount, (index) {
        final color = index < activeCount ? activeColor : inactiveColor;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.0),
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

class _OutsideMeta extends StatelessWidget {
  final ScenarioController controller;
  const _OutsideMeta({required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = controller.scenario;
    final has = controller.hasScenario;
    final possessionStart = (has && s.startType != StartType.jumpBall)
        ? (s.possession == TeamSide.home ? 'Home' : 'Guest')
        : '––';
    return Column(
      children: [
        Text('Possession Start: $possessionStart',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Start Type: ${has ? startTypeLabel(s.startType) : '––'}',
            style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _OneShotGif extends StatefulWidget {
  final String assetPath;
  final BoxFit fit;
  final VoidCallback onFinished;

  const _OneShotGif({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.contain,
    required this.onFinished,
  });

  @override
  State<_OneShotGif> createState() => _OneShotGifState();
}

class _OneShotGifState extends State<_OneShotGif> {
  ui.Codec? _codec;
  ui.Image? _currentImage;
  Timer? _frameTimer;
  bool _completed = false;
  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final data = await rootBundle.load(widget.assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
    );
    if (!mounted) {
      codec.dispose();
      return;
    }
    _codec = codec;
    _scheduleNextFrame();
  }

  void _scheduleNextFrame() async {
    final codec = _codec;
    if (codec == null) return;

    final frame = await codec.getNextFrame();
    if (!mounted) return;

    setState(() {
      _currentImage?.dispose();
      _currentImage = frame.image;
    });

    _frameIndex++;
    final duration = frame.duration == Duration.zero
        ? const Duration(milliseconds: 16)
        : frame.duration;

    if (_frameIndex >= codec.frameCount) {
      _frameTimer = Timer(duration, _notifyFinished);
    } else {
      _frameTimer = Timer(duration, _scheduleNextFrame);
    }
  }

  void _notifyFinished() {
    if (_completed || !mounted) return;
    _completed = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _currentImage?.dispose();
    _codec?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _currentImage;
    if (image == null) {
      return const SizedBox.shrink();
    }
    return FittedBox(
      fit: widget.fit,
      child: SizedBox(
        width: image.width.toDouble(),
        height: image.height.toDouble(),
        child: RawImage(image: image),
      ),
    );
  }
}
