import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/recipe.dart';
import '../widgets/app_spacing.dart';

class CookingModeScreen extends StatefulWidget {
  const CookingModeScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  int _stepIndex = 0;
  bool _keepAwake = false;
  Timer? _timerTicker;
  DateTime? _timerDeadline;
  Duration? _timerDuration;
  Duration? _timerRemaining;
  bool _timerRunning = false;

  @override
  void initState() {
    super.initState();
    unawaited(_enableKeepAwake());
  }

  @override
  void dispose() {
    _timerTicker?.cancel();
    if (_keepAwake) unawaited(WakelockPlus.disable());
    super.dispose();
  }

  Future<void> _enableKeepAwake() async {
    try {
      await WakelockPlus.enable();
      if (!mounted) {
        await WakelockPlus.disable();
        return;
      }
      _keepAwake = true;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not keep the screen on: $error')),
      );
    }
  }

  void _nextStep() {
    _clearTimer();
    if (_stepIndex == widget.recipe.steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _stepIndex++);
  }

  void _previousStep() {
    _clearTimer();
    setState(() => _stepIndex--);
  }

  void _startTimer(Duration duration) {
    _timerTicker?.cancel();
    setState(() {
      _timerDuration = duration;
      _timerRemaining = duration;
      _timerRunning = true;
      _timerDeadline = DateTime.now().add(duration);
    });
    _scheduleTimer();
  }

  void _scheduleTimer() {
    _timerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final millisecondsLeft = _timerDeadline!
          .difference(DateTime.now())
          .inMilliseconds;
      if (millisecondsLeft <= 0) {
        _timerTicker?.cancel();
        _timerTicker = null;
        if (!mounted) return;
        setState(() {
          _timerRemaining = Duration.zero;
          _timerRunning = false;
          _timerDeadline = null;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Step timer finished')));
        return;
      }
      if (!mounted) return;
      setState(
        () => _timerRemaining = Duration(
          seconds: (millisecondsLeft / 1000).ceil(),
        ),
      );
    });
  }

  void _pauseTimer() {
    final deadline = _timerDeadline;
    if (deadline == null) return;
    final millisecondsLeft = deadline.difference(DateTime.now()).inMilliseconds;
    _timerTicker?.cancel();
    _timerTicker = null;
    setState(() {
      _timerRemaining = millisecondsLeft <= 0
          ? Duration.zero
          : Duration(seconds: (millisecondsLeft / 1000).ceil());
      _timerRunning = false;
      _timerDeadline = null;
    });
  }

  void _resumeTimer() {
    final remaining = _timerRemaining;
    if (remaining == null || remaining == Duration.zero) return;
    setState(() {
      _timerRunning = true;
      _timerDeadline = DateTime.now().add(remaining);
    });
    _scheduleTimer();
  }

  void _clearTimer() {
    _timerTicker?.cancel();
    _timerTicker = null;
    _timerDeadline = null;
    _timerDuration = null;
    _timerRemaining = null;
    _timerRunning = false;
  }

  Future<void> _setCustomTimer() async {
    final controller = TextEditingController();
    String? errorText;
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set a timer'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Minutes',
              helperText: 'Enter 1 to 1440 minutes',
              errorText: errorText,
            ),
            onSubmitted: (_) {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value >= 1 && value <= 1440) {
                Navigator.of(context).pop(value);
              } else {
                setDialogState(
                  () => errorText = 'Enter a whole number from 1 to 1440',
                );
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value != null && value >= 1 && value <= 1440) {
                  Navigator.of(context).pop(value);
                } else {
                  setDialogState(
                    () => errorText = 'Enter a whole number from 1 to 1440',
                  );
                }
              },
              child: const Text('Start timer'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (!mounted || minutes == null) return;
    _startTimer(Duration(minutes: minutes));
  }

  String _formatTimer(Duration duration) {
    final seconds = duration.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildTimer(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final remaining = _timerRemaining;
    final duration = _timerDuration;
    final isFinished = remaining == Duration.zero;
    final progress = duration == null || duration == Duration.zero
        ? 0.0
        : (remaining?.inMilliseconds ?? 0) / duration.inMilliseconds;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: remaining == null
          ? Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.timer_outlined,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Step timer',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final minutes in [1, 5, 10])
                      _TimerPresetButton(
                        label: '$minutes min',
                        onPressed: () =>
                            _startTimer(Duration(minutes: minutes)),
                      ),
                    _TimerPresetButton(
                      label: 'Custom',
                      onPressed: _setCustomTimer,
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: 62,
                  height: 62,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: isFinished ? 0 : progress,
                          strokeWidth: 5,
                          strokeCap: StrokeCap.round,
                          backgroundColor: colors.surfaceContainerHighest,
                          color: colors.primary,
                        ),
                      ),
                      Icon(
                        isFinished ? Icons.check_rounded : Icons.timer_outlined,
                        color: colors.primary,
                        size: 25,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFinished ? 'Timer finished' : 'Time remaining',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimer(remaining),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          color: isFinished ? colors.primary : colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: isFinished
                      ? 'Start timer again'
                      : _timerRunning
                      ? 'Pause timer'
                      : 'Resume timer',
                  onPressed: isFinished
                      ? () => _startTimer(duration!)
                      : _timerRunning
                      ? _pauseTimer
                      : _resumeTimer,
                  icon: Icon(
                    isFinished
                        ? Icons.replay_rounded
                        : _timerRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Clear timer',
                  onPressed: () => setState(_clearTimer),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final steps = widget.recipe.steps;
    final stepNumber = _stepIndex + 1;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cooking mode'),
            Text(
              widget.recipe.title,
              style: theme.textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageGutter,
            AppSpacing.pageTop,
            AppSpacing.pageGutter,
            AppSpacing.pageGutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Step $stepNumber of ${steps.length}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: stepNumber / steps.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(10),
              ),
              Expanded(
                flex: 6,
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.cardRadius + 12,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'STEP $stepNumber',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colors.primary,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  child: Text(
                                    steps[_stepIndex],
                                    key: ValueKey(_stepIndex),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          color: colors.onPrimaryContainer,
                                          height: 1.25,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildTimer(context),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _stepIndex == 0 ? null : _previousStep,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(60),
                      ),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _nextStep,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(60),
                      ),
                      icon: Icon(
                        _stepIndex == steps.length - 1
                            ? Icons.check
                            : Icons.arrow_forward,
                      ),
                      label: Text(
                        _stepIndex == steps.length - 1 ? 'Done' : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerPresetButton extends StatelessWidget {
  const _TimerPresetButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    ),
    child: Text(label),
  );
}
