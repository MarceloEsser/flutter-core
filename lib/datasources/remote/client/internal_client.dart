import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_core/datasources/remote/client/http_client_exception.dart';
import 'package:flutter_core/datasources/remote/client/request/request.dart';
import 'package:flutter_core/datasources/remote/client/request/request_verb.dart';
import 'package:flutter_core/datasources/remote/response/reponse.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:logging/logging.dart';

final class InternalClient {
  final String _baseUrl;
  final log = Logger('HttpClient');
  final http.Client _inner;

  InternalClient(this._baseUrl, {http.Client? client})
      : _inner = client ?? http.Client();

  http.Client get _client => RetryClient(
        _inner,
        retries: 3,
        when: _retryWhen,
        whenError: _retryWhenError,
        delay: _retryDelay,
        onRetry: _onRetry,
      );

  Future<Response<T>> send<T>({
    required Request request,
  }) async {
    late Uri uri;

    try {
      if (!request.path.contains('https')) {
        uri = Uri.parse('https://$_baseUrl${request.path}');
      } else {
        uri = Uri.parse(request.path);
      }
    } on FormatException catch (e) {
      throw RequestFormatException(
        'Invalid URL format: ${e.message}',
        cause: e,
      );
    }

    await _addHeaders(request);

    if (request.queryParameters != null) {
      uri = uri.replace(queryParameters: request.queryParameters);
    }

    debug('Sending @${request.verb.name.toUpperCase()}: $uri');
    debug('Header: ${request.headers}');

    if (request.verb != RequestVerb.get) {
      debug('Body: ${jsonEncode(request.body).toString()}');
    }

    String encodeMap(Map data) {
      return data.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
    }

    try {
      final formattedBody =
          request.isFormData ? encodeMap(request.body) : request.body;
      return await _sendRequest<T>(
        json.encode(formattedBody),
        uri,
        request,
      );
    } on FormatException catch (e) {
      throw RequestFormatException(
        'Invalid request format: ${e.message}',
        uri: uri,
        cause: e,
      );
    } on SocketException catch (e) {
      throw NetworkException(
        'Network unavailable: ${e.message}',
        uri: uri,
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw NetworkException(
        'HTTP client error: ${e.message}',
        uri: uri,
        cause: e,
      );
    }
  }

  Future<Response<T>> _sendRequest<T>(
    dynamic encodedBody,
    Uri uri,
    Request request,
  ) async {
    var method = _methods(
      body: encodedBody,
      uri: uri,
      headers: request.headers,
      isFormData: request.isFormData,
    )[request.verb];

    if (method == null) {
      throw RequestFormatException('Invalid HTTP verb: ${request.verb}',
          uri: uri);
    }

    final response = await method().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('Request timeout after 30s', uri: uri);
      },
    );

    dynamic json;
    bool isJsonResponse = false;

    if (response.bodyBytes.isNotEmpty) {
      try {
        final decodedBody = utf8.decode(response.bodyBytes);
        json = jsonDecode(decodedBody);
        isJsonResponse = true;
      } catch (e) {
        final contentType = response.headers['content-type'];
        if (contentType?.contains('application/json') ?? false) {
          throw JsonParseException(
            'Failed to parse JSON response: ${e.toString()}',
            rawBody: utf8.decode(response.bodyBytes),
            uri: uri,
          );
        }
        debug('Non-JSON response: ${utf8.decode(response.bodyBytes)}');
        json = null;
      }
    }

    debug('Result @${request.verb.name.toUpperCase()}: $uri');
    debug('Header: ${response.headers}');
    debug('Status: ${response.statusCode}');
    if (isJsonResponse && json != null) {
      debug('Response: ${jsonEncode(json)}');
    } else if (response.bodyBytes.isNotEmpty) {
      debug('Response: ${utf8.decode(response.bodyBytes)}');
    }

    if (response.statusCode >= 400) {
      throw HttpStatusException(
        statusCode: response.statusCode,
        message: response.reasonPhrase ?? 'HTTP Error ${response.statusCode}',
        uri: uri,
        responseBody: json ?? utf8.decode(response.bodyBytes),
      );
    }

    return Response<T>(
      data: request.mapper?.call(json),
      raw: json ?? utf8.decode(response.bodyBytes),
      status: response.statusCode,
      message: response.reasonPhrase,
    );
  }

  Future<void> _addHeaders(Request request) async {
    request.headers ??= {};
    final baseHeaders = await _getBaseHeaders(
      request.isFormData,
      request.isAnonymous,
    );
    baseHeaders.forEach((key, value) {
      request.headers?.putIfAbsent(key, () => value);
    });
  }

  Future<Map<String, String>> _getBaseHeaders(
    bool isFormData,
    bool isAnonymous,
  ) async {
    //TODO: Add bearer token here if necessary
    final contentType = isFormData
        ? 'application/x-www-form-urlencoded'
        : 'application/json; charset=utf-8';
    final Map<String, String> header = {
      if (!isFormData) 'accept': 'application/json',
      'Content-Type': contentType,
    };
    return header;
  }

  FutureOr<bool> _retryWhen(http.BaseResponse response) {
    //TODO: Implement the logic to handle to token refresh when unauthorized
    return response.unauthorized() || response.internalServerError();
  }

  FutureOr<bool> _retryWhenError(Object error, StackTrace stackTrace) {
    //TODO: implement better error handling
    debug('_retryWhenError', error: error, stackTrace: stackTrace);
    return true;
  }

  Duration _retryDelay(int retryCount) {
    return Duration(seconds: retryCount);
  }

  FutureOr<void> _onRetry(
    http.BaseRequest request,
    http.BaseResponse? response,
    int retryCount,
  ) async {
    if (response == null) {
      debug("Retry: ${request.url}");
      debug("Cause: No response received (network error or timeout)");
      return;
    }

    debug("Retry: ${request.url}");
    debug("Cause: ${response.reasonPhrase}");

    //TODO: should refresh token or expire the session
  }

  Map<RequestVerb, Future Function()> _methods({
    required Uri uri,
    required Map<String, String>? headers,
    dynamic body,
    bool isFormData = false,
  }) {
    return {
      RequestVerb.get: () async => await _client.get(
            uri,
            headers: headers,
          ),
      RequestVerb.post: () async => await _client.post(
            uri,
            headers: headers,
            body: body,
            encoding: Encoding.getByName("utf-8"),
          ),
      RequestVerb.put: () async => await _client.put(
            uri,
            headers: headers,
            body: body,
            encoding: Encoding.getByName("utf-8"),
          ),
      RequestVerb.delete: () async => await _client.delete(
            uri,
            headers: headers,
          ),
    };
  }

  void debug(
    String? message, {
    Object? error,
    StackTrace? stackTrace,
    Level level = Level.ALL,
  }) {
    if (kDebugMode) {
      log.log(level, message ?? '', error, stackTrace);
    }
  }
}

extension BaseResponseStatusExtension on http.BaseResponse {
  bool unauthorized() => statusCode == HttpStatus.unauthorized;
  bool internalServerError() => statusCode == HttpStatus.internalServerError;
}
