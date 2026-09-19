import 'package:flutter/foundation.dart';

/// How many detailed progress screens (`ProgressPage`) are currently on screen.
///
/// Doorstep shows transfer progress in exactly one place at a time. Normally
/// that is the compact bottom banner. Once the user opens the *detailed*
/// progress screen, that screen becomes the surface — so the banner steps aside
/// instead of stacking a second, full-screen copy on top of it. That stacking
/// was the "the loading screen keeps showing up" complaint.
final ValueNotifier<int> progressScreenDepth = ValueNotifier<int>(0);
