import 'dart:io';
import 'package:xml/xml.dart';
import '../models/panel_model.dart';
import '../models/control_model.dart';
import '../models/state_variable_model.dart';

class PanelParser {
  /// Parse a panel file and return a Panel object
  Future<Panel> parseFromFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      return parseFromString(content);
    } catch (e) {
      throw Exception('Failed to parse panel file: $e');
    }
  }

  /// Parse panel XML from a string
  Panel parseFromString(String xmlString) {
    try {
      final document = XmlDocument.parse(xmlString);
      final panelNode = document.findAllElements('PANEL').first;
      
      // Parse panel properties
      final panel = _parsePanelProperties(panelNode);
      
      // Parse state variables
      panel.stateVariables = _parseStateVariables(panelNode);
      
      // Parse controls
      panel.controls = _parseControls(panelNode, panel.stateVariables);
      
      return panel;
    } catch (e) {
      throw Exception('Failed to parse panel XML: $e');
    }
  }

  /// Parse panel basic properties
  Panel _parsePanelProperties(XmlElement panelNode) {
    final panel = Panel(
      id: panelNode.getAttribute('id') ?? '',
      name: panelNode.getAttribute('name') ?? 'Unnamed Panel',
      width: int.tryParse(panelNode.getAttribute('width') ?? '0') ?? 0,
      height: int.tryParse(panelNode.getAttribute('height') ?? '0') ?? 0,
      backgroundColor: _parseColor(panelNode.getAttribute('backcolor')),
      foregroundColor: _parseColor(panelNode.getAttribute('forecolor')),
      stateVariables: [],
      controls: [],
    );
    
    return panel;
  }

  /// Parse all state variables from the panel
  List<StateVariable> _parseStateVariables(XmlElement panelNode) {
    final stateVariables = <StateVariable>[];
    
    final stateVarNodes = panelNode.findAllElements('STATEVARIABLE');
    for (final node in stateVarNodes) {
      stateVariables.add(_parseStateVariable(node));
    }
    
    return stateVariables;
  }

  /// Parse a single state variable
  StateVariable _parseStateVariable(XmlElement node) {
    final id = node.getAttribute('id') ?? '';
    final name = node.getAttribute('name') ?? '';
    final type = node.getAttribute('type') ?? '';
    final deviceIndex = int.tryParse(node.getAttribute('deviceidx') ?? '-1') ?? -1;
    final objectIndex = int.tryParse(node.getAttribute('objectidx') ?? '-1') ?? -1;
    final channel = int.tryParse(node.getAttribute('channel') ?? '-1') ?? -1;
    
    return StateVariable(
      id: id,
      name: name,
      type: type,
      deviceIndex: deviceIndex,
      objectIndex: objectIndex,
      channel: channel,
    );
  }

  /// Parse all controls from the panel
  List<Control> _parseControls(XmlElement panelNode, List<StateVariable> stateVariables) {
    final controls = <Control>[];
    
    // Parse different control types
    _parseControlType(panelNode, 'FADER', controls, stateVariables);
    _parseControlType(panelNode, 'METER', controls, stateVariables);
    _parseControlType(panelNode, 'BUTTON', controls, stateVariables);
    _parseControlType(panelNode, 'LABEL', controls, stateVariables);
    _parseControlType(panelNode, 'COMBO', controls, stateVariables);
    // Add more control types as needed
    
    return controls;
  }

  /// Parse controls of a specific type
  void _parseControlType(XmlElement panelNode, String controlType, 
      List<Control> controls, List<StateVariable> stateVariables) {
    
    final controlNodes = panelNode.findAllElements(controlType);
    for (final node in controlNodes) {
      final control = _parseControl(node, controlType, stateVariables);
      controls.add(control);
    }
  }

  /// Parse a single control
  Control _parseControl(XmlElement node, String controlType, List<StateVariable> stateVariables) {
    final id = node.getAttribute('id') ?? '';
    final name = node.getAttribute('name') ?? '';
    final x = int.tryParse(node.getAttribute('left') ?? '0') ?? 0;
    final y = int.tryParse(node.getAttribute('top') ?? '0') ?? 0;
    final width = int.tryParse(node.getAttribute('width') ?? '0') ?? 0;
    final height = int.tryParse(node.getAttribute('height') ?? '0') ?? 0;
    final zOrder = int.tryParse(node.getAttribute('zorder') ?? '0') ?? 0;
    
    // Parse linked state variable references
    final stateVarRef = node.getAttribute('statevariableref');
    StateVariable? linkedStateVariable;
    if (stateVarRef != null && stateVarRef.isNotEmpty) {
      linkedStateVariable = stateVariables.firstWhere(
        (sv) => sv.id == stateVarRef,
        orElse: () => StateVariable(id: '', name: '', type: '')
      );
    }
    
    // Parse control properties specific to the control type
    final properties = <String, dynamic>{};
    _parseControlProperties(node, properties, controlType);

    return Control(
      id: id,
      name: name,
      type: controlType,
      x: x,
      y: y,
      width: width,
      height: height,
      zOrder: zOrder,
      stateVariable: linkedStateVariable,
      properties: properties,
    );
  }

  /// Parse control-specific properties
  void _parseControlProperties(XmlElement node, Map<String, dynamic> properties, String controlType) {
    // Parse common properties
    properties['visible'] = _parseBool(node.getAttribute('visible') ?? 'true');
    properties['enabled'] = _parseBool(node.getAttribute('enabled') ?? 'true');
    properties['backgroundColor'] = _parseColor(node.getAttribute('backcolor'));
    properties['foregroundColor'] = _parseColor(node.getAttribute('forecolor'));
    
    // Parse control-specific properties
    switch (controlType) {
      case 'FADER':
        properties['min'] = double.tryParse(node.getAttribute('min') ?? '0') ?? 0.0;
        properties['max'] = double.tryParse(node.getAttribute('max') ?? '100') ?? 100.0;
        properties['value'] = double.tryParse(node.getAttribute('value') ?? '0') ?? 0.0;
        properties['orientation'] = node.getAttribute('orientation') ?? 'vertical';
        properties['showTickMarks'] = _parseBool(node.getAttribute('showtickmarks') ?? 'false');
        properties['style'] = node.getAttribute('style') ?? 'standard';
        break;
        
      case 'METER':
        properties['min'] = double.tryParse(node.getAttribute('min') ?? '0') ?? 0.0;
        properties['max'] = double.tryParse(node.getAttribute('max') ?? '100') ?? 100.0;
        properties['value'] = double.tryParse(node.getAttribute('value') ?? '0') ?? 0.0;
        properties['orientation'] = node.getAttribute('orientation') ?? 'vertical';
        properties['segments'] = int.tryParse(node.getAttribute('segments') ?? '10') ?? 10;
        properties['style'] = node.getAttribute('style') ?? 'standard';
        break;
        
      case 'BUTTON':
        properties['buttonType'] = node.getAttribute('buttontype') ?? 'momentary';
        properties['state'] = _parseBool(node.getAttribute('state') ?? 'false');
        properties['text'] = node.getAttribute('text') ?? '';
        properties['textAlignment'] = node.getAttribute('textalignment') ?? 'center';
        properties['imageOn'] = node.getAttribute('imageon') ?? '';
        properties['imageOff'] = node.getAttribute('imageoff') ?? '';
        break;
        
      case 'LABEL':
        properties['text'] = node.getAttribute('text') ?? '';
        properties['textAlignment'] = node.getAttribute('textalignment') ?? 'left';
        properties['fontSize'] = int.tryParse(node.getAttribute('fontsize') ?? '12') ?? 12;
        properties['fontStyle'] = node.getAttribute('fontstyle') ?? 'normal';
        break;
        
      case 'COMBO':
        properties['selectedIndex'] = int.tryParse(node.getAttribute('selectedindex') ?? '0') ?? 0;
        
        // Parse combo box items
        final items = <String>[];
        final itemNodes = node.findAllElements('ITEM');
        for (final itemNode in itemNodes) {
          items.add(itemNode.innerText);
        }
        properties['items'] = items;
        break;
    }
  }

  /// Parse color from string
  int _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) {
      return 0xFF000000; // Default to black
    }
    
    try {
      // Try to parse ARGB hex value (e.g., "#FFAABBCC")
      if (colorStr.startsWith('#')) {
        final hexColor = colorStr.substring(1);
        if (hexColor.length == 8) {
          return int.parse('0x$hexColor');
        } else if (hexColor.length == 6) {
          return int.parse('0xFF$hexColor');
        }
      }
      
      // Try to parse RGB decimal values (e.g., "255,128,64")
      if (colorStr.contains(',')) {
        final parts = colorStr.split(',');
        if (parts.length >= 3) {
          final r = int.tryParse(parts[0].trim()) ?? 0;
          final g = int.tryParse(parts[1].trim()) ?? 0;
          final b = int.tryParse(parts[2].trim()) ?? 0;
          final a = parts.length > 3 ? int.tryParse(parts[3].trim()) ?? 255 : 255;
          return (a << 24) | (r << 16) | (g << 8) | b;
        }
      }
    } catch (e) {
      // Use a logger instead of print in production code
    }
    
    return 0xFF000000; // Default to black
  }

  /// Parse boolean from string
  bool _parseBool(String boolStr) {
    final lowerStr = boolStr.toLowerCase();
    return lowerStr == 'true' || lowerStr == '1' || lowerStr == 'yes';
  }
}