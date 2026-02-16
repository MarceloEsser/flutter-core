import 'dart:io';

class Response<T> {
  final T? data;
  final dynamic raw;
  final int status;
  final String? message;

  Response({
    this.data,
    this.raw,
    required this.status,
    this.message,
  });

  bool get isSuccessful => status >= 200 && status < 300;
  bool ok() => status == HttpStatus.ok;
  bool created() => status == HttpStatus.created;
  bool noContent() => status == HttpStatus.noContent;
  bool accepted() => status == HttpStatus.accepted;

  bool get isClientError => status >= 400 && status < 500;
  bool get isServerError => status >= 500;
  bool get isAuthError => isUnauthorized() || isForbidden();

  bool isBadRequest() => status == HttpStatus.badRequest;
  bool isUnauthorized() => status == HttpStatus.unauthorized;
  bool isForbidden() => status == HttpStatus.forbidden;
  bool isNotFound() => status == HttpStatus.notFound;
  bool isValidationError() => status == 422;
  bool isServerErrorStatus() => status == HttpStatus.internalServerError;
  bool isServiceUnavailable() => status == HttpStatus.serviceUnavailable;
}
