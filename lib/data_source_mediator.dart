import 'package:flutter/foundation.dart';
import 'package:flutter_core/datasources/data_source.dart';
import 'package:flutter_core/datasources/local/database/dao/data_access_object.dart';
import 'package:flutter_core/datasources/remote/client/http_client_exception.dart';
import 'package:flutter_core/datasources/remote/response/reponse.dart';

/// Error types for comprehensive error handling
enum ErrorType {
  // Network errors
  networkError,
  networkTimeout,
  networkUnavailable,

  // HTTP Status errors
  badRequest, // 400
  unauthorized, // 401
  forbidden, // 403
  notFound, // 404
  validationError, // 422
  serverError, // 5xx
  serviceUnavailable, // 503

  // Data errors
  jsonParsingError,
  mapperError,

  // Database errors
  databaseError,
  tableNotFound,
  entityNotFound,

  // Other
  unknown
}

sealed class Result<T> {}

final class Data<T> extends Result<T> {
  final T data;
  final String? message;

  Data(this.data, {this.message});
}

final class Failure<T> extends Result<T> implements Exception {
  final String message;
  final ErrorType type;
  final int? statusCode;
  final dynamic cause;
  final StackTrace? stackTrace;

  Failure(
    this.message, {
    required this.type,
    this.statusCode,
    this.cause,
    this.stackTrace,
  });

  bool get isRetryable =>
      type == ErrorType.networkTimeout ||
      type == ErrorType.networkUnavailable ||
      type == ErrorType.networkError ||
      type == ErrorType.serviceUnavailable ||
      (type == ErrorType.serverError && statusCode == 503);

  bool get isAuthError =>
      type == ErrorType.unauthorized || type == ErrorType.forbidden;

  bool get shouldLogout => type == ErrorType.unauthorized;

  @override
  String toString() => 'Failure($type: $message)';
}

/*
  D - Data type
  N - Network type
  E - Entity type
*/
class DataSourceMediator<D extends Object?, N extends Object?,
    E extends Object?> {
  final RemoteDataSource<D, N>? _remoteDataSource;
  final LocalDataSource<D, E>? _localDataSource;
  final Future Function(Response<N>)? _saveCallResult;

  DataSourceMediator({
    RemoteDataSource<D, N>? remoteDataSource,
    LocalDataSource<D, E>? localDataSource,
    Future<dynamic> Function(Response<N>)? saveCallResult,
  })  : _saveCallResult = saveCallResult,
        _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  factory DataSourceMediator.local({
    required LocalDataSource<D, E> localDataSource,
  }) {
    return DataSourceMediator<D, Never, E>(localDataSource: localDataSource);
  }

  factory DataSourceMediator.remote({
    required RemoteDataSource<D, N> remoteDataSource,
    Future Function(Response<N>)? saveCallResult,
  }) {
    return DataSourceMediator<D, N, Never>(
      remoteDataSource: remoteDataSource,
      saveCallResult: saveCallResult,
    );
  }

  Stream<Result<D?>> execute() async* {
    // Emit cached data first (if local data source exists)
    if (_localDataSource != null) {
      yield* _localStrategyHandler();
    }
    // Then fetch from remote (if remote data source exists)
    if (_remoteDataSource != null) {
      yield* _remoteStrategyHandler();
    }
  }

  Stream<Result<D?>> _localStrategyHandler() async* {
    try {
      final localData = await _localDataSource?.fetch();
      yield Data(localData);
    } on TableNotFoundException catch (e, stackTrace) {
      yield Failure(
        e.message,
        type: ErrorType.tableNotFound,
        cause: e,
        stackTrace: stackTrace,
      );
    } on EntityNotFoundException catch (e, stackTrace) {
      yield Failure(
        e.message,
        type: ErrorType.entityNotFound,
        cause: e,
        stackTrace: stackTrace,
      );
    } on DaoException catch (e, stackTrace) {
      yield Failure(
        e.message,
        type: ErrorType.databaseError,
        cause: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      yield Failure(
        'Local fetch error: $e',
        type: ErrorType.unknown,
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  Stream<Result<D?>> _remoteStrategyHandler() async* {
    try {
      final result = await _remoteDataSource?.fetchWithMetadata();

      if (result?.isSuccessful ?? false) {
        yield Data(result?.data, message: result?.message);

        try {
          if (_saveCallResult != null && result?.response is Response<N>) {
            await _saveCallResult.call(result?.response as Response<N>);
          }
        } on DaoException catch (e) {
          debugPrint('Cache save failed: ${e.message}');
        } catch (e) {
          debugPrint('Cache save failed: $e');
        }
      } else {
        yield Failure(
          result?.message ?? 'Unknown error',
          type: ErrorType.serverError,
        );
      }
    } on HttpStatusException catch (e, stackTrace) {
      yield Failure(
        e.message,
        type: _mapHttpStatusToErrorType(e.statusCode),
        statusCode: e.statusCode,
        cause: e,
        stackTrace: stackTrace,
      );
    } on NetworkException catch (e, stackTrace) {
      yield Failure(
        e.message,
        type: ErrorType.networkError,
        cause: e,
        stackTrace: stackTrace,
      );
    } on TimeoutException catch (e, stackTrace) {
      yield Failure(
        e.message,
        type: ErrorType.networkTimeout,
        cause: e,
        stackTrace: stackTrace,
      );
    } on JsonParseException catch (e, stackTrace) {
      yield Failure(
        e.message,
        type: ErrorType.jsonParsingError,
        cause: e,
        stackTrace: stackTrace,
      );
    } on RequestFormatException catch (e, stackTrace) {
      yield Failure(
        e.message,
        type: ErrorType.badRequest,
        cause: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      yield Failure(
        'Remote fetch error: $e',
        type: ErrorType.unknown,
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  ErrorType _mapHttpStatusToErrorType(int statusCode) {
    switch (statusCode) {
      case 400:
        return ErrorType.badRequest;
      case 401:
        return ErrorType.unauthorized;
      case 403:
        return ErrorType.forbidden;
      case 404:
        return ErrorType.notFound;
      case 422:
        return ErrorType.validationError;
      case 503:
        return ErrorType.serviceUnavailable;
      case >= 500:
        return ErrorType.serverError;
      case >= 400:
        return ErrorType.badRequest;
      default:
        return ErrorType.unknown;
    }
  }
}
