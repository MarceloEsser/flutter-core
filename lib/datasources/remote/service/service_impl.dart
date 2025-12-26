import 'dart:async';
import 'dart:convert';

import 'package:flutter_core/datasources/remote/client/internal_client.dart';
import 'package:flutter_core/datasources/remote/response/reponse.dart';
import 'package:flutter_core/datasources/remote/service/service.dart';
import 'package:http/http.dart' as http;

import '../client/request/multipart_request.dart';
import '../client/request/request.dart';
import '../client/request/request_verb.dart';

class ServiceImpl extends Service {
  final InternalClient _client;

  ServiceImpl() : _client = InternalClient("your_base_url_here");

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, String?>? query,
    Map<String, String>? headers,
    T Function(dynamic)? map,
  }) async {
    final http.Response result = await _client.send(
      request: () => Request(
        path: path,
        verb: RequestVerb.get,
        headers: headers,
        queryParameters: query,
      ),
    );

    var response = jsonDecode(result.body.toString());
    return Response(
      status: result.statusCode,
      metadata: map?.call(response),
      message: result.reasonPhrase,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Map<String, String>? query,
    dynamic body,
    Map<String, String>? headers,
    T Function(dynamic)? map,
  }) async {
    body = jsonEncode(body);
    final http.Response result = await _client.send(
      request: () => Request(
        path: path,
        verb: RequestVerb.post,
        headers: headers,
        body: body,
        queryParameters: query,
      ),
    );

    var response = jsonDecode(result.body.toString());
    return Response(
      status: result.statusCode,
      metadata: map?.call(response),
      message: result.reasonPhrase,
    );
  }

  @override
  Future<int> put(
    String path, {
    Map<String, String>? query,
    dynamic body,
    bool shouldEncode = true,
    bool shouldAuthorize = true,
    Map<String, String>? headers,
  }) async {
    if (shouldEncode) body = jsonEncode(body);

    final http.Response result = await _client.send(
      request: () => Request(
        shouldAuthorize: shouldAuthorize,
        path: path,
        verb: RequestVerb.put,
        headers: headers,
        body: body,
        queryParameters: query,
      ),
    );

    return result.statusCode;
  }

  @override
  Future<int> delete(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final http.Response result = await _client.send(
      request: () => Request(
        path: path,
        verb: RequestVerb.delete,
        headers: headers,
        queryParameters: query,
      ),
    );

    return result.statusCode;
  }

  //Change this method to return only the necessary data ant not StreamedResponse
  //final bytes = await result.stream.toBytes();
  @override
  Future<http.StreamedResponse> multipartRequest(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) async {
    final http.StreamedResponse result = await _client.send(
      request: () => MultipartRequest(
          path: path,
          verb: RequestVerb.post,
          headers: headers,
          files: files,
          fields: fields),
    );
    return result;
  }
}
