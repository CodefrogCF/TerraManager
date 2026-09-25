import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/animal_repository.dart';
import '../../../core/database/repositories/box_repository.dart';
import '../../../core/presentation/widgets/constrained_page_width.dart';
import '../../navigation/presentation/pages/app_shell.dart';
import 'standalone_tutorial_dialog.dart';

class StandaloneTutorialGate extends StatefulWidget {
  const StandaloneTutorialGate({super.key, required this.database});

  final AppDatabase database;

  @override
  State<StandaloneTutorialGate> createState() => _StandaloneTutorialGateState();
}

class _StandaloneTutorialGateState extends State<StandaloneTutorialGate> {
  static const _seenKey = 'standalone_tutorial_seen';
  bool _tutorialOpen = false;
  int _targetPage = 0;
  int _navigationRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  Future<void> _maybeShowTutorial() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_seenKey) == true || !mounted) return;

    // Existing collections must never be interrupted by a first-run dialog.
    final boxes = await BoxRepository(widget.database).getAllBoxes();
    final animals = await AnimalRepository(widget.database).getAllAnimals();
    if (!mounted) return;
    if (boxes.isNotEmpty || animals.isNotEmpty) {
      await preferences.setBool(_seenKey, true);
      return;
    }

    await _openTutorial();
  }

  Future<void> _openTutorial() async {
    if (_tutorialOpen || !mounted) return;
    _tutorialOpen = true;
    try {
      final selectedPage = await showStandaloneTutorial(context);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_seenKey, true);
      if (!mounted || selectedPage == null) return;
      setState(() {
        _targetPage = selectedPage;
        _navigationRequest++;
      });
    } finally {
      _tutorialOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => ConstrainedPageWidth(
    maxWidth: 960,
    child: AppShell(
      database: widget.database,
      initialIndex: _targetPage,
      navigationRequest: _navigationRequest,
      onReplayTutorial: _openTutorial,
    ),
  );
}
