import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/home_navigation.dart';
import 'community/community_screen.dart' as impl;

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key, this.entryRequestListenable});

  final ValueListenable<NestedTabEntryRequest>? entryRequestListenable;

  @override
  Widget build(BuildContext context) {
    return impl.CommunityScreen(entryRequestListenable: entryRequestListenable);
  }
}
