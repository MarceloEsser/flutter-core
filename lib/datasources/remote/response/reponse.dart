import 'dart:io';

class Response<T> {
  final T? metadata;
  final int? status;
  final String? message;

  Response({this.metadata, required this.status, this.message});
}

extension ResponseWrapperStatusExtension on Response {
  bool ok() => status == HttpStatus.ok;
  bool created() => status == HttpStatus.ok;
}
