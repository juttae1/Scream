import 'package:flutter/material.dart';

class ItemListSection extends StatelessWidget {
  const ItemListSection({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> items = const [
      {'name': '오이', 'qty': '10상자'},
      {'name': '방울토마토', 'qty': '6상자'},
      {'name': '참외', 'qty': '4상자'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('등록된 품목', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
  ...items.map((e) => _ItemTile(name: e['name']!, qty: e['qty']!)),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.name, required this.qty});
  final String name;
  final String qty;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(qty, style: const TextStyle(fontSize: 16, color: Colors.black87)),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
