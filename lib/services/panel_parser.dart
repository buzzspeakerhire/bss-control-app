import 'dart:io';
import 'package:xml/xml.dart';
import '../models/panel_model.dart';
import '../models/control_model.dart';
import '../models/state_variable_model.dart';
import 'dart:math' as Math;

class PanelParser {
  /// Parse a panel file and return a Panel object
  Future<Panel> parseFromFile(String filePath) async {
    try {
      final file = File(filePath);
      
      // Verify file exists and has content
      if (!await file.exists()) {
        throw Exception('Panel file does not exist: $filePath');
      }
      
      final content = await file.readAsString();
      
      if (content.isEmpty) {
        throw Exception('Panel file is empty');
      }
      
      // Quick check if this looks like XML
      if (!content.trim().startsWith('<')) {
        throw Exception('File does not appear to be XML: ${content.substring(0, Math.min(50, content.length))}');
      }
      
      return parseFromString(content);
    } catch (e) {
      throw Exception('Failed to parse panel file: $e');
    }
  }

  /// Parse panel XML from a string
  Panel parseFromString(String xmlString) {
    try {
      // Pre-process XML to handle namespace correctly
      // Remove the xml:lang attribute that's causing issues
      String fixedXml = xmlString;
      
      if (fixedXml.contains('xml:lang')) {
        fixedXml = fixedXml.replaceAll('xml:lang="en-US"', 'xmlLang="en-US"');
      }
      
      // Attempt to parse the XML
      XmlDocument? document;
      try {
        document = XmlDocument.parse(fixedXml);
      } catch (e) {
        // Try a more aggressive fix if the first attempt fails
        if (fixedXml.contains('xml:')) {
          fixedXml = fixedXml.replaceAll(RegExp(r'xml:[a-zA-Z]+="[^"]*"'), '');
          document = XmlDocument.parse(fixedXml);
        } else {
          rethrow; // If it's not a namespace issue, rethrow
        }
      }
      
      if (document == null) {
        throw Exception('Failed to parse XML document');
      }
      
      // Find the Panel element within Panels root
      final panelsElements = document.findAllElements('Panels').toList();
      if (panelsElements.isEmpty) {
        // Try to find any element that could be the panel
        final allElements = document.findAllElements('*').toList();
        if (allElements.isEmpty) {
          throw Exception('Could not find any elements in the XML');
        }
        
        throw Exception('Could not find Panels element in the XML. Available elements: ${allElements.map((e) => e.name.local).toSet()}');
      }
      
      final panelsRoot = panelsElements.first;
      final panelElements = panelsRoot.findAllElements('Panel').toList();
      
      if (panelElements.isEmpty) {
        // Try to look for elements directly under the root
        final directChildren = panelsRoot.childElements.toList();
        if (directChildren.isEmpty) {
          throw Exception('Could not find Panel element or any children within Panels element');
        }
        
        throw Exception('Could not find Panel element within Panels element. Available children: ${directChildren.map((e) => e.name.local).toSet()}');
      }
      
      final panelNode = panelElements.first;
      
      // Parse panel properties
      final panel = Panel(
        id: panelNode.getAttribute('Version') ?? '',
        name: panelNode.getAttribute('Text') ?? 'Unnamed Panel',
        width: _extractDimension(panelNode.getAttribute('Size'), 0),
        height: _extractDimension(panelNode.getAttribute('Size'), 1),
        backgroundColor: _parseColor(panelNode.getAttribute('BackColor')),
        foregroundColor: _parseColor(panelNode.getAttribute('ForeColor')),
        stateVariables: [],
        controls: [],
      );
      
      // Parse all controls
      final controlNodes = panelNode.findAllElements('Control').toList();
      
      if (controlNodes.isEmpty) {
        print('Warning: No Control elements found in the panel');
      }
      
      // First pass: Extract all state variables
      final stateVariables = <StateVariable>[];
      
      for (final controlNode in controlNodes) {
        final stateVarItems = _findStateVariableItems(controlNode);
        
        for (final item in stateVarItems) {
          final nodeId = int.tryParse(item.getAttribute('NodeID') ?? '1') ?? 1;
          final vdIndex = int.tryParse(item.getAttribute('VdIndex') ?? '3') ?? 3;
          final objId = int.tryParse(item.getAttribute('ObjID') ?? '0') ?? 0;
          final svId = int.tryParse(item.getAttribute('svID') ?? '0') ?? 0;
          final svClassId = item.getAttribute('SVClassID') ?? '';
          
          // Create unique ID using the format needed for device communication
          final id = '${nodeId}_$vdIndex}_${objId}_$svId';
          final name = controlNode.getAttribute('Name') ?? 'Unnamed';
          
          final stateVar = StateVariable(
            id: id,
            name: name,
            type: _determineStateVarType(svClassId),
            deviceIndex: nodeId,
            objectIndex: objId,
            channel: svId,
            value: null, // Initial value, will be updated during operation
          );
          
          stateVariables.add(stateVar);
        }
      }
      
      panel.stateVariables = stateVariables;
      
      // Second pass: Create controls
      for (final controlNode in controlNodes) {
        final controlType = controlNode.getAttribute('Type') ?? '';
        final mappedType = _mapBssControlType(controlType);
        
        // Skip non-control elements like rectangles
        if (mappedType == 'UNKNOWN') continue;
        
        final stateVar = _findLinkedStateVariable(controlNode, stateVariables);
        
        final control = Control(
          id: controlNode.getAttribute('ControlKey') ?? '',
          name: controlNode.getAttribute('Name') ?? '',
          type: mappedType,
          x: _extractLocation(controlNode.getAttribute('Location'), 0),
          y: _extractLocation(controlNode.getAttribute('Location'), 1),
          width: _extractDimension(controlNode.getAttribute('Size'), 0),
          height: _extractDimension(controlNode.getAttribute('Size'), 1),
          zOrder: int.tryParse(controlNode.getAttribute('TabIndex') ?? '0') ?? 0,
          stateVariable: stateVar,
          properties: _extractControlProperties(controlNode, controlType, stateVar),
        );
        
        panel.controls.add(control);
      }
      
      if (panel.controls.isEmpty) {
        print('Warning: No controls were created from the panel file');
      }
      
      return panel;
    } catch (e) {
      throw Exception('Failed to parse panel XML: $e');
    }
  }
  
  // Find all StateVariableItem elements in a control
  List<XmlElement> _findStateVariableItems(XmlElement controlNode) {
    final items = <XmlElement>[];
    
    final complexProps = controlNode.findAllElements('ComplexProperties').toList();
    for (final prop in complexProps) {
      if (prop.getAttribute('Tag') == 'HProSVControl') {
        final stateVarItems = prop.findAllElements('StateVariableItem').toList();
        items.addAll(stateVarItems);
      }
    }
    
    return items;
  }
  
  // Extract location (x,y) from a string like "123, 456"
  int _extractLocation(String? location, int index) {
    if (location == null) return 0;
    
    final parts = location.split(',');
    if (parts.length <= index) return 0;
    
    return int.tryParse(parts[index].trim()) ?? 0;
  }
  
  // Extract dimension (width,height) from a string like "123, 456"
  int _extractDimension(String? size, int index) {
    if (size == null) return 0;
    
    final parts = size.split(',');
    if (parts.length <= index) return 0;
    
    return int.tryParse(parts[index].trim()) ?? 0;
  }
  
  // Map BSS control types to our internal types
  String _mapBssControlType(String bssType) {
    if (bssType.contains('HProSlider')) {
      return 'FADER';
    } else if (bssType.contains('HProFastMeter')) {
      return 'METER';
    } else if (bssType.contains('HProComboBox')) {
      return 'COMBO';
    } else if (bssType.contains('HProAnnotation')) {
      return 'LABEL';
    } else if (bssType.contains('HProButton')) {
      return 'BUTTON';
    } else if (bssType.contains('Rectangle')) {
      return 'UNKNOWN'; // We don't handle decorative elements
    } else {
      return 'UNKNOWN';
    }
  }
  
  // Find state variable linked to a control
  StateVariable? _findLinkedStateVariable(XmlElement controlNode, List<StateVariable> allVars) {
    final items = _findStateVariableItems(controlNode);
    if (items.isEmpty) return null;
    
    final item = items.first;
    final nodeId = int.tryParse(item.getAttribute('NodeID') ?? '1') ?? 1;
    final vdIndex = int.tryParse(item.getAttribute('VdIndex') ?? '3') ?? 3;
    final objId = int.tryParse(item.getAttribute('ObjID') ?? '0') ?? 0;
    final svId = int.tryParse(item.getAttribute('svID') ?? '0') ?? 0;
    
    final id = '${nodeId}_${vdIndex}_${objId}_$svId';
    
    // Find matching state variable
    for (final sv in allVars) {
      if (sv.id == id) return sv;
    }
    
    return null;
  }
  
  // Extract properties for each control type
  Map<String, dynamic> _extractControlProperties(XmlElement controlNode, String controlType, StateVariable? stateVar) {
    final props = <String, dynamic>{};
    
    // Add basic properties
    props['text'] = controlNode.getAttribute('Text') ?? '';
    
    // Extract control properties from ControlProperties element
    final controlPropsNodes = controlNode.findAllElements('ControlProperties').toList();
    if (controlPropsNodes.isNotEmpty) {
      final controlProps = controlPropsNodes.first;
      
      for (final prop in controlProps.childElements) {
        final propName = prop.localName;
        final propValue = prop.innerText;
        
        // Handle specific property types
        if (propValue.toLowerCase() == 'true' || propValue.toLowerCase() == 'false') {
          props[propName] = propValue.toLowerCase() == 'true';
        } else if (propName.toLowerCase().contains('color')) {
          props[propName] = _parseColor(propValue);
        } else if (double.tryParse(propValue) != null) {
          props[propName] = double.parse(propValue);
        } else {
          props[propName] = propValue;
        }
      }
    }
    
    // Add control-specific default properties
    if (controlType.contains('HProSlider')) {
      // Handle fader properties
      props['min'] = _parseDbValue(props['SVMin'] ?? '-∞dB');
      props['max'] = _parseDbValue(props['SVMax'] ?? '0dB');
      props['value'] = -20.0; // Default starting value
      props['orientation'] = controlType.contains('HProSliderV') ? 'vertical' : 'horizontal';
    } else if (controlType.contains('HProFastMeter')) {
      // Handle meter properties
      props['min'] = -80.0;
      props['max'] = 0.0;
      props['value'] = -80.0;
      props['orientation'] = 'vertical';
      props['segments'] = 20;
    } else if (controlType.contains('HProComboBox')) {
      // Handle combo box properties
      final items = <String>[];
      int selectedIndex = 0;
      
      // Extract items from ComplexProperties/UserList
      final userListProps = controlNode.findAllElements('ComplexProperties')
          .where((p) => p.getAttribute('Tag') == 'HProDiscreteControl')
          .toList();
      
      if (userListProps.isNotEmpty) {
        final stringLists = userListProps.first.findAllElements('StringList').toList();
        for (final item in stringLists) {
          items.add(item.getAttribute('Label') ?? '');
        }
      }
      
      props['items'] = items;
      props['selectedIndex'] = selectedIndex;
    } else if (controlType.contains('HProAnnotation')) {
      // Handle label properties
      props['textAlignment'] = props['Alignment'] ?? 'MiddleCenter';
      
      // Extract text lines
      final textLines = <String>[];
      final textLinesNodes = controlNode.findAllElements('TextLines').toList();
      if (textLinesNodes.isNotEmpty) {
        final lineNodes = textLinesNodes.first.findAllElements('Line').toList();
        for (final line in lineNodes) {
          textLines.add(line.innerText);
        }
      }
      
      if (textLines.isNotEmpty) {
        props['text'] = textLines.join('\n');
      }
      
      props['fontSize'] = 14; // Default font size
    }
    
    return props;
  }
  
  // Parse color from string like "145, 112, 219"
  int _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) {
      return 0xFF000000; // Default to black
    }
    
    try {
      // Handle named colors
      if (!colorStr.contains(',')) {
        switch (colorStr.toLowerCase()) {
          case 'black': return 0xFF000000;
          case 'white': return 0xFFFFFFFF;
          case 'whitesmoke': return 0xFFF5F5F5;
          case 'transparent': return 0x00000000;
          default: return 0xFF000000;
        }
      }
      
      // Parse RGB components
      final parts = colorStr.split(',');
      if (parts.length >= 3) {
        final r = int.tryParse(parts[0].trim()) ?? 0;
        final g = int.tryParse(parts[1].trim()) ?? 0;
        final b = int.tryParse(parts[2].trim()) ?? 0;
        final a = parts.length > 3 ? int.tryParse(parts[3].trim()) ?? 255 : 255;
        
        // ARGB format
        return (a << 24) | (r << 16) | (g << 8) | b;
      }
    } catch (e) {
      // Fallback to black on error
    }
    
    return 0xFF000000;
  }
  
  // Parse dB value from string
  double _parseDbValue(String dbStr) {
    if (dbStr.contains('∞')) return double.negativeInfinity;
    return double.tryParse(dbStr.replaceAll('dB', '').trim()) ?? 0.0;
  }
  
  // Determine state variable type based on SVClassID
  String _determineStateVarType(String? svClassId) {
    switch (svClassId) {
      case '106': return 'gain';    // Gain control objects
      case '107': return 'meter';   // Meter display objects
      case '128': return 'selector'; // Selector objects
      default: return 'unknown';
    }
  }
}