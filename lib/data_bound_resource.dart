import 'package:flutter_core/datasources/resource_strategy.dart';
import 'package:flutter_core/datasources/remote/remote_resource_trategy.dart';
import 'package:flutter_core/datasources/remote/response/response_wrapper.dart';
import 'package:flutter_core/resource.dart';
import 'package:flutter_core/result.dart';

class DataBoundResource<T> {
  final ResourceStrategy<T, ResponseWrapper<dynamic>>? remoteStrategy;
  final ResourceStrategy<T, dynamic>? localStrategy;
  final Future Function(ResponseWrapper<dynamic>)? saveCallResult;

  late final Result<T> _result;

  DataBoundResource({
    this.remoteStrategy,
    this.localStrategy,
    this.saveCallResult,
  }) : _result = Result<T>();

  Result<T> build() {
    if (localStrategy != null) {
      _localFetch();
    }

    if (remoteStrategy != null) {
      _remoteFetch();
    }

    return _result;
  }

  Future _remoteFetch() async {
    if ((remoteStrategy is RemoteResourceStrategy) == false) {
      throw Exception(
        "please, use the RemoteBoundResource as remote data resource",
      );
    }

    final wrapper = await remoteStrategy?.fetch?.call();
    if (wrapper == null) {
      _sendError("null wrapper on remoteFetch", DataSource.network);
      return;
    }

    final T? response = remoteStrategy?.mapper?.call(wrapper);
    if (response == null) {
      _sendError("null response on remoteFetch", DataSource.network);
      return;
    }

    if (wrapper.ok() || wrapper.created()) {
      try {
        _result.send(
          resource: Resource.success(response),
          dataSource: DataSource.network,
        );
        return;
      } catch (e) {
        if (wrapper.message != null) {
          _sendError(
              "remote fetch exception: ${wrapper.message}", DataSource.network);
          return;
        }
        _sendError("remote fetch exception: $e", DataSource.network);
      } finally {
        await saveCallResult?.call(wrapper);
      }
    }

    _sendError(
      wrapper.message ?? "remote fetch exception: $response",
      DataSource.network,
    );
  }

  void _sendError(String message, DataSource dataSource) {
    _result.send(resource: Resource.error(message), dataSource: dataSource);
  }

  Future _localFetch() async {
    try {
      final dynamic data = await this.localStrategy?.fetch?.call();
      if (localStrategy?.mapper != null) {
        final T? response = localStrategy?.mapper?.call(data);
        _result.send(
          resource: Resource.success(response),
          dataSource: DataSource.database,
        );
        return;
      }

      _result.send(
        resource: Resource.success(data),
        dataSource: DataSource.database,
      );
    } catch (e) {
      _sendError(e.toString(), DataSource.database);
    }
  }
}
