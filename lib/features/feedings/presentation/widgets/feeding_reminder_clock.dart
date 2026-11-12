import 'dart:async';

import 'package:flutter/widgets.dart';

/// Re-evaluates reminder views only at their next relevant time or on resume.
class FeedingReminderClockView extends StatefulWidget {
  const FeedingReminderClockView({
    super.key,
    required this.transitions,
    required this.builder,
    this.now,
  });

  final Iterable<DateTime> transitions;
  final DateTime Function()? now;
  final Widget Function(BuildContext, DateTime) builder;

  @override
  State<FeedingReminderClockView> createState() =>
      _FeedingReminderClockViewState();
}

class _FeedingReminderClockViewState extends State<FeedingReminderClockView> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;
  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: _tick,
      onPause: () => _timer?.cancel(),
    );
    _schedule();
  }

  @override
  void didUpdateWidget(covariant FeedingReminderClockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = _now;
    DateTime? next;
    for (final time in widget.transitions) {
      if (time.isAfter(now) && (next == null || time.isBefore(next))) {
        next = time;
      }
    }
    if (next != null) _timer = Timer(next.difference(now), _tick);
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
