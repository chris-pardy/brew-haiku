import 'package:flutter/material.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class QuantityInput extends StatefulWidget {
  final String label;
  final String? unit;
  final double? initialValue;
  final ValueChanged<double> onChanged;

  const QuantityInput({
    super.key,
    required this.label,
    this.unit,
    this.initialValue,
    required this.onChanged,
  });

  @override
  State<QuantityInput> createState() => _QuantityInputState();
}

class _QuantityInputState extends State<QuantityInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(widget.label, style: BrewTypography.body),
        ),
        SizedBox(
          width: 100,
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: BrewTypography.body,
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null) widget.onChanged(parsed);
            },
            decoration: InputDecoration(
              suffixText: widget.unit,
              suffixStyle: BrewTypography.labelSmall,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: BrewSpacing.sm,
                vertical: BrewSpacing.sm,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
