import 'scenario_generator.dart';

class SmartStrategyRecommendation {
  final String status;
  final String perspectiveLabel;
  final String headline;
  final String summary;
  final String stateLine;
  final String? rationale;
  final List<String> notes;

  const SmartStrategyRecommendation({
    required this.status,
    required this.perspectiveLabel,
    required this.headline,
    required this.summary,
    required this.stateLine,
    this.rationale,
    this.notes = const [],
  });
}

const Map<String, Map<String, String>> _offenseMatrix = {
  '1:00-0:52.1': {
    '-4': 'NORMAL OFFENSE',
    '-3': 'NORMAL OFFENSE',
    '-2': 'NORMAL OFFENSE',
    '-1': 'NORMAL OFFENSE',
    '0': 'NORMAL OFFENSE',
    '1': 'NORMAL OFFENSE',
    '2': 'NORMAL OFFENSE',
    '3': 'NORMAL OFFENSE',
  },
  '0:52-0:40.1': {
    '-4': '2 FOR 1',
    '-3': '2 FOR 1',
    '-2': '2 FOR 1',
    '-1': '2 FOR 1',
    '0': '2 FOR 1 / (GOOD SHOT ONLY)',
    '1': '2 FOR 1 / (GOOD SHOT ONLY)',
    '2': 'SHOOT UNDER :08 ON SHOT CLOCK',
    '3': 'SHOOT UNDER :08 ON SHOT CLOCK',
  },
  '0:40-0:35.1': {
    '-4': '2 FOR 1',
    '-3': '2 FOR 1',
    '-2': '2 FOR 1',
    '-1': '2 FOR 1',
    '0': '2 FOR 1 / (GOOD SHOT ONLY)',
    '1': '2 FOR 1 / (GOOD SHOT ONLY)',
    '2': 'SHOOT UNDER :08 ON SHOT CLOCK',
    '3': 'SHOOT UNDER :08 ON SHOT CLOCK',
  },
  '0:35-0:30.1': {
    '-4': 'QUICK 2 FOR 1 (USE TIMEOUT IF WE HAVE 2)',
    '-3': 'QUICK 2 FOR 1 (USE T/OUT IF HAVE 2)',
    '-2': 'QUICK 2 FOR 1 (USE T/OUT IF HAVE 2)',
    '-1': 'QUICK 2 FOR 1 (USE T/OUT IF HAVE 2)',
    '0': 'QUICK 2 FOR 1 (USE T/OUT IF HAVE 2)',
    '1': 'SHOOT UNDER :08 ON SHOT CLOCK',
    '2': 'SHOOT UNDER :08 ON SHOT CLOCK',
    '3': 'SHOOT UNDER :08 ON SHOT CLOCK',
  },
  '0:30-0:28.1': {
    '-4': 'QUICK 2 / OR / GOOD 3',
    '-3': 'QUICK 2 / OR / GOOD 3',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'SHOOT UNDER :08 ON SHOT CLOCK',
    '1': 'SHOOT UNDER :08 ON SHOT CLOCK',
    '2': 'SHOOT UNDER :08 ON SHOT CLOCK',
    '3': 'SHOOT UNDER :08 ON SHOT CLOCK',
  },
  '0:28-0:26.1': {
    '-4': 'QUICK 2 / OR / GOOD 3',
    '-3': 'QUICK 2 / OR / GOOD 3',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'SHOOT UNDER :08 ON SHOT CLOCK',
    '1': 'SHOOT UNDER :08 ON SHOT CLOCK',
    '2': 'SHOOT UNDER :05 ON SHOT CLOCK',
    '3': 'SHOOT UNDER :05 ON SHOT CLOCK',
  },
  '0:26-0:24.1': {
    '-4': 'QUICK 2 / OR / GOOD 3',
    '-3': 'QUICK 2 / OR / GOOD 3',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'SHOOT UNDER :08 ON SHOT CLOCK',
    '1':
        'SHOOT UNDER :05 ON SHOT CLOCK.  BUT IF OPPONENT HAS NO TIMEOUT, SHOOT UNDER :03 ON SHOT CLOCK',
    '2':
        'SHOOT UNDER :05 ON SHOT CLOCK.  BUT IF OPPONENT HAS NO TIMEOUT, SHOOT UNDER :03 ON SHOT CLOCK',
    '3':
        'SHOOT UNDER :05 ON SHOT CLOCK.  BUT IF OPPONENT HAS NO TIMEOUT, SHOOT UNDER :03 ON SHOT CLOCK',
  },
  '0:24-0:20.1': {
    '-4': 'QUICK 2 / OR / GOOD 3',
    '-3': 'QUICK 2 / OR / GOOD 3',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'HOLD BALL FOR LAST / SHOT',
    '2': 'HOLD BALL FOR LAST / SHOT',
    '3': 'HOLD BALL FOR LAST / SHOT',
  },
  '0:20-0:15.1': {
    '-4': 'QUICK 2 / OR / GOOD 3',
    '-3': 'QUICK 2 / OR / GOOD 3',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'HOLD BALL FOR LAST / SHOT',
    '2': 'HOLD BALL FOR LAST / SHOT',
    '3': 'HOLD BALL FOR LAST / SHOT',
  },
  '0:15-0:10.1': {
    '-4': 'QUICK 2 / OR / GOOD 3',
    '-3': 'QUICK 2 / OR / GOOD 3',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'HOLD BALL FOR LAST / SHOT',
    '2': 'HOLD BALL FOR LAST / SHOT',
    '3': 'HOLD BALL FOR LAST / SHOT',
  },
  '0:10-0:08.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'HOLD BALL FOR LAST / SHOT',
    '2': 'HOLD BALL FOR LAST / SHOT',
    '3': 'HOLD BALL FOR LAST / SHOT',
  },
  '0:08-0:07.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'HOLD BALL FOR LAST / SHOT',
    '2': 'HOLD BALL FOR LAST / SHOT',
    '3': 'HOLD BALL FOR LAST / SHOT',
  },
  '0:07-0:06.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'HOLD BALL FOR LAST / SHOT',
    '2': 'HOLD BALL FOR LAST / SHOT',
    '3': 'HOLD BALL FOR LAST / SHOT',
  },
  '0:06-0:05.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'HOLD BALL FOR LAST / SHOT',
    '2': 'HOLD BALL FOR LAST / SHOT',
    '3': 'HOLD BALL FOR LAST / SHOT',
  },
  '0:05-0:04.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'HOLD BALL FOR LAST / SHOT',
    '2': 'HOLD BALL FOR LAST / SHOT',
    '3': 'HOLD BALL FOR LAST / SHOT',
  },
  '0:04-0:03.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'LOB OR CATCH AND / SHOOT',
    '-1': 'LOB OR CATCH AND / SHOOT',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'HOLD BALL FOR LAST / SHOT',
    '2': 'HOLD BALL FOR LAST / SHOT',
    '3': 'HOLD BALL FOR LAST / SHOT',
  },
  '0:03-0:02.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'LOB OR CATCH AND / SHOOT',
    '-1': 'LOB OR CATCH AND / SHOOT',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'HOLD BALL FOR LAST / SHOT',
    '2': 'HOLD BALL FOR LAST / SHOT',
    '3': 'HOLD BALL FOR LAST / SHOT',
  },
  '0:02-0:01.1': {
    '-4': 'DRAW FOUL',
    '-3': 'DRAW FOUL',
    '-2': 'LOB / TIP',
    '-1': 'LOB / TIP',
    '0': 'LOB / TIP',
    '1': 'SAFE INBOUNDS',
    '2': 'SAFE INBOUNDS',
    '3': 'SAFE INBOUNDS',
  },
  '0:01-0:00.5': {
    '-4': 'DRAW FOUL',
    '-3': 'DRAW FOUL',
    '-2': 'LOB / TIP',
    '-1': 'LOB / TIP',
    '0': 'LOB / TIP',
    '1': 'SAFE INBOUNDS',
    '2': 'SAFE INBOUNDS',
    '3': 'SAFE INBOUNDS',
  },
};

SmartStrategyRecommendation evaluateSmartStrategy({
  required Scenario scenario,
  required Competition competition,
  required String homeTeamName,
  required String guestTeamName,
}) {
  if (competition != Competition.nba) {
    return SmartStrategyRecommendation(
      status: 'unavailable',
      perspectiveLabel: 'NBA only',
      headline: 'Smart Strategy unavailable',
      summary:
          'This recommendation tool is currently tuned only for NBA late-game rules.',
      stateLine: _stateLine(
        scenario: scenario,
        teamLabel:
            scenario.possession == TeamSide.home ? homeTeamName : guestTeamName,
        scoreDiff: _scoreDiffFromPossession(scenario),
      ),
    );
  }

  if (!(scenario.period == Period.p4 || scenario.period == Period.ot)) {
    return SmartStrategyRecommendation(
      status: 'inactive',
      perspectiveLabel:
          _possessionTeamLabel(scenario, homeTeamName, guestTeamName),
      headline: 'Smart Strategy inactive',
      summary: 'The late-game rules only apply in Q4 and overtime.',
      stateLine: _stateLine(
        scenario: scenario,
        teamLabel: _possessionTeamLabel(scenario, homeTeamName, guestTeamName),
        scoreDiff: _scoreDiffFromPossession(scenario),
      ),
    );
  }

  final secondsRemaining = scenario.gameClockTenths / 10.0;
  final scoreDiff = _scoreDiffFromPossession(scenario);
  final teamLabel = _possessionTeamLabel(scenario, homeTeamName, guestTeamName);

  if (secondsRemaining > 360) {
    return SmartStrategyRecommendation(
      status: 'inactive',
      perspectiveLabel: teamLabel,
      headline: 'Smart Strategy inactive',
      summary: 'The workbook-based late-game rules begin in the final 6:00.',
      stateLine: _stateLine(
        scenario: scenario,
        teamLabel: teamLabel,
        scoreDiff: scoreDiff,
      ),
    );
  }

  final playMode = _buildPlayMode(scoreDiff, secondsRemaining);
  if (secondsRemaining > 60) {
    return SmartStrategyRecommendation(
      status: playMode == null ? 'monitor' : 'play-mode',
      perspectiveLabel: '$teamLabel possession',
      headline: playMode?.mode ?? 'Play Mode watch',
      summary: playMode?.instruction ??
          'No special workbook instruction in this exact play-mode state.',
      stateLine: _stateLine(
        scenario: scenario,
        teamLabel: teamLabel,
        scoreDiff: scoreDiff,
      ),
      rationale:
          'Play Mode is driven by the final 6:00 table from the workbook.',
      notes: playMode == null
          ? const []
          : <String>['Mode source: Play Mode table.'],
    );
  }

  final band = _workbookTimeBand(secondsRemaining);
  final bucket = _offenseScoreBucket(scoreDiff);
  final rawInstruction = _offenseMatrix[band]?[bucket];
  if (rawInstruction == null) {
    return SmartStrategyRecommendation(
      status: 'unavailable',
      perspectiveLabel: '$teamLabel possession',
      headline: 'Smart Strategy unavailable',
      summary: 'No workbook instruction matched this exact scoreboard state.',
      stateLine: _stateLine(
        scenario: scenario,
        teamLabel: teamLabel,
        scoreDiff: scoreDiff,
      ),
    );
  }

  final mapped = _mapInstruction(
    rawInstruction,
    ourTimeouts: scenario.possession == TeamSide.home
        ? scenario.homeTimeouts
        : scenario.guestTimeouts,
    opponentTimeouts: scenario.possession == TeamSide.home
        ? scenario.guestTimeouts
        : scenario.homeTimeouts,
  );

  return SmartStrategyRecommendation(
    status: 'ready',
    perspectiveLabel: '$teamLabel possession',
    headline: mapped.$1,
    summary: mapped.$2,
    stateLine: _stateLine(
      scenario: scenario,
      teamLabel: teamLabel,
      scoreDiff: scoreDiff,
    ),
    rationale: 'Direct workbook lookup from the late-game offense matrix.',
    notes: mapped.$3,
  );
}

({String mode, String instruction})? _buildPlayMode(
    int scoreDiff, double secondsRemaining) {
  if (scoreDiff >= 20 && secondsRemaining < 360) {
    return (mode: 'Retreat', instruction: 'Rest starters');
  }
  if (scoreDiff >= 15 && secondsRemaining < 180) {
    return (mode: 'Retreat', instruction: 'Rest starters');
  }
  if (scoreDiff >= 10 && secondsRemaining < 60) {
    return (mode: 'Retreat', instruction: 'Rest starters');
  }
  if (scoreDiff <= -11 && secondsRemaining <= 359 && secondsRemaining >= 300) {
    return (mode: 'Speed Up', instruction: 'Shoot quick');
  }
  if (scoreDiff <= -10 && secondsRemaining <= 299 && secondsRemaining >= 240) {
    return (mode: 'Speed Up', instruction: "Mostly 3's");
  }
  if (scoreDiff <= -9 && secondsRemaining <= 239 && secondsRemaining >= 180) {
    return (mode: 'Speed Up', instruction: 'Crash 5');
  }
  if (scoreDiff <= -6 && secondsRemaining <= 179 && secondsRemaining >= 120) {
    return (mode: 'Speed Up', instruction: 'Press');
  }
  if (scoreDiff >= 11 && secondsRemaining <= 359 && secondsRemaining >= 300) {
    return (mode: 'Slow Down', instruction: 'Shoot < 8 secs');
  }
  if (scoreDiff >= 10 && secondsRemaining <= 299 && secondsRemaining >= 240) {
    return (mode: 'Slow Down', instruction: 'Press break');
  }
  if (scoreDiff >= 9 && secondsRemaining <= 239 && secondsRemaining >= 180) {
    return (mode: 'Slow Down', instruction: 'All 5 get back');
  }
  if (scoreDiff >= 6 && secondsRemaining <= 179 && secondsRemaining >= 120) {
    return (mode: 'Slow Down', instruction: 'Let ball roll when possible');
  }
  if (scoreDiff >= 5 && secondsRemaining < 120) {
    return (mode: 'Slow Down', instruction: 'Let ball roll when possible');
  }
  return null;
}

String _workbookTimeBand(double secondsRemaining) {
  if (secondsRemaining > 52) return '1:00-0:52.1';
  if (secondsRemaining > 40) return '0:52-0:40.1';
  if (secondsRemaining > 35) return '0:40-0:35.1';
  if (secondsRemaining > 30) return '0:35-0:30.1';
  if (secondsRemaining > 28) return '0:30-0:28.1';
  if (secondsRemaining > 26) return '0:28-0:26.1';
  if (secondsRemaining > 24) return '0:26-0:24.1';
  if (secondsRemaining > 20) return '0:24-0:20.1';
  if (secondsRemaining > 15) return '0:20-0:15.1';
  if (secondsRemaining > 10) return '0:15-0:10.1';
  if (secondsRemaining > 8) return '0:10-0:08.1';
  if (secondsRemaining > 7) return '0:08-0:07.1';
  if (secondsRemaining > 6) return '0:07-0:06.1';
  if (secondsRemaining > 5) return '0:06-0:05.1';
  if (secondsRemaining > 4) return '0:05-0:04.1';
  if (secondsRemaining > 3) return '0:04-0:03.1';
  if (secondsRemaining > 2) return '0:03-0:02.1';
  return '0:02-0:01.1';
}

String _offenseScoreBucket(int scoreDiff) {
  if (scoreDiff <= -4) return '-4';
  if (scoreDiff >= 3) return '3';
  return '$scoreDiff';
}

int _scoreDiffFromPossession(Scenario scenario) {
  if (scenario.possession == TeamSide.home) {
    return scenario.homeScore - scenario.guestScore;
  }
  return scenario.guestScore - scenario.homeScore;
}

String _possessionTeamLabel(
  Scenario scenario,
  String homeTeamName,
  String guestTeamName,
) {
  return scenario.possession == TeamSide.home ? homeTeamName : guestTeamName;
}

String _stateLine({
  required Scenario scenario,
  required String teamLabel,
  required int scoreDiff,
}) {
  final margin = scoreDiff > 0 ? '+$scoreDiff' : '$scoreDiff';
  final clock = formatGameClockTenths(scenario.gameClockTenths);
  final period = periodLabel(scenario.period);
  final periodText = scenario.period == Period.ot ? 'OT' : 'Q$period';
  return '$teamLabel possession · $periodText $clock · margin $margin';
}

(String, String, List<String>) _mapInstruction(
  String rawInstruction, {
  required int ourTimeouts,
  required int opponentTimeouts,
}) {
  final normalized = rawInstruction.replaceAll('\n', ' ').trim();
  switch (normalized) {
    case 'NORMAL OFFENSE':
      return ('Normal offense', 'Run normal late-game offense.', const []);
    case '2 FOR 1':
      return ('2 For 1', 'Push for the extra possession.', const []);
    case '2 FOR 1 / (GOOD SHOT ONLY)':
      return ('2 For 1', 'Good shot only.', const []);
    case 'QUICK 2 FOR 1 (USE TIMEOUT IF WE HAVE 2)':
    case 'QUICK 2 FOR 1 (USE T/OUT IF HAVE 2)':
      return (
        'Quick 2 For 1',
        'Use timeout if we have 2.',
        <String>['Timeouts remaining: $ourTimeouts.'],
      );
    case 'QUICK 2 / OR / GOOD 3':
      return ('Quick 2 or good 3', 'Attack immediately.', const []);
    case 'NEED 2 / BUT PREFER / 3':
      return (
        'Need 2, prefer 3',
        'Take 2 unless a clean 3 is there.',
        const []
      );
    case 'NEED 2':
      return ('Need 2', 'Attack for a quick 2.', const []);
    case 'SHOOT UNDER :08 ON SHOT CLOCK':
      return (
        'Late clock offense',
        'Shoot under :08 on the shot clock.',
        const []
      );
    case 'SHOOT UNDER :05 ON SHOT CLOCK':
      return (
        'Late clock offense',
        'Shoot under :05 on the shot clock.',
        const []
      );
    case 'SHOOT UNDER :05 ON SHOT CLOCK.  BUT IF OPPONENT HAS NO TIMEOUT, SHOOT UNDER :03 ON SHOT CLOCK':
      return (
        'Late clock offense',
        opponentTimeouts > 0
            ? 'Shoot under :05 on the shot clock.'
            : 'If they have no timeout, shoot under :03 on the shot clock.',
        <String>['Opponent timeouts remaining: $opponentTimeouts.'],
      );
    case 'HOLD BALL FOR LAST / SHOT':
      return (
        'Hold for last shot',
        'Use clock to control the final possession.',
        const []
      );
    case 'NEED 3 /  / *CRASH 5*':
      return ('Need 3', 'Crash 5.', const []);
    case 'LOB OR CATCH AND / SHOOT':
      return ('Lob or catch-and-shoot', 'Quick-hitter only.', const []);
    case 'DRAW FOUL':
      return ('Draw foul', 'Attack body contact immediately.', const []);
    case 'LOB / TIP':
      return ('Lob / tip', 'Quick-hitter only.', const []);
    case 'SAFE INBOUNDS':
      return (
        'Safe inbounds',
        'Value possession over advancement risk.',
        const []
      );
    default:
      return (normalized, 'Follow the workbook cell literally.', const []);
  }
}
