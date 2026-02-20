import '../services/profile_service.dart';

class SubscriptionService {
  SubscriptionService({ProfileService? profiles}) : _profiles = profiles ?? ProfileService();

  final ProfileService _profiles;

  static Future<bool> hasAccess() async {
    return SubscriptionService()._hasAccess();
  }

  Future<bool> _hasAccess() async {
    final profile = await _profiles.getOrCreateProfile();
    return profile.isPremium;
  }
}
