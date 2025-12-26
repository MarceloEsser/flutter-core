import 'package:flutter_core/datasources/remote/response/reponse.dart';

sealed class DataSource<Result> {
  Future<Result?> fetch();
}

final class LocalDataSource<R, E> implements DataSource<R> {
  final Future<E?> Function() _fetchFromLocal;
  final R Function(E) _mapper;

  LocalDataSource({
    required Future<E?> Function() fetchFromLocal,
    required R Function(E) mapper,
  })  : _fetchFromLocal = fetchFromLocal,
        _mapper = mapper;

  @override
  Future<R?> fetch() async {
    final entity = await _fetchFromLocal();
    if (entity == null) return null;
    return _mapper(entity);
  }
}

class RemoteDataSource<R, N> implements DataSource<R> {
  final Future<Response<N>> Function() _fetchFromRemote;
  final R Function(Response<N>) _mapper;

  RemoteDataSource({
    required Future<Response<N>> Function() fetchFromRemote,
    required R Function(Response<N>) mapper,
  })  : _fetchFromRemote = fetchFromRemote,
        _mapper = mapper;

  @override
  Future<R?> fetch() async {
    final wrapper = await _fetchFromRemote();
    if (wrapper.ok() || wrapper.created()) {
      return _mapper(wrapper);
    }
    return null;
  }

  Future<RemoteResult<R>> fetchWithMetadata() async {
    final wrapper = await _fetchFromRemote();
    R? data;

    if (wrapper.ok() || wrapper.created()) {
      data = _mapper(wrapper);
    }

    return RemoteResult(
      data: data,
      response: wrapper,
    );
  }
}

class RemoteResult<R> {
  final R? data;
  final Response response;

  RemoteResult({
    required this.data,
    required this.response,
  });

  bool get isSuccessful => response.ok() || response.created();
  String? get message => response.message;
}
