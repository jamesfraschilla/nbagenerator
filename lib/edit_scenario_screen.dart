import 'package:flutter/material.dart';

import 'scenario_generator.dart';

class EditScenarioScreen extends StatefulWidget {
  final Scenario initial;
  final Competition competition;
  const EditScenarioScreen(
      {super.key, required this.initial, required this.competition});

  @override
  State<EditScenarioScreen> createState() => _EditScenarioScreenState();
}

class _EditScenarioScreenState extends State<EditScenarioScreen> {
  final _formKey = GlobalKey<FormState>();

  late final Competition competition;
  late final CompetitionRules rules;

  late int homeScore;
  late int guestScore;
  late int gameClockTenths;
  late int shotClockSeconds;
  late bool shotClockBlank;
  late bool hideShotClock;
  late Period period;
  late TeamSide possession;
  late TeamSide possessionArrow;
  late StartType startType;
  late int homeFouls;
  late int guestFouls;
  late int homeTimeouts;
  late int guestTimeouts;

  @override
  void initState() {
    super.initState();
    competition = widget.competition;
    rules = rulesForCompetition(competition);
    final s = widget.initial;
    homeScore = s.homeScore;
    guestScore = s.guestScore;
    gameClockTenths = s.gameClockTenths;
    shotClockSeconds = s.shotClockSeconds.clamp(0, rules.shotClockMax).toInt();
    shotClockBlank = s.shotClockBlank;
    hideShotClock = s.hideShotClock;
    final allowedPeriods = rules.allowedPeriods;
    period =
        allowedPeriods.contains(s.period) ? s.period : allowedPeriods.first;
    possession = s.possession;
    possessionArrow = s.possessionArrow;
    startType = s.startType;
    homeFouls = s.homeFouls.clamp(rules.foulMin, rules.foulMax).toInt();
    guestFouls = s.guestFouls.clamp(rules.foulMin, rules.foulMax).toInt();
    homeTimeouts =
        s.homeTimeouts.clamp(rules.timeoutMin, rules.timeoutMax).toInt();
    guestTimeouts =
        s.guestTimeouts.clamp(rules.timeoutMin, rules.timeoutMax).toInt();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Scenario')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 640;
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        children: [
                          _adaptivePair(
                            isCompact: isCompact,
                            first: _numField(
                              'Home Score',
                              initial: homeScore,
                              onSaved: (value) => homeScore = value,
                            ),
                            second: _numField(
                              'Guest Score',
                              initial: guestScore,
                              onSaved: (value) => guestScore = value,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _adaptivePair(
                            isCompact: isCompact,
                            first: _clockFieldTenths(
                              label: 'Game Clock',
                              initialTenths: gameClockTenths,
                              onSaved: (value) => gameClockTenths =
                                  value.clamp(0, 1800).toInt(),
                            ),
                            second: _dropdown<int>(
                              label: 'Shot Clock (0-${rules.shotClockMax})',
                              value: shotClockSeconds,
                              items: List<int>.generate(
                                rules.shotClockMax + 1,
                                (i) => i,
                              ),
                              display: (v) => '$v',
                              onChanged: (value) => setState(() {
                                shotClockSeconds = value;
                                hideShotClock = false;
                                shotClockBlank = value <= 0;
                              }),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: hideShotClock,
                                onChanged: (value) => setState(() {
                                  hideShotClock = value ?? false;
                                  if (hideShotClock) {
                                    shotClockBlank = true;
                                  }
                                }),
                              ),
                              const Text('Hide Shot Clock'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _adaptivePair(
                            isCompact: isCompact,
                            first: _dropdown<Period>(
                              label: 'Period',
                              value: period,
                              items: rules.allowedPeriods,
                              display: periodLabel,
                              onChanged: (value) =>
                                  setState(() => period = value),
                            ),
                            second: _dropdown<TeamSide>(
                              label: 'Possession Start',
                              value: possession,
                              items: TeamSide.values,
                              display: (side) =>
                                  side == TeamSide.home ? 'Home' : 'Guest',
                              onChanged: (value) =>
                                  setState(() => possession = value),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _dropdown<StartType>(
                            label: 'Start Type',
                            value: startType,
                            items: StartType.values,
                            display: startTypeLabel,
                            onChanged: (value) =>
                                setState(() => startType = value),
                          ),
                          if (rules.showPossessionArrow) ...[
                            const SizedBox(height: 12),
                            _dropdown<TeamSide>(
                              label: 'Possession Arrow',
                              value: possessionArrow,
                              items: TeamSide.values,
                              display: (side) =>
                                  side == TeamSide.home ? 'Home' : 'Guest',
                              onChanged: (value) =>
                                  setState(() => possessionArrow = value),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _adaptivePair(
                            isCompact: isCompact,
                            first: _dropdown<int>(
                              label:
                                  'Home Fouls (${rules.foulMin}-${rules.foulMax})',
                              value: homeFouls,
                              items: _intRange(rules.foulMin, rules.foulMax),
                              display: (v) => '$v',
                              onChanged: (value) =>
                                  setState(() => homeFouls = value),
                            ),
                            second: _dropdown<int>(
                              label:
                                  'Guest Fouls (${rules.foulMin}-${rules.foulMax})',
                              value: guestFouls,
                              items: _intRange(rules.foulMin, rules.foulMax),
                              display: (v) => '$v',
                              onChanged: (value) =>
                                  setState(() => guestFouls = value),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _adaptivePair(
                            isCompact: isCompact,
                            first: _dropdown<int>(
                              label:
                                  'Home TOL (${rules.timeoutMin}-${rules.timeoutMax})',
                              value: homeTimeouts,
                              items:
                                  _intRange(rules.timeoutMin, rules.timeoutMax),
                              display: (v) => '$v',
                              onChanged: (value) =>
                                  setState(() => homeTimeouts = value),
                            ),
                            second: _dropdown<int>(
                              label:
                                  'Guest TOL (${rules.timeoutMin}-${rules.timeoutMax})',
                              value: guestTimeouts,
                              items:
                                  _intRange(rules.timeoutMin, rules.timeoutMax),
                              display: (v) => '$v',
                              onChanged: (value) =>
                                  setState(() => guestTimeouts = value),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _save,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _adaptivePair({
    required bool isCompact,
    required Widget first,
    required Widget second,
  }) {
    if (isCompact) {
      return Column(
        children: [
          first,
          const SizedBox(height: 12),
          second,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();

    if (homeScore < 0 ||
        homeScore > 150 ||
        guestScore < 0 ||
        guestScore > 150) {
      _show('Scores must be between 0 and 150.');
      return;
    }
    if ((homeScore - guestScore).abs() > 150) {
      _show('Score differential must be 150 or fewer.');
      return;
    }
    if (!hideShotClock && shotClockSeconds > (gameClockTenths ~/ 10)) {
      _show('Shot clock cannot exceed time remaining.');
      return;
    }
    if (!hideShotClock && shotClockSeconds > rules.shotClockMax) {
      _show('Shot clock must be ≤ ${rules.shotClockMax}.');
      return;
    }
    if (homeFouls < rules.foulMin ||
        homeFouls > rules.foulMax ||
        guestFouls < rules.foulMin ||
        guestFouls > rules.foulMax) {
      _show('Fouls must be between ${rules.foulMin} and ${rules.foulMax}.');
      return;
    }
    if (homeTimeouts < rules.timeoutMin ||
        homeTimeouts > rules.timeoutMax ||
        guestTimeouts < rules.timeoutMin ||
        guestTimeouts > rules.timeoutMax) {
      _show(
          'Timeouts must be between ${rules.timeoutMin} and ${rules.timeoutMax}.');
      return;
    }

    final updated = widget.initial.copyWith(
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

    Navigator.of(context).pop(updated);
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _numField(String label,
      {required int initial, required void Function(int value) onSaved}) {
    final controller = TextEditingController(text: initial.toString());
    return TextFormField(
      controller: controller,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Enter a number';
        if (int.tryParse(value) == null) return 'Enter a number';
        return null;
      },
      onSaved: (value) => onSaved(int.parse(value!)),
    );
  }

  Widget _clockFieldTenths({
    required String label,
    required int initialTenths,
    required void Function(int value) onSaved,
  }) {
    final controller = TextEditingController(text: _format(initialTenths));
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'e.g., 1:02 or 8.5',
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Enter clock';
        final parsed = _parseTenths(value);
        if (parsed == null) return 'Use m:ss (≥60s) or s.t (<60s)';
        if (parsed < 0 || parsed > 1800) return 'Keep it within 0–3:00';
        return null;
      },
      onSaved: (value) => onSaved(_parseTenths(value!)!),
    );
  }

  String _format(int tenths) {
    if (tenths >= 600) {
      final seconds = tenths ~/ 10;
      final minutes = seconds ~/ 60;
      final remSeconds = seconds % 60;
      return '$minutes:${remSeconds.toString().padLeft(2, '0')}';
    }
    if (tenths > 0) {
      final seconds = tenths ~/ 10;
      final tenth = tenths % 10;
      return '$seconds.$tenth';
    }
    return '0:00';
  }

  int? _parseTenths(String input) {
    if (input.contains(':')) {
      final parts = input.split(':');
      if (parts.length != 2) return null;
      final minutes = int.tryParse(parts[0]);
      final seconds = int.tryParse(parts[1]);
      if (minutes == null || seconds == null) return null;
      if (seconds < 0 || seconds > 59) return null;
      return (minutes * 60 + seconds) * 10;
    }
    if (input.contains('.')) {
      final parts = input.split('.');
      if (parts.length != 2) return null;
      final seconds = int.tryParse(parts[0]);
      final tenths = int.tryParse(parts[1]);
      if (seconds == null || tenths == null) return null;
      if (tenths < 0 || tenths > 9) return null;
      return seconds * 10 + tenths;
    }
    final seconds = int.tryParse(input);
    if (seconds == null) return null;
    if (seconds >= 60) return null;
    return seconds * 10;
  }

  List<int> _intRange(int min, int max) {
    if (max < min) return [min];
    return List<int>.generate(max - min + 1, (index) => min + index);
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T value) display,
    required ValueChanged<T> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items
              .map((item) =>
                  DropdownMenuItem<T>(value: item, child: Text(display(item))))
              .toList(),
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
      ),
    );
  }
}
