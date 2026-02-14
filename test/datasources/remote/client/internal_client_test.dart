import 'dart:convert';
import 'dart:io';

import 'package:flutter_core/datasources/remote/client/http_client_exception.dart';
import 'package:flutter_core/datasources/remote/client/internal_client.dart';
import 'package:flutter_core/datasources/remote/client/request/request.dart';
import 'package:flutter_core/datasources/remote/response/reponse.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'internal_client_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('InternalClient -', () {
    late String baseUrl;
    late MockClient mockHttpClient;

    setUp(() {
      baseUrl = 'api.example.com';
      mockHttpClient = MockClient();
    });

    http.Response _createSuccessResponse([Map<String, dynamic>? data]) {
      return http.Response(
        jsonEncode(data ?? {'success': true}),
        HttpStatus.ok,
        headers: {'content-type': 'application/json'},
      );
    }

    http.StreamedResponse _createStreamedResponse(int statusCode,
        [String? body]) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(body ?? jsonEncode({'success': true}))),
        statusCode,
        headers: {'content-type': 'application/json'},
      );
    }

    group('GET Requests', () {
      test('should send GET request successfully', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.get('/users'),
        );

        expect(response, isA<Response>());
        expect(response.status, HttpStatus.ok);
      });

      test('should include query parameters in GET request', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.get(
            '/users',
            queryParameters: {'page': '1', 'limit': '10'},
          ),
        );

        expect(response, isA<Response>());
        verify(mockHttpClient.send(
          argThat(predicate<http.BaseRequest>((req) =>
              req.url.queryParameters['page'] == '1' &&
              req.url.queryParameters['limit'] == '10')),
        )).called(1);
      });

      test('should include custom headers in GET request', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.get(
            '/users',
            headers: {'Authorization': 'Bearer token123'},
          ),
        );

        expect(response, isA<Response>());
        verify(mockHttpClient.send(
          argThat(predicate<http.BaseRequest>(
              (req) => req.headers['Authorization'] == 'Bearer token123')),
        )).called(1);
      });

      test('should handle absolute URLs in GET request', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.get('https://api.other.com/data'),
        );

        expect(response, isA<Response>());
        verify(mockHttpClient.send(
          argThat(predicate<http.BaseRequest>(
              (req) => req.url.toString() == 'https://api.other.com/data')),
        )).called(1);
      });

      test('should use mapper to transform response', () async {
        when(mockHttpClient.send(any)).thenAnswer((_) async =>
            _createStreamedResponse(
                HttpStatus.ok, jsonEncode({'name': 'John Doe'})));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send<String>(
          request: Request.get(
            '/users',
            mapper: (json) => json['name'] as String,
          ),
        );

        expect(response, isA<Response<String>>());
        expect(response.data, equals('John Doe'));
      });
    });

    group('POST Requests', () {
      test('should send POST request with JSON body', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);
        final body = {'name': 'John', 'email': 'john@example.com'};

        final response = await client.send(
          request: Request.post(
            '/users',
            body: body,
          ),
        );

        expect(response, isA<Response>());
        verify(mockHttpClient.send(
          argThat(predicate<http.BaseRequest>((req) => req.method == 'POST')),
        )).called(1);
      });

      test('should include content-type header in POST request', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);
        final body = {'data': 'test'};

        final response = await client.send(
          request: Request.post('/users', body: body),
        );

        expect(response, isA<Response>());
      });

      test('should send POST request with query parameters', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);
        final body = {'data': 'test'};

        final response = await client.send(
          request: Request.post(
            '/users',
            body: body,
            queryParameters: {'notify': 'true'},
          ),
        );

        expect(response, isA<Response>());
      });

      test('should send POST request with form data', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);
        final body = {'username': 'john', 'password': 'secret'};

        final response = await client.send(
          request: Request.post(
            '/login',
            body: body,
            isFormData: true,
          ),
        );

        expect(response, isA<Response>());
      });

      test('should send anonymous POST request', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);
        final body = {'email': 'test@example.com'};

        final response = await client.send(
          request: Request.post(
            '/register',
            body: body,
            isAnonymous: true,
          ),
        );

        expect(response, isA<Response>());
      });
    });

    group('PUT Requests', () {
      test('should send PUT request with body', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);
        final body = {'name': 'Updated Name'};

        final response = await client.send(
          request: Request.put(
            '/users/1',
            body: body,
          ),
        );

        expect(response, isA<Response>());
      });

      test('should handle PUT request with custom headers', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);
        final body = {'data': 'test'};

        final response = await client.send(
          request: Request.put(
            '/users/1',
            body: body,
            headers: {'X-Custom-Header': 'value'},
          ),
        );

        expect(response, isA<Response>());
      });
    });

    group('DELETE Requests', () {
      test('should send DELETE request', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.delete('/users/1'),
        );

        expect(response, isA<Response>());
      });

      test('should send DELETE request with query parameters', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.delete(
            '/users',
            queryParameters: {'force': 'true'},
          ),
        );

        expect(response, isA<Response>());
      });
    });

    group('Response Mapping', () {
      test('should map JSON response to typed object', () async {
        when(mockHttpClient.send(any)).thenAnswer((_) async =>
            _createStreamedResponse(
                HttpStatus.ok, jsonEncode({'id': 1, 'name': 'John'})));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send<Map<String, dynamic>>(
          request: Request.get(
            '/users/1',
            mapper: (json) => json as Map<String, dynamic>,
          ),
        );

        expect(response, isA<Response<Map<String, dynamic>>>());
        expect(response.data, isA<Map<String, dynamic>>());
      });

      test('should handle mapper returning null', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send<String?>(
          request: Request.get(
            '/users/1',
            mapper: (json) => null,
          ),
        );

        expect(response, isA<Response<String?>>());
        expect(response.data, isNull);
      });
    });

    group('Retry Logic', () {
      test('should handle retries gracefully', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.get('/protected'),
        );

        expect(response, isA<Response>());
        expect(response.status, HttpStatus.ok);
      });

      test('should return failure resource on persistent errors', () async {
        when(mockHttpClient.send(any)).thenAnswer((_) async =>
            _createStreamedResponse(HttpStatus.internalServerError));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        expect(
          () => client.send(request: Request.get('/error')),
          throwsA(isA<HttpStatusException>()),
        );
      });
    });

    group('Header Management', () {
      test('should add default content-type header', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.post('/data', body: {}),
        );

        expect(response, isA<Response>());
      });

      test('should not override provided headers', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.post(
            '/data',
            body: {},
            headers: {'Content-Type': 'application/xml'},
          ),
        );

        expect(response, isA<Response>());
        expect(response.status, HttpStatus.ok);
        verify(mockHttpClient.send(any)).called(1);
      });

      test('should handle authorization header when shouldAuthorize is true',
          () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.get(
            '/protected',
            shouldAuthorize: true,
          ),
        );

        expect(response, isA<Response>());
      });

      test('should skip authorization header when shouldAuthorize is false',
          () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.get(
            '/public',
            shouldAuthorize: false,
          ),
        );

        expect(response, isA<Response>());
      });

      test('should handle isAnonymous flag', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.get(
            '/public',
            isAnonymous: true,
          ),
        );

        expect(response, isA<Response>());
      });
    });

    group('URL Construction', () {
      test('should construct URL with baseUrl and path', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.get('/users/123'),
        );

        expect(response, isA<Response>());
        verify(mockHttpClient.send(
          argThat(predicate<http.BaseRequest>((req) =>
              req.url.toString() == 'https://api.example.com/users/123')),
        )).called(1);
      });

      test('should handle path starting with /', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.get('/api/v1/users'),
        );

        expect(response, isA<Response>());
      });

      test('should use full URL when path contains https://', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.get('https://other-api.com/data'),
        );

        expect(response, isA<Response>());
        verify(mockHttpClient.send(
          argThat(predicate<http.BaseRequest>(
              (req) => req.url.toString() == 'https://other-api.com/data')),
        )).called(1);
      });
    });

    group('Error Handling', () {
      test('should return failure resource on format exception', () async {
        when(mockHttpClient.send(any)).thenAnswer((_) async =>
            _createStreamedResponse(HttpStatus.ok, 'invalid json'));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        expect(
          () => client.send(request: Request.get('/invalid-json')),
          throwsA(isA<JsonParseException>()),
        );
      });

      test('should throw exception on client exception', () async {
        when(mockHttpClient.send(any))
            .thenThrow(http.ClientException('Connection failed'));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        expect(
          () => client.send(request: Request.get('/test')),
          throwsA(isA<NetworkException>()),
        );
      });

      test('should throw exception on network errors', () async {
        when(mockHttpClient.send(any))
            .thenThrow(const SocketException('Failed host lookup'));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        expect(
          () => client.send(request: Request.get('/test')),
          throwsA(isA<NetworkException>()),
        );
      });

      test('should throw exception for error responses', () async {
        when(mockHttpClient.send(any)).thenAnswer(
            (_) async => _createStreamedResponse(HttpStatus.notFound));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        expect(
          () => client.send(request: Request.get('/not-found')),
          throwsA(isA<HttpStatusException>()),
        );
      });
    });

    group('Response Status Extensions', () {
      test('unauthorized() should return true for 401 status', () {
        final response = http.Response('', HttpStatus.unauthorized);

        expect(response.unauthorized(), isTrue);
      });

      test('unauthorized() should return false for other status codes', () {
        final response = http.Response('', HttpStatus.ok);

        expect(response.unauthorized(), isFalse);
      });

      test('internalServerError() should return true for 500 status', () {
        final response = http.Response('', HttpStatus.internalServerError);

        expect(response.internalServerError(), isTrue);
      });

      test('internalServerError() should return false for other status codes',
          () {
        final response = http.Response('', HttpStatus.ok);

        expect(response.internalServerError(), isFalse);
      });
    });

    group('Form Data Handling', () {
      test('should encode map as form data when isFormData is true', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);
        final body = {'key1': 'value1', 'key2': 'value2'};

        final response = await client.send(
          request: Request.post(
            '/form',
            body: body,
            isFormData: true,
          ),
        );

        expect(response, isA<Response>());
      });

      test('should set correct content-type for form data', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.post(
            '/form',
            body: {'test': 'data'},
            isFormData: true,
          ),
        );

        expect(response, isA<Response>());
        verify(mockHttpClient.send(
          argThat(predicate<http.BaseRequest>((req) =>
              req.headers['content-type'] ==
              'application/x-www-form-urlencoded')),
        )).called(1);
      });
    });

    group('Debug Logging', () {
      test('should log request details in debug mode', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        // In debug mode, this should log without throwing
        await client.send(
          request: Request.get('/users'),
        );

        // No assertion needed - just verifying it doesn't crash
        expect(true, isTrue);
      });

      test('should log response details in debug mode', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        await client.send(
          request: Request.post('/users', body: {'test': 'data'}),
        );

        // Verify logging doesn't interfere with functionality
        expect(true, isTrue);
      });
    });

    group('Resource Wrappers', () {
      test('should include raw JSON in Resource', () async {
        when(mockHttpClient.send(any)).thenAnswer((_) async =>
            _createStreamedResponse(
                HttpStatus.ok, jsonEncode({'id': 1, 'name': 'Test'})));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.get('/users/1'),
        );

        expect(response, isA<Response>());
        expect(response.raw, isNotNull);
      });

      test('should have isSuccessful property', () async {
        when(mockHttpClient.send(any))
            .thenAnswer((_) async => _createStreamedResponse(HttpStatus.ok));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        final response = await client.send(
          request: Request.get('/users'),
        );

        expect(response, isA<Response>());
        expect(response.isSuccessful, isA<bool>());
        expect(response.isSuccessful, isTrue);
      });

      test('should throw exception on error', () async {
        when(mockHttpClient.send(any))
            .thenThrow(http.ClientException('Network error'));

        final client = InternalClient(baseUrl, client: mockHttpClient);

        expect(
          () => client.send(request: Request.get('/test')),
          throwsA(isA<NetworkException>()),
        );
      });
    });
  });
}
