import 'package:flutter/foundation.dart';
import 'log_manager.dart';

/// Compatibility wrapper so older imports of AppLog still work.
class AppLog {
  static ValueListenable<int> get listenable => LogManager.listenable;
  static List<String> get lines => LogManager.lines;
  static void d(String msg) => LogManager.d('APP', msg);
  static void clear() => LogManager.clear();
}
