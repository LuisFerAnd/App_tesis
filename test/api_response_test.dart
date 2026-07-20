import 'package:flutter_test/flutter_test.dart';
import 'package:sanare_mobile/main.dart';

void main() {
  test('adds the API path to a local server URL', () {
    expect(
      normalizeApiBaseUrl('http://10.16.33.220:8000'),
      'http://10.16.33.220:8000/api',
    );
  });

  test('does not duplicate an existing API path', () {
    expect(
      normalizeApiBaseUrl('http://10.16.33.220:8000/api/'),
      'http://10.16.33.220:8000/api',
    );
  });

  test('decodes a successful JSON object', () {
    final response = decodeApiResponse(
      statusCode: 200,
      responseBody: '{"token":"abc"}',
    );

    expect(response['token'], 'abc');
  });

  test('uses the API message for an unsuccessful JSON response', () {
    expect(
      () => decodeApiResponse(
        statusCode: 422,
        responseBody: '{"message":"Credenciales incorrectas."}',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.toString(),
          'message',
          'Credenciales incorrectas.',
        ),
      ),
    );
  });

  test('turns an HTML response into an actionable API error', () {
    expect(
      () => decodeApiResponse(
        statusCode: 502,
        responseBody: '<!DOCTYPE html><html><body>Bad gateway</body></html>',
      ),
      throwsA(
        isA<ApiException>()
            .having(
              (error) => error.toString(),
              'response type',
              contains('HTML en lugar de JSON'),
            )
            .having(
              (error) => error.toString(),
              'status code',
              contains('HTTP 502'),
            ),
      ),
    );
  });
}
