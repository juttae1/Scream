import 'package:flutter/foundation.dart';

class LogEntry {
  final DateTime time;
  final String tag; // e.g. KAMIS, UI, ITEM:팥
  final String message;

  LogEntry(this.tag, this.message) : time = DateTime.now();

  @override
  String toString() => '[${time.toIso8601String()}][$tag] $message';
}

class LogManager {
  static final List<LogEntry> _entries = [];
  static final ValueNotifier<int> _version = ValueNotifier<int>(0);
  static int maxEntries = 1000;

  static ValueListenable<int> get listenable => _version;

  static List<String> get lines => _entries.map((e) => e.toString()).toList();

  static void d(String tag, String msg) {
    final entry = LogEntry(tag, msg);
    // keep debugPrint for terminal visibility
    debugPrint(entry.toString());
    _entries.add(entry);
    if (_entries.length > maxEntries) _entries.removeRange(0, _entries.length - maxEntries);
    _version.value++;
  }

  static void clear() {
    _entries.clear();
    _version.value++;
  }

  static List<LogEntry> filter(String? q) {
    if (q == null || q.trim().isEmpty) return List.unmodifiable(_entries);
    final low = q.toLowerCase();
    return _entries.where((e) => e.tag.toLowerCase().contains(low) || e.message.toLowerCase().contains(low)).toList();
  }
}
