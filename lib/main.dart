import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui
    show Codec, Image, ImageByteFormat, instantiateImageCodec;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'gallery_exporter.dart';

import 'edit_scenario_screen.dart';
import 'scenario_generator.dart';
import 'smart_strategy.dart';
import 'storage.dart';

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
      final value =
          (await AppStorage.instance.readText(_themeFileName))?.trim();
      if (value == null || !mounted) return;
      setState(() {
        _mode = value == 'light'
            ? ThemeMode.light
            : value == 'dark'
                ? ThemeMode.dark
                : ThemeMode.dark;
      });
    } catch (e) {
      debugPrint('Failed to load theme preference: $e');
    }
  }

  Future<void> _toggleTheme() async {
    final next = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setState(() => _mode = next);
    try {
      await AppStorage.instance.writeText(
        _themeFileName,
        next == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (e) {
      debugPrint('Failed to save theme preference: $e');
    }
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
  final String homeTeamName;
  final String guestTeamName;
  final Competition competition;

  ScenarioLogEntry({
    required this.createdAt,
    required this.scenario,
    required this.notes,
    required this.homeTeamName,
    required this.guestTeamName,
    required this.competition,
  });

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'scenario': scenario.toJson(),
      'notes': notes,
      'homeTeamName': homeTeamName,
      'guestTeamName': guestTeamName,
      'competition': competition.name,
    };
  }

  factory ScenarioLogEntry.fromJson(Map<String, dynamic> json) {
    Scenario parseScenario(Map<String, dynamic>? map) {
      if (map == null) return Scenario.defaults();
      try {
        return Scenario.fromJson(map);
      } catch (e) {
        debugPrint('Failed to parse scenario from history: $e');
        return Scenario.defaults();
      }
    }

    Competition parseCompetition(String? value) {
      if (value == null) return Competition.nba;
      return Competition.values.firstWhere(
        (c) => c.name == value,
        orElse: () => Competition.nba,
      );
    }

    return ScenarioLogEntry(
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      scenario: parseScenario(
        (json['scenario'] as Map?)?.cast<String, dynamic>(),
      ),
      notes: json['notes'] as String? ?? '',
      homeTeamName: json['homeTeamName'] as String? ?? 'HOME',
      guestTeamName: json['guestTeamName'] as String? ?? 'GUEST',
      competition: parseCompetition(json['competition'] as String?),
    );
  }
}

class HistoryStore {
  HistoryStore._();
  static final HistoryStore instance = HistoryStore._();

  static const _historyFileName = 'history.json';
  static const int _maxEntries = 250;

  final ValueNotifier<List<ScenarioLogEntry>> entries =
      ValueNotifier<List<ScenarioLogEntry>>([]);

  Future<void>? _loadFuture;

  Future<void> ensureLoaded() {
    _loadFuture ??= _readFromDisk();
    return _loadFuture!;
  }

  Future<void> add({
    required Scenario scenario,
    required String notes,
    required String homeTeamName,
    required String guestTeamName,
    required Competition competition,
  }) async {
    await ensureLoaded();
    final entry = ScenarioLogEntry(
      createdAt: DateTime.now(),
      scenario: scenario,
      notes: notes,
      homeTeamName: homeTeamName,
      guestTeamName: guestTeamName,
      competition: competition,
    );
    final list = List<ScenarioLogEntry>.from(entries.value);
    list.insert(0, entry);
    if (list.length > _maxEntries) {
      list.removeRange(_maxEntries, list.length);
    }
    entries.value = list;
    await _writeToDisk(list);
  }

  Future<void> removeEntry(ScenarioLogEntry entry) async {
    await ensureLoaded();
    final list = List<ScenarioLogEntry>.from(entries.value);
    final index = list.indexOf(entry);
    if (index == -1) return;
    list.removeAt(index);
    entries.value = list;
    await _writeToDisk(list);
  }

  Future<void> clear() async {
    entries.value = const <ScenarioLogEntry>[];
    try {
      await AppStorage.instance.writeText(_historyFileName, '[]');
    } catch (e) {
      debugPrint('Failed to clear history: $e');
    }
  }

  Future<void> _writeToDisk(List<ScenarioLogEntry> list) async {
    try {
      final data = list.map((entry) => entry.toJson()).toList();
      await AppStorage.instance.writeText(_historyFileName, jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save history: $e');
    }
  }

  Future<void> _readFromDisk() async {
    try {
      final raw = await AppStorage.instance.readText(_historyFileName);
      if (raw == null) {
        entries.value = const <ScenarioLogEntry>[];
        return;
      }
      if (raw.trim().isEmpty) {
        entries.value = const <ScenarioLogEntry>[];
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        entries.value = const <ScenarioLogEntry>[];
        return;
      }
      final list = <ScenarioLogEntry>[];
      for (final item in decoded) {
        if (item is Map) {
          list.add(
            ScenarioLogEntry.fromJson(item.cast<String, dynamic>()),
          );
        }
      }
      entries.value = list;
    } catch (e) {
      debugPrint('Failed to load history: $e');
      entries.value = const <ScenarioLogEntry>[];
    }
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
  final GlobalKey<_RangeSelectorState> _rangeSelectorKey =
      GlobalKey<_RangeSelectorState>();
  static const _animationFadeDuration = Duration(milliseconds: 400);
  static const _competitionFileName = 'competition.txt';
  static const _onboardingFileName = 'onboarding_complete.txt';

  bool _isAnimating = false;
  bool _showAnimation = false;
  bool _animationFadeOut = false;
  int _animationRun = 0;
  Completer<void>? _animationCompleter;
  bool _hideShotClock = false;
  bool _forceHideShotClock = false;
  bool _savingHistory = false;
  bool _exportingImage = false;
  bool _forceLightExportTheme = false;
  bool _shotClockManualOverride = false;
  final GlobalKey _scoreboardCaptureKey = GlobalKey();
  final GlobalKey _filtersTutorialKey = GlobalKey();
  final GlobalKey _savedPresetsKey = GlobalKey();
  final GlobalKey _moreFiltersButtonKey = GlobalKey();
  final GlobalKey _saveFiltersButtonKey = GlobalKey();
  final GlobalKey _generateButtonKey = GlobalKey();
  final GlobalKey _editButtonKey = GlobalKey();
  final GlobalKey _notesButtonKey = GlobalKey();
  final GlobalKey _smartStrategyButtonKey = GlobalKey();
  final GlobalKey _exportButtonKey = GlobalKey();

  Future<void> _loadCompetition() async {
    try {
      final value =
          (await AppStorage.instance.readText(_competitionFileName))?.trim();
      if (value == null) return;
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
      await AppStorage.instance.writeText(
        _competitionFileName,
        competition.name,
      );
    } catch (e) {
      debugPrint('Failed to save competition preference: $e');
    }
  }

  Future<void> _markOnboardingComplete() async {
    try {
      await AppStorage.instance.writeText(_onboardingFileName, 'done');
    } catch (e) {
      debugPrint('Failed to save onboarding preference: $e');
    }
  }

  Future<void> _maybeStartOnboarding() async {
    // Tutorial disabled.
    unawaited(_markOnboardingComplete());
  }

  @override
  void initState() {
    super.initState();
    _loadCompetition();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartOnboarding();
    });
  }

  @override
  Widget build(BuildContext context) {
    final has = controller.hasScenario;
    final s = controller.scenario;
    final headerOpacity = _showAnimation ? 0.3 : 1.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final titleFontSize = screenWidth >= 900
        ? 40.0
        : screenWidth >= 600
            ? 34.0
            : 28.0;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedOpacity(
          opacity: headerOpacity,
          duration: const Duration(milliseconds: 200),
          child: AppBar(
            title: Text(
              'CLUTCH TIME',
              style: TextStyle(
                fontFamily: 'DIN',
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: titleFontSize,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'History',
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen())),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideLayout = constraints.maxWidth >= 1100;
            final isTabletLayout = constraints.maxWidth >= 700;
            final contentMaxWidth = constraints.maxWidth >= 1200
                ? 760.0
                : isTabletLayout
                    ? 720.0
                    : 560.0;
            final outerPadding = EdgeInsets.fromLTRB(
              isWideLayout ? 20 : 12,
              8,
              isWideLayout ? 20 : 12,
              16,
            );

            return Stack(
              children: [
                AnimatedOpacity(
                  opacity: _showAnimation ? 0.3 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: SingleChildScrollView(
                    padding: outerPadding,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              constraints.maxHeight - outerPadding.vertical,
                          maxWidth: contentMaxWidth,
                        ),
                        child: Column(
                          children: [
                            _buildScoreboardSection(
                              maxWidth: contentMaxWidth,
                            ),
                            const SizedBox(height: 12),
                            _buildControlPanel(
                              context,
                              has: has,
                              scenario: s,
                              headerOpacity: headerOpacity,
                              maxWidth: contentMaxWidth,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                            widthFactor: isWideLayout ? 0.38 : 0.75,
                            child: _OneShotGif(
                              key: ValueKey(_animationRun),
                              assetPath:
                                  'assets/clock_bg_transparent_minimal.png',
                              fit: BoxFit.contain,
                              onFinished: _onAnimationFinished,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildScoreboardSection({required double maxWidth}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ColoredBox(
          color: (_exportingImage || _forceLightExportTheme)
              ? Colors.white
              : Colors.transparent,
          child: RepaintBoundary(
            key: _scoreboardCaptureKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: _OutsideMeta(
                    controller: controller,
                    forceLightText: _exportingImage || _forceLightExportTheme,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 6.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        width: constraints.maxWidth,
                        child: AspectRatio(
                          aspectRatio: _scoreboardAspectRatio,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: _scoreboardDesignWidth,
                              height: _scoreboardDesignHeight,
                              child: _Scoreboard(
                                controller: controller,
                                onEditTeamName: _editTeamName,
                                onEditScore: _editScore,
                                onEditFouls: _editFouls,
                                onEditTimeouts: _editTimeouts,
                                onEditGameClock: _editGameClock,
                                onEditShotClock: _editShotClock,
                                manualShotClockOverride:
                                    _shotClockManualOverride,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel(
    BuildContext context, {
    required bool has,
    required Scenario scenario,
    required double headerOpacity,
    required double maxWidth,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RangeSelector(
              key: _rangeSelectorKey,
              controller: controller,
              onChanged: () => setState(() {}),
              onReset: _handleRangeReset,
              onHideShotClockChanged: _toggleHideShotClock,
              onCompetitionChanged: _handleCompetitionChanged,
              initialHideShotClock: _forceHideShotClock || _hideShotClock,
              filtersTutorialKey: _filtersTutorialKey,
              savedPresetsKey: _savedPresetsKey,
              moreFiltersButtonKey: _moreFiltersButtonKey,
              saveFiltersButtonKey: _saveFiltersButtonKey,
            ),
            const SizedBox(height: 8),
            _buildPrimaryActions(context, has: has, scenario: scenario),
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: headerOpacity,
              duration: const Duration(milliseconds: 200),
              child: _buildSecondaryActions(context, has: has),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryActions(
    BuildContext context, {
    required bool has,
    required Scenario scenario,
  }) {
    final buttons = <Widget>[
      KeyedSubtree(
        key: _generateButtonKey,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Colors.orange, width: 2),
            foregroundColor: Colors.orange,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          onPressed: _isAnimating ? null : _handleGenerate,
          child: const Text('GENERATE'),
        ),
      ),
      KeyedSubtree(
        key: _editButtonKey,
        child: OutlinedButton.icon(
          onPressed:
              has && !_isAnimating ? () => _openEditScenario(scenario) : null,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('EDIT'),
        ),
      ),
      TextButton(
        onPressed: () => _rangeSelectorKey.currentState?.resetFilters(),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        child: const Text('RESET'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                SizedBox(width: double.infinity, child: buttons[i]),
                if (i != buttons.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: buttons[0]),
            const SizedBox(width: 12),
            Expanded(child: buttons[1]),
            const SizedBox(width: 12),
            Expanded(child: buttons[2]),
          ],
        );
      },
    );
  }

  Widget _buildSecondaryActions(
    BuildContext context, {
    required bool has,
  }) {
    final smartStrategyEnabled = has &&
        !_isAnimating &&
        controller.settings.competition == Competition.nba;
    final exportIcon = _exportingImage
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          )
        : const Icon(Icons.download_outlined);

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttons = <Widget>[
          KeyedSubtree(
            key: _notesButtonKey,
            child: FilledButton.icon(
              onPressed: has && !_isAnimating && !_savingHistory
                  ? _saveScenarioToHistory
                  : null,
              icon: const Icon(Icons.history_edu_outlined),
              label: Text(_savingHistory ? 'Saving…' : 'Add Notes'),
            ),
          ),
          KeyedSubtree(
            key: _smartStrategyButtonKey,
            child: FilledButton.icon(
              onPressed: smartStrategyEnabled ? _openSmartStrategy : null,
              icon: const Icon(Icons.psychology_alt_outlined),
              label: const Text('Smart Strategy'),
            ),
          ),
          KeyedSubtree(
            key: _exportButtonKey,
            child: FilledButton.icon(
              onPressed: has && !_isAnimating && !_exportingImage
                  ? _exportScoreboard
                  : null,
              icon: exportIcon,
              label: const Text('Export'),
            ),
          ),
        ];

        if (constraints.maxWidth < 460) {
          return Column(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                SizedBox(width: double.infinity, child: buttons[i]),
                if (i != buttons.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        final maxRowWidth = math.min(constraints.maxWidth, 760).toDouble();
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: maxRowWidth,
            child: Row(
              children: [
                Expanded(child: buttons[0]),
                const SizedBox(width: 12),
                Expanded(child: buttons[1]),
                const SizedBox(width: 12),
                Expanded(child: buttons[2]),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditScenario(Scenario scenario) async {
    final updated = await Navigator.of(context).push<Scenario>(
      MaterialPageRoute(
        builder: (_) => EditScenarioScreen(
          initial: scenario,
          competition: controller.settings.competition,
        ),
      ),
    );
    if (updated == null || !mounted) return;

    setState(() {
      if (controller.settings.competition == Competition.highSchool) {
        controller.setForceHideShotClockHighSchool(updated.hideShotClock);
      } else {
        controller.setForceHideShotClockHighSchool(false);
      }
      controller.setScenario(updated);
      _forceHideShotClock = updated.hideShotClock;
      _hideShotClock = updated.hideShotClock;
    });
  }

  void _handleRangeReset() {
    setState(() {
      _forceHideShotClock = false;
      _hideShotClock = false;
    });
  }

  void _handleCompetitionChanged(Competition competition) {
    _saveCompetition(competition);
    if (!controller.hasScenario) {
      return;
    }
    final scenario = controller.scenario;
    final int threshold =
        (competition == Competition.nba || competition == Competition.fiba)
            ? 240
            : 300;
    final bool shouldAutoHide = scenario.gameClockTenths <= threshold;
    int shotClockSeconds = scenario.shotClockSeconds;
    bool shotClockBlank = scenario.shotClockBlank;
    if (shouldAutoHide) {
      shotClockSeconds = 0;
      shotClockBlank = true;
    } else {
      shotClockBlank = shotClockBlank || shotClockSeconds <= 0;
    }
    controller.setCompetition(competition);
    final updated = scenario.copyWith(
      hideShotClock: _forceHideShotClock ? true : shouldAutoHide,
      shotClockBlank:
          _forceHideShotClock ? true : shotClockBlank || shotClockSeconds <= 0,
      shotClockSeconds: shotClockSeconds,
    );
    controller.setScenario(updated);
    setState(() {
      _hideShotClock = _forceHideShotClock ? true : shouldAutoHide;
      if (!shouldAutoHide) {
        _shotClockManualOverride = false;
      }
    });
  }

  void _toggleHideShotClock(bool value) {
    setState(() {
      _forceHideShotClock = value;
      _hideShotClock = value;
    });
    if (controller.hasScenario) {
      controller.setScenario(
        controller.scenario.copyWith(
          hideShotClock: value,
          shotClockBlank: value ? true : controller.scenario.shotClockBlank,
        ),
      );
    }
  }

  Future<void> _saveScenarioToHistory() async {
    if (_savingHistory || !controller.hasScenario) return;
    final notes = await _promptNotes();
    if (notes == null) return;

    setState(() => _savingHistory = true);
    final scenario = controller.scenario;
    final trimmedNotes = notes.trim();

    try {
      await HistoryStore.instance.add(
        scenario: scenario,
        notes: trimmedNotes,
        homeTeamName: controller.homeTeamName,
        guestTeamName: controller.guestTeamName,
        competition: controller.settings.competition,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes saved to history')),
        );
      }
    } catch (e) {
      debugPrint('Failed to save history entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save notes')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingHistory = false);
      } else {
        _savingHistory = false;
      }
    }
  }

  Future<void> _openSmartStrategy() async {
    if (!controller.hasScenario) return;
    if (controller.settings.competition != Competition.nba) return;
    var selectedVantage = controller.scenario.possession;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            final recommendation = evaluateSmartStrategy(
              scenario: controller.scenario,
              competition: controller.settings.competition,
              homeTeamName: controller.homeTeamName,
              guestTeamName: controller.guestTeamName,
              vantageSide: selectedVantage,
            );

            Widget vantageButton(TeamSide side, String label) {
              final isSelected = selectedVantage == side;
              return Expanded(
                child: FilledButton(
                  onPressed: () => setModalState(() => selectedVantage = side),
                  style: FilledButton.styleFrom(
                    backgroundColor: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                  child: Text(label),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Smart Strategy',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                recommendation.perspectiveLabel,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Vantage',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        vantageButton(TeamSide.home, controller.homeTeamName),
                        const SizedBox(width: 10),
                        vantageButton(TeamSide.guest, controller.guestTeamName),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      recommendation.headline,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recommendation.summary,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        recommendation.stateLine,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (recommendation.rationale != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Why: ${recommendation.rationale!}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (recommendation.notes.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      for (final note in recommendation.notes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '• $note',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportScoreboard() async {
    if (_exportingImage || !controller.hasScenario) return;
    if (!GalleryExporter.isSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export is not available on this device.'),
          ),
        );
      }
      return;
    }
    final boundary = _scoreboardCaptureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to capture scoreboard')),
        );
      }
      return;
    }

    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    if (widget.isDarkMode) {
      setState(() {
        _exportingImage = true;
        _forceLightExportTheme = true;
      });
      await Future<void>.delayed(Duration.zero);
      await WidgetsBinding.instance.endOfFrame;
    } else {
      setState(() => _exportingImage = true);
    }
    try {
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw Exception('Failed to encode image bytes');
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final bool success = await GalleryExporter.saveImage(
        pngBytes: pngBytes,
        fileName: 'clutch_scenario_$timestamp.png',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Scoreboard exported successfully'
                : 'Could not save image',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to export scoreboard: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export scoreboard')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportingImage = false;
          _forceLightExportTheme = false;
        });
      } else {
        _exportingImage = false;
        _forceLightExportTheme = false;
      }
    }
  }

  Future<String?> _promptNotes() async {
    final textController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Notes'),
          content: TextField(
            controller: textController,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Add notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(textController.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editTeamName(TeamSide side) async {
    final current = side == TeamSide.home
        ? controller.homeTeamName
        : controller.guestTeamName;
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
    final current =
        side == TeamSide.home ? scenario.homeScore : scenario.guestScore;
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
    final current =
        side == TeamSide.home ? scenario.homeFouls : scenario.guestFouls;
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
      title:
          side == TeamSide.home ? 'Edit Home Timeouts' : 'Edit Guest Timeouts',
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
    controller.updateShotClock(seconds: result, hide: false);
    setState(() {
      _shotClockManualOverride = result > 0;
      _hideShotClock = result <= 0 ? true : _hideShotClock;
    });
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
              onPressed: () =>
                  Navigator.of(context).pop(textController.text.trim()),
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
    final applied = generated.copyWith(
      hideShotClock: shouldHide,
      shotClockBlank: shouldHide ? true : generated.shotClockBlank,
    );

    controller.setScenario(applied);
    setState(() {
      _animationFadeOut = true;
      _hideShotClock = shouldHide;
      _shotClockManualOverride = false;
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
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final store = HistoryStore.instance;
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
  String _query = '';

  @override
  void initState() {
    super.initState();
    unawaited(store.ensureLoaded());
    _clockMinOptions = _buildClockMinOptions();
    _clockMaxOptions = _buildClockMaxOptions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 700) {
                        return Column(
                          children: [
                            _historyFilterField(
                              context,
                              label: 'Score',
                              value: _scoreLabel(),
                              onTap: _showScoreSelector,
                            ),
                            const SizedBox(height: 8),
                            _historyFilterField(
                              context,
                              label: 'Clock',
                              value: _clockLabel(),
                              onTap: _showClockSelector,
                            ),
                            const SizedBox(height: 8),
                            _historyFilterField(
                              context,
                              label: 'Start Type',
                              value: _startLabel(),
                              onTap: _showStartSelector,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: _historyFilterField(
                              context,
                              label: 'Score',
                              value: _scoreLabel(),
                              onTap: _showScoreSelector,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _historyFilterField(
                              context,
                              label: 'Clock',
                              value: _clockLabel(),
                              onTap: _showClockSelector,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _historyFilterField(
                              context,
                              label: 'Start Type',
                              value: _startLabel(),
                              onTap: _showStartSelector,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: _searchField(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
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
                    itemBuilder: (context, i) {
                      final entry = filtered[i];
                      return _HistoryCard(
                        entry: entry,
                        onDelete: () => store.removeEntry(entry),
                      );
                    },
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
    bool inScore(Scenario s) {
      final diff = (s.homeScore - s.guestScore).abs();
      if (_scoreTie) return diff == 0;
      if (_scoreMin != null && diff < _scoreMin!) return false;
      if (_scoreMax != null && diff > _scoreMax!) return false;
      return true;
    }

    bool inClock(Scenario s) {
      final value = s.gameClockTenths;
      if (_clockMin != null && value < _clockMin!) return false;
      if (_clockMax != null && value > _clockMax!) return false;
      return true;
    }

    bool inStartType(Scenario s) =>
        _selectedStarts.isEmpty || _selectedStarts.contains(s.startType);

    return list.where((entry) {
      final scenario = entry.scenario;
      if (!inStartType(scenario)) return false;
      if (!inScore(scenario)) return false;
      if (!inClock(scenario)) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!entry.notes.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Widget _historyFilterField(
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

  String _scoreLabel() {
    if (_scoreTie) return 'Tied only';
    if (_scoreMin == null && _scoreMax == null) return 'Any';
    if (_scoreMin == null) return '≤ $_scoreMax';
    if (_scoreMax == null) return '$_scoreMin+';
    if (_scoreMin == _scoreMax) return '$_scoreMin';
    return '$_scoreMin-$_scoreMax';
  }

  String _clockLabel() {
    final min = _clockMin;
    final max = _clockMax;
    if (min == null && max == null) return 'Any';
    if (min == null) return '≤ ${_formatClockValue(max!)}';
    if (max == null) return '${_formatClockValue(min)}+';
    if (min == max) return _formatClockValue(min);
    return '${_formatClockValue(min)} - ${_formatClockValue(max)}';
  }

  String _startLabel() {
    if (_selectedStarts.isEmpty) return 'Any';
    if (_selectedStarts.length == StartType.values.length) return 'All';
    return _selectedStarts.map(startTypeLabel).join(', ');
  }

  String _formatClockValue(int tenths) {
    final seconds = tenths ~/ 10;
    final tenthsPart = tenths % 10;
    if (tenths >= 600) {
      final minutes = seconds ~/ 60;
      final remaining = seconds % 60;
      return '${minutes}m ${remaining.toString().padLeft(2, '0')}s';
    }
    if (tenthsPart == 0) {
      return '$seconds' 's';
    }
    return '$seconds.${tenthsPart}s';
  }

  Future<void> _showScoreSelector() async {
    final result = await showModalBottomSheet<ScoreDiffSelection>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        int? tempMin = _scoreMin;
        int? tempMax = _scoreMax;
        bool tie = _scoreTie;
        final minController = FixedExtentScrollController(
            initialItem: _scoreOptionIndex(tempMin));
        final maxController = FixedExtentScrollController(
            initialItem: _scoreOptionIndex(tempMax));
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
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: tie,
                      onChanged: (value) =>
                          sheetSetState(() => tie = value ?? false),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tie only'),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: tie ? 0.4 : 1,
                      child: IgnorePointer(
                        ignoring: tie,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('MIN'),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 160,
                                    child: CupertinoPicker(
                                      scrollController: minController,
                                      itemExtent: 32,
                                      useMagnifier: true,
                                      magnification: 1.08,
                                      onSelectedItemChanged: (index) =>
                                          sheetSetState(
                                        () => tempMin = _scoreOptions[index],
                                      ),
                                      children: _scoreOptions
                                          .map((value) => Center(
                                                child: Text(value == null
                                                    ? 'ANY'
                                                    : '$value'),
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
                                  const Text('MAX'),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 160,
                                    child: CupertinoPicker(
                                      scrollController: maxController,
                                      itemExtent: 32,
                                      useMagnifier: true,
                                      magnification: 1.08,
                                      onSelectedItemChanged: (index) =>
                                          sheetSetState(
                                        () => tempMax = _scoreOptions[index],
                                      ),
                                      children: _scoreOptions
                                          .map((value) => Center(
                                                child: Text(value == null
                                                    ? 'ANY'
                                                    : '$value'),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            sheetSetState(() {
                              tempMin = null;
                              tempMax = null;
                              tie = false;
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
      setState(() {
        _scoreTie = result.tie;
        _scoreMin = result.tie ? null : result.min;
        _scoreMax = result.tie ? null : result.max;
      });
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
            initialItem: _clockOptionIndex(_clockMinOptions, tempMin));
        final maxController = FixedExtentScrollController(
            initialItem: _clockOptionIndex(_clockMaxOptions, tempMax));
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
                              const Text('MIN'),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 160,
                                child: CupertinoPicker(
                                  scrollController: minController,
                                  itemExtent: 32,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  onSelectedItemChanged: (index) =>
                                      sheetSetState(
                                    () => tempMin = _clockMinOptions[index],
                                  ),
                                  children: _clockMinOptions
                                      .map((value) => Center(
                                            child:
                                                Text(_clockOptionLabel(value)),
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
                              const Text('MAX'),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 160,
                                child: CupertinoPicker(
                                  scrollController: maxController,
                                  itemExtent: 32,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  onSelectedItemChanged: (index) =>
                                      sheetSetState(
                                    () => tempMax = _clockMaxOptions[index],
                                  ),
                                  children: _clockMaxOptions
                                      .map((value) => Center(
                                            child:
                                                Text(_clockOptionLabel(value)),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
      setState(() {
        _clockMin = result.minTenths;
        _clockMax = result.maxTenths;
      });
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
      setState(() {
        _selectedStarts
          ..clear()
          ..addAll(result);
      });
    }
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

  int _scoreOptionIndex(int? value) {
    final index = _scoreOptions.indexOf(value);
    return index >= 0 ? index : 0;
  }

  int _clockOptionIndex(List<int?> options, int? value) {
    final index = options.indexOf(value);
    return index >= 0 ? index : 0;
  }

  String _clockOptionLabel(int? tenths) {
    if (tenths == null) return 'ANY';
    return _formatClockValue(tenths);
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
  final VoidCallback onDelete;
  const _HistoryCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final s = entry.scenario;
    final time = entry.createdAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final timestamp =
        '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';

    return Stack(
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(timestamp,
                        style: Theme.of(context).textTheme.labelMedium),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                    _kv(
                        'Shot',
                        (s.hideShotClock || s.shotClockBlank)
                            ? '––'
                            : '${s.shotClockSeconds}'),
                    _kv('Period', periodLabel(s.period)),
                    _kv(
                        'Possession',
                        s.possession == TeamSide.home
                            ? entry.homeTeamName
                            : entry.guestTeamName),
                    _kv('Score', '${s.homeScore} - ${s.guestScore}'),
                    _kv('Fouls (H/G)', '${s.homeFouls}/${s.guestFouls}'),
                    _kv('TOL (H/G)', '${s.homeTimeouts}/${s.guestTimeouts}'),
                  ],
                ),
                if (entry.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(entry.notes,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 4,
          child: IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close, color: Colors.red),
            tooltip: 'Remove from history',
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
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
  final ValueChanged<bool> onHideShotClockChanged;
  final ValueChanged<Competition>? onCompetitionChanged;
  final bool initialHideShotClock;
  final GlobalKey? filtersTutorialKey;
  final GlobalKey? savedPresetsKey;
  final GlobalKey? moreFiltersButtonKey;
  final GlobalKey? saveFiltersButtonKey;
  const _RangeSelector({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onReset,
    required this.onHideShotClockChanged,
    this.onCompetitionChanged,
    this.initialHideShotClock = false,
    this.filtersTutorialKey,
    this.savedPresetsKey,
    this.moreFiltersButtonKey,
    this.saveFiltersButtonKey,
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
  final List<_SavedFilter> _favorites = <_SavedFilter>[];
  String? _selectedFavoriteName;
  static const _favoritesFileName = 'favorites.json';
  bool _hideShotClock = false;
  final GlobalKey _moreFiltersSheetKey = GlobalKey();

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
    _hideShotClock = widget.initialHideShotClock;
    unawaited(_loadFavorites());
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
      _foulRange != null ||
      _timeoutRange != null ||
      _possessionPreference != null ||
      widget.controller.settings.competition != Competition.nba ||
      _hideShotClock;

  Future<void> _loadFavorites() async {
    try {
      final raw = await AppStorage.instance.readText(_favoritesFileName);
      if (raw == null) return;
      if (raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = <_SavedFilter>[];
      for (final entry in decoded) {
        try {
          if (entry is Map<String, dynamic>) {
            final filter = _SavedFilter.fromJson(entry);
            if (filter != null) {
              loaded.add(filter);
            }
          } else if (entry is Map) {
            final filter =
                _SavedFilter.fromJson(Map<String, dynamic>.from(entry));
            if (filter != null) {
              loaded.add(filter);
            }
          }
        } catch (_) {
          // Skip malformed favorite entries.
        }
      }
      final deduped = <String, _SavedFilter>{};
      for (final filter in loaded) {
        deduped[filter.name.toLowerCase()] = filter;
      }
      final favorites = deduped.values.toList();
      if (!mounted) return;
      setState(() {
        _favorites
          ..clear()
          ..addAll(favorites);
        _sortFavorites();
        if (_selectedFavoriteName != null &&
            !_favorites.any((f) =>
                f.name.toLowerCase() == _selectedFavoriteName!.toLowerCase())) {
          _selectedFavoriteName = null;
        }
      });
    } catch (e) {
      debugPrint('Failed to load favorites: $e');
    }
  }

  Future<void> _persistFavorites() async {
    try {
      final data = _favorites.map((f) => f.toJson()).toList();
      await AppStorage.instance.writeText(_favoritesFileName, jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save favorites: $e');
    }
  }

  void _sortFavorites() {
    _favorites.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }

  void _deleteFavorite(String name) {
    final initialLength = _favorites.length;
    setState(() {
      _favorites.removeWhere(
        (existing) => existing.name.toLowerCase() == name.toLowerCase(),
      );
      if (_selectedFavoriteName != null &&
          _selectedFavoriteName!.toLowerCase() == name.toLowerCase()) {
        _selectedFavoriteName = null;
      }
    });
    if (_favorites.length != initialLength) {
      unawaited(_persistFavorites());
    }
  }

  double _favoritesMenuWidth(BuildContext context, TextStyle? textStyle) {
    if (_favorites.isEmpty) return 0;
    final style = textStyle ??
        Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      maxLines: 1,
    );
    double maxWidth = 0;
    for (final favorite in _favorites) {
      painter
        ..text = TextSpan(text: favorite.name, style: style)
        ..layout();
      maxWidth = math.max(maxWidth, painter.width);
    }
    // Add padding for menu content and delete icon.
    maxWidth += 48;
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 0) {
      maxWidth = math.min(maxWidth, screenWidth - 32);
    }
    return math.max(0, maxWidth);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final favoritesTextStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(fontWeight: FontWeight.w600);
    final favoritesMenuWidth = _favoritesMenuWidth(context, favoritesTextStyle);
    return Container(
      key: widget.filtersTutorialKey,
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
                child: InputDecorator(
                  key: widget.savedPresetsKey,
                  decoration: const InputDecoration(
                    labelText: 'Saved Presets',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: _FavoritesMenuButton(
                    favorites: _favorites,
                    selectedName: _selectedFavoriteName,
                    textStyle: favoritesTextStyle,
                    menuWidth: favoritesMenuWidth,
                    onSelect: _applyFavorite,
                    onDelete: _deleteFavorite,
                    placeholder: 'SELECT',
                    isEnabled: _favorites.isNotEmpty,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 640) {
                return Column(
                  children: [
                    _filterField(
                      context,
                      label: 'Score',
                      value: _scoreLabel(),
                      onTap: _showScoreSelector,
                    ),
                    const SizedBox(height: 8),
                    _filterField(
                      context,
                      label: 'Clock',
                      value: _clockLabel(),
                      onTap: _showClockSelector,
                    ),
                    const SizedBox(height: 8),
                    _filterField(
                      context,
                      label: 'Start',
                      value: _startLabel(),
                      onTap: _showStartSelector,
                    ),
                  ],
                );
              }

              return Row(
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
              );
            },
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              const toggleWidth = 150.0;
              final remaining = math
                  .max(constraints.maxWidth - toggleWidth - 12, 0)
                  .toDouble();
              return Row(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: toggleWidth),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _ShotClockToggle(
                        value: !_hideShotClock,
                        onChanged: _handleShotClockToggle,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: remaining),
                    child: FittedBox(
                      alignment: Alignment.centerRight,
                      fit: BoxFit.scaleDown,
                      child: Row(
                        children: [
                          _FilterActionButton(
                            key: widget.moreFiltersButtonKey,
                            label: 'MORE',
                            onPressed: _openMoreFilters,
                            color: _hasAdvancedFilters
                                ? scheme.primary
                                : scheme.onSurface,
                          ),
                          const SizedBox(width: 4),
                          _FilterActionButton(
                            key: widget.saveFiltersButtonKey,
                            label: 'SAVE',
                            onPressed: _saveCurrentFilters,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
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
        final minController = FixedExtentScrollController(
            initialItem: _scoreOptionIndex(tempMin));
        final maxController = FixedExtentScrollController(
            initialItem: _scoreOptionIndex(tempMax));

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
                                  style:
                                      Theme.of(context).textTheme.labelMedium),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 160,
                                child: CupertinoPicker(
                                  scrollController: minController,
                                  itemExtent: 32,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  onSelectedItemChanged: (index) {
                                    sheetSetState(
                                        () => tempMin = _scoreOptions[index]);
                                  },
                                  children: _scoreOptions
                                      .map((value) => Center(
                                            child:
                                                Text(_scoreOptionLabel(value)),
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
                                  style:
                                      Theme.of(context).textTheme.labelMedium),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 160,
                                child: CupertinoPicker(
                                  scrollController: maxController,
                                  itemExtent: 32,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  onSelectedItemChanged: (index) {
                                    sheetSetState(
                                        () => tempMax = _scoreOptions[index]);
                                  },
                                  children: _scoreOptions
                                      .map((value) => Center(
                                            child:
                                                Text(_scoreOptionLabel(value)),
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
                      onChanged: (value) =>
                          sheetSetState(() => tie = value ?? false),
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
                                  style:
                                      Theme.of(context).textTheme.labelMedium),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 180,
                                child: CupertinoPicker(
                                  scrollController: minController,
                                  itemExtent: 32,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  onSelectedItemChanged: (index) {
                                    sheetSetState(() =>
                                        tempMin = _clockMinOptions[index]);
                                  },
                                  children: _clockMinOptions
                                      .map((value) => Center(
                                            child: Text(
                                                _formatClockOptionLabel(value)),
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
                                  style:
                                      Theme.of(context).textTheme.labelMedium),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 180,
                                child: CupertinoPicker(
                                  scrollController: maxController,
                                  itemExtent: 32,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  onSelectedItemChanged: (index) {
                                    sheetSetState(() =>
                                        tempMax = _clockMaxOptions[index]);
                                  },
                                  children: _clockMaxOptions
                                      .map((value) => Center(
                                            child: Text(
                                                _formatClockOptionLabel(value)),
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

  Future<void> _openMoreFilters({bool showTutorial = false}) async {
    var competition = widget.controller.settings.competition;
    var foulBounds = _foulBoundsForCompetition(competition);
    var timeoutBounds = _timeoutBoundsForCompetition(competition);

    int? foulsMin = _clampOrNull(_foulRange?.min, foulBounds);
    int? foulsMax = _clampOrNull(_foulRange?.max, foulBounds);
    int? timeoutsMin = _clampOrNull(_timeoutRange?.min, timeoutBounds);
    int? timeoutsMax = _clampOrNull(_timeoutRange?.max, timeoutBounds);
    PossessionPreference? possession = _possessionPreference;

    List<int?> foulMinOptions = _buildNumericOptions(foulBounds);
    List<int?> foulMaxOptions = _buildNumericOptions(foulBounds);
    List<int?> timeoutMinOptions = _buildNumericOptions(timeoutBounds);
    List<int?> timeoutMaxOptions = _buildNumericOptions(timeoutBounds);

    final foulMinController = FixedExtentScrollController(
        initialItem: _optionIndex(foulMinOptions, foulsMin));
    final foulMaxController = FixedExtentScrollController(
        initialItem: _optionIndex(foulMaxOptions, foulsMax));
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
                key: _moreFiltersSheetKey,
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
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Competition',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Competition>(
                          value: competition,
                          isExpanded: true,
                          items: Competition.values
                              .map(
                                (c) => DropdownMenuItem<Competition>(
                                  value: c,
                                  child: Text(competitionLabel(c)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null || value == competition) return;
                            final newFoulBounds =
                                _foulBoundsForCompetition(value);
                            final newTimeoutBounds =
                                _timeoutBoundsForCompetition(value);

                            foulsMin = _clampOrNull(foulsMin, newFoulBounds);
                            foulsMax = _clampOrNull(foulsMax, newFoulBounds);
                            timeoutsMin =
                                _clampOrNull(timeoutsMin, newTimeoutBounds);
                            timeoutsMax =
                                _clampOrNull(timeoutsMax, newTimeoutBounds);

                            final updatedFoulMinOptions =
                                _buildNumericOptions(newFoulBounds);
                            final updatedFoulMaxOptions =
                                _buildNumericOptions(newFoulBounds);
                            final updatedTimeoutMinOptions =
                                _buildNumericOptions(newTimeoutBounds);
                            final updatedTimeoutMaxOptions =
                                _buildNumericOptions(newTimeoutBounds);

                            final nextFoulMinIndex =
                                _optionIndex(updatedFoulMinOptions, foulsMin);
                            final nextFoulMaxIndex =
                                _optionIndex(updatedFoulMaxOptions, foulsMax);
                            final nextTimeoutMinIndex = _optionIndex(
                                updatedTimeoutMinOptions, timeoutsMin);
                            final nextTimeoutMaxIndex = _optionIndex(
                                updatedTimeoutMaxOptions, timeoutsMax);

                            sheetSetState(() {
                              competition = value;
                              foulBounds = newFoulBounds;
                              timeoutBounds = newTimeoutBounds;
                              foulMinOptions = updatedFoulMinOptions;
                              foulMaxOptions = updatedFoulMaxOptions;
                              timeoutMinOptions = updatedTimeoutMinOptions;
                              timeoutMaxOptions = updatedTimeoutMaxOptions;
                            });

                            foulMinController.jumpToItem(nextFoulMinIndex);
                            foulMaxController.jumpToItem(nextFoulMaxIndex);
                            timeoutMinController
                                .jumpToItem(nextTimeoutMinIndex);
                            timeoutMaxController
                                .jumpToItem(nextTimeoutMaxIndex);
                          },
                        ),
                      ),
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
                      ).copyWith(
                          labelText: 'Possession', alignLabelWithHint: true),
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
                          onChanged: (value) =>
                              sheetSetState(() => possession = value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            sheetSetState(() {
                              competition = Competition.nba;
                              foulBounds =
                                  _foulBoundsForCompetition(competition);
                              timeoutBounds =
                                  _timeoutBoundsForCompetition(competition);
                              foulMinOptions = _buildNumericOptions(foulBounds);
                              foulMaxOptions = _buildNumericOptions(foulBounds);
                              timeoutMinOptions =
                                  _buildNumericOptions(timeoutBounds);
                              timeoutMaxOptions =
                                  _buildNumericOptions(timeoutBounds);
                              foulsMin = null;
                              foulsMax = null;
                              timeoutsMin = null;
                              timeoutsMax = null;
                              possession = null;
                            });
                            foulMinController.jumpToItem(0);
                            foulMaxController.jumpToItem(0);
                            timeoutMinController.jumpToItem(0);
                            timeoutMaxController.jumpToItem(0);
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
                                competition: competition,
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
        competition: result.competition,
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
      _selectedFavoriteName = null;
    });
    widget.controller.setScoreDiffSelection(selection);
    widget.onChanged();
  }

  void _applyClockSelection(ClockSelection selection) {
    setState(() {
      _clockMin = selection.minTenths;
      _clockMax = selection.maxTenths;
      _selectedFavoriteName = null;
    });
    widget.controller.setClockSelection(selection);
    widget.onChanged();
  }

  void _applyStartSelection(Set<StartType> selection) {
    setState(() {
      _selectedStarts
        ..clear()
        ..addAll(selection);
      _selectedFavoriteName = null;
    });
    widget.controller.setStartTypes(selection);
    widget.onChanged();
  }

  void _applyMoreFilters({
    required Competition competition,
    IntRange? fouls,
    IntRange? timeouts,
    PossessionPreference? possession,
  }) {
    setState(() {
      _foulRange = fouls;
      _timeoutRange = timeouts;
      _possessionPreference = possession;
      _selectedFavoriteName = null;
    });
    widget.controller.setCompetition(competition);
    widget.controller.setFoulRange(fouls);
    widget.controller.setTimeoutRange(timeouts);
    widget.controller.setPossessionPreference(possession);
    widget.onCompetitionChanged?.call(competition);
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
      _selectedFavoriteName = null;
      _hideShotClock = false;
    });
    widget.controller.resetFilters();
    widget.controller.clearScenario();
    widget.onChanged();
    widget.onHideShotClockChanged(false);
    widget.onReset?.call();
  }

  void resetFilters() {
    _resetFilters();
  }

  void _handleShotClockToggle(bool isActive) {
    final shouldHide = !isActive;
    setState(() {
      _hideShotClock = shouldHide;
      _selectedFavoriteName = null;
    });
    widget.onHideShotClockChanged(shouldHide);
    widget.onChanged();
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
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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

  Future<void> _saveCurrentFilters() async {
    final name = await _promptFavoriteName();
    if (name == null) return;

    final favorite = _SavedFilter(
      name: name,
      score: ScoreDiffSelection(
        min: _scoreTie ? null : _scoreMin,
        max: _scoreTie ? null : _scoreMax,
        tie: _scoreTie,
      ),
      clock: ClockSelection(minTenths: _clockMin, maxTenths: _clockMax),
      startTypes: Set<StartType>.from(_selectedStarts),
      fouls: _foulRange,
      timeouts: _timeoutRange,
      possession: _possessionPreference,
      hideShotClock: _hideShotClock,
    );

    setState(() {
      _favorites.removeWhere(
        (existing) => existing.name.toLowerCase() == name.toLowerCase(),
      );
      _favorites.add(favorite);
      _sortFavorites();
      _selectedFavoriteName = favorite.name;
    });

    await _persistFavorites();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved filters as "$name"')),
    );
  }

  void _applyFavorite(_SavedFilter favorite) {
    setState(() {
      _scoreTie = favorite.score.tie;
      _scoreMin = favorite.score.tie ? null : favorite.score.min;
      _scoreMax = favorite.score.tie ? null : favorite.score.max;
      _clockMin = favorite.clock.minTenths;
      _clockMax = favorite.clock.maxTenths;
      _selectedStarts
        ..clear()
        ..addAll(favorite.startTypes);
      _foulRange = favorite.fouls;
      _timeoutRange = favorite.timeouts;
      _possessionPreference = favorite.possession;
      _hideShotClock = favorite.hideShotClock;
      _selectedFavoriteName = favorite.name;
    });

    final startTypes = favorite.startTypes.isEmpty
        ? null
        : Set<StartType>.from(favorite.startTypes);
    widget.controller.setScoreDiffSelection(favorite.score);
    widget.controller.setClockSelection(favorite.clock);
    widget.controller.setStartTypes(startTypes);
    widget.controller.setFoulRange(favorite.fouls);
    widget.controller.setTimeoutRange(favorite.timeouts);
    widget.controller.setPossessionPreference(favorite.possession);
    widget.onChanged();
    widget.onHideShotClockChanged(favorite.hideShotClock);
  }

  Future<String?> _promptFavoriteName() async {
    String? error;
    final textController =
        TextEditingController(text: _selectedFavoriteName ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Save Filters'),
              content: TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter name',
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
                    final trimmed = textController.text.trim();
                    if (trimmed.isEmpty) {
                      setLocalState(() => error = 'Enter a name');
                      return;
                    }
                    Navigator.of(context).pop(trimmed);
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
}

class _MoreFiltersResult {
  final Competition competition;
  final IntRange? fouls;
  final IntRange? timeouts;
  final PossessionPreference? possession;

  const _MoreFiltersResult({
    required this.competition,
    this.fouls,
    this.timeouts,
    this.possession,
  });
}

class _FavoritesMenuButton extends StatelessWidget {
  const _FavoritesMenuButton({
    required this.favorites,
    required this.selectedName,
    required this.textStyle,
    required this.menuWidth,
    required this.onSelect,
    required this.onDelete,
    required this.placeholder,
    required this.isEnabled,
  });

  final List<_SavedFilter> favorites;
  final String? selectedName;
  final TextStyle? textStyle;
  final double menuWidth;
  final ValueChanged<_SavedFilter> onSelect;
  final ValueChanged<String> onDelete;
  final String placeholder;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedName = selectedName?.toLowerCase();
    _SavedFilter? selected;
    if (normalizedName != null) {
      for (final favorite in favorites) {
        if (favorite.name.toLowerCase() == normalizedName) {
          selected = favorite;
          break;
        }
      }
    }

    final displayStyle = (selected == null
            ? textStyle?.copyWith(color: theme.hintColor)
            : textStyle) ??
        theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: selected == null ? theme.hintColor : null,
        );

    final double resolvedWidth =
        math.max(menuWidth, 200); // ensure reasonable minimum width

    return PopupMenuButton<_SavedFilter>(
      enabled: isEnabled,
      position: PopupMenuPosition.under,
      constraints: BoxConstraints(minWidth: resolvedWidth),
      tooltip: isEnabled ? 'Favorites' : null,
      color: theme.colorScheme.surface,
      onSelected: onSelect,
      itemBuilder: (context) {
        return favorites
            .map(
              (favorite) => PopupMenuItem<_SavedFilter>(
                value: favorite,
                padding: EdgeInsets.zero,
                child: SizedBox(
                  width: resolvedWidth,
                  child: _FavoriteMenuItemRow(
                    favorite: favorite,
                    textStyle: textStyle ??
                        theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                    onDelete: () => onDelete(favorite.name),
                  ),
                ),
              ),
            )
            .toList();
      },
      child: Row(
        children: [
          Expanded(
            child: Text(
              selected?.name ?? placeholder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: displayStyle,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_drop_down,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _ShotClockToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ShotClockToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
        ),
        const SizedBox(width: 4),
        Text(
          'SHOT CLOCK',
          style: labelStyle,
        ),
      ],
    );
  }
}

class _FavoriteMenuItemRow extends StatefulWidget {
  const _FavoriteMenuItemRow({
    required this.favorite,
    required this.textStyle,
    required this.onDelete,
  });

  final _SavedFilter favorite;
  final TextStyle? textStyle;
  final VoidCallback onDelete;

  @override
  State<_FavoriteMenuItemRow> createState() => _FavoriteMenuItemRowState();
}

class _FavoriteMenuItemRowState extends State<_FavoriteMenuItemRow> {
  bool _removed = false;

  @override
  Widget build(BuildContext context) {
    if (_removed) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(
              widget.favorite.name,
              style: widget.textStyle,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            widget.onDelete();
            if (mounted) {
              setState(() => _removed = true);
            }
          },
          icon: const Icon(
            Icons.close,
            size: 16,
            color: Colors.grey,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
          splashRadius: 18,
          tooltip: 'Delete',
        ),
      ],
    );
  }
}

class _SavedFilter {
  final String name;
  final ScoreDiffSelection score;
  final ClockSelection clock;
  final Set<StartType> startTypes;
  final IntRange? fouls;
  final IntRange? timeouts;
  final PossessionPreference? possession;
  final bool hideShotClock;

  const _SavedFilter({
    required this.name,
    required this.score,
    required this.clock,
    required this.startTypes,
    this.fouls,
    this.timeouts,
    this.possession,
    this.hideShotClock = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'score': {
        'min': score.min,
        'max': score.max,
        'tie': score.tie,
      },
      'clock': {
        'minTenths': clock.minTenths,
        'maxTenths': clock.maxTenths,
      },
      'startTypes': startTypes.map((type) => type.name).toList(),
      'fouls': fouls == null
          ? null
          : {
              'min': fouls!.min,
              'max': fouls!.max,
              'label': fouls!.label,
            },
      'timeouts': timeouts == null
          ? null
          : {
              'min': timeouts!.min,
              'max': timeouts!.max,
              'label': timeouts!.label,
            },
      'possession': possession?.name,
      'hideShotClock': hideShotClock,
    };
  }

  static _SavedFilter? fromJson(Map<String, dynamic> json) {
    final rawName = json['name'];
    if (rawName is! String) return null;
    final name = rawName.trim();
    if (name.isEmpty) return null;

    ScoreDiffSelection score = const ScoreDiffSelection();
    final scoreMap = json['score'];
    if (scoreMap is Map) {
      final tie = scoreMap['tie'] == true;
      final minValue = scoreMap['min'];
      final maxValue = scoreMap['max'];
      score = ScoreDiffSelection(
        min: tie ? null : (minValue is num ? minValue.toInt() : score.min),
        max: tie ? null : (maxValue is num ? maxValue.toInt() : score.max),
        tie: tie,
      );
    }

    ClockSelection clock = const ClockSelection();
    final clockMap = json['clock'];
    if (clockMap is Map) {
      final minValue = clockMap['minTenths'];
      final maxValue = clockMap['maxTenths'];
      clock = ClockSelection(
        minTenths: minValue is num ? minValue.toInt() : null,
        maxTenths: maxValue is num ? maxValue.toInt() : null,
      );
    }

    IntRange? parseRange(dynamic data) {
      if (data is! Map) return null;
      final minValue = data['min'];
      final maxValue = data['max'];
      if (minValue is! num || maxValue is! num) return null;
      final minInt = minValue.toInt();
      final maxInt = maxValue.toInt();
      final labelValue = data['label'];
      final label = labelValue is String && labelValue.isNotEmpty
          ? labelValue
          : '$minInt-$maxInt';
      return IntRange(minInt, maxInt, label);
    }

    final startTypes = <StartType>{};
    final startTypesList = json['startTypes'];
    if (startTypesList is List) {
      for (final entry in startTypesList) {
        if (entry is! String) continue;
        final match = StartType.values.where((type) => type.name == entry);
        if (match.isNotEmpty) {
          startTypes.add(match.first);
        }
      }
    }

    IntRange? fouls;
    final foulsData = json['fouls'];
    if (foulsData != null) {
      fouls = parseRange(foulsData);
    }

    IntRange? timeouts;
    final timeoutsData = json['timeouts'];
    if (timeoutsData != null) {
      timeouts = parseRange(timeoutsData);
    }

    PossessionPreference? possession;
    final possessionValue = json['possession'];
    if (possessionValue is String) {
      for (final option in PossessionPreference.values) {
        if (option.name == possessionValue) {
          possession = option;
          break;
        }
      }
    }

    final hideShotClock = json['hideShotClock'] == true;

    return _SavedFilter(
      name: name,
      score: score,
      clock: clock,
      startTypes: startTypes,
      fouls: fouls,
      timeouts: timeouts,
      possession: possession,
      hideShotClock: hideShotClock,
    );
  }
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

const double _scoreboardDesignWidth = 760;
const double _scoreboardAspectRatio = 1.2;
const double _scoreboardDesignHeight =
    _scoreboardDesignWidth / _scoreboardAspectRatio;

class _BoxedClockTight extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final _ClockBoxStyle? styleOverrides;
  const _BoxedClockTight(
      {required this.text, this.textStyle, this.styleOverrides});

  @override
  Widget build(BuildContext context) {
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
              border: Border.all(color: const Color(0xFF8C8C8C), width: 2),
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
  final bool manualShotClockOverride;
  const _Scoreboard({
    required this.controller,
    this.onEditTeamName,
    this.onEditScore,
    this.onEditFouls,
    this.onEditTimeouts,
    this.onEditGameClock,
    this.onEditShotClock,
    this.manualShotClockOverride = false,
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
    final competition = controller.settings.competition;
    final int autoHideThreshold =
        (competition == Competition.nba || competition == Competition.fiba)
            ? 240
            : 300;
    final bool autoHideShotClock = has &&
        !manualShotClockOverride &&
        s.gameClockTenths <= autoHideThreshold;
    final shotClockHidden = has && (s.hideShotClock || autoHideShotClock);
    final shotClockText =
        (has && !shotClockHidden) ? '${s.shotClockSeconds}' : '—';
    const backgroundColor = Color(0xFF111111);
    const insetColor = Color(0xFF1E1E1E);
    final borderColor = Colors.white.withValues(alpha: 0.22);
    final labelStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 1.0,
      color: Colors.white,
      fontSize: 16,
    );
    final metaLabelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: Colors.white,
      fontSize: 12,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardWidth = constraints.maxWidth;
        final boardHeight = constraints.maxHeight;
        final scale = (boardWidth / _scoreboardDesignWidth).clamp(0.48, 1.0);
        final gameClockStyle = _ClockBoxStyle(
          width: boardWidth * 0.22,
          height: boardHeight * 0.085,
          borderRadius: 0,
          backgroundColor: insetColor,
          textColorOverride: Colors.white,
          horizontalPadding: 12,
        );
        final shotClockStyle = _ClockBoxStyle(
          width: boardWidth * 0.085,
          height: boardWidth * 0.085,
          borderRadius: 0,
          backgroundColor: insetColor,
          textColorOverride: null,
          horizontalPadding: 8,
        );
        final periodBoxWidth = boardWidth * 0.075;
        final periodBoxHeight = boardHeight * 0.075;
        final teamBoxWidth = boardWidth * 0.235;
        final teamBoxHeight = boardHeight * 0.275;
        final leftTeamX = boardWidth * 0.055;
        final rightTeamX = boardWidth - leftTeamX - teamBoxWidth;
        final teamBoxTop = boardHeight * 0.17;
        final clockTop = boardHeight * 0.03;
        final periodTop = boardHeight * 0.46;
        final shotClockTop = boardHeight * 0.64;
        final statsTop = boardHeight * 0.83;
        final timeoutTop = boardHeight * 0.92;
        final periodLeft = (boardWidth - periodBoxWidth) / 2;
        final shotClockLeft = (boardWidth - shotClockStyle.width) / 2;
        final showHomeArrow = showArrow && s.possessionArrow == TeamSide.home;
        final showGuestArrow = showArrow && s.possessionArrow == TeamSide.guest;
        final shotClockColor =
            shotClockHidden ? Colors.white.withValues(alpha: 0.35) : Colors.red;

        Widget buildTeamLabel(String text,
            {required bool arrowLeft, required bool showArrowIcon}) {
          final arrowIcon = Icon(
            arrowLeft
                ? Icons.arrow_back_ios_new_rounded
                : Icons.arrow_forward_ios_rounded,
            color: theme.colorScheme.primary,
            size: 16,
          );
          final label = Text(text, style: labelStyle);
          if (!showArrowIcon) return label;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: arrowLeft
                ? [arrowIcon, const SizedBox(width: 4), label]
                : [label, const SizedBox(width: 4), arrowIcon],
          );
        }

        Widget buildScoreBox({
          required String text,
          required Future<void> Function()? onTap,
        }) {
          final baseFont = theme.textTheme.displayLarge?.fontSize ?? 60;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null ? null : () => onTap(),
            child: Container(
              decoration: BoxDecoration(
                color: insetColor,
                border: Border.all(color: borderColor, width: 2.5),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: teamBoxWidth * 0.08,
                vertical: teamBoxHeight * 0.09,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: _BalancedScoreText(
                    text: text,
                    baseFont: baseFont,
                    targetFontSize: teamBoxHeight * 0.34,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }

        Widget buildStatBox({
          required String title,
          required String value,
          required Future<void> Function()? onTap,
        }) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null ? null : () => onTap(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: metaLabelStyle),
                SizedBox(height: 4 * scale),
                Container(
                  width: boardWidth * 0.05,
                  height: boardHeight * 0.075,
                  decoration: BoxDecoration(
                    color: insetColor,
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'TimesSquare',
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget buildTimeoutBox({
          required int? timeouts,
          required Future<void> Function()? onTap,
        }) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null ? null : () => onTap(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('T.O.L.', style: metaLabelStyle),
                SizedBox(height: 4 * scale),
                Container(
                  width: boardWidth * 0.09,
                  height: boardHeight * 0.04,
                  decoration: BoxDecoration(
                    color: insetColor,
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: Center(
                    child: _TimeoutDots(
                      activeCount: (timeouts ?? 0).clamp(0, 5),
                      totalCount: 5,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white.withValues(alpha: 0.25),
                      dotSize: 6,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: clockTop,
                left: (boardWidth - gameClockStyle.width) / 2,
                width: gameClockStyle.width,
                height: gameClockStyle.height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap:
                      onEditGameClock == null ? null : () => onEditGameClock!(),
                  child: _BoxedClockTight(
                    text: gameClockText,
                    textStyle: theme.textTheme.displayMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w700,
                      fontFamily: 'TimesSquare',
                      fontSize: 34,
                    ),
                    styleOverrides: gameClockStyle,
                  ),
                ),
              ),
              Positioned(
                top: teamBoxTop - 40,
                left: leftTeamX,
                width: teamBoxWidth,
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onEditTeamName == null
                        ? null
                        : () => onEditTeamName!(TeamSide.home),
                    child: buildTeamLabel(
                      homeName.trim().isEmpty ? 'HOME' : homeName,
                      arrowLeft: true,
                      showArrowIcon: showHomeArrow,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: teamBoxTop,
                left: leftTeamX,
                width: teamBoxWidth,
                height: teamBoxHeight,
                child: buildScoreBox(
                  text: has ? '${s.homeScore}' : '––',
                  onTap: onEditScore == null || !has
                      ? null
                      : () => onEditScore!(TeamSide.home),
                ),
              ),
              Positioned(
                top: teamBoxTop - 40,
                left: rightTeamX,
                width: teamBoxWidth,
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onEditTeamName == null
                        ? null
                        : () => onEditTeamName!(TeamSide.guest),
                    child: buildTeamLabel(
                      guestName.trim().isEmpty ? 'GUEST' : guestName,
                      arrowLeft: false,
                      showArrowIcon: showGuestArrow,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: teamBoxTop,
                left: rightTeamX,
                width: teamBoxWidth,
                height: teamBoxHeight,
                child: buildScoreBox(
                  text: has ? '${s.guestScore}' : '––',
                  onTap: onEditScore == null || !has
                      ? null
                      : () => onEditScore!(TeamSide.guest),
                ),
              ),
              Positioned(
                top: periodTop,
                left: periodLeft - 24,
                width: periodBoxWidth + 48,
                child: Center(
                    child: Text('PERIOD',
                        style: metaLabelStyle?.copyWith(fontSize: 14))),
              ),
              Positioned(
                top: periodTop + 34,
                left: periodLeft,
                width: periodBoxWidth,
                height: periodBoxHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: insetColor,
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      periodText,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'TimesSquare',
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: shotClockTop,
                left: shotClockLeft - 40,
                width: shotClockStyle.width + 80,
                child: Center(
                    child: Text('SHOT CLOCK',
                        style: metaLabelStyle?.copyWith(fontSize: 14))),
              ),
              Positioned(
                top: shotClockTop + 32,
                left: shotClockLeft,
                width: shotClockStyle.width,
                height: shotClockStyle.height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEditShotClock == null || !has
                      ? null
                      : () => onEditShotClock!(),
                  child: _BoxedClockTight(
                    text: shotClockText,
                    textStyle: theme.textTheme.displaySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w900,
                      color: shotClockColor,
                      fontFamily: 'TimesSquare',
                      letterSpacing: -0.4,
                      fontSize: 30,
                    ),
                    styleOverrides: shotClockStyle,
                  ),
                ),
              ),
              Positioned(
                top: statsTop,
                left: boardWidth * 0.09,
                child: buildStatBox(
                  title: 'FLS',
                  value: has ? '${s.homeFouls}' : '––',
                  onTap: onEditFouls == null || !has
                      ? null
                      : () => onEditFouls!(TeamSide.home),
                ),
              ),
              Positioned(
                top: timeoutTop,
                left: boardWidth * 0.07,
                child: buildTimeoutBox(
                  timeouts: has ? s.homeTimeouts : null,
                  onTap: onEditTimeouts == null || !has
                      ? null
                      : () => onEditTimeouts!(TeamSide.home),
                ),
              ),
              Positioned(
                top: statsTop,
                right: boardWidth * 0.09,
                child: buildStatBox(
                  title: 'FLS',
                  value: has ? '${s.guestFouls}' : '––',
                  onTap: onEditFouls == null || !has
                      ? null
                      : () => onEditFouls!(TeamSide.guest),
                ),
              ),
              Positioned(
                top: timeoutTop,
                right: boardWidth * 0.07,
                child: buildTimeoutBox(
                  timeouts: has ? s.guestTimeouts : null,
                  onTap: onEditTimeouts == null || !has
                      ? null
                      : () => onEditTimeouts!(TeamSide.guest),
                ),
              ),
            ],
          ),
        );
      },
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
    final adjustments = {2: 0.74, 3: 0.68, 4: 0.62};
    final scale = adjustments[digits] ?? 0.58;
    final fontSize = targetFontSize * scale;

    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.displayLarge?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -1.5,
        fontFamily: 'TimesSquare',
        fontSize: math.max(fontSize, baseFont * scale),
      ),
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
  final bool forceLightText;
  const _OutsideMeta({
    required this.controller,
    this.forceLightText = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = controller.scenario;
    final has = controller.hasScenario;
    final homeTeam = controller.homeTeamName;
    final guestTeam = controller.guestTeamName;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: forceLightText
              ? Colors.black
              : Theme.of(context).textTheme.titleMedium?.color,
        );
    String startText = '*Start: ';
    if (has) {
      final String type = startTypeLabel(s.startType);
      final String possession = (s.startType == StartType.jumpBall)
          ? ''
          : ' (${s.possession == TeamSide.home ? homeTeam : guestTeam})';
      startText += '$type$possession*';
    } else {
      startText += '––';
    }

    return Column(
      children: [
        Text(startText, style: titleStyle),
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

class _FilterActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  const _FilterActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color ?? Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}
