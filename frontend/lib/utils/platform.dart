import 'package:flutter/foundation.dart';

/// True on phones and tablets: no hover, soft keyboard.
bool get isTouchPlatform =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;