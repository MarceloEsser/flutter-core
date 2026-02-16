import 'package:example/data/viacep/remote/model/viacep_network.dart';
import 'package:flutter_core/datasources/remote/response/reponse.dart';

abstract class ViacepService {
  Future<Response<AddressNetwork?>> fetchAddressByZipCode(String zipCode);
}
