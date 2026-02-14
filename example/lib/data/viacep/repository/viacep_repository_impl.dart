import 'package:example/data/viacep/local/model/address_entity.dart';
import 'package:example/data/viacep/local/viacep_database.dart';
import 'package:example/data/viacep/local/viacep_database_impl.dart';
import 'package:example/data/viacep/remote/model/viacep_network.dart';
import 'package:example/data/viacep/remote/viacep_service.dart';
import 'package:example/data/viacep/remote/viacep_service_impl.dart';
import 'package:example/data/viacep/repository/model/address.dart';
import 'package:example/data/viacep/repository/viacep_repository.dart';
import 'package:flutter_core/data_source_mediator.dart';
import 'package:flutter_core/datasources/data_source.dart';

class ViacepRepositoryImpl implements ViacepRepository {
  final ViacepService _service;
  final ViacepDatabase _storage;

  ViacepRepositoryImpl({ViacepService? service, ViacepDatabase? storage})
    : _service = service ?? ViacepServiceImpl(),
      _storage = storage ?? ViacepDatabaseImpl();

  @override
  Stream<Result<Address?>> fetchAddressByZipCode(String zipCode) async* {
    yield* DataSourceMediator<Address?, AddressNetwork?, AddressEntity?>(
      remoteDataSource: RemoteDataSource(
        fetchFromRemote: () async {
          return await _service.fetchAddressByZipCode(zipCode);
        },
        mapper: (response) {
          return response.data?.toModel();
        },
      ),
      localDataSource: LocalDataSource(
        fetchFromLocal: () async {
          final result = await _storage.getAddressByZipCode(zipCode);
          return result.firstOrNull;
        },
        mapper: (entity) => entity?.toModel(),
      ),
      saveCallResult: (network) async {
        final networkData = network.data;
        if (networkData != null) {
          await _storage.saveAddress(networkData.toEntity());
        }
      },
    ).execute();
  }
}
