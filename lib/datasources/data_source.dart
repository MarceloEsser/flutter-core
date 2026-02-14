import 'package:flutter_core/datasources/remote/client/http_client_exception.dart';
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
    final response = await _fetchFromRemote();
    // InternalClient now throws on error status codes,
    // so if we reach here, it's a success
    if (response.ok() || response.created()) {
      return _mapper(response);
    }

    // Fallback: throw if somehow we get a non-success response
    throw HttpStatusException(
      statusCode: response.status,
      message: response.message ?? 'Unknown error',
    );
  }

  Future<RemoteResult<R>> fetchWithMetadata() async {
    final response = await _fetchFromRemote();
    // InternalClient now throws on error status codes,
    // so if we reach here, it's a success
    R? data;

    if (response.ok() || response.created()) {
      data = _mapper(response);
    }

    return RemoteResult(
      data: data,
      response: response,
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
