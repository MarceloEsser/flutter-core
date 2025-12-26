@GenerateNiceMocks([MockSpec<DataAccessObjectImpl>()])
import 'dart:io';

import 'package:flutter_core/data_bound_resource.dart';
import 'package:flutter_core/datasources/local/database/dao/data_access_object_impl.dart';
import 'package:flutter_core/datasources/local/local_resource_strategy.dart';
import 'package:flutter_core/datasources/remote/remote_resource_trategy.dart';
import 'package:flutter_core/datasources/remote/response/reponse.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'data_bound_resource_test.mocks.dart';
import 'database/di/di.dart';
import 'database/model/dummy_entity.dart';
import 'database/model/dummy_network.dart';
import 'model/dummy_model.dart';

void main() {
  setUpAll(() {
    setupDatabase();
  });

  group('DataBoundResource test group: ', () {
    test(
      'DataBoundResource should send the database result as models when the query and the map finish',
      () async {
        var database = MockDataAccessObjectImpl();
        when(
          database.getAll(
            table: DummyTable.tableName,
            toEntity: DummyEntity.fromMap,
          ),
        ).thenAnswer((realInvocation) async => dummyEntityList);

        final dataBoundResource = DataSourceMediator(
          localSource: LocalDatasource.build(
            get: () async {
              final result = await database.getAll<DummyEntity>(
                table: DummyTable.tableName,
                toEntity: DummyEntity.fromMap,
              );

              return result;
            },
            mapper: (raw) => raw.map((e) => e.toModel()).toList(),
          ),
        ).factory();

        final resource = await dataBoundResource.localCompleter;
        assert(resource.data is List<DummyModel>);
      },
    );

    test(
      'DataBoundResource should send the network result when the fetch finish',
      () async {
        final mediator = DataSourceMediator(
          remoteSource: RemoteDataSource.build(
            fetch: () async {
              return Response(
                status: HttpStatus.ok,
                metadata: dummyNetworkList,
              );
            },
            mapper: (raw) => raw.metadata?.map((e) => e.toModel()).toList(),
          ),
        ).factory();

        final resource = await mediator.networkCompleter;
        expect(resource.data?.length, 4);
      },
    );
  });
}

final List<DummyEntity> dummyEntityList = [
  DummyEntity(1, "dummy1"),
  DummyEntity(2, "dummy2"),
  DummyEntity(3, "dummy3"),
  DummyEntity(4, "dummy4"),
];

final List<DummyNetwork> dummyNetworkList = [
  DummyNetwork(1, "dummy1"),
  DummyNetwork(2, "dummy2"),
  DummyNetwork(3, "dummy3"),
  DummyNetwork(4, "dummy4"),
];
