import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/models/registered_item.dart';

class ItemService {
  static const _key = 'items.registered';

  Future<List<RegisteredItem>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(RegisteredItem.fromJson).toList();
  }

  Future<void> saveItems(List<RegisteredItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  Future<void> addItem(RegisteredItem item) async {
    final items = await getItems();
    items.add(item);
    await saveItems(items);
  }
}
