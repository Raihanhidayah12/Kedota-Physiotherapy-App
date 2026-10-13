// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kedotaapp/utils/rest_crypto.dart';
import 'package:kedotaapp/utils/rest_crypto_interceptor.dart';

const _testKeys = '''
REST_ENCRYPT_KEY=deadbeefcafebabe0123456789abcdef0123456789abcdef0123456789abcdef
REST_HMAC_KEY=feedfacedeadbeefcafebabefeedface0123456789abcdef0123456789abcdef01
''';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({
    required this.statusCode,
    required this.responseData,
    this.headers = const {},
  });

  final int statusCode;
  final String responseData;
  final Map<String, List<String>> headers;
  Object? requestData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestData = options.data;
    return ResponseBody.fromString(
      responseData,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.testLoad(fileInput: _testKeys);
  });

  group('App performance checklist', () {
    test('CPU workload benchmark is measurable and completes', () {
      const iterations = 20000;
      var value = 'kedota-performance';
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        value = crypto.sha256.convert(utf8.encode(value)).toString();
      }
      stopwatch.stop();

      debugPrint(
        '[PERF] CPU SHA-256 workload: $iterations iterations in '
        '${stopwatch.elapsedMilliseconds}ms',
      );
      expect(value, isNotEmpty);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 30)));
    });

    test('memory footprint is observable during a retained allocation', () {
      final beforeBytes = ProcessInfo.currentRss;
      final retainedBuffer = Uint8List(8 * 1024 * 1024);
      for (var offset = 0; offset < retainedBuffer.length; offset += 4096) {
        retainedBuffer[offset] = 1;
      }
      retainedBuffer[retainedBuffer.length - 1] = 1;
      final duringBytes = ProcessInfo.currentRss;

      debugPrint(
        '[PERF] RSS before=${beforeBytes ~/ (1024 * 1024)}MiB '
        'during=${duringBytes ~/ (1024 * 1024)}MiB '
        'observedDelta=${(duringBytes - beforeBytes) ~/ 1024}KiB '
        'retainedBuffer=${retainedBuffer.length ~/ (1024 * 1024)}MiB',
      );
      expect(beforeBytes, greaterThan(0));
      expect(retainedBuffer.first + retainedBuffer.last, 2);
    });

    test(
      'REST request is encrypted and successful response is decrypted',
      () async {
        final encryptedResponse = RestCrypto.encryptPayload({
          'success': true,
          'message': 'PIN updated',
        });
        final adapter = _StubAdapter(
          statusCode: 200,
          responseData: jsonEncode(encryptedResponse),
          headers: const {
            'X-Encrypted': ['1'],
          },
        );
        final dio = createRestCryptoDio()..httpClientAdapter = adapter;

        final stopwatch = Stopwatch()..start();
        final response = await dio.post<Map<String, dynamic>>(
          'https://example.test/functions/v1/update-pin',
          data: {'profile_id': 'test-profile', 'new_pin': '123456'},
        );
        stopwatch.stop();

        final wireBody = Map<String, dynamic>.from(adapter.requestData! as Map);
        expect(wireBody.keys, containsAll(['data', 'iv', 'sig']));
        expect(jsonEncode(wireBody), isNot(contains('123456')));
        expect(RestCrypto.decryptPayload(wireBody)['new_pin'], '123456');
        expect(response.data, {'success': true, 'message': 'PIN updated'});
        debugPrint(
          '[PERF] Encrypted REST request + response handling: '
          '${stopwatch.elapsedMilliseconds}ms',
        );
      },
    );

    test('REST API errors preserve HTTP status and error body', () async {
      final adapter = _StubAdapter(
        statusCode: 503,
        responseData: jsonEncode({'error': 'temporarily unavailable'}),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final stopwatch = Stopwatch()..start();

      DioException? observed;
      try {
        await dio.get<Map<String, dynamic>>(
          'https://example.test/rest/v1/ping',
        );
      } on DioException catch (error) {
        observed = error;
      }
      stopwatch.stop();

      expect(observed?.response?.statusCode, 503);
      expect(observed?.response?.data['error'], 'temporarily unavailable');
      debugPrint(
        '[PERF] REST 503 response handling: ${stopwatch.elapsedMilliseconds}ms',
      );
    });

    test('non-encrypted endpoints remain unchanged', () async {
      final adapter = _StubAdapter(
        statusCode: 202,
        responseData: jsonEncode({'accepted': true}),
      );
      final dio = createRestCryptoDio()..httpClientAdapter = adapter;
      final plainPayload = {'source': 'flutter_client', 'status_code': 503};

      await dio.post<Map<String, dynamic>>(
        'https://example.test/functions/v1/client-error-log',
        data: plainPayload,
      );

      expect(adapter.requestData, plainPayload);
    });

    test('tampered encrypted response is rejected', () async {
      final encryptedResponse = RestCrypto.encryptPayload({'success': true});
      encryptedResponse['sig'] = '0' * 64;
      final adapter = _StubAdapter(
        statusCode: 200,
        responseData: jsonEncode(encryptedResponse),
        headers: const {
          'X-Encrypted': ['1'],
        },
      );
      final dio = createRestCryptoDio()..httpClientAdapter = adapter;

      await expectLater(
        dio.post<Map<String, dynamic>>(
          'https://example.test/functions/v1/update-pin',
          data: {'profile_id': 'test-profile', 'new_pin': '123456'},
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('bundled image load and decode stays within the CI budget', () async {
      final stopwatch = Stopwatch()..start();
      final asset = await rootBundle.load('assets/image/Logo.jpeg');
      final codec = await ui.instantiateImageCodec(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      stopwatch.stop();

      debugPrint(
        '[PERF] Logo asset load + decode: ${stopwatch.elapsedMilliseconds}ms '
        '(${frame.image.width}x${frame.image.height}, ${asset.lengthInBytes} bytes)',
      );
      expect(frame.image.width, greaterThan(0));
      expect(frame.image.height, greaterThan(0));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      frame.image.dispose();
      codec.dispose();
    });

    test('low-end device workload stays within a conservative time budget', () {
      const iterations = 2000;
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        RestCrypto.encryptPayload({'id': i, 'pin_hash': 'synthetic-test-hash'});
      }
      stopwatch.stop();

      debugPrint(
        '[PERF] Conservative-device crypto workload: $iterations iterations '
        'in ${stopwatch.elapsedMilliseconds}ms',
      );
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 30)));
    });
  });
}
