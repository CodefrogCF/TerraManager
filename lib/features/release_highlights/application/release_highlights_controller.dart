import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstalledRelease {
  const InstalledRelease({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;
  String get identity => '$version+$buildNumber';
}

typedef InstalledReleaseLoader = Future<InstalledRelease> Function();

/// Device-local display state, deliberately separate from collection backups.
class ReleaseHighlightsController {
  ReleaseHighlightsController({
    InstalledReleaseLoader? loadRelease,
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _loadRelease = loadRelease ?? _installedRelease,
       _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const lastShownReleaseKey = 'standalone_last_shown_release';
  final InstalledReleaseLoader _loadRelease;
  final Future<SharedPreferences> Function() _loadPreferences;
  Future<InstalledRelease>? _release;

  static Future<InstalledRelease> _installedRelease() async {
    final information = await PackageInfo.fromPlatform();
    return InstalledRelease(
      version: information.version,
      buildNumber: information.buildNumber,
    );
  }

  Future<InstalledRelease> currentRelease() => _release ??= _readRelease();

  Future<InstalledRelease> _readRelease() async {
    try {
      final release = await _loadRelease();
      if (release.version.trim().isEmpty ||
          release.buildNumber.trim().isEmpty) {
        throw StateError('Installed release information is unavailable');
      }
      return release;
    } catch (_) {
      _release = null;
      rethrow;
    }
  }

  Future<InstalledRelease?> pendingForStartup({
    required bool existingInstallation,
  }) async {
    final release = await currentRelease();
    final preferences = await _loadPreferences();
    final seen = preferences.get(lastShownReleaseKey);
    if (seen == release.identity) return null;
    if (seen is! String && !existingInstallation) {
      await markShown(release);
      return null;
    }
    return release;
  }

  Future<void> markShown(InstalledRelease release) async {
    final preferences = await _loadPreferences();
    if (!await preferences.setString(lastShownReleaseKey, release.identity)) {
      throw StateError('Could not persist the shown release');
    }
  }
}
