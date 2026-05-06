import 'dart:math';

/// Identifies the side with the ball or on the scoreboard.
enum TeamSide { home, guest }

/// Types of possessions that start a scenario.
enum StartType {
  sob,
  bob,
  ftLine,
  backCourtBaseline,
  backCourtSideline,
  jumpBall,
}

/// Periods in regulation plus overtime.
enum Period { p1, p2, p3, p4, ot }

/// Competition presets (logic currently matches NBA; other presets configurable later).
enum Competition { nba, ncaa, highSchool, fiba }

class CompetitionRules {
  final int scoreMin;
  final int scoreMax;
  final int shotClockMax;
  final int foulMin;
  final int foulMax;
  final int timeoutMin;
  final int timeoutMax;
  final bool showPossessionArrow;
  final List<Period> allowedPeriods;
  final Period preferredRegulationPeriod;

  const CompetitionRules({
    required this.scoreMin,
    required this.scoreMax,
    required this.shotClockMax,
    required this.foulMin,
    required this.foulMax,
    required this.timeoutMin,
    required this.timeoutMax,
    required this.showPossessionArrow,
    required this.allowedPeriods,
    required this.preferredRegulationPeriod,
  });
}

const Map<Competition, CompetitionRules> competitionRules = {
  Competition.nba: CompetitionRules(
    scoreMin: 95,
    scoreMax: 135,
    shotClockMax: 24,
    foulMin: 3,
    foulMax: 5,
    timeoutMin: 0,
    timeoutMax: 2,
    showPossessionArrow: false,
    allowedPeriods: [Period.p1, Period.p2, Period.p3, Period.p4, Period.ot],
    preferredRegulationPeriod: Period.p4,
  ),
  Competition.highSchool: CompetitionRules(
    scoreMin: 50,
    scoreMax: 75,
    shotClockMax: 35,
    foulMin: 5,
    foulMax: 10,
    timeoutMin: 0,
    timeoutMax: 3,
    showPossessionArrow: true,
    allowedPeriods: [Period.p1, Period.p2, Period.p3, Period.p4, Period.ot],
    preferredRegulationPeriod: Period.p4,
  ),
  Competition.fiba: CompetitionRules(
    scoreMin: 50,
    scoreMax: 80,
    shotClockMax: 24,
    foulMin: 1,
    foulMax: 4,
    timeoutMin: 0,
    timeoutMax: 3,
    showPossessionArrow: false,
    allowedPeriods: [Period.p1, Period.p2, Period.p3, Period.p4, Period.ot],
    preferredRegulationPeriod: Period.p4,
  ),
  Competition.ncaa: CompetitionRules(
    scoreMin: 50,
    scoreMax: 80,
    shotClockMax: 30,
    foulMin: 5,
    foulMax: 10,
    timeoutMin: 0,
    timeoutMax: 3,
    showPossessionArrow: true,
    allowedPeriods: [Period.p1, Period.p2, Period.ot],
    preferredRegulationPeriod: Period.p2,
  ),
};

CompetitionRules rulesForCompetition(Competition c) => competitionRules[c]!;

String startTypeLabel(StartType t) {
  switch (t) {
    case StartType.sob:
      return 'SOB';
    case StartType.bob:
      return 'BOB';
    case StartType.ftLine:
      return 'FT Line';
    case StartType.backCourtBaseline:
      return 'Back Court Baseline';
    case StartType.backCourtSideline:
      return 'Back Court Sideline';
    case StartType.jumpBall:
      return 'Jump Ball';
  }
}

String periodLabel(Period p) {
  switch (p) {
    case Period.p1:
      return '1';
    case Period.p2:
      return '2';
    case Period.p3:
      return '3';
    case Period.p4:
      return '4';
    case Period.ot:
      return 'OT';
  }
}

String competitionLabel(Competition c) {
  switch (c) {
    case Competition.nba:
      return 'NBA';
    case Competition.ncaa:
      return 'NCAA';
    case Competition.highSchool:
      return 'High School';
    case Competition.fiba:
      return 'FIBA';
  }
}

/// Formats the game clock per basketball conventions.
/// >= 60.0 seconds -> `m:ss`
/// < 60.0 seconds  -> `s.t` with no leading zero for single digits.
String formatGameClockTenths(int totalTenths) {
  if (totalTenths <= 0) return '0:00';
  final totalSeconds = totalTenths ~/ 10;
  if (totalTenths >= 600) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  final tenths = totalTenths % 10;
  return '$totalSeconds.$tenths';
}

class IntRange {
  final int min;
  final int max;
  final String label;

  const IntRange(this.min, this.max, this.label);

  @override
  String toString() => label;
}

class ScoreDiffSelection {
  final int? min;
  final int? max;
  final bool tie;

  const ScoreDiffSelection({this.min, this.max, this.tie = false});

  const ScoreDiffSelection.any() : this();

  ScoreDiffSelection copyWith(
      {int? min,
      bool includeMin = false,
      int? max,
      bool includeMax = false,
      bool? tie}) {
    return ScoreDiffSelection(
      min: includeMin ? min : this.min,
      max: includeMax ? max : this.max,
      tie: tie ?? this.tie,
    );
  }
}

class ClockSelection {
  final int? minTenths;
  final int? maxTenths;

  const ClockSelection({this.minTenths, this.maxTenths});

  const ClockSelection.any() : this();

  ClockSelection copyWith({
    int? minTenths,
    bool includeMin = false,
    int? maxTenths,
    bool includeMax = false,
  }) {
    return ClockSelection(
      minTenths: includeMin ? minTenths : this.minTenths,
      maxTenths: includeMax ? maxTenths : this.maxTenths,
    );
  }
}

enum PossessionPreference { winning, losing }

const List<IntRange> scoreDiffPresets = <IntRange>[
  IntRange(0, 12, 'Any'),
  IntRange(0, 0, 'Tie only'),
  IntRange(1, 3, '1–3'),
  IntRange(4, 6, '4–6'),
  IntRange(1, 6, '1–6'),
  IntRange(7, 9, '7–9'),
  IntRange(10, 12, '10–12'),
  IntRange(7, 12, '7–12'),
];

class ScenarioSettings {
  Competition competition = Competition.nba;
  ScoreDiffSelection scoreDiff = const ScoreDiffSelection();
  ClockSelection clock = const ClockSelection();
  bool favorFourthOrOT = true;
  Set<StartType>? startTypes;
  IntRange? foulRange;
  IntRange? timeoutRange;
  PossessionPreference? possessionPreference;
}

class Scenario {
  final int homeScore;
  final int guestScore;
  final int gameClockTenths;
  final int shotClockSeconds;
  final bool shotClockBlank;
  final bool hideShotClock;
  final Period period;
  final TeamSide possession;
  final TeamSide possessionArrow;
  final StartType startType;
  final int homeFouls;
  final int guestFouls;
  final int homeTimeouts;
  final int guestTimeouts;

  const Scenario({
    required this.homeScore,
    required this.guestScore,
    required this.gameClockTenths,
    required this.shotClockSeconds,
    required this.shotClockBlank,
    required this.hideShotClock,
    required this.period,
    required this.possession,
    required this.possessionArrow,
    required this.startType,
    required this.homeFouls,
    required this.guestFouls,
    required this.homeTimeouts,
    required this.guestTimeouts,
  });

  Scenario copyWith({
    int? homeScore,
    int? guestScore,
    int? gameClockTenths,
    int? shotClockSeconds,
    bool? shotClockBlank,
    bool? hideShotClock,
    Period? period,
    TeamSide? possession,
    TeamSide? possessionArrow,
    StartType? startType,
    int? homeFouls,
    int? guestFouls,
    int? homeTimeouts,
    int? guestTimeouts,
  }) {
    return Scenario(
      homeScore: homeScore ?? this.homeScore,
      guestScore: guestScore ?? this.guestScore,
      gameClockTenths: gameClockTenths ?? this.gameClockTenths,
      shotClockSeconds: shotClockSeconds ?? this.shotClockSeconds,
      shotClockBlank: shotClockBlank ?? this.shotClockBlank,
      hideShotClock: hideShotClock ?? this.hideShotClock,
      period: period ?? this.period,
      possession: possession ?? this.possession,
      possessionArrow: possessionArrow ?? this.possessionArrow,
      startType: startType ?? this.startType,
      homeFouls: homeFouls ?? this.homeFouls,
      guestFouls: guestFouls ?? this.guestFouls,
      homeTimeouts: homeTimeouts ?? this.homeTimeouts,
      guestTimeouts: guestTimeouts ?? this.guestTimeouts,
    );
  }

  static Scenario defaults() => const Scenario(
        homeScore: 0,
        guestScore: 0,
        gameClockTenths: 0,
        shotClockSeconds: 0,
        shotClockBlank: true,
        hideShotClock: true,
        period: Period.p4,
        possession: TeamSide.home,
        possessionArrow: TeamSide.home,
        startType: StartType.sob,
        homeFouls: 0,
        guestFouls: 0,
        homeTimeouts: 0,
        guestTimeouts: 0,
      );

  Map<String, dynamic> toJson() {
    return {
      'homeScore': homeScore,
      'guestScore': guestScore,
      'gameClockTenths': gameClockTenths,
      'shotClockSeconds': shotClockSeconds,
      'shotClockBlank': shotClockBlank,
      'hideShotClock': hideShotClock,
      'period': period.name,
      'possession': possession.name,
      'possessionArrow': possessionArrow.name,
      'startType': startType.name,
      'homeFouls': homeFouls,
      'guestFouls': guestFouls,
      'homeTimeouts': homeTimeouts,
      'guestTimeouts': guestTimeouts,
    };
  }

  factory Scenario.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return fallback;
    }

    bool readBool(String key, bool fallback) {
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lowered = value.toLowerCase();
        if (lowered == 'true' || lowered == '1') return true;
        if (lowered == 'false' || lowered == '0') return false;
      }
      return fallback;
    }

    TeamSide readTeamSide(String key, TeamSide fallback) {
      final value = json[key];
      if (value is String) {
        try {
          return TeamSide.values.byName(value);
        } catch (_) {}
      }
      return fallback;
    }

    Period readPeriod(String key, Period fallback) {
      final value = json[key];
      if (value is String) {
        try {
          return Period.values.byName(value);
        } catch (_) {}
      }
      return fallback;
    }

    StartType readStartType(String key, StartType fallback) {
      final value = json[key];
      if (value is String) {
        try {
          return StartType.values.byName(value);
        } catch (_) {}
      }
      return fallback;
    }

    return Scenario(
      homeScore: readInt('homeScore', 0),
      guestScore: readInt('guestScore', 0),
      gameClockTenths: readInt('gameClockTenths', 0),
      shotClockSeconds: readInt('shotClockSeconds', 0),
      shotClockBlank: readBool('shotClockBlank', false),
      hideShotClock: readBool('hideShotClock', false),
      period: readPeriod('period', Period.p4),
      possession: readTeamSide('possession', TeamSide.home),
      possessionArrow: readTeamSide('possessionArrow', TeamSide.home),
      startType: readStartType('startType', StartType.sob),
      homeFouls: readInt('homeFouls', 0),
      guestFouls: readInt('guestFouls', 0),
      homeTimeouts: readInt('homeTimeouts', 0),
      guestTimeouts: readInt('guestTimeouts', 0),
    );
  }
}

class ScenarioController {
  final _rng = Random();
  final ScenarioSettings settings = ScenarioSettings();
  Scenario? _scenario;
  bool forceHideShotClockHighSchool = false;
  String _homeTeamName = 'HOME';
  String _guestTeamName = 'GUEST';

  bool get hasScenario => _scenario != null;
  Scenario get scenario => _scenario ?? _placeholder();
  CompetitionRules get currentRules =>
      rulesForCompetition(settings.competition);
  String get homeTeamName => _homeTeamName;
  String get guestTeamName => _guestTeamName;

  Scenario _placeholder() => Scenario.defaults();

  void setScenario(Scenario s) {
    _scenario = s;
  }

  void setHomeTeamName(String name) {
    final trimmed = name.trim();
    _homeTeamName = trimmed.isEmpty ? 'HOME' : trimmed;
  }

  void setGuestTeamName(String name) {
    final trimmed = name.trim();
    _guestTeamName = trimmed.isEmpty ? 'GUEST' : trimmed;
  }

  void setScoreDiffSelection(ScoreDiffSelection selection) {
    settings.scoreDiff = selection;
  }

  void setClockSelection(ClockSelection selection) {
    settings.clock = selection;
  }

  void setCompetition(Competition competition) {
    settings.competition = competition;
    if (competition != Competition.highSchool) {
      forceHideShotClockHighSchool = false;
    }
  }

  void setForceHideShotClockHighSchool(bool value) {
    forceHideShotClockHighSchool = value;
  }

  void setStartTypes(Set<StartType>? startTypes) {
    if (startTypes == null || startTypes.isEmpty) {
      settings.startTypes = null;
    } else {
      settings.startTypes = startTypes.toSet();
    }
  }

  void updateHomeScore(int value) {
    _updateScenario(
      (s) => s.copyWith(homeScore: _clamp(value, 0, 150)),
    );
  }

  void updateGuestScore(int value) {
    _updateScenario(
      (s) => s.copyWith(guestScore: _clamp(value, 0, 150)),
    );
  }

  void updateHomeFouls(int value) {
    _updateScenario(
      (s) => s.copyWith(homeFouls: _clamp(value, 0, currentRules.foulMax)),
    );
  }

  void updateGuestFouls(int value) {
    _updateScenario(
      (s) => s.copyWith(guestFouls: _clamp(value, 0, currentRules.foulMax)),
    );
  }

  void updateHomeTimeouts(int value) {
    _updateScenario(
      (s) => s.copyWith(homeTimeouts: _clamp(value, 0, 5)),
    );
  }

  void updateGuestTimeouts(int value) {
    _updateScenario(
      (s) => s.copyWith(guestTimeouts: _clamp(value, 0, 5)),
    );
  }

  void updateGameClockTenths(int tenths) {
    final clamped = _clamp(tenths, 0, 1800);
    _updateScenario(
      (s) {
        final maxShot = clamped ~/ 10;
        final adjustedShot = maxShot > 0 ? min(s.shotClockSeconds, maxShot) : 0;
        return s.copyWith(
          gameClockTenths: clamped,
          shotClockSeconds: adjustedShot,
        );
      },
    );
  }

  void updateShotClock({required int seconds, required bool hide}) {
    final rules = currentRules;
    _updateScenario(
      (s) {
        final clampedSeconds = _clamp(seconds, 0, rules.shotClockMax);
        final maxByClock = s.gameClockTenths ~/ 10;
        final adjusted = maxByClock > 0 ? min(clampedSeconds, maxByClock) : 0;
        return s.copyWith(
          shotClockSeconds: adjusted,
          shotClockBlank: adjusted <= 0,
          hideShotClock: hide,
        );
      },
    );
  }

  void setFoulRange(IntRange? range) {
    settings.foulRange = range;
  }

  void setTimeoutRange(IntRange? range) {
    settings.timeoutRange = range;
  }

  void setPossessionPreference(PossessionPreference? preference) {
    settings.possessionPreference = preference;
  }

  void resetFilters() {
    settings
      ..scoreDiff = const ScoreDiffSelection()
      ..clock = const ClockSelection()
      ..startTypes = null
      ..foulRange = null
      ..timeoutRange = null
      ..possessionPreference = null;
    forceHideShotClockHighSchool = false;
  }

  void clearScenario() {
    _scenario = null;
  }

  Scenario generateScenario() {
    final rules = currentRules;
    final competition = settings.competition;
    final clockSelection = settings.clock;
    final int rawClockMin = (clockSelection.minTenths ?? 1).clamp(1, 1800);
    final int rawClockMax = (clockSelection.maxTenths ?? 1800).clamp(1, 1800);
    final int clockMin = min(rawClockMin, rawClockMax);
    final int clockMax = max(rawClockMin, rawClockMax);

    int gameClockTenths = _randIn(clockMin, clockMax);
    gameClockTenths = gameClockTenths.clamp(1, 1800).toInt();

    bool hideShotClock = false;
    bool shotClockBlank = false;
    int shotClockSeconds = 0;

    if (gameClockTenths < 100) {
      hideShotClock = _rng.nextInt(100) < 90;
      if (!hideShotClock) {
        shotClockSeconds = min(rules.shotClockMax, gameClockTenths ~/ 10);
      }
    } else if (gameClockTenths >= 101 && gameClockTenths <= 199) {
      hideShotClock = _rng.nextInt(100) < 85;
      if (!hideShotClock) {
        shotClockSeconds = min(rules.shotClockMax, gameClockTenths ~/ 10);
      }
    } else if (gameClockTenths >= 200 && gameClockTenths <= 240) {
      hideShotClock = _rng.nextInt(100) < 75;
      if (!hideShotClock) {
        shotClockSeconds = 5 + _rng.nextInt(11);
        shotClockSeconds = min(shotClockSeconds, gameClockTenths ~/ 10);
        shotClockSeconds = min(shotClockSeconds, rules.shotClockMax);
      }
    } else {
      shotClockSeconds = _rng.nextInt(rules.shotClockMax + 1);
      final maxShot = gameClockTenths ~/ 10;
      if (shotClockSeconds > maxShot) {
        shotClockSeconds = maxShot < 0 ? 0 : min(maxShot, rules.shotClockMax);
      }
    }

    final selectedStarts = settings.startTypes;
    late final StartType startType;
    if (selectedStarts != null && selectedStarts.isNotEmpty) {
      final list = selectedStarts.toList();
      startType = list[_rng.nextInt(list.length)];
    } else {
      final startRoll = _rng.nextInt(100);
      if (startRoll < 60) {
        startType = StartType.sob;
      } else if (startRoll < 65) {
        startType = StartType.bob;
      } else if (startRoll < 85) {
        startType = StartType.ftLine;
      } else if (startRoll < 90) {
        startType = StartType.backCourtBaseline;
      } else if (startRoll < 92) {
        startType = StartType.backCourtSideline;
      } else {
        startType = StartType.jumpBall;
      }
    }

    final maxShotClock = min(rules.shotClockMax, gameClockTenths ~/ 10);
    final bool inboundStart =
        startType == StartType.sob || startType == StartType.bob;
    final int inboundCap =
        (competition == Competition.nba || competition == Competition.fiba)
            ? 20
            : 25;
    final int effectiveCap =
        inboundStart ? min(maxShotClock, inboundCap) : maxShotClock;
    final int baselineThresholdSeconds =
        (competition == Competition.nba || competition == Competition.fiba)
            ? 24
            : 30;
    final int baselineThresholdTenths = baselineThresholdSeconds * 10;

    final bool jumpBallLowClock = startType == StartType.jumpBall &&
        ((competition == Competition.nba || competition == Competition.fiba)
            ? gameClockTenths <= 240
            : gameClockTenths <= 300);
    final bool jumpBallOverride = startType == StartType.jumpBall &&
        ((competition == Competition.nba || competition == Competition.fiba)
            ? gameClockTenths >= 241
            : gameClockTenths >= 301);
    final int jumpBallTarget =
        (competition == Competition.nba || competition == Competition.fiba)
            ? 24
            : 30;

    if (jumpBallOverride && effectiveCap > 0) {
      hideShotClock = false;
      shotClockSeconds = min(jumpBallTarget, effectiveCap);
      shotClockBlank = false;
    } else if (jumpBallLowClock) {
      hideShotClock = true;
      shotClockSeconds = 0;
      shotClockBlank = true;
    } else if (competition == Competition.highSchool &&
        forceHideShotClockHighSchool) {
      hideShotClock = true;
      shotClockSeconds = 0;
      shotClockBlank = true;
    } else if (startType == StartType.backCourtBaseline &&
        gameClockTenths < baselineThresholdTenths) {
      hideShotClock = true;
      shotClockSeconds = 0;
      shotClockBlank = true;
    } else if (startType == StartType.ftLine) {
      final bool isPro =
          competition == Competition.nba || competition == Competition.fiba;
      final int thresholdTenths = isPro ? 240 : 300;
      final int target = isPro ? 24 : 30;

      if (gameClockTenths <= thresholdTenths) {
        hideShotClock = true;
        shotClockSeconds = 0;
        shotClockBlank = true;
      } else {
        hideShotClock = false;
        shotClockSeconds =
            min(target, effectiveCap > 0 ? effectiveCap : target);
        shotClockBlank = false;
      }
    } else if (hideShotClock || effectiveCap <= 0) {
      hideShotClock = true;
      shotClockSeconds = 0;
      shotClockBlank = true;
    } else {
      if (shotClockSeconds <= 0 || shotClockSeconds > effectiveCap) {
        shotClockSeconds = _randIn(1, max(1, effectiveCap));
      }
    }

    final bool isProCompetition =
        competition == Competition.nba || competition == Competition.fiba;
    final int extendedThresholdTenths = isProCompetition ? 240 : 300;
    if (gameClockTenths > extendedThresholdTenths) {
      final int upperBound = max(
        1,
        min(maxShotClock > 0 ? maxShotClock : rules.shotClockMax,
            rules.shotClockMax),
      );

      int pickRangeInclusive(int minSeconds, int maxSeconds) {
        final int clampedMax = min(maxSeconds, upperBound);
        final int clampedMin = min(max(minSeconds, 1), clampedMax);
        if (clampedMax < clampedMin) {
          return clampedMax;
        }
        return _randIn(clampedMin, clampedMax);
      }

      int sobProShot() {
        final roll = _rng.nextInt(100);
        if (roll < 75) {
          return min(14, upperBound);
        } else if (roll < 85) {
          return pickRangeInclusive(15, 20);
        } else if (roll < 90) {
          return pickRangeInclusive(8, 13);
        } else if (roll < 95) {
          return pickRangeInclusive(4, 7);
        }
        return pickRangeInclusive(2, 3);
      }

      int bobProShot() {
        final roll = _rng.nextInt(100);
        if (roll < 75) {
          return pickRangeInclusive(10, 18);
        } else if (roll < 95) {
          return pickRangeInclusive(5, 9);
        }
        return pickRangeInclusive(2, 4);
      }

      int sobNcaaShot() {
        final roll = _rng.nextInt(100);
        if (roll < 75) {
          return min(20, upperBound);
        } else if (roll < 85) {
          return pickRangeInclusive(21, 25);
        } else if (roll < 90) {
          return pickRangeInclusive(8, 18);
        } else if (roll < 95) {
          return pickRangeInclusive(4, 7);
        }
        return pickRangeInclusive(2, 3);
      }

      int bobNcaaShot() {
        final roll = _rng.nextInt(100);
        if (roll < 75) {
          return pickRangeInclusive(10, 22);
        } else if (roll < 95) {
          return pickRangeInclusive(5, 9);
        }
        return pickRangeInclusive(2, 4);
      }

      int desiredSeconds = shotClockSeconds;

      if (isProCompetition) {
        switch (startType) {
          case StartType.ftLine:
            desiredSeconds = min(24, upperBound);
            break;
          case StartType.backCourtBaseline:
            desiredSeconds = min(24, upperBound);
            break;
          case StartType.backCourtSideline:
            desiredSeconds = pickRangeInclusive(18, 24);
            break;
          case StartType.jumpBall:
            desiredSeconds = min(24, upperBound);
            break;
          case StartType.sob:
            desiredSeconds = sobProShot();
            break;
          case StartType.bob:
            desiredSeconds = bobProShot();
            break;
        }
      } else {
        switch (startType) {
          case StartType.ftLine:
            desiredSeconds = min(30, upperBound);
            break;
          case StartType.backCourtBaseline:
            desiredSeconds = min(30, upperBound);
            break;
          case StartType.backCourtSideline:
            desiredSeconds = pickRangeInclusive(22, 30);
            break;
          case StartType.jumpBall:
            desiredSeconds = min(30, upperBound);
            break;
          case StartType.sob:
            desiredSeconds = sobNcaaShot();
            break;
          case StartType.bob:
            desiredSeconds = bobNcaaShot();
            break;
        }
      }

      if (desiredSeconds <= 0) {
        desiredSeconds = upperBound;
      }
      shotClockSeconds = desiredSeconds.clamp(1, upperBound);
      hideShotClock = false;
      shotClockBlank = false;
    }

    shotClockBlank = shotClockBlank || hideShotClock || shotClockSeconds <= 0;

    final bool shortClockBlank =
        isProCompetition ? gameClockTenths <= 240 : gameClockTenths <= 300;
    if (shortClockBlank) {
      shotClockBlank = true;
    }

    final diffSelection = settings.scoreDiff;
    final int diff;
    if (diffSelection.tie) {
      diff = 0;
    } else {
      final int minDiff = max(0, diffSelection.min ?? 0);
      final int maxDiff = max(minDiff, diffSelection.max ?? 12);
      diff = _randIn(minDiff, maxDiff);
    }

    final maxAllowableDiff = rules.scoreMax - rules.scoreMin;
    final appliedDiff = min(diff, maxAllowableDiff);
    final lowerBoundMax = rules.scoreMax - appliedDiff;
    final safeLowerMax = max(lowerBoundMax, rules.scoreMin);
    final lowerScore = _randIn(rules.scoreMin, safeLowerMax);
    final higherScore =
        (lowerScore + appliedDiff).clamp(rules.scoreMin, rules.scoreMax);

    int homeScore;
    int guestScore;

    if (_rng.nextBool()) {
      homeScore = higherScore;
      guestScore = lowerScore;
    } else {
      homeScore = lowerScore;
      guestScore = higherScore;
    }

    final allowedPeriods = rules.allowedPeriods;
    final nonOtPeriods = allowedPeriods.where((p) => p != Period.ot).toList();
    final preferLate = settings.favorFourthOrOT;
    Period period;
    if (preferLate) {
      final includeOt =
          allowedPeriods.contains(Period.ot) && _rng.nextInt(100) < 20;
      if (includeOt) {
        period = Period.ot;
      } else if (allowedPeriods.contains(rules.preferredRegulationPeriod)) {
        period = rules.preferredRegulationPeriod;
      } else if (nonOtPeriods.isNotEmpty) {
        period = nonOtPeriods[_rng.nextInt(nonOtPeriods.length)];
      } else {
        period = allowedPeriods.first;
      }
    } else {
      if (nonOtPeriods.isNotEmpty) {
        period = nonOtPeriods[_rng.nextInt(nonOtPeriods.length)];
      } else {
        period = allowedPeriods.first;
      }
    }

    TeamSide possession;
    final possessionPreference = settings.possessionPreference;
    if (possessionPreference != null && homeScore != guestScore) {
      final TeamSide leading =
          homeScore > guestScore ? TeamSide.home : TeamSide.guest;
      final TeamSide trailing =
          leading == TeamSide.home ? TeamSide.guest : TeamSide.home;
      possession = possessionPreference == PossessionPreference.winning
          ? leading
          : trailing;
    } else {
      possession = _rng.nextBool() ? TeamSide.home : TeamSide.guest;
    }
    final possessionArrow = rules.showPossessionArrow
        ? (_rng.nextBool() ? TeamSide.home : TeamSide.guest)
        : possession;

    int randomFouls() {
      final customRange = settings.foulRange;
      if (customRange != null) {
        final minValue =
            max(rules.foulMin, min(customRange.min, customRange.max));
        final maxValue =
            min(rules.foulMax, max(customRange.min, customRange.max));
        return _randIn(minValue, maxValue);
      }
      if (competition == Competition.fiba) {
        final roll = _rng.nextInt(100);
        if (roll < 3) return 1;
        if (roll < 10) return 2; // 3-10 => 7%
        if (roll < 30) return 3; // 10-30 => 20%
        return 4; // remaining 70%
      }
      return rules.foulMin + _rng.nextInt(rules.foulMax - rules.foulMin + 1);
    }

    int randomTimeouts() {
      final customRange = settings.timeoutRange;
      if (customRange != null) {
        final minValue =
            max(rules.timeoutMin, min(customRange.min, customRange.max));
        final maxValue =
            min(rules.timeoutMax, max(customRange.min, customRange.max));
        return _randIn(minValue, maxValue);
      }
      return rules.timeoutMin +
          _rng.nextInt(rules.timeoutMax - rules.timeoutMin + 1);
    }

    final homeFouls = randomFouls();
    final guestFouls = randomFouls();
    final homeTimeouts = randomTimeouts();
    final guestTimeouts = randomTimeouts();

    return Scenario(
      homeScore: homeScore,
      guestScore: guestScore,
      gameClockTenths: gameClockTenths,
      shotClockSeconds: shotClockSeconds,
      shotClockBlank: shotClockBlank,
      hideShotClock: hideShotClock,
      period: period,
      possession: possession,
      possessionArrow: possessionArrow,
      startType: startType,
      homeFouls: homeFouls,
      guestFouls: guestFouls,
      homeTimeouts: homeTimeouts,
      guestTimeouts: guestTimeouts,
    );
  }

  void rollNewScenario() {
    _scenario = generateScenario();
  }

  int _randIn(int min, int max) {
    if (max < min) {
      final temp = min;
      min = max;
      max = temp;
    }
    return min + _rng.nextInt(max - min + 1);
  }

  void _updateScenario(Scenario Function(Scenario) transform) {
    final current = _scenario ?? _placeholder();
    _scenario = transform(current);
  }

  int _clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
