import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_store_host/mini_program/app_android_location_provider.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(AppAndroidLocationProvider.channelName);

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps a native result into the provider-neutral contract', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getCurrentLocation');
          expect(call.arguments, containsPair('accuracy', 'approximate'));
          return <String, Object?>{
            'latitude': 23.8103,
            'longitude': 90.4125,
            'accuracyMeters': 800.0,
            'capturedAtUtc': '2026-07-15T10:00:00.000Z',
            'source': 'device',
          };
        });

    final result = await const AppAndroidLocationProvider().getCurrentLocation(
      accuracy: MiniProgramLocationAccuracy.approximate,
      timeout: const Duration(seconds: 10),
    );

    expect(result.latitude, 23.8103);
    expect(result.capturedAtUtc.isUtc, isTrue);
  });

  test('maps stable native permission failures', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: MiniProgramErrorCodes.locationPermissionDeniedPermanently,
            message: 'Open Android settings.',
          );
        });

    expect(
      () => const AppAndroidLocationProvider().getCurrentLocation(
        accuracy: MiniProgramLocationAccuracy.approximate,
        timeout: const Duration(seconds: 10),
      ),
      throwsA(
        isA<MiniProgramLocationException>().having(
          (error) => error.errorCode,
          'errorCode',
          MiniProgramErrorCodes.locationPermissionDeniedPermanently,
        ),
      ),
    );
  });

  test('maps unknown native failures to location unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'native_failure');
        });

    expect(
      () => const AppAndroidLocationProvider().getCurrentLocation(
        accuracy: MiniProgramLocationAccuracy.approximate,
        timeout: const Duration(seconds: 10),
      ),
      throwsA(
        isA<MiniProgramLocationException>().having(
          (error) => error.errorCode,
          'errorCode',
          MiniProgramErrorCodes.locationUnavailable,
        ),
      ),
    );
  });
}
