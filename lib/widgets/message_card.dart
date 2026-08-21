import 'package:flutter/material.dart';
import '../theme/sori_tokens.dart';

class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.customerName,
    required this.messagePreview,
    required this.careType,
    this.scheduledTime,
    this.onTap,
  });

  final String customerName;
  final String messagePreview;
  final String careType;
  final String? scheduledTime;
  final VoidCallback? onTap;

  static const Color soriPurple = Color(0xFF6C5CE7);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoriTokens.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SoriTokens.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: soriPurple.withValues(alpha: 0.12),
                  child: Text(
                    customerName.characters.first,
                    style: const TextStyle(
                      color: soriPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (scheduledTime != null)
                            Text(
                              scheduledTime!,
                              style: TextStyle(
                                fontSize: 12,
                                color: SoriTokens.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: soriPurple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          careType,
                          style: const TextStyle(
                            fontSize: 11,
                            color: soriPurple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        messagePreview,
                        style: TextStyle(
                          fontSize: 14,
                          color: SoriTokens.textPrimary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: SoriTokens.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
