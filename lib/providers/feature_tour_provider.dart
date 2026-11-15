import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final featureTourSeenProvider =
    AsyncNotifierProvider<FeatureTourSeenNotifier, bool>(
      FeatureTourSeenNotifier.new,
    );

class FeatureTourSeenNotifier extends AsyncNotifier<bool> {
  static const _seenKey = 'feature_tour_seen';

  @override
  Future<bool> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_seenKey) ?? false;
  }

  Future<void> markSeen() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_seenKey, true);
    state = const AsyncData(true);
  }
}
