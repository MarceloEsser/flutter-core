import 'request_verb.dart';

class Request {
  final String path;
  final RequestVerb verb;
  Map<String, String?>? queryParameters;
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
}