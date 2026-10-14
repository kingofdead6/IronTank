import 'dart:math' as math;

/// Weight unit preference. The API always speaks kilograms; conversion
/// happens only at the edges (display and input).
enum WeightUnit {
  kg('kg'),
  lb('lb');

  const WeightUnit(this.label);
  final String label;

  static WeightUnit fromApi(String? value) => value == 'lb' ? WeightUnit.lb : WeightUnit.kg;
  String get apiValue => name;
}

abstract final class Units {
  static const double lbPerKg = 2.2046226218;

  /// Plate-friendly increment for the +/- steppers.
  static double step(WeightUnit unit) => unit == WeightUnit.kg ? 2.5 : 5;

  static double fromKg(double kg, WeightUnit unit) => unit == WeightUnit.kg ? kg : kg * lbPerKg;

  static double toKg(double value, WeightUnit unit) => unit == WeightUnit.kg ? value : value / lbPerKg;

  /// "102.5" / "225" — at most one decimal, trailing zeros dropped.
  static String formatNumber(double value, {int decimals = 1}) {
    // Round explicitly: toStringAsFixed alone turns 12.45 into "12.4" (binary floats).
    final factor = math.pow(10, decimals);
    final fixed = ((value * factor).round() / factor).toStringAsFixed(decimals);
    return fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
  }

  /// Formats a stored kg value in the user's unit, e.g. "225 lb".
  static String weight(double kg, WeightUnit unit, {bool withUnit = true}) {
    final value = formatNumber(fromKg(kg, unit));
    return withUnit ? '$value ${unit.label}' : value;
  }

  /// Large volumes compacted: 12 450 kg → "12.5k".
  static String volume(double kg, WeightUnit unit) {
    final v = fromKg(kg, unit);
    if (v >= 1000000) return '${formatNumber(v / 1000000)}M';
    if (v >= 10000) return '${formatNumber(v / 1000)}k';
    return formatNumber(v, decimals: 0);
  }

  static double cmToInches(double cm) => cm / 2.54;
  static double inchesToCm(double inches) => inches * 2.54;
}
