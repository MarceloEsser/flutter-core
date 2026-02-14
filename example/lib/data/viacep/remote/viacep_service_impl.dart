import 'package:example/data/viacep/remote/model/viacep_network.dart';
import 'package:example/data/viacep/remote/viacep_service.dart';
import 'package:flutter_core/datasources/remote/client/internal_client.dart';
import 'package:flutter_core/datasources/remote/client/request/request.dart';
import 'package:flutter_core/datasources/remote/response/reponse.dart';

class ViacepServiceImpl implements ViacepService {
  final _client = InternalClient('https://viacep.com.br/ws/');

  @override
  Future<Response<AddressNetwork?>> fetchAddressByZipCode(String zipCode) async {
    return await _client.send<AddressNetwork?>(
      request: Request.get(
        '$zipCode/json/',
        mapper: (json) => AddressNetwork.fromJson(json),
      ),
    );
  }
}
