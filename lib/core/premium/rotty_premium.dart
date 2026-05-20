import '../../services/storage_service.dart';

/// Premium gates — real UPI unlock via [PremiumScreen].
class RottyPremium {
  RottyPremium._();

  /// Keep false in production. UPI success unlocks PRO.
  static const bool devUnlockAll = false;

  static bool isPremiumActive(StorageService storage) {
    if (devUnlockAll) return true;
    return storage.isPremiumActive;
  }
}
