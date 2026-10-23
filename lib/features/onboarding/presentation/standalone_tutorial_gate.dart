import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/animal_repository.dart';
import '../../../core/database/repositories/box_repository.dart';
import '../../../core/presentation/widgets/constrained_page_width.dart';
import '../../navigation/presentation/pages/app_shell.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../release_highlights/application/release_highlights_controller.dart';
import '../../release_highlights/presentation/release_highlights_dialog.dart';
import 'standalone_tutorial_dialog.dart';

class StandaloneTutorialGate extends StatefulWidget {
  const StandaloneTutorialGate({
    super.key,
    required this.database,
    this.dataRevision = 0,
    this.releaseHighlightsController,
  });

  final AppDatabase database;
  final int dataRevision;
  final ReleaseHighlightsController? releaseHighlightsController;

  @override
  State<StandaloneTutorialGate> createState() => _StandaloneTutorialGateState();
}

class _StandaloneTutorialGateState extends State<StandaloneTutorialGate> {
  static const _seenKey = 'standalone_tutorial_seen';
  bool _tutorialOpen = false;
  bool _highlightsOpen = false;
  bool _highlightsScheduled = false;
  InstalledRelease? _pendingRelease;
  late final ReleaseHighlightsController _releaseHighlights;

  bool get _supportsHighlights =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _releaseHighlights =
        widget.releaseHighlightsController ?? ReleaseHighlightsController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  Future<void> _maybeShowTutorial() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    var existingInstallation = preferences.getBool(_seenKey) == true;

    if (!existingInstallation) {
      // Existing collections must never be interrupted by a first-run dialog.
      final boxes = await BoxRepository(widget.database).getAllBoxes();
      final animals = await AnimalRepository(widget.database).getAllAnimals();
      if (!mounted) return;
      existingInstallation = boxes.isNotEmpty || animals.isNotEmpty;
      if (existingInstallation) {
        await preferences.setBool(_seenKey, true);
      } else {
        await _openTutorial();
      }
    }

    if (!_supportsHighlights || !mounted) return;
    try {
      final release = await _releaseHighlights.pendingForStartup(
        existingInstallation: existingInstallation,
      );
      if (mounted && release != null) setState(() => _pendingRelease = release);
    } catch (_) {
      // Optional release information must never prevent normal app startup.
    }
  }

  Future<void> _openTutorial() async {
    if (_tutorialOpen || !mounted) return;
    _tutorialOpen = true;
    try {
      await showStandaloneTutorial(context);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_seenKey, true);
    } finally {
      _tutorialOpen = false;
      if (mounted && _pendingRelease != null) setState(() {});
    }
  }

  bool get _homeIsCurrent => ModalRoute.of(context)?.isCurrent ?? false;

  void _scheduleHighlights() {
    if (_pendingRelease == null ||
        _tutorialOpen ||
        _highlightsOpen ||
        _highlightsScheduled ||
        !_homeIsCurrent) {
      return;
    }
    _highlightsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _highlightsScheduled = false;
      if (mounted) _openHighlights(automatic: true);
    });
  }

  Future<void> _openHighlights({bool automatic = false}) async {
    if (_tutorialOpen || _highlightsOpen || !mounted || !_supportsHighlights) {
      return;
    }
    _highlightsOpen = true;
    try {
      final release = automatic
          ? _pendingRelease
          : await _releaseHighlights.currentRelease();
      if (release == null || !mounted || !_homeIsCurrent) return;
      await _releaseHighlights.markShown(release);
      if (!mounted || !_homeIsCurrent) return;
      setState(() => _pendingRelease = null);
      await showReleaseHighlights(context, release: release);
    } catch (_) {
      if (mounted) {
        setState(() => _pendingRelease = null);
        if (!automatic) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.releaseHighlightsUnavailable)),
          );
        }
      }
    } finally {
      _highlightsOpen = false;
      if (mounted && _pendingRelease != null) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleHighlights();
    return ConstrainedPageWidth(
      maxWidth: 960,
      child: AppShell(
        database: widget.database,
        dataRevision: widget.dataRevision,
        onReplayTutorial: _openTutorial,
        onShowReleaseHighlights: _supportsHighlights ? _openHighlights : null,
      ),
    );
  }
}
