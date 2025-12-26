import 'package:flutter_core/datasources/remote/response/reponse.dart';
import 'package:http/http.dart' as http;

abstract class Service {
  Future<Response<T>> get<T>(
    String path, {
    Map<String, String?>? query,
    Map<String, String>? headers,
  });

  Future<Response<T>> post<T>(
    String path, {
    Map<String, String>? query,
    dynamic body,
    Map<String, String>? headers,
  });

  Future<int> put(
    String path, {
    Map<String, String>? query,
    dynamic body,
    bool shouldAuthorize,
    Map<String, String>? headers,
  });

  Future<int> delete(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  });

  Future<http.StreamedResponse> multipartRequest(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<http.MultipartFile> files,
  });
}
