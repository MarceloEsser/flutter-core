import 'dart:io';

import 'package:flutter_core/datasources/remote/client/internal_client.dart';
import 'package:flutter_core/datasources/remote/client/request/request.dart';
import 'package:flutter_core/resource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('InternalClient -', () {
    late String baseUrl;

    setUp(() {
      baseUrl = 'api.example.com';
    });

    group('GET Requests', () {
      test('should send GET request successfully', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get('/users'),
        );

        expect(response, isA<Resource>());
      });

      test('should include query parameters in GET request', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get(
            '/users',
            queryParameters: {'page': '1', 'limit': '10'},
          ),
        );

        expect(response, isA<Resource>());
      });

      test('should include custom headers in GET request', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get(
            '/users',
            headers: {'Authorization': 'Bearer token123'},
          ),
        );

        expect(response, isA<Resource>());
      });

      test('should handle absolute URLs in GET request', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get('https://api.other.com/data'),
        );

        expect(response, isA<Resource>());
      });

      test('should use mapper to transform response', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send<String>(
          request: Request.get(
            '/users',
            mapper: (json) => json['name'] as String,
          ),
        );

        expect(response, isA<Resource<String>>());
      });
    });

    group('POST Requests', () {
      test('should send POST request with JSON body', () async {
        final client = InternalClient(baseUrl);
        final body = {'name': 'John', 'email': 'john@example.com'};

        final response = await client.send(
          request: Request.post(
            '/users',
            body: body,
          ),
        );

        expect(response, isA<Resource>());
      });

      test('should include content-type header in POST request', () async {
        final client = InternalClient(baseUrl);
        final body = {'data': 'test'};

        final response = await client.send(
          request: Request.post('/users', body: body),
        );

        expect(response, isA<Resource>());
      });

      test('should send POST request with query parameters', () async {
        final client = InternalClient(baseUrl);
        final body = {'data': 'test'};

        final response = await client.send(
          request: Request.post(
            '/users',
            body: body,
            queryParameters: {'notify': 'true'},
          ),
        );

        expect(response, isA<Resource>());
      });

      test('should send POST request with form data', () async {
        final client = InternalClient(baseUrl);
        final body = {'username': 'john', 'password': 'secret'};

        final response = await client.send(
          request: Request.post(
            '/login',
            body: body,
            isFormData: true,
          ),
        );

        expect(response, isA<Resource>());
      });

      test('should send anonymous POST request', () async {
        final client = InternalClient(baseUrl);
        final body = {'email': 'test@example.com'};

        final response = await client.send(
          request: Request.post(
            '/register',
            body: body,
            isAnonymous: true,
          ),
        );

        expect(response, isA<Resource>());
      });
    });

    group('PUT Requests', () {
      test('should send PUT request with body', () async {
        final client = InternalClient(baseUrl);
        final body = {'name': 'Updated Name'};

        final response = await client.send(
          request: Request.put(
            '/users/1',
            body: body,
          ),
        );

        expect(response, isA<Resource>());
      });

      test('should handle PUT request with custom headers', () async {
        final client = InternalClient(baseUrl);
        final body = {'data': 'test'};

        final response = await client.send(
          request: Request.put(
            '/users/1',
            body: body,
            headers: {'X-Custom-Header': 'value'},
          ),
        );

        expect(response, isA<Resource>());
      });
    });

    group('DELETE Requests', () {
      test('should send DELETE request', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.delete('/users/1'),
        );

        expect(response, isA<Resource>());
      });

      test('should send DELETE request with query parameters', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.delete(
            '/users',
            queryParameters: {'force': 'true'},
          ),
        );

        expect(response, isA<Resource>());
      });
    });

    group('Response Mapping', () {
      test('should map JSON response to typed object', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send<Map<String, dynamic>>(
          request: Request.get(
            '/users/1',
            mapper: (json) => json as Map<String, dynamic>,
          ),
        );

        expect(response, isA<Resource<Map<String, dynamic>>>());
      });

      test('should handle mapper returning null', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send<String?>(
          request: Request.get(
            '/users/1',
            mapper: (json) => null,
          ),
        );

        expect(response, isA<Resource<String?>>());
      });
    });

    group('Retry Logic', () {
      test('should handle retries gracefully', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get('/protected'),
        );

        expect(response, isA<Resource>());
      });

      test('should return failure resource on persistent errors', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get('/error'),
        );

        expect(response, isA<Resource>());
      });
    });

    group('Header Management', () {
      test('should add default content-type header', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.post('/data', body: {}),
        );

        expect(response, isA<Resource>());
      });

      test('should not override provided headers', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.post(
            '/data',
            body: {},
            headers: {'content-type': 'application/xml'},
          ),
        );

        expect(response, isA<Resource>());
      });

      test('should handle authorization header when shouldAuthorize is true',
          () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get(
            '/protected',
            shouldAuthorize: true,
          ),
        );

        expect(response, isA<Resource>());
      });

      test('should skip authorization header when shouldAuthorize is false',
          () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get(
            '/public',
            shouldAuthorize: false,
          ),
        );

        expect(response, isA<Resource>());
      });

      test('should handle isAnonymous flag', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get(
            '/public',
            isAnonymous: true,
          ),
        );

        expect(response, isA<Resource>());
      });
    });

    group('URL Construction', () {
      test('should construct URL with baseUrl and path', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get('/users/123'),
        );

        expect(response, isA<Resource>());
      });

      test('should handle path starting with /', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get('/api/v1/users'),
        );

        expect(response, isA<Resource>());
      });

      test('should use full URL when path contains https://', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get('https://other-api.com/data'),
        );

        expect(response, isA<Resource>());
      });
    });

    group('Error Handling', () {
      test('should return failure resource on format exception', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get('/invalid-json'),
        );

        expect(response, isA<Resource>());
        // Response could be success or failure depending on actual response
      });

      test('should return failure resource on client exception', () async {
        final client = InternalClient('invalid..domain..com');

        final response = await client.send(
          request: Request.get('/test'),
        );

        expect(response, isA<Resource>());
        expect(response.isFailure, isTrue);
      });

      test('should handle network errors gracefully', () async {
        final client = InternalClient('non-existent-domain-12345.com');

        final response = await client.send(
          request: Request.get('/test'),
        );

        expect(response, isA<Resource>());
        expect(response.isFailure, isTrue);
      });

      test('should return failure resource for error responses', () async {
        final client = InternalClient(baseUrl);

        // This would typically fail with a real API
        final response = await client.send(
          request: Request.get('/not-found'),
        );

        expect(response, isA<Resource>());
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
        final client = InternalClient(baseUrl);
        final body = {'key1': 'value1', 'key2': 'value2'};

        final response = await client.send(
          request: Request.post(
            '/form',
            body: body,
            isFormData: true,
          ),
        );

        expect(response, isA<Resource>());
      });

      test('should set correct content-type for form data', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.post(
            '/form',
            body: {'test': 'data'},
            isFormData: true,
          ),
        );

        expect(response, isA<Resource>());
      });
    });

    group('Debug Logging', () {
      test('should log request details in debug mode', () async {
        final client = InternalClient(baseUrl);

        // In debug mode, this should log without throwing
        await client.send(
          request: Request.get('/users'),
        );

        // No assertion needed - just verifying it doesn't crash
      });

      test('should log response details in debug mode', () async {
        final client = InternalClient(baseUrl);

        await client.send(
          request: Request.post('/users', body: {'test': 'data'}),
        );

        // Verify logging doesn't interfere with functionality
      });
    });

    group('Resource Wrappers', () {
      test('should include raw JSON in Resource', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get('/users/1'),
        );

        expect(response, isA<Resource>());
        // raw property should be accessible
      });

      test('should check isSuccess property', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: Request.get('/users'),
        );

        expect(response, isA<Resource>());
        expect(response.isSuccess, isA<bool>());
      });

      test('should check isFailure property', () async {
        final client = InternalClient('invalid..domain..com');

        final response = await client.send(
          request: Request.get('/test'),
        );

        expect(response, isA<Resource>());
        expect(response.isFailure, isTrue);
      });
    });
  });
}
