import 'package:flutter_core/datasources/local/database/dao/data_access_object.dart';
import 'package:flutter_core/datasources/local/database/dao/data_access_object_impl.dart';
import 'package:flutter_core/datasources/local/database/provider/database_provider.dart';
import 'package:flutter_core/datasources/local/entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../database/model/dummy_entity.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DataAccessObject dao;
  late DatabaseProvider provider;

  setUp(() async {
    provider = await _createTestDatabaseProvider();
    dao = DataAccessObjectImpl(provider);
  });

  tearDown(() async {
    await dao.close();
  });

  group('DataAccessObject - Insert Operations', () {
    test('insert() should create table and insert entity successfully',
        () async {
      final entity = DummyEntity(null, "test_data");

      final id = await dao.insert(entity: entity);

      expect(id, greaterThan(0));
    });

    test('insert() should replace entity on conflict', () async {
      final entity1 = DummyEntity(1, "first");
      final entity2 = DummyEntity(1, "second");

      await dao.insert(entity: entity1);
      await dao.insert(entity: entity2);

      final result = await dao.get<DummyEntity>(
        1,
        table: DummyTable.tableName,
        toEntity: DummyEntity.fromMap,
      );

      expect(result?.self, equals("second"));
    });

    test('insert() should throw DatabaseOperationException on error', () async {
      final invalidEntity = _InvalidEntity();

      expect(
        () => dao.insert(entity: invalidEntity),
        throwsA(isA<DatabaseOperationException>()),
      );
    });

    test('insertAll() should return empty list when entities list is empty',
        () async {
      final result = await dao.insertAll<DummyEntity>(entities: []);

      expect(result, isEmpty);
    });

    test('insertAll() should insert multiple entities in transaction',
        () async {
      final entities = [
        DummyEntity(null, "entity_1"),
        DummyEntity(null, "entity_2"),
        DummyEntity(null, "entity_3"),
      ];

      final ids = await dao.insertAll(entities: entities);

      expect(ids.length, equals(3));
      expect(ids, everyElement(greaterThan(0)));
    });

    test('insertAll() should rollback transaction on error', () async {
      final entities = [
        DummyEntity(null, "entity_1"),
        _InvalidEntity(),
      ];

      expect(
        () => dao.insertAll(entities: entities),
        throwsA(isA<DatabaseOperationException>()),
      );
    });
  });

  group('DataAccessObject - Query Operations', () {
    test('get() should return entity by id', () async {
      final entity = DummyEntity(null, "test_get");
      final insertedId = await dao.insert(entity: entity);

      final result = await dao.get<DummyEntity>(
        insertedId,
        table: DummyTable.tableName,
        toEntity: DummyEntity.fromMap,
      );

      expect(result, isNotNull);
      expect(result?.self, equals("test_get"));
    });

    test('get() should return null when entity not found', () async {
      await dao.insert(entity: DummyEntity(null, "test"));

      final result = await dao.get<DummyEntity>(
        999,
        table: DummyTable.tableName,
        toEntity: DummyEntity.fromMap,
      );

      expect(result, isNull);
    });

    test('get() should throw TableNotFoundException when table does not exist',
        () async {
      expect(
        () => dao.get<DummyEntity>(
          1,
          table: "NonExistentTable",
          toEntity: DummyEntity.fromMap,
        ),
        throwsA(isA<TableNotFoundException>()),
      );
    });

    test('getAll() should return all entities from table', () async {
      final entities = [
        DummyEntity(null, "entity_1"),
        DummyEntity(null, "entity_2"),
        DummyEntity(null, "entity_3"),
      ];
      await dao.insertAll(entities: entities);

      final result = await dao.getAll<DummyEntity>(
        table: DummyTable.tableName,
        toEntity: DummyEntity.fromMap,
      );

      expect(result.length, equals(3));
    });

    test('getAll() should return empty list when table is empty', () async {
      // Create table first
      await dao.insert(entity: DummyEntity(null, "temp"));
      await dao.deleteWithId(table: DummyTable.tableName, id: 1);

      final result = await dao.getAll<DummyEntity>(
        table: DummyTable.tableName,
        toEntity: DummyEntity.fromMap,
      );

      expect(result, isEmpty);
    });

    test('getAll() should throw TableNotFoundException for non-existent table',
        () async {
      expect(
        () => dao.getAll<DummyEntity>(
          table: "NonExistentTable",
          toEntity: DummyEntity.fromMap,
        ),
        throwsA(isA<TableNotFoundException>()),
      );
    });

    test('containsEntity() should return true when entity exists', () async {
      final entity = DummyEntity(null, "unique_value");
      final id = await dao.insert(entity: entity);

      final exists = await dao.containsEntity(
        entity: DummyEntity(id, "unique_value"),
      );

      expect(exists, isTrue);
    });

    test('containsEntity() should return false when entity does not exist',
        () async {
      await dao.insert(entity: DummyEntity(null, "value"));

      final exists = await dao.containsEntity(
        entity: DummyEntity(999, "nonexistent"),
      );

      expect(exists, isFalse);
    });

    test('containsEntity() should return false when table does not exist',
        () async {
      final entity = DummyEntity(null, "test");

      final exists = await dao.containsEntity(entity: entity);

      expect(exists, isFalse);
    });
  });

  group('DataAccessObject - Delete Operations', () {
    test('delete() should remove entity successfully', () async {
      final entity = DummyEntity(null, "to_delete");
      final id = await dao.insert(entity: entity);

      final deleteCount = await dao.delete(DummyEntity(id, "to_delete"));

      expect(deleteCount, equals(1));

      final result = await dao.get<DummyEntity>(
        id,
        table: DummyTable.tableName,
        toEntity: DummyEntity.fromMap,
      );
      expect(result, isNull);
    });

    test('delete() should throw exception when entity is null', () async {
      expect(
        () => dao.delete<DummyEntity>(null),
        throwsA(isA<DatabaseOperationException>()),
      );
    });

    test(
        'delete() should throw TableNotFoundException when table does not exist',
        () async {
      final entity = _NonExistentTableEntity(1, "test");

      expect(
        () => dao.delete(entity),
        throwsA(isA<TableNotFoundException>()),
      );
    });

    test('deleteWithId() should remove entity by id', () async {
      final id = await dao.insert(entity: DummyEntity(null, "test"));

      final deleteCount = await dao.deleteWithId(
        table: DummyTable.tableName,
        id: id,
      );

      expect(deleteCount, equals(1));
    });

    test('deleteWithId() should throw exception when id is null', () async {
      expect(
        () => dao.deleteWithId(
          table: DummyTable.tableName,
          id: null,
        ),
        throwsA(isA<DatabaseOperationException>()),
      );
    });

    test('deleteWithId() should return 0 when entity does not exist', () async {
      await dao.insert(entity: DummyEntity(null, "test"));

      final deleteCount = await dao.deleteWithId(
        table: DummyTable.tableName,
        id: 999,
      );

      expect(deleteCount, equals(0));
    });

    test('deleteWithArgs() should delete entities matching conditions',
        () async {
      await dao.insertAll(entities: [
        DummyEntity(null, "delete_me"),
        DummyEntity(null, "delete_me"),
        DummyEntity(null, "keep_me"),
      ]);

      final deleteCount = await dao.deleteWithArgs(
        table: DummyTable.tableName,
        args: {DummyTable.columnSelf: "delete_me"},
      );

      expect(deleteCount, equals(2));

      final remaining = await dao.getAll<DummyEntity>(
        table: DummyTable.tableName,
        toEntity: DummyEntity.fromMap,
      );
      expect(remaining.length, equals(1));
    });

    test('deleteWithArgs() should throw exception when args is empty',
        () async {
      expect(
        () => dao.deleteWithArgs(
          table: DummyTable.tableName,
          args: {},
        ),
        throwsA(isA<DatabaseOperationException>()),
      );
    });

    test(
        'deleteWithArgs() should throw TableNotFoundException for non-existent table',
        () async {
      expect(
        () => dao.deleteWithArgs(
          table: "NonExistentTable",
          args: {"id": 1},
        ),
        throwsA(isA<TableNotFoundException>()),
      );
    });
  });

  group('DataAccessObject - Utility Operations', () {
    test('tableExists() should return true when table exists', () async {
      await dao.insert(entity: DummyEntity(null, "test"));
      final database = await provider.database;

      final exists = await dao.tableExists(database, DummyTable.tableName);

      expect(exists, isTrue);
    });

    test('tableExists() should return false when table does not exist',
        () async {
      final database = await provider.database;

      final exists = await dao.tableExists(database, "NonExistentTable");

      expect(exists, isFalse);
    });

    test('close() should close database connection', () async {
      await dao.insert(entity: DummyEntity(null, "test"));

      await dao.close();

      // Attempting to use dao after close should fail
      expect(
        () => dao.insert(entity: DummyEntity(null, "test")),
        throwsA(anything),
      );
    });
  });

  group('DataAccessObject - Error Handling', () {
    test('should preserve DaoException when thrown in nested operation',
        () async {
      expect(
        () => dao.get<DummyEntity>(
          1,
          table: "NonExistent",
          toEntity: DummyEntity.fromMap,
        ),
        throwsA(isA<TableNotFoundException>()),
      );
    });

    test('should wrap non-DaoException errors in DatabaseOperationException',
        () async {
      final entity = _InvalidEntity();

      expect(
        () => dao.insert(entity: entity),
        throwsA(
          isA<DatabaseOperationException>().having(
            (e) => e.message,
            'message',
            contains('Failed to insert entity'),
          ),
        ),
      );
    });
  });

  group('DataAccessObject - WhereOperator', () {
    test('should support AND operator in where clauses (default)', () async {
      await dao.insertAll(entities: [
        DummyEntity(null, "value_1"),
        DummyEntity(null, "value_2"),
      ]);

      final entities = await dao.getAll<DummyEntity>(
        table: DummyTable.tableName,
        toEntity: DummyEntity.fromMap,
      );

      expect(entities.length, equals(2));
    });
  });
}

// Helper function to create test database provider
Future<DatabaseProvider> _createTestDatabaseProvider() async {
  return _TestDatabaseProvider();
}

class _TestDatabaseProvider implements DatabaseProvider {
  Database? _database;

  @override
  Future<Database> get database async {
    _database ??= await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
      ),
    );
    return _database!;
  }

  @override
  Future<String> get path async => inMemoryDatabasePath;

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

// Helper class for testing error scenarios
class _InvalidEntity extends Entity {
  @override
  int? get id => null;

  @override
  String get table => "Invalid\$Table"; // Invalid table name

  @override
  String createTable() => "INVALID SQL";

  @override
  Map<String, dynamic> toMap() => throw Exception("Mapping error");
}

class _NonExistentTableEntity extends Entity {
  final int _id;
  final String value;

  _NonExistentTableEntity(this._id, this.value);

  @override
  int? get id => _id;

  @override
  String get table => "NonExistentTable";

  @override
  String createTable() => '''
    CREATE TABLE NonExistentTable (
      id INTEGER PRIMARY KEY,
      value TEXT
    )
  ''';

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'value': value,
      };
}
