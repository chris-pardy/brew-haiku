import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vessels.dart';
import '../models/timer_model.dart';
import '../providers/auth_provider.dart';
import '../services/timer_create_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Provider for the timer create service
final timerCreateServiceProvider = Provider<TimerCreateService>((ref) {
  return TimerCreateService();
});

/// Screen for creating a new timer recipe
class TimerCreateScreen extends ConsumerStatefulWidget {
  /// Optional vessel to pre-populate
  final Vessel? initialVessel;

  /// Callback when timer is created successfully
  final void Function(TimerModel timer)? onTimerCreated;

  /// Callback to go back
  final VoidCallback? onBack;

  const TimerCreateScreen({
    super.key,
    this.initialVessel,
    this.onTimerCreated,
    this.onBack,
  });

  @override
  ConsumerState<TimerCreateScreen> createState() => _TimerCreateScreenState();
}

class _TimerCreateScreenState extends ConsumerState<TimerCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _vesselController = TextEditingController();
  final _ratioController = TextEditingController();

  String _brewType = 'coffee';
  List<_EditableStep> _steps = [];
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialVessel != null) {
      _vesselController.text = widget.initialVessel!.name;
      _brewType = widget.initialVessel!.category;
      _ratioController.text = widget.initialVessel!.defaultRatio.toString();
    }
    // Add one default step
    _steps.add(_EditableStep());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vesselController.dispose();
    _ratioController.dispose();
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  void _addStep() {
    setState(() {
      _steps.add(_EditableStep());
    });
  }

  void _removeStep(int index) {
    if (_steps.length > 1) {
      setState(() {
        _steps[index].dispose();
        _steps.removeAt(index);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authState = ref.read(authStateProvider);
    final session = authState.session;

    if (session == null) {
      setState(() {
        _error = 'Please sign in to create a timer';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final service = ref.read(timerCreateServiceProvider);

      final steps = _steps.map((s) => TimerStepModel(
            action: s.actionController.text,
            stepType: s.stepType,
            durationSeconds: s.stepType == 'timed'
                ? int.tryParse(s.durationController.text)
                : null,
          )).toList();

      final result = await service.createTimer(
        session: session,
        name: _nameController.text.trim(),
        vessel: _vesselController.text.trim(),
        brewType: _brewType,
        steps: steps,
        ratio: double.tryParse(_ratioController.text),
      );

      // Create a TimerModel to pass back
      final createdTimer = TimerModel(
        uri: result.timerUri,
        did: session.did,
        handle: session.handle,
        name: _nameController.text.trim(),
        vessel: _vesselController.text.trim(),
        brewType: _brewType,
        ratio: double.tryParse(_ratioController.text),
        steps: steps,
        saveCount: 1,
        createdAt: DateTime.now(),
      );

      // Haptic feedback
      HapticFeedback.mediumImpact();

      widget.onTimerCreated?.call(createdTimer);
    } on TimerCreateException catch (e) {
      setState(() {
        _error = e.message;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to create timer';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? BrewColors.fogDark : BrewColors.fogLight;
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final accentColor = isDark ? BrewColors.accentGold : BrewColors.warmBrown;
    final surfaceColor =
        isDark ? BrewColors.surfaceDark : BrewColors.surfaceLight;

    if (!authState.isAuthenticated) {
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
            'Create Timer',
            style: textTheme.titleLarge?.copyWith(color: textColor),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 48, color: secondaryColor),
              const SizedBox(height: 16),
              Text(
                'Sign in to create timers',
                style: TextStyle(color: secondaryColor),
              ),
            ],
          ),
        ),
      );
    }

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
          'Create Timer',
          style: textTheme.titleLarge?.copyWith(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(accentColor),
                    ),
                  )
                : Text(
                    'Publish',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Error message
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Timer name
            _buildTextField(
              controller: _nameController,
              label: 'Timer Name',
              hint: 'e.g., My V60 Recipe',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                if (value.length > 100) {
                  return 'Name must be 100 characters or less';
                }
                return null;
              },
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Vessel
            _buildTextField(
              controller: _vesselController,
              label: 'Vessel',
              hint: 'e.g., Hario V60, Gaiwan',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a vessel';
                }
                return null;
              },
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Brew type and ratio row
            Row(
              children: [
                // Brew type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Brew Type',
                        style: textTheme.labelMedium?.copyWith(
                          color: secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _brewType,
                            isExpanded: true,
                            dropdownColor: surfaceColor,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: secondaryColor,
                            ),
                            items: ['coffee', 'tea'].map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type[0].toUpperCase() + type.substring(1),
                                  style: TextStyle(color: textColor),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _brewType = value!);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Ratio
                Expanded(
                  child: _buildTextField(
                    controller: _ratioController,
                    label: 'Ratio',
                    hint: '16',
                    keyboardType: TextInputType.number,
                    suffixText: ':1',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Steps section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Steps',
                  style: textTheme.titleMedium?.copyWith(color: textColor),
                ),
                TextButton.icon(
                  onPressed: _addStep,
                  icon: Icon(Icons.add, color: accentColor, size: 20),
                  label: Text(
                    'Add Step',
                    style: TextStyle(color: accentColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Step list
            ..._steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return _StepEditor(
                key: ValueKey(step),
                step: step,
                index: index,
                onRemove: _steps.length > 1 ? () => _removeStep(index) : null,
                isDark: isDark,
              );
            }),

            // Bottom padding
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? suffixText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    required bool isDark,
  }) {
    final textTheme = BrewTypography.getTextTheme(isDark: isDark);
    final textColor =
        isDark ? BrewColors.textPrimaryDark : BrewColors.textPrimaryLight;
    final secondaryColor =
        isDark ? BrewColors.textSecondaryDark : BrewColors.textSecondaryLight;
    final surfaceColor =
        isDark ? BrewColors.surfaceDark : BrewColors.surfaceLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(color: secondaryColor),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: secondaryColor.withOpacity(0.5)),
            suffixText: suffixText,
            suffixStyle: TextStyle(color: secondaryColor),
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// Editable step data holder
class _EditableStep {
  final TextEditingController actionController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  String stepType = 'timed';

  void dispose() {
    actionController.dispose();
    durationController.dispose();
  }
}

/// Widget for editing a single step
class _StepEditor extends StatefulWidget {
  final _EditableStep step;
  final int index;
  final VoidCallback? onRemove;
  final bool isDark;

  const _StepEditor({
    super.key,
    required this.step,
    required this.index,
    this.onRemove,
    required this.isDark,
  });

  @override
  State<_StepEditor> createState() => _StepEditorState();
}

class _StepEditorState extends State<_StepEditor> {
  @override
  Widget build(BuildContext context) {
    final textTheme = BrewTypography.getTextTheme(isDark: widget.isDark);
    final textColor = widget.isDark
        ? BrewColors.textPrimaryDark
        : BrewColors.textPrimaryLight;
    final secondaryColor = widget.isDark
        ? BrewColors.textSecondaryDark
        : BrewColors.textSecondaryLight;
    final surfaceColor = widget.isDark
        ? BrewColors.surfaceDark
        : BrewColors.surfaceLight;
    final accentColor =
        widget.isDark ? BrewColors.accentGold : BrewColors.warmBrown;

    return Card(
      color: surfaceColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.isDark ? BrewColors.mistDark : BrewColors.mistLight,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index + 1}',
                      style: textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Step ${widget.index + 1}',
                  style: textTheme.labelMedium?.copyWith(color: secondaryColor),
                ),
                const Spacer(),
                if (widget.onRemove != null)
                  IconButton(
                    icon: Icon(Icons.close, color: secondaryColor, size: 20),
                    onPressed: widget.onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Action input
            TextFormField(
              controller: widget.step.actionController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'e.g., Bloom, Pour, Steep...',
                hintStyle: TextStyle(color: secondaryColor.withOpacity(0.5)),
                filled: true,
                fillColor: widget.isDark
                    ? BrewColors.fogDark
                    : BrewColors.fogLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an action';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Step type and duration row
            Row(
              children: [
                // Step type toggle
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'timed',
                      label: Text('Timed'),
                      icon: Icon(Icons.timer_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 'indeterminate',
                      label: Text('Manual'),
                      icon: Icon(Icons.touch_app_outlined, size: 16),
                    ),
                  ],
                  selected: {widget.step.stepType},
                  onSelectionChanged: (value) {
                    setState(() {
                      widget.step.stepType = value.first;
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return accentColor.withOpacity(0.2);
                      }
                      return Colors.transparent;
                    }),
                  ),
                ),
                const SizedBox(width: 12),

                // Duration input (only for timed steps)
                if (widget.step.stepType == 'timed')
                  Expanded(
                    child: TextFormField(
                      controller: widget.step.durationController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Seconds',
                        hintStyle:
                            TextStyle(color: secondaryColor.withOpacity(0.5)),
                        suffixText: 's',
                        suffixStyle: TextStyle(color: secondaryColor),
                        filled: true,
                        fillColor: widget.isDark
                            ? BrewColors.fogDark
                            : BrewColors.fogLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      validator: (value) {
                        if (widget.step.stepType == 'timed') {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Invalid';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
