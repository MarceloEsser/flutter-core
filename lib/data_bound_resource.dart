import 'package:flutter_core/data_dispatcher.dart';
import 'package:flutter_core/datasources/local/local_resource_strategy.dart';
import 'package:flutter_core/datasources/remote/remote_resource_trategy.dart';
import 'package:flutter_core/datasources/remote/response/reponse.dart';
import 'package:flutter_core/resource.dart';

class DataSourceMediator<Result, Entity, Network> {
  final RemoteDataSource<Result, Response<Network>>? _remoteDataSource;

  final LocalDatasource<Result, Entity>? _localDataSource;

  final Future Function(Response<Network>)? _saveCallResult;

  late final DataDispatcher<Result> _dispatcher;

  DataSourceMediator({
    RemoteDataSource<Result, Response<Network>>? remoteSource,
    LocalDatasource<Result, Entity>? localSource,
    Future<dynamic> Function(Response<Network>)? saveCallResult,
  })  : _saveCallResult = saveCallResult,
        _localDataSource = localSource,
        _remoteDataSource = remoteSource,
        _dispatcher = DataDispatcher<Result>();

  DataDispatcher<Result> factory() {
    if (_localDataSource != null) {
      _localFetch();
    }

    if (_remoteDataSource != null) {
      _createRemoteCall();
    }

    return _dispatcher;
  }

  Future _createRemoteCall() async {
    if ((_remoteDataSource is RemoteDataSource) == false) {
      throw Exception(
        "please, use the RemoteBoundResource as remote data resource",
      );
    }

    final wrapper = await _remoteDataSource?.fetch?.call();
    if (wrapper == null) {
      _sendError("null wrapper on remoteFetch", DataSource.network);
      return;
    }

    final Result? response = _remoteDataSource?.mapper.call(wrapper);
    if (response == null) {
      _sendError("null response on remoteFetch", DataSource.network);
      return;
    }

    if (wrapper.ok() || wrapper.created()) {
      try {
        _dispatcher.send(
          resource: Resource.success(response),
          dataSource: DataSource.network,
        );
        return;
      } catch (e) {
        if (wrapper.message != null) {
          _sendError(
            "remote fetch exception: ${wrapper.message}",
            DataSource.network,
          );
          return;
        }
        _sendError("remote fetch exception: $e", DataSource.network);
      } finally {
        await _saveCallResult?.call(wrapper);
      }
    }

    _sendError(
      wrapper.message ?? "remote fetch exception: $response",
      DataSource.network,
    );
  }

  Future _localFetch() async {
    try {
      final Entity? databaseResult = await this._localDataSource?.get?.call();
      if (databaseResult != null) {
        final Result? response = _localDataSource?.mapper.call(databaseResult);
        _dispatcher.send(
          resource: Resource.success(response),
          dataSource: DataSource.database,
        );
      }
    } catch (e) {
      _sendError(e.toString(), DataSource.database);
    }
  }

  void _sendError(String message, DataSource dataSource) {
    _dispatcher.send(resource: Resource.error(message), dataSource: dataSource);
  }
}
