import 'dart:io';

/// VM / Windows / test — inherit PowerShell User/Machine env when the process has it.
String readProcessEnv(String name) {
  final v = Platform.environment[name];
  if (v == null) return '';
  return v.trim();
}
