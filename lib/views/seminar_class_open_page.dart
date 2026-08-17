import 'package:flutter/material.dart';

import '../models/seminar_class.dart';
import '../services/sori_store.dart';
import '../theme/sori_tokens.dart';
import 'seminar_class_detail_page.dart';

/// 원장 — 세미나 클래스 등록 폼.
class SeminarClassOpenPage extends StatefulWidget {
  const SeminarClassOpenPage({
    super.key,
    required this.store,
    this.targetCaseId,
    this.initialTitle = '',
  });

  final SoriStore store;
  final String? targetCaseId;
  final String initialTitle;

  @override
  State<SeminarClassOpenPage> createState() => _SeminarClassOpenPageState();
}

class _SeminarClassOpenPageState extends State<SeminarClassOpenPage> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '150000');
  final _capacityCtrl = TextEditingController(text: '12');
  DateTime? _eventDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.initialTitle.trim().isEmpty
        ? '임상 케이스 라이브 세미나'
        : widget.initialTitle.trim();
    _eventDate = DateTime.now().add(const Duration(days: 14));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    final draft = SeminarClass(
      id: '',
      directorShopId: widget.store.shop.id,
      targetCaseId: widget.targetCaseId,
      title: title,
      eventDate: _eventDate,
      location: _locationCtrl.text.trim(),
      price: int.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0,
      maxCapacity: int.tryParse(_capacityCtrl.text) ?? 12,
      status: SeminarClassStatus.open,
    );

    final created = await widget.store.createSeminarClass(draft);
    if (!mounted) return;
    setState(() => _saving = false);

    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('클래스 등록에 실패했습니다.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${created.title}」 클래스가 오픈됐어요'),
        backgroundColor: SoriTokens.primary,
      ),
    );
    Navigator.pop(context);
    if (!context.mounted) return;
    await SeminarClassDetailPage.open(
      context,
      store: widget.store,
      classId: created.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _eventDate == null
        ? '일정 선택'
        : '${_eventDate!.year}.${_eventDate!.month.toString().padLeft(2, '0')}.${_eventDate!.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('클래스 오픈하기'),
        backgroundColor: Colors.white,
        foregroundColor: SoriTokens.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SoriTokens.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '수강료는 SORI 에스크로(held)로 보관되며, 수강 완료 후 정산 RPC로 원장 지갑에 입금됩니다.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '클래스 제목',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('일정'),
            subtitle: Text(dateLabel),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: '장소',
              hintText: '샵 실습실 / 온라인 Zoom 등',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '수강료 (원)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _capacityCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '정원',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: SoriTokens.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _saving ? '등록 중…' : '클래스 오픈',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
