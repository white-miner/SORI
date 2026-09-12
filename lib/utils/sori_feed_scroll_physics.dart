import 'package:flutter/widgets.dart';

/// Feed-only overscroll. Do not apply through [ScrollBehavior] or to
/// Timer / Visit / Consent / sheets / map / camera.
const ScrollPhysics soriFeedScrollPhysics = BouncingScrollPhysics(
  parent: AlwaysScrollableScrollPhysics(),
);
