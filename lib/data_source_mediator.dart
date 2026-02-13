import 'package:flutter_core/datasources/data_source.dart';
import 'package:flutter_core/datasources/remote/response/reponse.dart';

sealed class Result {}

final class Data<T> extends Result {
  final T data;
  final String? message;

  Data(this.data, {this.message});
}

final class Failure extends Result implements Exception {
  final String message;

  Failure(this.message);

  @override
  String toString() => 'DataSourceMediator Failure: $message';
}

/*
  D - Data type
  N - Network type
  E - Entity type
*/
final class DataSourceMediator<D extends Object?, N extends Object?,
    E extends Object?> {
  final RemoteDataSource<D, N>? _remoteStrategy;
  final LocalDataSource<D, E>? _localStrategy;
  final Future Function(Response<N>)? _saveCallResult;

  DataSourceMediator({
    RemoteDataSource<D, N>? remoteStrategy,
    LocalDataSource<D, E>? localStrategy,
    Future<dynamic> Function(Response<N>)? saveCallResult,
  })  : _saveCallResult = saveCallResult,
        _localStrategy = localStrategy,
        _remoteStrategy = remoteStrategy;

  factory DataSourceMediator.local({
    required LocalDataSource<D, E> localStrategy,
  }) {
    return DataSourceMediator<D, Never, E>(localStrategy: localStrategy);
  }

  factory DataSourceMediator.remote({
    required RemoteDataSource<D, N> remoteStrategy,
    Future Function(Response<N>)? saveCallResult,
  }) {
    return DataSourceMediator<D, N, Never>(
      remoteStrategy: remoteStrategy,
      saveCallResult: saveCallResult,
    );
  }

  Stream<Result> execute() async* {
    if (_remoteStrategy != null) {
      yield* _remoteStrategyHandler();
    }
    if (_localStrategy != null) {
      yield* _localStrategyHandler();
    }
  }

  Stream<Result> _localStrategyHandler() async* {
    try {
      final localData = await _localStrategy?.fetch();
      yield Data(localData);
    } catch (e) {
      yield Failure("Local fetch error: $e");
    }
  }

  Stream<Result> _remoteStrategyHandler() async* {
    final result = await _remoteStrategy?.fetchWithMetadata();
    if (result?.isSuccessful ?? false) {
      yield Data(result?.data as D, message: result?.message);
      try {
        if (_saveCallResult != null && result?.response is Response<N>) {
          await _saveCallResult.call(result?.response as Response<N>);
        }
      } catch (e) {
        yield Failure("Save call result error: $e");
      }
    } else {
      yield Failure(result?.message ?? "Unknown error");
    }
  }
}
