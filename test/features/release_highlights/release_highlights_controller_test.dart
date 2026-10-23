import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terramanager/features/release_highlights/application/release_highlights_controller.dart';

void main() {
  const current = InstalledRelease(version: '1.16.0', buildNumber: '93');
  ReleaseHighlightsController controller([
    InstalledRelease release = current,
  ]) => ReleaseHighlightsController(loadRelease: () async => release);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'reads the actual installed version and build from package information',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'TerraManager',
        packageName: 'com.codefrog.terramanager',
        version: '1.16.0',
        buildNumber: '93',
        buildSignature: '',
      );
      final release = await ReleaseHighlightsController().currentRelease();
      expect(release.identity, '1.16.0+93');
    },
  );

  test(
    'a fresh installation records its baseline without an update overlay',
    () async {
      expect(
        await controller().pendingForStartup(existingInstallation: false),
        isNull,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(ReleaseHighlightsController.lastShownReleaseKey),
        current.identity,
      );
    },
  );

  test(
    'existing installations see this feature once, including across restarts',
    () async {
      final first = controller();
      expect(
        await first.pendingForStartup(existingInstallation: true),
        current,
      );
      await first.markShown(current);
      expect(
        await controller().pendingForStartup(existingInstallation: true),
        isNull,
      );
    },
  );

  for (final previous in ['1.15.5+92', '1.16.0+92', '1.15.5+93']) {
    test('a different version/build is eligible after $previous', () async {
      SharedPreferences.setMockInitialValues({
        ReleaseHighlightsController.lastShownReleaseKey: previous,
      });
      expect(
        await controller().pendingForStartup(existingInstallation: true),
        current,
      );
    });
  }

  test('a recorded baseline detects the next update even without a tutorial marker', () async {
    await controller().pendingForStartup(existingInstallation: false);
    const newer = InstalledRelease(version: '1.16.0', buildNumber: '94');
    expect(
      await controller(newer).pendingForStartup(existingInstallation: false),
      newer,
    );
  });

  test(
    'a failed version lookup can be retried and successful lookups are cached',
    () async {
      var requests = 0;
      final value = ReleaseHighlightsController(
        loadRelease: () async {
          if (++requests == 1) throw StateError('temporarily unavailable');
          return current;
        },
      );
      await expectLater(value.currentRelease(), throwsStateError);
      expect(await value.currentRelease(), current);
      expect(await value.currentRelease(), current);
      expect(requests, 2);
    },
  );

  test('invalid package information does not acknowledge a release', () async {
    final value = controller(
      const InstalledRelease(version: '', buildNumber: '93'),
    );
    await expectLater(
      value.pendingForStartup(existingInstallation: true),
      throwsStateError,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.containsKey(ReleaseHighlightsController.lastShownReleaseKey),
      false,
    );
  });

  test('release state preserves unrelated settings and stays separate from backups', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'standalone_tutorial_seen': true,
    });
    await controller().markShown(current);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.get('theme_mode'), 'dark');
    expect(preferences.get('standalone_tutorial_seen'), true);
    expect(preferences.getKeys(), {
      'theme_mode',
      'standalone_tutorial_seen',
      ReleaseHighlightsController.lastShownReleaseKey,
    });
  });
}
