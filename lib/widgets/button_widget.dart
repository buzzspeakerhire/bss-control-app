import 'package:flutter/material.dart';

class ButtonWidget extends StatefulWidget {
  final String text;
  final bool state;
  final String buttonType;
  final ValueChanged<bool> onChanged;

  const ButtonWidget({
    super.key,
    required this.text,
    required this.state,
    required this.buttonType,
    required this.onChanged,
  });

  @override
  State<ButtonWidget> createState() => _ButtonWidgetState();
}

class _ButtonWidgetState extends State<ButtonWidget> {
  late bool _currentState;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _currentState = widget.state;
  }

  @override
  void didUpdateWidget(ButtonWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _currentState = widget.state;
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.buttonType.toLowerCase() == 'momentary') {
      setState(() {
        _isPressed = true;
        _currentState = true;
      });
      widget.onChanged(true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.buttonType.toLowerCase() == 'momentary') {
      setState(() {
        _isPressed = false;
        _currentState = false;
      });
      widget.onChanged(false);
    }
  }

  void _handleTapCancel() {
    if (widget.buttonType.toLowerCase() == 'momentary') {
      setState(() {
        _isPressed = false;
        _currentState = false;
      });
      widget.onChanged(false);
    }
  }

  void _handleTap() {
    if (widget.buttonType.toLowerCase() == 'toggle') {
      final newState = !_currentState;
      setState(() {
        _currentState = newState;
      });
      widget.onChanged(newState);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMomentary = widget.buttonType.toLowerCase() == 'momentary';
    
    // For momentary buttons, we use GestureDetector to track press state
    if (isMomentary) {
      return GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: _buildButtonContent(),
      );
    }
    
    // For toggle buttons, we use InkWell for the tap effect
    return InkWell(
      onTap: _handleTap,
      child: _buildButtonContent(),
    );
  }

  Widget _buildButtonContent() {
    final isActive = _isPressed || _currentState;
    
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.blue : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isActive ? Colors.blue[700]! : Colors.grey,
          width: 2,
        ),
        boxShadow: isActive
            ? []
            : [
                BoxShadow(
                  color: Colors.black26,
                  offset: const Offset(0, 2),
                  blurRadius: 2,
                ),
              ],
      ),
      child: Center(
        child: Text(
          widget.text,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}