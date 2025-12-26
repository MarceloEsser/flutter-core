import 'dart:async';
import 'dart:isolate';

import 'package:flutter_core/datasources/remote/client/internal_client.dart';
import 'package:flutter_core/resource.dart';

enum DataSource { database, network }

class DataDispatcher<T> {
  final _receivePort = ReceivePort();
  final Completer<Resource<T>> _networkCompleter = Completer();
  final Completer<Resource<T>> _localCompleter = Completer();

  SendPort get _sendPort => _receivePort.sendPort;

  Future<Resource<T>> get networkCompleter async =>
      await _networkCompleter.future;

  Future<Resource<T>> get localCompleter async => await _localCompleter.future;

  void send({required Resource<T> resource, required DataSource dataSource}) {
    _sendPort.send(resource);
    _complete(resource, dataSource);
  }

  void _complete(Resource<T> message, DataSource dataSource) {
    if (dataSource == DataSource.database && !_localCompleter.isCompleted) {
      _localCompleter.complete(message);
      return;
    }
    if (!_networkCompleter.isCompleted) {
      _networkCompleter.complete(message);
    }
  }

  collect(
    Function(Resource<T> resource) onData, {
    Function(Object error)? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    try {
      return _receivePort.listen(
        (message) {
          onData.call(message as Resource<T>);
        },
        onError: (e) {
          onError?.call(e);
          debug(e.toString(), error: e);
        },
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
    } catch (e) {
      onError?.call(e);
      debug(e.toString(), error: e);
    }

    return null;
  }
}
