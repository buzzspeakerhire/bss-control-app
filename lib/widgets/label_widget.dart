import 'package:flutter/material.dart';

class LabelWidget extends StatelessWidget {
  final String text;
  final String textAlignment;
  final int fontSize;

  const LabelWidget({
    super.key,
    required this.text,
    required this.textAlignment,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      alignment: _getAlignment(),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize.toDouble(),
          fontWeight: FontWeight.normal,
        ),
        textAlign: _getTextAlign(),
        overflow: TextOverflow.ellipsis,
        maxLines: 3,
      ),
    );
  }

  Alignment _getAlignment() {
    switch (textAlignment.toLowerCase()) {
      case 'left':
      case 'start':
        return Alignment.centerLeft;
      case 'right':
      case 'end':
        return Alignment.centerRight;
      case 'top':
        return Alignment.topCenter;
      case 'bottom':
        return Alignment.bottomCenter;
      case 'center':
      default:
        return Alignment.center;
    }
  }

  TextAlign _getTextAlign() {
    switch (textAlignment.toLowerCase()) {
      case 'left':
      case 'start':
        return TextAlign.left;
      case 'right':
      case 'end':
        return TextAlign.right;
      case 'center':
      default:
        return TextAlign.center;
    }
  }
}