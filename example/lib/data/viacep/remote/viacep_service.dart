import 'package:example/data/viacep/remote/model/viacep_network.dart';
import 'package:flutter_core/resource.dart';

abstract class ViacepService {
  Future<Resource<AddressNetwork?>> fetchAddressByZipCode(String zipCode);
}
