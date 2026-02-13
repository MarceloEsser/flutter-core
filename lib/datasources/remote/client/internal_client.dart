import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_core/datasources/remote/client/request/request.dart';
import 'package:flutter_core/datasources/remote/client/request/request_verb.dart';
import 'package:flutter_core/resource.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:logging/logging.dart';

final class InternalClient {
  final String _baseUrl;
  final log = Logger('HttpClient');
  final _inner = http.Client();

  InternalClient(this._baseUrl);

  http.Client get _client => RetryClient(
        _inner,
        retries: 3,
        when: _retryWhen,
        whenError: _retryWhenError,
        delay: _retryDelay,
        onRetry: _onRetry,
      );

  Future<Resource<T>> send<T>({
    required Request request,
  }) async {
    try {
      late Uri uri;
      if (!request.path.contains('https')) {
        uri = Uri.parse('https://$_baseUrl${request.path}');
      } else {
        uri = Uri.parse(request.path);
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

      final formattedBody =
          request.isFormData ? encodeMap(request.body) : request.body;
      return await _sendRequest<T>(
        json.encode(formattedBody),
        uri,
        request,
      );
    } on FormatException catch (f) {
      final message = '${f.message}: ${f.source}';
      debug(message);
      return Resource.failure(message: message);
    } on http.ClientException catch (c) {
      final message = '${c.uri}: ${c.message}';
      debug(message);
      return Resource.failure(message: message);
    } catch (e) {
      debug('Result: $e');
      return Resource.failure(message: e.toString());
    }
  }

  Future<Resource<T>> _sendRequest<T>(
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
      throw Exception('Method not found');
    }

    final response = await method();
    dynamic json;
    bool isJsonResponse = false;

    if (response.bodyBytes.isNotEmpty) {
      try {
        final decodedBody = utf8.decode(response.bodyBytes);
        json = jsonDecode(decodedBody);
        isJsonResponse = true;
      } catch (e) {
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

    if (response.statusCode >= HttpStatus.ok &&
        response.statusCode < HttpStatus.multipleChoices) {
      return Resource.success(
        request.mapper?.call(json),
        raw: json,
        message: response.reasonPhrase,
      );
    }
    return Resource.failure(raw: json, message: response.reasonPhrase);
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
    if (response == null) throw Exception('_onRetry Response is null');

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
