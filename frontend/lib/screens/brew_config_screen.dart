import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vessels.dart';
import '../models/timer_model.dart';
import '../providers/timer_provider.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Screen for configuring brew parameters before starting a timer.
///
/// Displays:
/// - Ratio calculator with dry weight input and real-time water calculation
/// - Timer name and vessel info
/// - Step preview with timed/indeterminate indicators
/// - Start brew button
class BrewConfigScreen extends ConsumerStatefulWidget {
  /// The timer to configure
  final TimerModel timer;

  /// Optional vessel for additional context
  final Vessel? vessel;

  /// Callback when user starts the brew
  final void Function(CurrentBrew brew)? onStartBrew;

  /// Callback to go back
  final VoidCallback? onBack;

  const BrewConfigScreen({
    super.key,
    required this.timer,
    this.vessel,
    this.onStartBrew,
    this.onBack,
  });

  @override
  ConsumerState<BrewConfigScreen> createState() => _BrewConfigScreenState();
}

class _BrewConfigScreenState extends ConsumerState<BrewConfigScreen> {
  late TextEditingController _dryWeightController;
  late TextEditingController _waterWeightController;
  late TextEditingController _ratioController;

  double? _dryWeight;
  double? _waterWeight;
  double? _ratio;
  bool _useCustomWater = false;

  @override
  void initState() {
    super.initState();
    _ratio = widget.timer.ratio;
    _dryWeightController = TextEditingController();
    _waterWeightController = TextEditingController();
    _ratioController = TextEditingController(
      text: _ratio?.toStringAsFixed(_ratio == _ratio?.truncateToDouble() ? 0 : 1),
    );
  }

  @override
  void dispose() {
    _dryWeightController.dispose();
    _waterWeightController.dispose();
    _ratioController.dispose();
    super.dispose();
  }

  void _onDryWeightChanged(String value) {
    setState(() {
      _dryWeight = double.tryParse(value);
      if (!_useCustomWater) {
        _updateCalculatedWater();
      }
    });
  }

  void _onWaterWeightChanged(String value) {
    setState(() {
      _waterWeight = double.tryParse(value);
      _useCustomWater = true;
    });
  }

  void _onRatioChanged(String value) {
    setState(() {
      _ratio = double.tryParse(value);
      if (!_useCustomWater) {
        _updateCalculatedWater();
      }
    });
  }

  void _updateCalculatedWater() {
    if (_dryWeight != null && _ratio != null) {
      _waterWeight = _dryWeight! * _ratio!;
      _waterWeightController.text = _waterWeight!.toStringAsFixed(0);
    }
  }

  void _resetToCalculated() {
    setState(() {
      _useCustomWater = false;
      _updateCalculatedWater();
    });
  }

  void _onStartBrew() {
    final notifier = ref.read(currentBrewProvider.notifier);
    notifier.setTimer(widget.timer);
    if (_dryWeight != null) {
      notifier.setDryWeight(_dryWeight!);
    }
    if (_waterWeight != null) {
      notifier.setWaterWeight(_waterWeight!);
    }

    final brew = ref.read(currentBrewProvider);
    widget.onStartBrew?.call(brew);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? BrewColors.fogDark : BrewColors.fogLight;
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;
    final cardColor = isDark ? BrewColors.surfaceDark : BrewColors.surfaceLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: widget.onBack != null
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: textColor),
                onPressed: widget.onBack,
              )
            : null,
        title: Text(
          'Configure Brew',
          style: textTheme.titleLarge?.copyWith(color: textColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Timer info header
          _TimerInfoCard(
            timer: widget.timer,
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // Ratio calculator section
          if (widget.timer.ratio != null) ...[
            _SectionHeader(
              title: 'Ratio Calculator',
              subtitle: 'Water (ml) = Dry (g) × Ratio',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _RatioCalculatorCard(
              dryWeightController: _dryWeightController,
              waterWeightController: _waterWeightController,
              ratioController: _ratioController,
              ratio: _ratio,
              dryWeight: _dryWeight,
              waterWeight: _waterWeight,
              useCustomWater: _useCustomWater,
              onDryWeightChanged: _onDryWeightChanged,
              onWaterWeightChanged: _onWaterWeightChanged,
              onRatioChanged: _onRatioChanged,
              onResetToCalculated: _resetToCalculated,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
          ],

          // Steps preview section
          _SectionHeader(
            title: 'Brew Steps',
            subtitle: '${widget.timer.steps.length} steps • ${widget.timer.formattedDuration}',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _StepsPreviewCard(
            steps: widget.timer.steps,
            isDark: isDark,
          ),

          // Bottom padding for button
          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _onStartBrew,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: isDark ? BrewColors.deepEspresso : BrewColors.softCream,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Start Brew',
              style: textTheme.titleMedium?.copyWith(
                color: isDark ? BrewColors.deepEspresso : BrewColors.softCream,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header widget
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(color: textColor),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(color: secondaryColor),
        ),
      ],
    );
  }
}

/// Card showing timer name and basic info
class _TimerInfoCard extends StatelessWidget {
  final TimerModel timer;
  final bool isDark;

  const _TimerInfoCard({
    required this.timer,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final cardColor = isDark ? BrewColors.surfaceDark : BrewColors.surfaceLight;
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? BrewColors.mistDark : BrewColors.mistLight,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                timer.brewType == 'coffee'
                    ? Icons.coffee_outlined
                    : Icons.emoji_food_beverage_outlined,
                color: accentColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timer.name,
                    style: textTheme.titleMedium?.copyWith(color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${timer.vessel} • ${timer.formattedDuration}',
                    style: textTheme.bodySmall?.copyWith(color: secondaryColor),
                  ),
                ],
              ),
            ),
            if (timer.ratio != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${timer.ratio!.toStringAsFixed(timer.ratio! == timer.ratio!.truncateToDouble() ? 0 : 1)}:1',
                  style: textTheme.labelMedium?.copyWith(color: accentColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Card with ratio calculator inputs
class _RatioCalculatorCard extends StatelessWidget {
  final TextEditingController dryWeightController;
  final TextEditingController waterWeightController;
  final TextEditingController ratioController;
  final double? ratio;
  final double? dryWeight;
  final double? waterWeight;
  final bool useCustomWater;
  final ValueChanged<String> onDryWeightChanged;
  final ValueChanged<String> onWaterWeightChanged;
  final ValueChanged<String> onRatioChanged;
  final VoidCallback onResetToCalculated;
  final bool isDark;

  const _RatioCalculatorCard({
    required this.dryWeightController,
    required this.waterWeightController,
    required this.ratioController,
    this.ratio,
    this.dryWeight,
    this.waterWeight,
    required this.useCustomWater,
    required this.onDryWeightChanged,
    required this.onWaterWeightChanged,
    required this.onRatioChanged,
    required this.onResetToCalculated,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final cardColor = isDark ? BrewColors.surfaceDark : BrewColors.surfaceLight;
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? BrewColors.mistDark : BrewColors.mistLight,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dry weight input
            _WeightInputField(
              controller: dryWeightController,
              label: 'Dry Weight',
              unit: 'g',
              hint: 'Enter grams',
              onChanged: onDryWeightChanged,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Ratio row
            Row(
              children: [
                Text(
                  '×',
                  style: textTheme.titleLarge?.copyWith(color: secondaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WeightInputField(
                    controller: ratioController,
                    label: 'Ratio',
                    unit: ':1',
                    hint: 'Ratio',
                    onChanged: onRatioChanged,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Equals divider
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: isDark ? BrewColors.mistDark : BrewColors.mistLight,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '=',
                    style: textTheme.titleLarge?.copyWith(color: secondaryColor),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: isDark ? BrewColors.mistDark : BrewColors.mistLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Water weight (calculated or custom)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _WeightInputField(
                    controller: waterWeightController,
                    label: useCustomWater ? 'Water (Custom)' : 'Water (Calculated)',
                    unit: 'ml',
                    hint: 'Water amount',
                    onChanged: onWaterWeightChanged,
                    isDark: isDark,
                    highlighted: !useCustomWater,
                  ),
                ),
                if (useCustomWater) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onResetToCalculated,
                    child: Text(
                      'Reset',
                      style: textTheme.labelSmall?.copyWith(color: accentColor),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual weight input field
class _WeightInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unit;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool isDark;
  final bool highlighted;

  const _WeightInputField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.hint,
    required this.onChanged,
    required this.isDark,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;
    final fieldColor = isDark ? BrewColors.fogDark : BrewColors.fogLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: highlighted ? accentColor : secondaryColor,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          onChanged: onChanged,
          style: textTheme.titleMedium?.copyWith(
            color: highlighted ? accentColor : textColor,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: textTheme.bodyMedium?.copyWith(color: secondaryColor),
            suffixText: unit,
            suffixStyle: textTheme.bodySmall?.copyWith(color: secondaryColor),
            filled: true,
            fillColor: fieldColor,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? BrewColors.mistDark : BrewColors.mistLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? BrewColors.mistDark : BrewColors.mistLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accentColor),
            ),
          ),
        ),
      ],
    );
  }
}

/// Card showing preview of brew steps
class _StepsPreviewCard extends StatelessWidget {
  final List<TimerStepModel> steps;
  final bool isDark;

  const _StepsPreviewCard({
    required this.steps,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final cardColor = isDark ? BrewColors.surfaceDark : BrewColors.surfaceLight;
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? BrewColors.mistDark : BrewColors.mistLight,
          width: 1,
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: steps.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: isDark ? BrewColors.mistDark : BrewColors.mistLight,
        ),
        itemBuilder: (context, index) {
          final step = steps[index];
          return _StepRow(
            step: step,
            stepNumber: index + 1,
            isDark: isDark,
          );
        },
      ),
    );
  }
}

/// Individual step row in preview
class _StepRow extends StatelessWidget {
  final TimerStepModel step;
  final int stepNumber;
  final bool isDark;

  const _StepRow({
    required this.step,
    required this.stepNumber,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Step number
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber.toString(),
                style: textTheme.labelSmall?.copyWith(color: accentColor),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Step action
          Expanded(
            child: Text(
              step.action,
              style: textTheme.bodyMedium?.copyWith(color: textColor),
            ),
          ),

          // Duration or indicator
          if (step.isTimed)
            Text(
              step.formattedDuration,
              style: textTheme.bodySmall?.copyWith(color: secondaryColor),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Manual',
                style: textTheme.labelSmall?.copyWith(color: secondaryColor),
              ),
            ),
        ],
      ),
    );
  }
}

/// Standalone ratio calculator widget for use in other screens
class RatioCalculator extends StatefulWidget {
  final double? initialRatio;
  final double? initialDryWeight;
  final ValueChanged<double?>? onDryWeightChanged;
  final ValueChanged<double?>? onWaterWeightChanged;
  final ValueChanged<double?>? onRatioChanged;

  const RatioCalculator({
    super.key,
    this.initialRatio,
    this.initialDryWeight,
    this.onDryWeightChanged,
    this.onWaterWeightChanged,
    this.onRatioChanged,
  });

  @override
  State<RatioCalculator> createState() => _RatioCalculatorState();
}

class _RatioCalculatorState extends State<RatioCalculator> {
  late TextEditingController _dryWeightController;
  late TextEditingController _waterWeightController;
  late TextEditingController _ratioController;

  double? _dryWeight;
  double? _waterWeight;
  double? _ratio;
  bool _useCustomWater = false;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
    _dryWeight = widget.initialDryWeight;
    if (_dryWeight != null && _ratio != null) {
      _waterWeight = _dryWeight! * _ratio!;
    }

    _dryWeightController = TextEditingController(
      text: _dryWeight?.toStringAsFixed(1),
    );
    _waterWeightController = TextEditingController(
      text: _waterWeight?.toStringAsFixed(0),
    );
    _ratioController = TextEditingController(
      text: _ratio?.toStringAsFixed(_ratio == _ratio?.truncateToDouble() ? 0 : 1),
    );
  }

  @override
  void dispose() {
    _dryWeightController.dispose();
    _waterWeightController.dispose();
    _ratioController.dispose();
    super.dispose();
  }

  void _onDryWeightChanged(String value) {
    setState(() {
      _dryWeight = double.tryParse(value);
      if (!_useCustomWater) {
        _updateCalculatedWater();
      }
      widget.onDryWeightChanged?.call(_dryWeight);
    });
  }

  void _onWaterWeightChanged(String value) {
    setState(() {
      _waterWeight = double.tryParse(value);
      _useCustomWater = true;
      widget.onWaterWeightChanged?.call(_waterWeight);
    });
  }

  void _onRatioChanged(String value) {
    setState(() {
      _ratio = double.tryParse(value);
      if (!_useCustomWater) {
        _updateCalculatedWater();
      }
      widget.onRatioChanged?.call(_ratio);
    });
  }

  void _updateCalculatedWater() {
    if (_dryWeight != null && _ratio != null) {
      _waterWeight = _dryWeight! * _ratio!;
      _waterWeightController.text = _waterWeight!.toStringAsFixed(0);
      widget.onWaterWeightChanged?.call(_waterWeight);
    }
  }

  void _resetToCalculated() {
    setState(() {
      _useCustomWater = false;
      _updateCalculatedWater();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _RatioCalculatorCard(
      dryWeightController: _dryWeightController,
      waterWeightController: _waterWeightController,
      ratioController: _ratioController,
      ratio: _ratio,
      dryWeight: _dryWeight,
      waterWeight: _waterWeight,
      useCustomWater: _useCustomWater,
      onDryWeightChanged: _onDryWeightChanged,
      onWaterWeightChanged: _onWaterWeightChanged,
      onRatioChanged: _onRatioChanged,
      onResetToCalculated: _resetToCalculated,
      isDark: isDark,
    );
  }
}
