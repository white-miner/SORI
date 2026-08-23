import 'package:flutter/material.dart';

import '../theme/sori_tokens.dart';
import 'my_app.dart';
import 'service_menu_page.dart';

/// 샵 `service_menu`에서만 고르는 관리 메뉴 선택 필드 (자유 입력 없음).
class ManagementMenuField extends StatelessWidget {
  const ManagementMenuField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hasError = false,
    this.hintText = '관리 메뉴를 선택하세요',
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool hasError;
  final String hintText;

  Future<void> _openPicker(BuildContext context) async {
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('마이페이지 > 샵 관리에서 관리 메뉴를 먼저 등록해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            builder: (_, scrollController) {
              return Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('닫기'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: options.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final name = options[index];
                        final selectedNow = name == value;
                        return ListTile(
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight:
                                  selectedNow ? FontWeight.w800 : FontWeight.w600,
                              color: selectedNow
                                  ? MyApp.soriPurple
                                  : SoriTokens.textPrimary,
                            ),
                          ),
                          trailing: selectedNow
                              ? const Icon(Icons.check_rounded,
                                  color: MyApp.soriPurple)
                              : null,
                          onTap: () => Navigator.pop(ctx, name),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (selected != null && selected.trim().isNotEmpty) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    final borderColor = hasError
        ? const Color(0xFFE53935)
        : Colors.grey.shade400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: hasError ? const Color(0xFFE53935) : MyApp.soriPurple,
                  width: 1.6,
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
              suffixIcon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: hasError ? const Color(0xFFE53935) : MyApp.soriPurple,
              ),
            ),
            child: Text(
              hasValue ? value : hintText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: hasValue
                    ? SoriTokens.textPrimary
                    : Colors.grey.shade500,
              ),
            ),
          ),
        ),
        if (options.isEmpty) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ServiceMenuPage(),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: const Text('샵 관리에서 메뉴 등록'),
            style: TextButton.styleFrom(
              foregroundColor: MyApp.soriPurple,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ],
    );
  }
}
