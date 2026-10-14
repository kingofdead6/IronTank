import 'package:flutter/widgets.dart';

/// Client-side form validation mirroring the API's rules.
abstract final class Validators {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static FormFieldValidator<String> required(String message) =>
      (v) => (v == null || v.trim().isEmpty) ? message : null;

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  static String? password(String? v) {
    final value = v ?? '';
    if (value.length < 8) return 'Use at least 8 characters';
    if (value.length > 128) return 'Use at most 128 characters';
    return null;
  }

  static String? username(String? v) {
    final value = v?.trim() ?? '';
    if (value.length < 2) return 'At least 2 characters';
    if (value.length > 32) return 'At most 32 characters';
    return null;
  }
}
