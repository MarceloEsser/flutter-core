import 'package:example/data/viacep/local/model/address_entity.dart';

abstract interface class ViacepDatabase {
  Future<List<AddressEntity>> getAddressByZipCode(String zipCode);

  Future<int> saveAddress(AddressEntity address);
}
