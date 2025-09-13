import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/app_log.dart';
import 'package:flutter_application_1/services/kamis_daily_price_service.dart';
import 'package:flutter_application_1/services/item_service.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});
  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final TextEditingController _controller = TextEditingController();
  // filter removed; using registered items and manual text field instead
  final _itemService = ItemService();
  List<String> _registeredNames = [];
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _loadRegistered();
  }

  Future<void> _loadRegistered() async {
    final items = await _itemService.getItems();
    if (!mounted) return;
    setState(() {
      _registeredNames = items.map((e) => e.name).toList();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startDump(String item) async {
  // set manual search to the dumped item for convenience
  _controller.text = item;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$item 관련 덤프 시작...'), duration: const Duration(seconds: 1)));
  await KamisDailyPriceService().debugDumpAllItemLists(itemName: item, regionName: '서울 가락시장', maxItems: -1);
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('필터 덤프 완료')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('로그'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined),
            tooltip: '등록된 품목으로 덤프',
            onPressed: () async {
              if (_registeredNames.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('등록된 품목이 없습니다.')));
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('등록된 품목 덤프 시작...'), duration: Duration(seconds: 1)));
              for (final name in _registeredNames) {
                await KamisDailyPriceService().debugDumpAllItemLists(itemName: name, regionName: '서울 가락시장', maxItems: -1);
              }
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('등록된 품목 덤프 완료')));
            },
          ),
          IconButton(
            icon: Icon(_showAll ? Icons.visibility : Icons.filter_list),
            tooltip: _showAll ? '전체 로그 보기' : '등록 품목으로 필터',
            onPressed: () => setState(() => _showAll = !_showAll),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => AppLog.clear(),
            tooltip: 'Clear',
          )
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(children: [
            Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '수동 검색 (예: 새우)'))),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () { final v = _controller.text.trim(); if (v.isNotEmpty) _startDump(v); }, child: const Text('덤프'))
          ]),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row(children: [
          Text('등록된 품목 필터: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          Expanded(child: Text(_registeredNames.isEmpty ? '없음' : _registeredNames.join(', '), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          if (_registeredNames.isNotEmpty) TextButton(onPressed: _loadRegistered, child: const Text('새로고침'))
        ])),
        Expanded(child: ValueListenableBuilder<int>(
            valueListenable: AppLog.listenable,
          builder: (_, __, ___) {
            final allLines = AppLog.lines.reversed.toList();
            List<String> lines;
            final manual = _controller.text.trim();
            if (manual.isNotEmpty) {
              lines = allLines.where((l) => l.toLowerCase().contains(manual.toLowerCase())).toList();
            } else if (_showAll || _registeredNames.isEmpty) {
              lines = allLines;
            } else {
              lines = allLines.where((l) {
                for (final name in _registeredNames) {
                  if (l.toLowerCase().contains(name.toLowerCase())) return true;
                }
                return false;
              }).toList();
            }
            return ListView.builder(
              reverse: false,
              itemCount: lines.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: SelectableText(
                  lines[i],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            );
          },
        ))
      ]),
    );
  }
}