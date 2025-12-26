import 'package:flutter_core/datasources/data_source.dart';
import 'package:flutter_core/datasources/remote/response/reponse.dart';

sealed class Result {}

final class Data<T> implements Result {
  final T data;
  final String? message;

  Data(this.data, {this.message});
}

final class Error implements Result {
  final String message;

  Error(this.message);
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
    yield* _localStrategyHandler();
    yield* _remoteStrategyHandler();
  }

  Stream<Result> _localStrategyHandler() async* {
    if (_localStrategy != null) {
      try {
        final localData = await _localStrategy.fetch();
        if (localData != null) {
          yield Data(localData);
        }
      } catch (e) {
        yield Error("Local fetch error: $e");
      }
    }
  }

  Stream<Result> _remoteStrategyHandler() async* {
    if (_remoteStrategy != null) {
      final result = await _remoteStrategy.fetchWithMetadata();
      if (result.isSuccessful) {
        if (result.data != null) {
          yield Data(result.data as D, message: result.message);
        }
        if (_saveCallResult != null && result.response is Response<N>) {
          await _saveCallResult.call(result.response as Response<N>);
        }
      } else {
        yield Error(result.message ?? "Unknown error");
      }
    }
  }
}
