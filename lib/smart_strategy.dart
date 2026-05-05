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
    '1': 'BALL SECURITY & PREPARE FOR FOUL',
    '2': 'BALL SECURITY & PREPARE FOR FOUL',
    '3': 'BALL SECURITY & PREPARE FOR FOUL',
  },
  '0:20-0:15.1': {
    '-4': 'QUICK 2 / OR / GOOD 3',
    '-3': 'QUICK 2 / OR / GOOD 3',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'BALL SECURITY & PREPARE FOR FOUL',
    '2': 'BALL SECURITY & PREPARE FOR FOUL',
    '3': 'BALL SECURITY & PREPARE FOR FOUL',
  },
  '0:15-0:10.1': {
    '-4': 'QUICK 2 / OR / GOOD 3',
    '-3': 'QUICK 2 / OR / GOOD 3',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'BALL SECURITY & PREPARE FOR FOUL',
    '2': 'BALL SECURITY & PREPARE FOR FOUL',
    '3': 'BALL SECURITY & PREPARE FOR FOUL',
  },
  '0:10-0:08.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'BALL SECURITY & PREPARE FOR FOUL',
    '2': 'BALL SECURITY & PREPARE FOR FOUL',
    '3': 'BALL SECURITY & PREPARE FOR FOUL',
  },
  '0:08-0:07.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'BALL SECURITY & PREPARE FOR FOUL',
    '2': 'BALL SECURITY & PREPARE FOR FOUL',
    '3': 'BALL SECURITY & PREPARE FOR FOUL',
  },
  '0:07-0:06.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'BALL SECURITY & PREPARE FOR FOUL',
    '2': 'BALL SECURITY & PREPARE FOR FOUL',
    '3': 'BALL SECURITY & PREPARE FOR FOUL',
  },
  '0:06-0:05.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'BALL SECURITY & PREPARE FOR FOUL',
    '2': 'BALL SECURITY & PREPARE FOR FOUL',
    '3': 'BALL SECURITY & PREPARE FOR FOUL',
  },
  '0:05-0:04.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'NEED 2 / BUT PREFER / 3',
    '-1': 'NEED 2',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'BALL SECURITY & PREPARE FOR FOUL',
    '2': 'BALL SECURITY & PREPARE FOR FOUL',
    '3': 'BALL SECURITY & PREPARE FOR FOUL',
  },
  '0:04-0:03.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'LOB OR CATCH AND / SHOOT',
    '-1': 'LOB OR CATCH AND / SHOOT',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'BALL SECURITY & PREPARE FOR FOUL',
    '2': 'BALL SECURITY & PREPARE FOR FOUL',
    '3': 'BALL SECURITY & PREPARE FOR FOUL',
  },
  '0:03-0:02.1': {
    '-4': 'NEED 3 /  / *CRASH 5*',
    '-3': 'NEED 3 /  / *CRASH 5*',
    '-2': 'LOB OR CATCH AND / SHOOT',
    '-1': 'LOB OR CATCH AND / SHOOT',
    '0': 'HOLD BALL FOR LAST / SHOT',
    '1': 'BALL SECURITY & PREPARE FOR FOUL',
    '2': 'BALL SECURITY & PREPARE FOR FOUL',
    '3': 'BALL SECURITY & PREPARE FOR FOUL',
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
  '0:00.4-0:00.1': {
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

const Map<String, Map<String, String>> _defenseMatrix = {
  '1:00-0:52.1': {
    '-5': 'DEFEND NORMALLY',
    '-4': 'DEFEND NORMALLY',
    '-3': 'DEFEND NORMALLY',
    '-2': 'DEFEND NORMALLY',
    '-1': 'DEFEND NORMALLY',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'DEFEND NORMALLY',
    '4+': 'DEFEND NORMALLY',
  },
  '0:52-0:40.1': {
    '-5': '1 TRAP, THEN FOUL',
    '-4': 'DEFEND NORMALLY',
    '-3': 'DEFEND NORMALLY',
    '-2': 'DEFEND NORMALLY',
    '-1': 'DEFEND NORMALLY',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'DEFEND NORMALLY',
    '4+': 'DEFEND NORMALLY',
  },
  '0:40-0:35.1': {
    '-5': '1 TRAP, THEN FOUL',
    '-4': 'DEFEND NORMALLY',
    '-3': 'DEFEND NORMALLY',
    '-2': 'DEFEND NORMALLY',
    '-1': 'DEFEND NORMALLY',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'DEFEND NORMALLY',
    '4+': 'DEFEND NORMALLY',
  },
  '0:35-0:30.1': {
    '-5': '1 TRAP, THEN FOUL',
    '-4': '1 TRAP, THEN FOUL',
    '-3': 'DEFEND NORMALLY',
    '-2': 'DEFEND NORMALLY',
    '-1': 'DEFEND NORMALLY',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'NO 3 / DEFENSE',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:30-0:28.1': {
    '-5': 'FOUL',
    '-4': '1 TRAP, THEN FOUL',
    '-3': '1 TRAP, THEN FOUL',
    '-2': '1 TRAP, THEN FOUL',
    '-1': '1 TRAP, THEN FOUL',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'NO 3 / DEFENSE',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:28-0:26.1': {
    '-5': 'FOUL',
    '-4': '1 TRAP, THEN FOUL',
    '-3': '1 TRAP, THEN FOUL',
    '-2': '1 TRAP, THEN FOUL',
    '-1': '1 TRAP, THEN FOUL',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'NO 3 / DEFENSE',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:26-0:24.1': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': '1 TRAP, THEN FOUL',
    '-2': '1 TRAP, THEN FOUL',
    '-1': '1 TRAP, THEN FOUL',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'NO 3 / DEFENSE',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:24-0:20.1': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': '1 TRAP, THEN FOUL',
    '-2': '1 TRAP, THEN FOUL',
    '-1': '1 TRAP, THEN FOUL',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'NO 3 / DEFENSE',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:20-0:15.1': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': '1 TRAP, THEN FOUL',
    '-2': '1 TRAP, THEN FOUL',
    '-1': '1 TRAP, THEN FOUL',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'NO 3 / DEFENSE',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:15-0:10.1': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': 'FOUL',
    '-2': 'FOUL',
    '-1': 'FOUL',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'NO 3 / DEFENSE',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:10-0:08.1': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': 'FOUL',
    '-2': 'FOUL',
    '-1': 'FOUL',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'FOUL',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:08-0:07.1': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': 'FOUL',
    '-2': 'FOUL',
    '-1': 'FOUL',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'FOUL',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:07-0:06.1': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': 'FOUL',
    '-2': 'FOUL',
    '-1': 'FOUL',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'FOUL',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:06-0:05.1': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': 'FOUL',
    '-2': 'FOUL',
    '-1': 'FOUL',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'FOUL',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:05-0:04.1': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': 'FOUL',
    '-2': 'FOUL',
    '-1': 'FOUL',
    '0': 'DEFEND NORMALLY',
    '1': 'DEFEND NORMALLY',
    '2': 'DEFEND NORMALLY',
    '3': 'FOUL',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:04-0:03.1': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': 'FOUL',
    '-2': 'FOUL',
    '-1': 'FOUL',
    '0': 'NO CATCH & SHOOT',
    '1': 'NO CATCH & SHOOT',
    '2': 'NO CATCH & SHOOT',
    '3': 'FOUL',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:03-0:02.1': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': 'FOUL',
    '-2': 'FOUL',
    '-1': 'FOUL',
    '0': 'NO CATCH & SHOOT',
    '1': 'NO CATCH & SHOOT',
    '2': 'NO CATCH & SHOOT',
    '3': 'NO 3 / DEFENSE',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:02-0:01.1': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': 'FOUL',
    '-2': 'FOUL',
    '-1': 'FOUL',
    '0': 'NO CATCH & SHOOT',
    '1': 'NO CATCH & SHOOT',
    '2': 'NO CATCH & SHOOT',
    '3': 'NO 3 / DEFENSE',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:01-0:00.5': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': 'FOUL',
    '-2': 'FOUL',
    '-1': 'FOUL',
    '0': 'NO FOULS. / ZONE THE RIM',
    '1': 'NO FOULS. / ZONE THE RIM',
    '2': 'NO FOULS. / ZONE THE RIM',
    '3': 'NO 3 / DEFENSE',
    '4+': 'NO 3 / DEFENSE',
  },
  '0:00.4-0:00.1': {
    '-5': 'FOUL',
    '-4': 'FOUL',
    '-3': 'FOUL',
    '-2': 'FOUL',
    '-1': 'FOUL',
    '0': 'NO FOULS. / ZONE THE RIM',
    '1': 'NO FOULS. / ZONE THE RIM',
    '2': 'NO FOULS. / ZONE THE RIM',
    '3': 'NO FOULS',
    '4+': 'NO FOULS',
  },
};

SmartStrategyRecommendation evaluateSmartStrategy({
  required Scenario scenario,
  required Competition competition,
  required String homeTeamName,
  required String guestTeamName,
  required TeamSide vantageSide,
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
        teamLabel: _teamLabelForSide(vantageSide, homeTeamName, guestTeamName),
        scoreDiff: _scoreDiffFromVantage(scenario, vantageSide),
        homeTeamName: homeTeamName,
        guestTeamName: guestTeamName,
      ),
    );
  }

  if (!(scenario.period == Period.p4 || scenario.period == Period.ot)) {
    return SmartStrategyRecommendation(
      status: 'inactive',
      perspectiveLabel:
          '${_teamLabelForSide(vantageSide, homeTeamName, guestTeamName)} perspective',
      headline: 'Smart Strategy inactive',
      summary: 'The late-game rules only apply in Q4 and overtime.',
      stateLine: _stateLine(
        scenario: scenario,
        teamLabel: _teamLabelForSide(vantageSide, homeTeamName, guestTeamName),
        scoreDiff: _scoreDiffFromVantage(scenario, vantageSide),
        homeTeamName: homeTeamName,
        guestTeamName: guestTeamName,
      ),
    );
  }

  final referenceSecondsRemaining = _referenceSecondsRemaining(
    scenario: scenario,
    competition: competition,
  );
  final scoreDiff = _scoreDiffFromVantage(scenario, vantageSide);
  final teamLabel = _teamLabelForSide(vantageSide, homeTeamName, guestTeamName);
  final isOurPossession = scenario.possession == vantageSide;
  final ourTimeouts = vantageSide == TeamSide.home
      ? scenario.homeTimeouts
      : scenario.guestTimeouts;
  final opponentTimeouts = vantageSide == TeamSide.home
      ? scenario.guestTimeouts
      : scenario.homeTimeouts;
  final ourFouls =
      vantageSide == TeamSide.home ? scenario.homeFouls : scenario.guestFouls;
  final foulsToGive = (4 - ourFouls).clamp(0, 4);

  if (referenceSecondsRemaining > 360) {
    return SmartStrategyRecommendation(
      status: 'inactive',
      perspectiveLabel: '$teamLabel perspective',
      headline: 'Smart Strategy inactive',
      summary: 'The workbook-based late-game rules begin in the final 6:00.',
      stateLine: _stateLine(
        scenario: scenario,
        teamLabel: teamLabel,
        scoreDiff: scoreDiff,
        homeTeamName: homeTeamName,
        guestTeamName: guestTeamName,
      ),
    );
  }

  if (scenario.startType == StartType.jumpBall) {
    final winBranch = _instructionForState(
      scoreDiff: scoreDiff,
      secondsRemaining: referenceSecondsRemaining,
      isOurPossession: true,
      ourTimeouts: ourTimeouts,
      opponentTimeouts: opponentTimeouts,
      foulsToGive: foulsToGive,
    );
    final loseBranch = _instructionForState(
      scoreDiff: scoreDiff,
      secondsRemaining: referenceSecondsRemaining,
      isOurPossession: false,
      ourTimeouts: ourTimeouts,
      opponentTimeouts: opponentTimeouts,
      foulsToGive: foulsToGive,
    );
    return SmartStrategyRecommendation(
      status: 'ready',
      perspectiveLabel: '$teamLabel perspective',
      headline: 'Jump ball branches',
      summary:
          'Handle both outcomes of the jump: one plan if we win possession, one if we defend.',
      stateLine: _stateLine(
        scenario: scenario,
        teamLabel: teamLabel,
        scoreDiff: scoreDiff,
        homeTeamName: homeTeamName,
        guestTeamName: guestTeamName,
      ),
      rationale:
          'Jump ball possession is undecided, so both possession outcomes are mapped.',
      notes: <String>[
        'If we win jump ball: ${winBranch.$1} — ${winBranch.$2}',
        'If we lose jump ball: ${loseBranch.$1} — ${loseBranch.$2}',
      ],
    );
  }

  final playMode = _buildPlayMode(scoreDiff, referenceSecondsRemaining);
  if (referenceSecondsRemaining > 60) {
    if (playMode == null) {
      return _normalFallbackRecommendation(
        scenario: scenario,
        teamLabel: teamLabel,
        scoreDiff: scoreDiff,
        homeTeamName: homeTeamName,
        guestTeamName: guestTeamName,
        isOurPossession: isOurPossession,
      );
    }
    return SmartStrategyRecommendation(
      status: 'play-mode',
      perspectiveLabel: '$teamLabel perspective',
      headline: playMode.mode,
      summary: playMode.instruction,
      stateLine: _stateLine(
        scenario: scenario,
        teamLabel: teamLabel,
        scoreDiff: scoreDiff,
        homeTeamName: homeTeamName,
        guestTeamName: guestTeamName,
      ),
      rationale:
          'Play Mode is driven by the final 6:00 table from the workbook.',
      notes: const <String>[],
    );
  }

  if (scenario.startType == StartType.ftLine) {
    final shooterSide = scenario.possession;
    final branchNotes = <String>[];
    for (final made in <int>[2, 1, 0]) {
      final adjustedScoreDiff =
          scoreDiff + (vantageSide == shooterSide ? made : -made);
      final afterFtPossessionIsOurs = shooterSide != vantageSide;
      final branch = _instructionForState(
        scoreDiff: adjustedScoreDiff,
        secondsRemaining: referenceSecondsRemaining,
        isOurPossession: afterFtPossessionIsOurs,
        ourTimeouts: ourTimeouts,
        opponentTimeouts: opponentTimeouts,
        foulsToGive: foulsToGive,
      );
      final marginLabel =
          adjustedScoreDiff > 0 ? '+$adjustedScoreDiff' : '$adjustedScoreDiff';
      branchNotes.add(
        'If FT shooter makes $made: margin $marginLabel, then ${afterFtPossessionIsOurs ? "our ball" : "their ball"} -> ${branch.$1} — ${branch.$2}',
      );
    }
    return SmartStrategyRecommendation(
      status: 'ready',
      perspectiveLabel: '$teamLabel perspective',
      headline: 'After FT',
      summary: '',
      stateLine: _stateLine(
        scenario: scenario,
        teamLabel: teamLabel,
        scoreDiff: scoreDiff,
        homeTeamName: homeTeamName,
        guestTeamName: guestTeamName,
      ),
      rationale:
          'FT-line starts are branch states, so strategy is mapped for makes 2, makes 1, and makes 0.',
      notes: branchNotes,
    );
  }

  final band = _workbookTimeBand(referenceSecondsRemaining);
  final bucket = isOurPossession
      ? _offenseScoreBucket(scoreDiff)
      : _defenseScoreBucket(scoreDiff);
  final bandMatrix =
      isOurPossession ? _offenseMatrix[band] : _defenseMatrix[band];
  final rawInstruction = bandMatrix == null ? null : bandMatrix[bucket];
  if (rawInstruction == null) {
    return _normalFallbackRecommendation(
      scenario: scenario,
      teamLabel: teamLabel,
      scoreDiff: scoreDiff,
      homeTeamName: homeTeamName,
      guestTeamName: guestTeamName,
      isOurPossession: isOurPossession,
    );
  }

  final mapped = _mapInstruction(
    rawInstruction,
    ourTimeouts: ourTimeouts,
    opponentTimeouts: opponentTimeouts,
    foulsToGive: foulsToGive,
  );

  return SmartStrategyRecommendation(
    status: 'ready',
    perspectiveLabel: '$teamLabel perspective',
    headline: mapped.$1,
    summary: mapped.$2,
    stateLine: _stateLine(
      scenario: scenario,
      teamLabel: teamLabel,
      scoreDiff: scoreDiff,
      homeTeamName: homeTeamName,
      guestTeamName: guestTeamName,
    ),
    rationale: isOurPossession
        ? 'Direct workbook lookup from the late-game offense matrix.'
        : 'Direct workbook lookup from the late-game defense matrix.',
    notes: mapped.$3,
  );
}

SmartStrategyRecommendation _normalFallbackRecommendation({
  required Scenario scenario,
  required String teamLabel,
  required int scoreDiff,
  required String homeTeamName,
  required String guestTeamName,
  required bool isOurPossession,
}) {
  return SmartStrategyRecommendation(
    status: 'fallback',
    perspectiveLabel: '$teamLabel perspective',
    headline: isOurPossession ? 'Normal Offense' : 'Normal Defense',
    summary: '',
    stateLine: _stateLine(
      scenario: scenario,
      teamLabel: teamLabel,
      scoreDiff: scoreDiff,
      homeTeamName: homeTeamName,
      guestTeamName: guestTeamName,
    ),
  );
}

(String, String, List<String>) _instructionForState({
  required int scoreDiff,
  required double secondsRemaining,
  required bool isOurPossession,
  required int ourTimeouts,
  required int opponentTimeouts,
  required int foulsToGive,
}) {
  if (secondsRemaining > 60) {
    final playMode = _buildPlayMode(scoreDiff, secondsRemaining);
    if (playMode != null) {
      return (playMode.mode, playMode.instruction, const []);
    }
    return (
      isOurPossession ? 'Normal offense' : 'Normal defense',
      isOurPossession
          ? 'Run normal late-game offense.'
          : 'Stay home and finish the possession.',
      const [],
    );
  }

  final band = _workbookTimeBand(secondsRemaining);
  final bucket = isOurPossession
      ? _offenseScoreBucket(scoreDiff)
      : _defenseScoreBucket(scoreDiff);
  final bandMatrix =
      isOurPossession ? _offenseMatrix[band] : _defenseMatrix[band];
  final rawInstruction = bandMatrix == null ? null : bandMatrix[bucket];
  if (rawInstruction == null) {
    return (
      'No mapped call',
      'No workbook instruction matched this state.',
      const []
    );
  }
  return _mapInstruction(
    rawInstruction,
    ourTimeouts: ourTimeouts,
    opponentTimeouts: opponentTimeouts,
    foulsToGive: foulsToGive,
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
  if (secondsRemaining > 1) return '0:02-0:01.1';
  if (secondsRemaining > 0.4) return '0:01-0:00.5';
  return '0:00.4-0:00.1';
}

double _referenceSecondsRemaining({
  required Scenario scenario,
  required Competition competition,
}) {
  final rules = rulesForCompetition(competition);
  final shotClockSeconds = scenario.shotClockSeconds;
  if (scenario.hideShotClock || scenario.shotClockBlank) {
    return scenario.gameClockTenths / 10.0;
  }
  if (shotClockSeconds <= 0 || shotClockSeconds >= rules.shotClockMax) {
    return scenario.gameClockTenths / 10.0;
  }
  return (scenario.gameClockTenths / 10.0) + shotClockSeconds;
}

String _offenseScoreBucket(int scoreDiff) {
  if (scoreDiff <= -4) return '-4';
  if (scoreDiff >= 3) return '3';
  return '$scoreDiff';
}

String _defenseScoreBucket(int scoreDiff) {
  if (scoreDiff <= -5) return '-5';
  if (scoreDiff >= 4) return '4+';
  return '$scoreDiff';
}

int _scoreDiffFromVantage(Scenario scenario, TeamSide vantageSide) {
  if (vantageSide == TeamSide.home) {
    return scenario.homeScore - scenario.guestScore;
  }
  return scenario.guestScore - scenario.homeScore;
}

String _teamLabelForSide(
  TeamSide side,
  String homeTeamName,
  String guestTeamName,
) {
  return side == TeamSide.home ? homeTeamName : guestTeamName;
}

String _stateLine({
  required Scenario scenario,
  required String teamLabel,
  required int scoreDiff,
  required String homeTeamName,
  required String guestTeamName,
}) {
  final margin = scoreDiff > 0 ? '+$scoreDiff' : '$scoreDiff';
  final clock = formatGameClockTenths(scenario.gameClockTenths);
  final period = periodLabel(scenario.period);
  final periodText = scenario.period == Period.ot ? 'OT' : 'Q$period';
  final possessionLabel = scenario.possession == TeamSide.home
      ? '$homeTeamName ball'
      : '$guestTeamName ball';
  return '$teamLabel perspective · $periodText $clock · margin $margin · $possessionLabel';
}

(String, String, List<String>) _mapInstruction(
  String rawInstruction, {
  required int ourTimeouts,
  required int opponentTimeouts,
  required int foulsToGive,
}) {
  final normalized = rawInstruction.replaceAll('\n', ' ').trim();
  switch (normalized) {
    case 'NORMAL OFFENSE':
      return ('Normal offense', 'Run normal late-game offense.', const []);
    case 'DEFEND NORMALLY':
      return (
        'Defend normally',
        'Stay home and finish the possession.',
        const []
      );
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
    case 'BALL SECURITY & PREPARE FOR FOUL':
      return (
        'Ball security',
        'Protect the ball and prepare for the foul game.',
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
    case '1 TRAP, THEN FOUL':
      return (
        '1 trap, then foul',
        'Pressure first, then foul if no turnover.',
        <String>['Fouls to give: $foulsToGive.'],
      );
    case 'FOUL':
      return (
        'Foul',
        'Stop the clock immediately.',
        <String>['Fouls to give: $foulsToGive.'],
      );
    case 'NO 3 / DEFENSE':
      return ('No 3 defense', 'Take away the arc first.', const []);
    case 'NO CATCH & SHOOT':
      return (
        'No catch & shoot',
        'Take away the clean perimeter catch.',
        const []
      );
    case 'NO FOULS. / ZONE THE RIM':
      return (
        'No fouls, zone the rim',
        'Protect the rim without bailing them out.',
        <String>['Fouls to give: $foulsToGive.'],
      );
    case 'NO FOULS':
      return (
        'No fouls',
        'Finish the possession without sending them to the line.',
        <String>['Fouls to give: $foulsToGive.'],
      );
    default:
      return (normalized, 'Follow the workbook cell literally.', const []);
  }
}
