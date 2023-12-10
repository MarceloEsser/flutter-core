import 'package:flutter_core/datasources/resource_strategy.dart';
import 'package:flutter_core/datasources/remote/response/response_wrapper.dart';

class RemoteResourceStrategy<T> extends ResourceStrategy<T, ResponseWrapper> {
  RemoteResourceStrategy.handler({
    required Future<ResponseWrapper>? Function()? fetch,
    Future<ResponseWrapper>? Function(dynamic)? send,
    T Function(ResponseWrapper)? mapServiceResult,
  }) : super.build(fetch: fetch, send: send, mapper: mapServiceResult);
}
