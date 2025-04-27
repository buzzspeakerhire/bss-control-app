import 'package:intl/intl.dart';

/// Helper class for working with BSS parameter values
class BssParameterCalculator {
  // Format for displaying dB values
  static final NumberFormat _dbFormat = NumberFormat('##0.0', 'en_US');

  /// Convert a raw Gain parameter value to dB
  /// Raw range: -280,617 (-80dB) to 100,000 (+10dB)
  /// Unity gain (0dB) = 0
  static double gainRawToDB(int rawValue) {
    if (rawValue <= -280617) {
      return double.negativeInfinity; // -∞dB
    } else if (rawValue == 0) {
      return 0.0; // Unity gain (0dB)
    } else if (rawValue < 0) {
      // Logarithmic scale from -inf to -10dB
      // This is an approximation - in a real implementation, you'd use the exact BSS scaling law
      return -80.0 + ((rawValue + 280617) / 280617) * 70.0;
    } else {
      // Linear scale from 0dB to +10dB
      return (rawValue / 10000);
    }
  }
  
  /// Convert dB to a raw Gain parameter value
  static int dbToGainRaw(double dbValue) {
    if (dbValue == double.negativeInfinity || dbValue <= -80.0) {
      return -280617; // Minimum value (-80dB)
    } else if (dbValue == 0.0) {
      return 0; // Unity gain (0dB)
    } else if (dbValue > 0.0) {
      // Positive values (0dB to +10dB) - linear scale
      return (dbValue * 10000).round();
    } else {
      // Negative values (-80dB to 0dB) - logarithmic scale
      // This is an approximation - in a real implementation, you'd use the exact BSS scaling law
      return ((dbValue + 80.0) / 70.0 * 280617 - 280617).round();
    }
  }
  
  /// Convert a raw Meter parameter value to dB
  /// Raw range: -800,000 (-80dB) to 400,000 (+40dB)
  /// 0dB value = 0
  static double meterRawToDB(int rawValue) {
    // Linear scale: dB value = Raw / 10,000
    return rawValue / 10000;
  }
  
  /// Convert a normalized value (0.0 to 1.0) to dB for a fader
  /// 0.0 -> -∞dB, ~0.73 -> 0dB, 1.0 -> +10dB
  static double normalizedToFaderDB(double normalizedValue) {
    if (normalizedValue <= 0.01) {
      return double.negativeInfinity; // Mute
    } else if (normalizedValue < 0.73) {
      // Below unity gain (0dB) - logarithmic scale
      return -80.0 + (normalizedValue * 109.6);
    } else {
      // Above unity gain - linear scale
      return (normalizedValue - 0.73) * 37.0;
    }
  }
  
  /// Convert a dB value to a normalized (0.0 to 1.0) value for a fader
  static double faderDBToNormalized(double dbValue) {
    if (dbValue == double.negativeInfinity || dbValue <= -80.0) {
      return 0.0;
    } else if (dbValue <= 0.0) {
      return (dbValue + 80.0) / 109.6;
    } else {
      return 0.73 + (dbValue / 37.0);
    }
  }
  
  /// Convert a normalized value (0.0 to 1.0) to dB for a meter
  /// 0.0 -> -80dB, 0.67 -> 0dB, 1.0 -> +40dB
  static double normalizedToMeterDB(double normalizedValue) {
    return -80.0 + (normalizedValue * 120.0);
  }
  
  /// Convert a dB value to a normalized (0.0 to 1.0) value for a meter
  static double meterDBToNormalized(double dbValue) {
    if (dbValue <= -80.0) {
      return 0.0;
    } else if (dbValue >= 40.0) {
      return 1.0;
    } else {
      return (dbValue + 80.0) / 120.0;
    }
  }
  
  /// Format a dB value for display
  static String formatDB(double dbValue) {
    if (dbValue == double.negativeInfinity) {
      return '-∞';
    } else if (dbValue == 0.0) {
      return '0.0';
    } else if (dbValue > 0.0) {
      return '+${_dbFormat.format(dbValue)}';
    } else {
      return _dbFormat.format(dbValue);
    }
  }
  
  /// Convert a raw percentage value to a percentage (0-100)
  /// Raw percentage = percentage value × 65536
  static double rawToPercent(int rawValue) {
    return rawValue / 65536 * 100;
  }
  
  /// Convert a percentage (0-100) to a raw percentage value
  static int percentToRaw(double percentValue) {
    return (percentValue / 100 * 65536).round();
  }
}