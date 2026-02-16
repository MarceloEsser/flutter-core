import 'package:example/data/viacep/repository/model/address.dart';
import 'package:flutter_core/data_source_mediator.dart';

abstract class ViacepRepository {
  Stream<Result<Address?>> fetchAddressByZipCode(String zipCode);
}
