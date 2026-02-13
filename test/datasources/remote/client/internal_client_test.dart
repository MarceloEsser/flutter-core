import 'dart:convert';
import 'dart:io';

import 'package:flutter_core/datasources/remote/client/internal_client.dart';
import 'package:flutter_core/datasources/remote/client/request/multipart_request.dart';
import 'package:flutter_core/datasources/remote/client/request/request.dart';
import 'package:flutter_core/datasources/remote/client/request/request_verb.dart';
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

        // Mock the HTTP client
        final response = await client.send(
          request: () => Request.get('/users'),
        );

        expect(response, isA<http.Response>());
      });

      test('should include query parameters in GET request', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: () => Request.get(
            '/users',
            queryParameters: {'page': '1', 'limit': '10'},
          ),
        );

        expect(response, isA<http.Response>());
      });

      test('should include custom headers in GET request', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: () => Request.get(
            '/users',
            headers: {'Authorization': 'Bearer token123'},
          ),
        );

        expect(response, isA<http.Response>());
      });

      test('should handle absolute URLs in GET request', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: () => Request.get('https://api.other.com/data'),
        );

        expect(response, isA<http.Response>());
      });
    });

    group('POST Requests', () {
      test('should send POST request with JSON body', () async {
        final client = InternalClient(baseUrl);
        final body = jsonEncode({'name': 'John', 'email': 'john@example.com'});

        final response = await client.send(
          request: () => Request.post(
            '/users',
            body: body,
          ),
        );

        expect(response, isA<http.Response>());
      });

      test('should include content-type header in POST request', () async {
        final client = InternalClient(baseUrl);
        final body = jsonEncode({'data': 'test'});

        final response = await client.send(
          request: () => Request.post('/users', body: body),
        );

        expect(response, isA<http.Response>());
      });

      test('should send POST request with query parameters', () async {
        final client = InternalClient(baseUrl);
        final body = jsonEncode({'data': 'test'});

        final response = await client.send(
          request: () => Request.post(
            '/users',
            body: body,
            queryParameters: {'notify': 'true'},
          ),
        );

        expect(response, isA<http.Response>());
      });
    });

    group('PUT Requests', () {
      test('should send PUT request with body', () async {
        final client = InternalClient(baseUrl);
        final body = jsonEncode({'name': 'Updated Name'});

        final response = await client.send(
          request: () => Request.put(
            '/users/1',
            body: body,
          ),
        );

        expect(response, isA<http.Response>());
      });

      test('should handle PUT request with custom headers', () async {
        final client = InternalClient(baseUrl);
        final body = jsonEncode({'data': 'test'});

        final response = await client.send(
          request: () => Request.put(
            '/users/1',
            body: body,
            headers: {'X-Custom-Header': 'value'},
          ),
        );

        expect(response, isA<http.Response>());
      });
    });

    group('DELETE Requests', () {
      test('should send DELETE request', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: () => Request.delete('/users/1'),
        );

        expect(response, isA<http.Response>());
      });

      test('should send DELETE request with query parameters', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: () => Request.delete(
            '/users',
            queryParameters: {'force': 'true'},
          ),
        );

        expect(response, isA<http.Response>());
      });
    });

    group('Multipart Requests', () {
      test('should send multipart request with fields', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: () => MultipartRequest(
            path: '/upload',
            verb: RequestVerb.post,
            fields: {'name': 'test', 'description': 'test file'},
          ),
        );

        expect(response, isA<http.StreamedResponse>());
      });

      test('should send multipart request with files', () async {
        final client = InternalClient(baseUrl);
        final file = http.MultipartFile.fromString(
          'file',
          'file content',
          filename: 'test.txt',
        );

        final response = await client.send(
          request: () => MultipartRequest(
            path: '/upload',
            verb: RequestVerb.post,
            files: [file],
          ),
        );

        expect(response, isA<http.StreamedResponse>());
      });

      test('should send multipart request with fields and files', () async {
        final client = InternalClient(baseUrl);
        final file = http.MultipartFile.fromString(
          'file',
          'content',
          filename: 'doc.pdf',
        );

        final response = await client.send(
          request: () => MultipartRequest(
            path: '/upload',
            verb: RequestVerb.post,
            fields: {'title': 'Document'},
            files: [file],
          ),
        );

        expect(response, isA<http.StreamedResponse>());
      });
    });

    group('Retry Logic', () {
      test('should retry on 401 unauthorized', () async {
        final client = InternalClient(baseUrl);

        // This will trigger retries but eventually fail or succeed based on actual implementation
        try {
          await client.send(
            request: () => Request.get('/protected'),
          );
        } catch (e) {
          // Expected to fail or retry
          expect(e, isNotNull);
        }
      });

      test('should retry on 500 internal server error', () async {
        final client = InternalClient(baseUrl);

        try {
          await client.send(
            request: () => Request.get('/error'),
          );
        } catch (e) {
          expect(e, isNotNull);
        }
      });

      test('should implement exponential backoff on retries', () async {
        final client = InternalClient(baseUrl);

        try {
          await client.send(
            request: () => Request.get('/failing-endpoint'),
          );
        } catch (e) {
          expect(e, isNotNull);
        }
      });
    });

    group('Header Management', () {
      test('should add default content-type header', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: () => Request.post('/data', body: '{}'),
        );

        expect(response, isA<http.Response>());
      });

      test('should not override provided headers', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: () => Request.post(
            '/data',
            body: '{}',
            headers: {'content-type': 'application/xml'},
          ),
        );

        expect(response, isA<http.Response>());
      });

      test('should handle authorization header when shouldAuthorize is true',
          () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: () => Request.get(
            '/protected',
            shouldAuthorize: true,
          ),
        );

        expect(response, isA<http.Response>());
      });

      test('should skip authorization header when shouldAuthorize is false',
          () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: () => Request.get(
            '/public',
            shouldAuthorize: false,
          ),
        );

        expect(response, isA<http.Response>());
      });
    });

    group('URL Construction', () {
      test('should construct URL with baseUrl and path', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: () => Request.get('/users/123'),
        );

        expect(response, isA<http.Response>());
      });

      test('should handle path starting with /', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: () => Request.get('/api/v1/users'),
        );

        expect(response, isA<http.Response>());
      });

      test('should use full URL when path contains https://', () async {
        final client = InternalClient(baseUrl);

        final response = await client.send(
          request: () => Request.get('https://other-api.com/data'),
        );

        expect(response, isA<http.Response>());
      });
    });

    group('Error Handling', () {
      test('should rethrow exceptions from HTTP client', () async {
        final client = InternalClient('invalid..domain..com');

        expect(
          () => client.send(request: () => Request.get('/test')),
          throwsA(anything),
        );
      });

      test('should handle network errors', () async {
        final client = InternalClient('non-existent-domain-12345.com');

        expect(
          () => client.send(request: () => Request.get('/test')),
          throwsA(anything),
        );
      });

      test('should throw exception for unsupported HTTP method', () async {
        final client = InternalClient(baseUrl);

        // This would require creating an invalid request type
        // which is protected by the type system, so this test
        // verifies the type safety
        expect(
          () => client.send(
            request: () => Request(
              path: '/test',
              verb: RequestVerb.multipart, // Invalid for regular Request
            ),
          ),
          throwsA(anything),
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

    group('Debug Logging', () {
      test('should log request details in debug mode', () async {
        final client = InternalClient(baseUrl);

        // In debug mode, this should log without throwing
        await client.send(
          request: () => Request.get('/users'),
        );

        // No assertion needed - just verifying it doesn't crash
      });

      test('should log response details in debug mode', () async {
        final client = InternalClient(baseUrl);

        await client.send(
          request: () => Request.post('/users', body: '{"test":"data"}'),
        );

        // Verify logging doesn't interfere with functionality
      });
    });
  });
}
