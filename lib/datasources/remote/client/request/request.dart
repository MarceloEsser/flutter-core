import 'request_verb.dart';

class Request {
  final String path;
  final RequestVerb verb;
  final Map<String, String?>? queryParameters;
  Map<String, String>? headers;
  final bool shouldAuthorize;
  final dynamic body;

  Request({
    required this.path,
    required this.verb,
    this.headers,
    this.shouldAuthorize = true,
    this.queryParameters,
    this.body,
  });

  factory Request.get(
    String path, {
    Map<String, String?>? queryParameters,
    Map<String, String>? headers,
    bool shouldAuthorize = true,
  }) {
    return Request(
      path: path,
      verb: RequestVerb.get,
      queryParameters: queryParameters,
      headers: headers,
      shouldAuthorize: shouldAuthorize,
    );
  }

  factory Request.post(
    String path, {
    dynamic body,
    Map<String, String?>? queryParameters,
    Map<String, String>? headers,
    bool shouldAuthorize = true,
  }) {
    return Request(
      path: path,
      verb: RequestVerb.post,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      shouldAuthorize: shouldAuthorize,
    );
  }

  factory Request.put(
    String path, {
    dynamic body,
    Map<String, String?>? queryParameters,
    Map<String, String>? headers,
    bool shouldAuthorize = true,
  }) {
    return Request(
      path: path,
      verb: RequestVerb.put,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      shouldAuthorize: shouldAuthorize,
    );
  }

  factory Request.delete(
    String path, {
    Map<String, String?>? queryParameters,
    Map<String, String>? headers,
    bool shouldAuthorize = true,
  }) {
    return Request(
      path: path,
      verb: RequestVerb.delete,
      queryParameters: queryParameters,
      headers: headers,
      shouldAuthorize: shouldAuthorize,
    );
  }
}
