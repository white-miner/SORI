import 'package:flutter/material.dart';

import 'views/my_app.dart';

void main() {
  // Hash routing 기본값 유지 → GitHub Pages `/#/review?token=...` 404 방지
  runApp(const MyApp());
}
