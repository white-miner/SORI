import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/press_bounce.dart';

class QuickCalculatorSheet extends StatefulWidget {
  const QuickCalculatorSheet({super.key});

  @override
  State<QuickCalculatorSheet> createState() => _QuickCalculatorSheetState();
}

class _QuickCalculatorSheetState extends State<QuickCalculatorSheet> {
  String _display = '0';
  String _operand = '';
  String _op = '';

  void _tapDigit(String d) {
    setState(() {
      if (_display == '0' && d != '.') {
        _display = d;
      } else {
        _display += d;
      }
    });
  }

  void _tapOp(String op) {
    setState(() {
      _operand = _display;
      _op = op;
      _display = '0';
    });
  }

  void _equals() {
    final a = double.tryParse(_operand) ?? 0;
    final b = double.tryParse(_display) ?? 0;
    double r = b;
    switch (_op) {
      case '+':
        r = a + b;
      case '-':
        r = a - b;
      case '×':
        r = a * b;
      case '÷':
        r = b == 0 ? 0 : a / b;
    }
    setState(() {
      _display = r == r.roundToDouble() ? '${r.round()}' : r.toStringAsFixed(2);
      _operand = '';
      _op = '';
    });
  }

  void _clear() {
    setState(() {
      _display = '0';
      _operand = '';
      _op = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _display,
                  style: GoogleFonts.nunito(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _row(['C', '÷', '×', '⌫'], accent: true),
              _row(['7', '8', '9', '-'], accent: true),
              _row(['4', '5', '6', '+'], accent: true),
              _row(['1', '2', '3', '='], accent: true),
              _row(['0', '.', '', ''], accent: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(List<String> keys, {required bool accent}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (final k in keys)
            if (k.isNotEmpty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _Key(
                    label: k,
                    accent: accent && k != '=',
                    onTap: () {
                      if (k == 'C') {
                        _clear();
                      } else if (k == '⌫') {
                        setState(() {
                          if (_display.length <= 1) {
                            _display = '0';
                          } else {
                            _display = _display.substring(0, _display.length - 1);
                          }
                        });
                      } else if (k == '=') {
                        _equals();
                      } else if ('+-×÷'.contains(k)) {
                        _tapOp(k);
                      } else {
                        _tapDigit(k);
                      }
                    },
                  ),
                ),
              )
            else
              const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return PressBounce(
      child: Material(
      color: accent ? const Color(0xFFF4F6F9) : const Color(0xFF111111),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: accent ? const Color(0xFF111111) : Colors.white,
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
