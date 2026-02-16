import 'package:example/data/viacep/local/model/address_entity.dart';
import 'package:example/data/viacep/local/viacep_database.dart';
import 'package:flutter_core/datasources/local/database/dao/data_access_object_impl.dart';
import 'package:flutter_core/datasources/local/database/provider/database_provider_impl.dart';

class ViacepDatabaseImpl implements ViacepDatabase {
  final _storage = DataAccessObjectImpl(
    DatabaseProviderImpl(dbName: 'viacep.db', version: 1),
  );

  @override
  Future<List<AddressEntity>> getAddressByZipCode(String zipCode) async {
    return await _storage.getAll(
      table: AddressEntity.tableName,
      toEntity: AddressEntity.fromMap,
      args: {'cep': zipCode}, // Fixed: use 'cep' not 'zipCode'
    );
  }

  @override
  Future<int> saveAddress(AddressEntity address) async {
    return await _storage.insert(entity: address);
  }
}
