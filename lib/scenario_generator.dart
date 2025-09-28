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

class ClockRange {
  final int minTenths;
  final int maxTenths;
  final String label;

  const ClockRange(this.minTenths, this.maxTenths, this.label);
}

class IntRange {
  final int min;
  final int max;
  final String label;

  const IntRange(this.min, this.max, this.label);

  @override
  String toString() => label;
}

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

const List<ClockRange> clockPresets = <ClockRange>[
  ClockRange(1, 1800, 'Any'),
  ClockRange(1, 4, ':00.1-:00.4'),
  ClockRange(10, 40, ':01-:04'),
  ClockRange(40, 90, ':04-:09'),
  ClockRange(1, 90, ':00.1-:09'),
  ClockRange(90, 150, ':09-:15'),
  ClockRange(150, 230, ':15-:23'),
  ClockRange(90, 230, ':09-:23'),
  ClockRange(250, 600, ':25-1:00'),
  ClockRange(600, 1200, '1:00-2:00'),
  ClockRange(1200, 1790, '2:00-2:59'),
];

class ScenarioSettings {
  Competition competition = Competition.nba;
  IntRange scoreDiff = scoreDiffPresets.first;
  ClockRange clock = clockPresets.first;
  bool favorFourthOrOT = true;
  StartType? startType;
}

class Scenario {
  final int homeScore;
  final int guestScore;
  final int gameClockTenths;
  final int shotClockSeconds;
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
}

class ScenarioController {
  final _rng = Random();
  final ScenarioSettings settings = ScenarioSettings();
  Scenario? _scenario;
  bool forceHideShotClockHighSchool = false;

  bool get hasScenario => _scenario != null;
  Scenario get scenario => _scenario ?? _placeholder();
  CompetitionRules get currentRules => rulesForCompetition(settings.competition);

  Scenario _placeholder() => const Scenario(
        homeScore: 0,
        guestScore: 0,
        gameClockTenths: 0,
        shotClockSeconds: 0,
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

  void setScenario(Scenario s) {
    _scenario = s;
  }

  void setScoreDiffRange(IntRange range) {
    settings.scoreDiff = range;
  }

  void setClockRange(ClockRange range) {
    settings.clock = range;
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

  void setStartType(StartType? startType) {
    settings.startType = startType;
  }

  Scenario generateScenario() {
    final rules = currentRules;
    final competition = settings.competition;
    final clockRange = settings.clock;
    int gameClockTenths = _randIn(clockRange.minTenths, clockRange.maxTenths);
    gameClockTenths = gameClockTenths.clamp(1, 1800).toInt();

    bool hideShotClock = false;
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

    late final StartType startType;
    final desiredStart = settings.startType;
    if (desiredStart != null) {
      startType = desiredStart;
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
    final bool inboundStart = startType == StartType.sob || startType == StartType.bob;
    final int inboundCap =
        (competition == Competition.nba || competition == Competition.fiba) ? 20 : 25;
    final int effectiveCap = inboundStart ? min(maxShotClock, inboundCap) : maxShotClock;
    final int baselineThresholdSeconds =
        (competition == Competition.nba || competition == Competition.fiba) ? 24 : 30;
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
        (competition == Competition.nba || competition == Competition.fiba) ? 24 : 30;

    if (jumpBallOverride && effectiveCap > 0) {
      hideShotClock = false;
      shotClockSeconds = min(jumpBallTarget, effectiveCap);
    } else if (jumpBallLowClock) {
      hideShotClock = true;
      shotClockSeconds = 0;
    } else if (competition == Competition.highSchool && forceHideShotClockHighSchool) {
      hideShotClock = true;
      shotClockSeconds = 0;
    } else if (startType == StartType.backCourtBaseline &&
        gameClockTenths < baselineThresholdTenths) {
      hideShotClock = true;
      shotClockSeconds = 0;
    } else if (startType == StartType.ftLine) {
      final bool isPro = competition == Competition.nba || competition == Competition.fiba;
      final int thresholdTenths = isPro ? 240 : 300;
      final int target = isPro ? 24 : 30;

      if (gameClockTenths <= thresholdTenths) {
        hideShotClock = true;
        shotClockSeconds = 0;
      } else {
        hideShotClock = false;
        shotClockSeconds = min(target, effectiveCap > 0 ? effectiveCap : target);
      }
    } else if (hideShotClock || effectiveCap <= 0) {
      hideShotClock = true;
      shotClockSeconds = 0;
    } else {
      if (shotClockSeconds <= 0 || shotClockSeconds > effectiveCap) {
        shotClockSeconds = _rng.nextInt(effectiveCap) + 1;
      }
    }

    final diffRange = settings.scoreDiff;
    final diff = diffRange.min == 0 && diffRange.max == 0
        ? 0
        : _randIn(diffRange.min, diffRange.max);

    final maxAllowableDiff = rules.scoreMax - rules.scoreMin;
    final appliedDiff = min(diff, maxAllowableDiff);
    final lowerBoundMax = rules.scoreMax - appliedDiff;
    final safeLowerMax = max(lowerBoundMax, rules.scoreMin);
    final lowerScore = _randIn(rules.scoreMin, safeLowerMax);
    final higherScore = (lowerScore + appliedDiff).clamp(rules.scoreMin, rules.scoreMax);

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
      final includeOt = allowedPeriods.contains(Period.ot) && _rng.nextInt(100) < 20;
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

    final possession = _rng.nextBool() ? TeamSide.home : TeamSide.guest;
    final possessionArrow = rules.showPossessionArrow
        ? (_rng.nextBool() ? TeamSide.home : TeamSide.guest)
        : possession;

    int randomFouls() {
      if (competition == Competition.fiba) {
        final roll = _rng.nextInt(100);
        if (roll < 3) return 1;
        if (roll < 10) return 2; // 3-10 => 7%
        if (roll < 30) return 3; // 10-30 => 20%
        return 4; // remaining 70%
      }
      return rules.foulMin + _rng.nextInt(rules.foulMax - rules.foulMin + 1);
    }
    int randomTimeouts() => rules.timeoutMin + _rng.nextInt(rules.timeoutMax - rules.timeoutMin + 1);

    final homeFouls = randomFouls();
    final guestFouls = randomFouls();
    final homeTimeouts = randomTimeouts();
    final guestTimeouts = randomTimeouts();

    return Scenario(
      homeScore: homeScore,
      guestScore: guestScore,
      gameClockTenths: gameClockTenths,
      shotClockSeconds: shotClockSeconds,
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
}
