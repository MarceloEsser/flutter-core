import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_core/datasources/remote/client/request/multipart_request.dart';
import 'package:flutter_core/datasources/remote/client/request/request.dart';
import 'package:flutter_core/datasources/remote/client/request/request_verb.dart';
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

  Future<dynamic> send<T extends Request>({
    required T Function() request,
  }) async {
    try {
      T req = request();
      var uri = Uri.parse('https://$_baseUrl${req.path}');
      if (req.path.contains('https://')) uri = Uri.parse(req.path);

      await _addHeaders(req);

      if (req.queryParameters != null) {
        uri = uri.replace(queryParameters: req.queryParameters);
      }

      debug('Sending @${req.verb.name.toUpperCase()}: $uri');
      debug('Header: ${req.headers}');

      if (T == MultipartRequest) {
        final MultipartRequest req = request() as MultipartRequest;
        debug('Fields: ${req.fields}');
        debug('Files: ${req.files?.map((e) => e.filename)}');

        final result = await _sendMultipartRequest(uri, req: req);
        debug('Result @${req.verb.name.toUpperCase()}: $uri');
        debug('Header: ${result.headers}');
        debug('Status: ${result.statusCode}');

        return result;
      }

      if (req.verb != RequestVerb.get) {
        debug('Body: ${req.body.toString()}');
      }

      var result = await _sendRequest(req.body, uri, req);

      debug('Result @${req.verb.name.toUpperCase()}: $uri');
      debug('Header: ${result.headers}');
      debug('Status: ${result.statusCode}');
      debug('Response: ${result.body}');

      return result;
    } catch (e) {
      debug('Result: $e');
      rethrow;
    }
  }

  Future<http.StreamedResponse> _sendMultipartRequest(
    Uri uri, {
    required MultipartRequest req,
  }) async {
    final String verb = req.verb.name.toUpperCase();
    final request = http.MultipartRequest(verb, uri);

    request.headers.addAll({...?req.headers});
    request.fields.addAll({...?req.fields});
    request.files.addAll([...?req.files]);

    return await request.send();
  }

  Future<dynamic> _sendRequest(
    dynamic encodedBody,
    Uri uri,
    Request req,
  ) async {
    var method = _methods(
      body: encodedBody,
      uri: uri,
      headers: req.headers,
    )[req.verb];

    if (method == null) throw Exception('Method not found');
    final result = await method.call();
    return result;
  }

  Future<void> _addHeaders(Request req) async {
    req.headers ??= {};
    final baseHeaders = await _getBaseHeaders(req.shouldAuthorize);
    baseHeaders.forEach((key, value) {
      req.headers?.putIfAbsent(key, () => value);
    });
  }

  Future<Map<String, String>> _getBaseHeaders(bool shouldAuthorize) async {
    //TODO: Add bearer here if necessary
    final Map<String, String> header = {
      'content-type': 'application/json',
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
}

void debug(
  String? message, {
  Object? error,
  StackTrace? stackTrace,
  Level level = Level.ALL,
}) {
  if (kDebugMode) {
    developer.log(message ?? 'message: NULL',
        error: error, stackTrace: stackTrace);
  }
}

extension BaseResponseStatusExtension on http.BaseResponse {
  bool unauthorized() => statusCode == HttpStatus.unauthorized;
  bool internalServerError() => statusCode == HttpStatus.internalServerError;
}
