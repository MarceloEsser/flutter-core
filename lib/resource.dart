class Resource<T> {
  final String? message;
  final Status status;
  final T? data;
  final dynamic raw;

  Resource({
    this.message,
    required this.status,
    this.data,
    this.raw,
  });

  Resource.success(
    this.data, {
    this.message,
    this.raw,
  }) : status = Status.success;

  Resource.failure({
    this.message,
    this.data,
    this.raw,
  }) : status = Status.error;

  bool get isFailure => status == Status.error;
  bool get isSuccess => status == Status.success;
}

enum Status { success, error }

extension StatusExtension on Status {
  bool isSuccessful() => this == Status.success;
}
