import 'dart:io';

sealed class HttpClientException implements Exception {
  final String message;
  final Uri? uri;
  final dynamic cause;

  HttpClientException(this.message, {this.uri, this.cause});

  @override
  String toString() =>
      'HttpClientException: $message${uri != null ? ' ($uri)' : ''}';
}

final class NetworkException extends HttpClientException {
  NetworkException(super.message, {super.uri, super.cause});

  @override
  String toString() =>
      'NetworkException: $message${uri != null ? ' ($uri)' : ''}';
}

final class TimeoutException extends HttpClientException {
  TimeoutException(super.message, {super.uri});

  @override
  String toString() =>
      'TimeoutException: $message${uri != null ? ' ($uri)' : ''}';
}

final class HttpStatusException extends HttpClientException {
  final int statusCode;
  final dynamic responseBody;

  HttpStatusException({
    required this.statusCode,
    required String message,
    Uri? uri,
    this.responseBody,
  }) : super(message, uri: uri);

  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500;
  bool get isUnauthorized => statusCode == HttpStatus.unauthorized;
  bool get isForbidden => statusCode == HttpStatus.forbidden;
  bool get isNotFound => statusCode == HttpStatus.notFound;
  bool get isValidationError => statusCode == 422;
  bool get isBadRequest => statusCode == HttpStatus.badRequest;

  @override
  String toString() =>
      'HttpStatusException($statusCode): $message${uri != null ? ' ($uri)' : ''}';
}

final class JsonParseException extends HttpClientException {
  final String rawBody;

  JsonParseException(super.message, {required this.rawBody, super.uri});

  @override
  String toString() =>
      'JsonParseException: $message${uri != null ? ' ($uri)' : ''}';
}

final class RequestFormatException extends HttpClientException {
  RequestFormatException(super.message, {super.uri, super.cause});

  @override
  String toString() =>
      'RequestFormatException: $message${uri != null ? ' ($uri)' : ''}';
}
