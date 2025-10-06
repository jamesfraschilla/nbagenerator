import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui show Codec, Image, instantiateImageCodec;

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

  bool _isAnimating = false;
  bool _showAnimation = false;
  bool _animationFadeOut = false;
  int _animationRun = 0;
  Completer<void>? _animationCompleter;

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
                              if (c != null)
                                setState(() => controller.setCompetition(c));
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                _RangeSelector(
                    controller: controller, onChanged: () => setState(() {})),
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
                          child: _Scoreboard(controller: controller),
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
                          label: Text(has ? 'Re-roll in Range' : 'Generate'),
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

                // Save Scenario button
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: has && !_isAnimating
                          ? () => _openSaveDialog(context, controller.scenario)
                          : null,
                      icon: const Icon(Icons.save_alt_outlined),
                      label: const Text('Save Scenario'),
                    ),
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

    controller.setScenario(generated);
    setState(() {
      _animationFadeOut = true;
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

  Future<void> _openSaveDialog(BuildContext context, Scenario scenario) async {
    final controllerNotes = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Notes'),
        content: TextField(
          controller: controllerNotes,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText:
                'What happened in practice? Thoughts, outcomes, next drills...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controllerNotes.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );

    if (!context.mounted) return;

    if (result != null && result.isNotEmpty) {
      HistoryStore.instance.add(scenario, result);
      if (!context.mounted) return;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
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
    final items = scoreDiffPresets
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

/// --------- Existing widgets (range selector, dropdowns, etc.) ---------
class _RangeSelector extends StatefulWidget {
  final ScenarioController controller;
  final VoidCallback onChanged;
  const _RangeSelector({required this.controller, required this.onChanged});

  @override
  State<_RangeSelector> createState() => _RangeSelectorState();
}

class _StartTypeFilterOption {
  final StartType? value;
  final String label;

  const _StartTypeFilterOption(this.value, this.label);
}

class _RangeSelectorState extends State<_RangeSelector> {
  int _selectedScoreIdx = 0; // default Any
  int _selectedClockIdx = 0; // default Any
  int _selectedStartIdx = 0; // default Any
  late final List<_StartTypeFilterOption> _startTypeOptions;

  @override
  void initState() {
    super.initState();
    _startTypeOptions = <_StartTypeFilterOption>[
      const _StartTypeFilterOption(null, 'Any'),
      ...StartType.values
          .map((type) => _StartTypeFilterOption(type, startTypeLabel(type))),
    ];
    widget.controller.setScoreDiffRange(scoreDiffPresets[_selectedScoreIdx]);
    widget.controller.setClockRange(clockPresets[_selectedClockIdx]);
    widget.controller.setStartType(_startTypeOptions[_selectedStartIdx].value);
  }

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
      child: Row(
        children: [
          Expanded(
            child: _ScoreDiffDropdown(
              label: 'Score Diff',
              value: scoreDiffPresets[_selectedScoreIdx],
              items: scoreDiffPresets,
              onChanged: (r) {
                setState(() {
                  _selectedScoreIdx = scoreDiffPresets.indexOf(r);
                  widget.controller.setScoreDiffRange(r);
                  widget.onChanged();
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ClockDropdown(
              label: 'Game Clock',
              value: clockPresets[_selectedClockIdx],
              items: clockPresets,
              onChanged: (r) {
                setState(() {
                  _selectedClockIdx = clockPresets.indexOf(r);
                  widget.controller.setClockRange(r);
                  widget.onChanged();
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StartTypeDropdown(
              label: 'Start',
              value: _startTypeOptions[_selectedStartIdx],
              options: _startTypeOptions,
              onChanged: (option) {
                setState(() {
                  final idx = _startTypeOptions.indexOf(option);
                  _selectedStartIdx = idx >= 0 ? idx : 0;
                  widget.controller.setStartType(option.value);
                  widget.onChanged();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClockDropdown extends StatefulWidget {
  final String label;
  final ClockRange value;
  final List<ClockRange> items;
  final ValueChanged<ClockRange> onChanged;

  const _ClockDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_ClockDropdown> createState() => _ClockDropdownState();
}

class _ClockDropdownState extends State<_ClockDropdown> {
  static const double _menuWidth = 170;
  bool _open = false;
  final GlobalKey _buttonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedLabel = widget.value.label;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: InputDecorator(
            isFocused: _open,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ).copyWith(labelText: widget.label, alignLabelWithHint: true),
            child: InkWell(
              key: _buttonKey,
              onTap: () async {
                setState(() => _open = true);

                final overlay =
                    Overlay.of(context).context.findRenderObject() as RenderBox;
                final buttonBox =
                    _buttonKey.currentContext!.findRenderObject() as RenderBox;
                final Offset topLeft =
                    buttonBox.localToGlobal(Offset.zero, ancestor: overlay);
                final Offset topRight = buttonBox.localToGlobal(
                    Offset(buttonBox.size.width, 0),
                    ancestor: overlay);
                final double buttonBottom = topLeft.dy + buttonBox.size.height;

                final double menuWidth =
                    math.max(_menuWidth, buttonBox.size.width);
                double left = topRight.dx - menuWidth;
                if (left < 0) left = 0;
                if (left + menuWidth > overlay.size.width) {
                  left = overlay.size.width - menuWidth;
                }
                final double right = overlay.size.width - left - menuWidth;

                final selected = await showMenu<ClockRange>(
                  context: context,
                  position: RelativeRect.fromLTRB(
                    left,
                    buttonBottom,
                    right,
                    overlay.size.height - buttonBottom,
                  ),
                  color: theme.colorScheme.surface,
                  items: widget.items
                      .map((option) => PopupMenuItem<ClockRange>(
                            value: option,
                            child: SizedBox(
                              width: menuWidth,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  option.label,
                                  textAlign: TextAlign.right,
                                  style: option == widget.value
                                      ? theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold)
                                      : theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                );

                if (!mounted) return;
                setState(() => _open = false);
                if (selected != null) {
                  widget.onChanged(selected);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        selectedLabel,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
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
}

class _ScoreDiffDropdown extends StatefulWidget {
  final String label;
  final IntRange value;
  final List<IntRange> items;
  final ValueChanged<IntRange> onChanged;

  const _ScoreDiffDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_ScoreDiffDropdown> createState() => _ScoreDiffDropdownState();
}

class _ScoreDiffDropdownState extends State<_ScoreDiffDropdown> {
  bool _open = false;
  final GlobalKey _buttonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedLabel = widget.value.label;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: InputDecorator(
            isFocused: _open,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ).copyWith(labelText: widget.label, alignLabelWithHint: true),
            child: InkWell(
              key: _buttonKey,
              onTap: () async {
                setState(() => _open = true);

                final overlay =
                    Overlay.of(context).context.findRenderObject() as RenderBox;
                final buttonBox =
                    _buttonKey.currentContext!.findRenderObject() as RenderBox;
                final Offset topLeft =
                    buttonBox.localToGlobal(Offset.zero, ancestor: overlay);
                final double buttonBottom = topLeft.dy + buttonBox.size.height;
                final double menuWidth = buttonBox.size.width;
                double left = topLeft.dx;
                if (left + menuWidth > overlay.size.width) {
                  left = overlay.size.width - menuWidth;
                }
                final double right = overlay.size.width - left - menuWidth;

                final selected = await showMenu<IntRange>(
                  context: context,
                  position: RelativeRect.fromLTRB(
                    left,
                    buttonBottom,
                    right,
                    overlay.size.height - buttonBottom,
                  ),
                  color: theme.colorScheme.surface,
                  items: widget.items
                      .map((option) => PopupMenuItem<IntRange>(
                            value: option,
                            child: SizedBox(
                              width: menuWidth,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  option.label,
                                  style: option == widget.value
                                      ? theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold)
                                      : theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                );

                if (!mounted) return;
                setState(() => _open = false);
                if (selected != null) {
                  widget.onChanged(selected);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Text(
                      selectedLabel,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
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
}

class _StartTypeDropdown extends StatefulWidget {
  final String label;
  final _StartTypeFilterOption value;
  final List<_StartTypeFilterOption> options;
  final ValueChanged<_StartTypeFilterOption> onChanged;

  const _StartTypeDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_StartTypeDropdown> createState() => _StartTypeDropdownState();
}

class _StartTypeDropdownState extends State<_StartTypeDropdown> {
  static const double _menuWidth = 200;
  bool _open = false;
  final GlobalKey _buttonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedLabel = widget.value.label;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: InputDecorator(
            isFocused: _open,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ).copyWith(labelText: widget.label, alignLabelWithHint: true),
            child: InkWell(
              key: _buttonKey,
              onTap: () async {
                setState(() => _open = true);

                final overlay =
                    Overlay.of(context).context.findRenderObject() as RenderBox;
                final buttonBox =
                    _buttonKey.currentContext!.findRenderObject() as RenderBox;
                final Offset topLeft =
                    buttonBox.localToGlobal(Offset.zero, ancestor: overlay);
                final Offset topRight = buttonBox.localToGlobal(
                    Offset(buttonBox.size.width, 0),
                    ancestor: overlay);
                final double buttonBottom = topLeft.dy + buttonBox.size.height;

                final double menuWidth =
                    math.max(_menuWidth, buttonBox.size.width);
                double left = topRight.dx - menuWidth;
                if (left < 0) left = 0;
                if (left + menuWidth > overlay.size.width) {
                  left = overlay.size.width - menuWidth;
                }
                final double right = overlay.size.width - left - menuWidth;

                final selected = await showMenu<_StartTypeFilterOption>(
                  context: context,
                  position: RelativeRect.fromLTRB(
                    left,
                    buttonBottom,
                    right,
                    overlay.size.height - buttonBottom,
                  ),
                  color: theme.colorScheme.surface,
                  items: widget.options
                      .map((option) => PopupMenuItem<_StartTypeFilterOption>(
                            value: option,
                            child: SizedBox(
                              width: menuWidth,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  option.label,
                                  textAlign: TextAlign.right,
                                  style: option == widget.value
                                      ? theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold)
                                      : theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                );

                if (!mounted) return;
                setState(() => _open = false);
                if (selected != null) {
                  widget.onChanged(selected);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        selectedLabel,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
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
  const _Scoreboard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = controller.scenario;
    final has = controller.hasScenario;
    final rules = controller.currentRules;
    final showArrow = rules.showPossessionArrow && has;

    final gameClockText = has ? formatGameClockTenths(s.gameClockTenths) : '––';
    final periodText = has ? periodLabel(s.period) : '––';
    final shotClockText =
        (has && !s.hideShotClock) ? '${s.shotClockSeconds}' : '––';
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
          borderRadius: compact ? 14 : 16,
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
              _BoxedClockTight(
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
              SizedBox(height: compact ? 10 : 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _TeamPanel(
                        side: TeamSide.home,
                        scoreText: has ? '${s.homeScore}' : '––',
                        foulsText: has ? '${s.homeFouls}' : '––',
                        timeouts: has ? s.homeTimeouts : null,
                        showPossessionIndicator: showArrow,
                        hasPossession:
                            has && s.possessionArrow == TeamSide.home,
                        panelColor: insetColor,
                        borderColor: borderColor,
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: middleSpacing / 3),
                    Flexible(
                      flex: compact ? 1 : 2,
                      child: _CenterPanel(
                        periodText: periodText,
                        shotClockText: shotClockText,
                        backgroundColor: insetColor,
                        borderColor: borderColor,
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: middleSpacing / 3),
                    Expanded(
                      child: _TeamPanel(
                        side: TeamSide.guest,
                        scoreText: has ? '${s.guestScore}' : '––',
                        foulsText: has ? '${s.guestFouls}' : '––',
                        timeouts: has ? s.guestTimeouts : null,
                        showPossessionIndicator: showArrow,
                        hasPossession:
                            has && s.possessionArrow == TeamSide.guest,
                        panelColor: insetColor,
                        borderColor: borderColor,
                        compact: compact,
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
  final String scoreText;
  final String foulsText;
  final int? timeouts;
  final bool showPossessionIndicator;
  final bool hasPossession;
  final Color panelColor;
  final Color borderColor;
  final bool compact;

  const _TeamPanel({
    required this.side,
    required this.scoreText,
    required this.foulsText,
    required this.timeouts,
    this.showPossessionIndicator = false,
    this.hasPossession = false,
    required this.panelColor,
    required this.borderColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = side == TeamSide.home ? 'HOME' : 'GUEST';
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
                    Text(label, style: labelStyle)
                  ]
                : [
                    Text(label, style: labelStyle),
                    const SizedBox(width: 4),
                    arrowIcon
                  ],
          )
        : Text(label, style: labelStyle);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: SizedBox(key: ValueKey(showArrow), child: labelWidget),
        ),
        SizedBox(height: compact ? 4 : 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final baseFont = theme.textTheme.displayLarge?.fontSize ?? 60;
              final widthPadding = constraints.maxWidth * 0.035;
              final heightPadding = constraints.maxHeight * 0.1;
              final usableWidth = constraints.maxWidth - (widthPadding * 2);
              final fontSize = math.min(
                constraints.maxHeight * 0.7,
                usableWidth * 0.5,
              );
              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius:
                      BorderRadius.circular(constraints.maxWidth * 0.22),
                  border: Border.all(color: borderColor, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
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
              );
            },
          ),
        ),
        SizedBox(height: compact ? 12 : 20),
        compact
            ? Column(
                children: [
                  _StatPill(
                    title: 'FLS',
                    value: foulsText,
                    foreground: Colors.white,
                    background: panelColor,
                    borderColorOverride: borderColor,
                    compact: true,
                  ),
                  const SizedBox(height: 8),
                  _TimeoutPill(
                    foreground: Colors.white,
                    background: panelColor,
                    borderColor: borderColor,
                    compact: true,
                    timeouts: timeouts,
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatPill(
                    title: 'FLS',
                    value: foulsText,
                    foreground: Colors.white,
                    background: panelColor,
                    borderColorOverride: borderColor,
                  ),
                  const SizedBox(width: 14),
                  _TimeoutPill(
                    foreground: Colors.white,
                    background: panelColor,
                    borderColor: borderColor,
                    timeouts: timeouts,
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
  const _CenterPanel({
    required this.periodText,
    required this.shotClockText,
    required this.backgroundColor,
    required this.borderColor,
    this.compact = false,
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
    final shotClockStyle = _ClockBoxStyle(
      width: compact ? 100 : 130,
      height: compact ? 52 : 64,
      borderRadius: compact ? 12 : 16,
      backgroundColor: backgroundColor,
      textColorOverride: null,
      horizontalPadding: compact ? 8 : 12,
    );

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
            borderRadius: BorderRadius.circular(16),
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
        SizedBox(height: compact ? 10 : 16),
        Text('SHOT CLOCK', style: shotClockLabelStyle),
        SizedBox(height: compact ? 3 : 8),
        _BoxedClockTight(
          text: shotClockText,
          textStyle: theme.textTheme.displaySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w900,
            color: Colors.red,
            fontFamily: 'TimesSquare',
            letterSpacing: -0.4,
            fontSize: (theme.textTheme.displayMedium?.fontSize ?? 36) +
                (compact ? -2 : 2),
          ),
          styleOverrides: shotClockStyle,
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
            borderRadius: BorderRadius.circular(12),
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
            borderRadius: BorderRadius.circular(12),
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
