import 'package:flutter/material.dart';

class SelectorWidget extends StatefulWidget {
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const SelectorWidget({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  State<SelectorWidget> createState() => _SelectorWidgetState();
}

class _SelectorWidgetState extends State<SelectorWidget> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(SelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _currentIndex = widget.selectedIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Make sure we have at least one item
    if (widget.items.isEmpty) {
      return const Center(child: Text('No items'));
    }

    // Ensure currentIndex is valid
    final validIndex = _currentIndex.clamp(0, widget.items.length - 1);
    if (_currentIndex != validIndex) {
      _currentIndex = validIndex;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _currentIndex,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          elevation: 16,
          items: List.generate(widget.items.length, (index) {
            return DropdownMenuItem<int>(
              value: index,
              child: Text(
                widget.items[index],
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _currentIndex = value;
              });
              widget.onChanged(value);
            }
          },
        ),
      ),
    );
  }
}