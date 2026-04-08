import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enom_app/screens/camera_permission_screen.dart';
import 'package:enom_app/l10n/app_localizations.dart';

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'checkPermissionStatus') return 0;
        if (methodCall.method == 'requestPermissions') return <dynamic, dynamic>{};
        if (methodCall.method == 'shouldShowRequestPermissionRationale') return false;
        if (methodCall.method == 'openAppSettings') return true;
        return null;
      },
    );
  });

  test('MOOD-301e: CameraPermissionResult enum has 3 values', () {
    expect(CameraPermissionResult.granted.index, 0);
    expect(CameraPermissionResult.denied.index, 1);
    expect(CameraPermissionResult.cancelled.index, 2);
    expect(CameraPermissionResult.values.length, 3);
  });

  testWidgets(
    'MOOD-301e: Explainer state UI, translations, and cancel flow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // ── Verify translation keys inline (avoids rootBundle hang) ──
      final l10n = AppLocalizations(const Locale('en'));
      await l10n.load();

      // Explainer state keys
      expect(l10n.translate('mood_camera_title'), 'Mood Detection');
      expect(l10n.translate('mood_camera_subtitle'), 'Let your face tell the story');
      expect(l10n.translate('mood_camera_desc'), contains('front camera'));
      expect(l10n.translate('mood_camera_enable'), 'Enable Camera');
      expect(l10n.translate('mood_camera_not_now'), 'Not Now');
      expect(l10n.translate('mood_camera_privacy'), contains('privacy'));
      // Denied
      expect(l10n.translate('mood_camera_denied_title'), 'Camera Access Needed');
      expect(l10n.translate('mood_camera_denied_desc'), contains('camera access'));
      expect(l10n.translate('mood_camera_try_again'), 'Try Again');
      // Permanently denied
      expect(l10n.translate('mood_camera_perm_denied_title'), 'Camera Blocked');
      expect(l10n.translate('mood_camera_perm_denied_desc'), contains('permanently denied'));
      // Restricted
      expect(l10n.translate('mood_camera_restricted_title'), 'Camera Restricted');
      expect(l10n.translate('mood_camera_restricted_desc'), contains('parental controls'));
      // Requesting
      expect(l10n.translate('mood_camera_initializing'), 'Preparing camera...');

      // ── Widget test: render the screen ──

      late CameraPermissionResult? popResult;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  popResult = await Navigator.push<CameraPermissionResult>(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => const CameraPermissionScreen(),
                    ),
                  );
                },
                child: const Text('Launch'),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Navigate to permission screen
      await tester.tap(find.text('Launch'));
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify explainer state elements
      expect(find.text('Mood Detection'), findsOneWidget);
      expect(find.text('Let your face tell the story'), findsOneWidget);
      expect(find.textContaining('ENOM uses your front camera'), findsOneWidget);
      expect(find.textContaining('Your privacy matters'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.text('Enable Camera'), findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // AppBar
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.transparent);
      expect(appBar.elevation, 0);

      // Cancel via "Not Now"
      await tester.tap(find.text('Not Now'));
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Launch'), findsOneWidget);
      expect(find.text('Enable Camera'), findsNothing);
      expect(popResult, CameraPermissionResult.cancelled);
    },
  );
}
