import 'package:flutter/material.dart';

class FaderWidget extends StatefulWidget {
  final double min;
  final double max;
  final double value;
  final String orientation;
  final ValueChanged<double> onChanged;

  const FaderWidget({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.orientation,
    required this.onChanged,
  });

  @override
  State<FaderWidget> createState() => _FaderWidgetState();
}

class _FaderWidgetState extends State<FaderWidget> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(FaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVertical = widget.orientation.toLowerCase() == 'vertical';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: isVertical
          ? _buildVerticalFader()
          : _buildHorizontalFader(),
    );
  }

  Widget _buildVerticalFader() {
    return RotatedBox(
      quarterTurns: 3,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 8.0,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
          valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
          showValueIndicator: ShowValueIndicator.always,
        ),
        child: Slider(
          min: widget.min,
          max: widget.max,
          value: _currentValue,
          label: _currentValue.toStringAsFixed(1),
          onChanged: (value) {
            setState(() {
              _currentValue = value;
            });
            widget.onChanged(value);
          },
        ),
      ),
    );
  }

  Widget _buildHorizontalFader() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 8.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        showValueIndicator: ShowValueIndicator.always,
      ),
      child: Slider(
        min: widget.min,
        max: widget.max,
        value: _currentValue,
        label: _currentValue.toStringAsFixed(1),
        onChanged: (value) {
          setState(() {
            _currentValue = value;
          });
          widget.onChanged(value);
        },
      ),
    );
  }
}