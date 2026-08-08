import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'views/my_app.dart';

void main() {
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  runApp(const MyApp());
}
