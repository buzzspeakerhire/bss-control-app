import 'package:flutter/material.dart';

class MeterWidget extends StatefulWidget {
  final double min;
  final double max;
  final double value;
  final String orientation;
  final int segments;

  const MeterWidget({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.orientation,
    required this.segments,
  });

  @override
  State<MeterWidget> createState() => _MeterWidgetState();
}

class _MeterWidgetState extends State<MeterWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _updateAnimation();
    _controller.forward();
  }

  @override
  void didUpdateWidget(MeterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.min != widget.min ||
        oldWidget.max != widget.max) {
      _updateAnimation();
      _controller.forward(from: 0.0);
    }
  }

  void _updateAnimation() {
    // Normalize the value to 0.0-1.0 range
    final normalizedValue = (widget.value - widget.min) / (widget.max - widget.min);
    final clampedValue = normalizedValue.clamp(0.0, 1.0);
    
    _animation = Tween<double>(
      begin: 0.0,
      end: clampedValue,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVertical = widget.orientation.toLowerCase() == 'vertical';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(2),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return isVertical
              ? _buildVerticalMeter(_animation.value)
              : _buildHorizontalMeter(_animation.value);
        },
      ),
    );
  }

  Widget _buildVerticalMeter(double value) {
    return Column(
      children: List.generate(widget.segments, (index) {
        // Calculate if this segment should be lit
        final segmentValue = 1.0 - (index / (widget.segments - 1));
        final isLit = value >= segmentValue;
        
        // Determine segment color based on its position
        Color segmentColor;
        if (segmentValue > 0.8) {
          segmentColor = Colors.red;
        } else if (segmentValue > 0.6) {
          segmentColor = Colors.orange;
        } else if (segmentValue > 0.4) {
          segmentColor = Colors.yellow;
        } else {
          segmentColor = Colors.green;
        }
        
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              color: isLit ? segmentColor : Colors.grey[800],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }).reversed.toList(),
    );
  }

  Widget _buildHorizontalMeter(double value) {
    return Row(
      children: List.generate(widget.segments, (index) {
        // Calculate if this segment should be lit
        final segmentValue = index / (widget.segments - 1);
        final isLit = value >= segmentValue;
        
        // Determine segment color based on its position
        Color segmentColor;
        if (segmentValue > 0.8) {
          segmentColor = Colors.red;
        } else if (segmentValue > 0.6) {
          segmentColor = Colors.orange;
        } else if (segmentValue > 0.4) {
          segmentColor = Colors.yellow;
        } else {
          segmentColor = Colors.green;
        }
        
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: isLit ? segmentColor : Colors.grey[800],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}