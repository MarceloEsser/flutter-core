import 'package:flutter/foundation.dart';
import 'package:flutter_core/datasources/local/database/dao/data_access_object.dart';
import 'package:flutter_core/datasources/local/entity.dart';
import 'package:sqflite/sqflite.dart';

import '../provider/database_provider.dart';

class DataAccessObjectImpl implements DataAccessObject {
  final DatabaseProvider _provider;

  Future<Database> get _database async => _provider.database;

  DataAccessObjectImpl(this._provider);

  @override
  Future<int> insert<T extends Entity>({required T entity}) async {
    return _executeWithErrorHandling(
      operation: () async {
        final database = await _database;
        return _insert(database, entity);
      },
      errorMessage: 'Failed to insert entity into table: ${entity.table}',
    );
  }

  @override
  Future<List<int>> insertAll<T extends Entity>({
    required List<T> entities,
  }) async {
    if (entities.isEmpty) return [];

    return _executeWithErrorHandling(
      operation: () async {
        final database = await _database;
        final List<int> ids = [];

        await database.transaction((txn) async {
          for (final entity in entities) {
            await _ensureTableExists(txn, entity);
            final id = await txn.insert(
              entity.table,
              entity.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            ids.add(id);
          }
        });

        return ids;
      },
      errorMessage: 'Failed to insert batch of ${entities.length} entities',
    );
  }

  @override
  Future<T?> get<T extends Entity>(
    int id, {
    required T Function(Map<String, Object?>) toEntity,
    required String table,
  }) async {
    return _executeWithErrorHandling(
      operation: () async {
        final database = await _database;
        await _validateTableExists(database, table);

        final result = await database.query(
          table,
          where: 'id = ?',
          whereArgs: [id],
        );

        return result.isEmpty ? null : toEntity(result.first);
      },
      errorMessage: 'Failed to get entity with id $id from table: $table',
    );
  }

  @override
  Future<List<T>> getAll<T extends Entity>({
    required String table,
    required T Function(Map<String, Object?>) toEntity,
  }) async {
    return _executeWithErrorHandling(
      operation: () async {
        final database = await _database;
        await _validateTableExists(database, table);

        final result = await database.query(table);
        return result.map(toEntity).toList();
      },
      errorMessage: 'Failed to get all entities from table: $table',
    );
  }

  @override
  Future<bool> containsEntity<T extends Entity>({
    required T entity,
  }) async {
    return _executeWithErrorHandling(
      operation: () async {
        final database = await _database;

        final tableExistsResult = await tableExists(database, entity.table);
        if (!tableExistsResult) return false;

        final whereClause = _buildWhereClause(entity.toMap());
        final result = await database.query(
          entity.table,
          where: whereClause.condition,
          whereArgs: whereClause.arguments,
        );

        return result.isNotEmpty;
      },
      errorMessage:
          'Failed to check if entity exists in table: ${entity.table}',
    );
  }

  @override
  Future<int> delete<T extends Entity>(T? entity) async {
    if (entity == null) {
      throw DatabaseOperationException('Cannot operate with null entity');
    }

    return _executeWithErrorHandling(
      operation: () async {
        final database = await _database;
        return _deleteById(database, entity.table, entity.id);
      },
      errorMessage: 'Failed to delete entity from table: ${entity.table}',
    );
  }

  @override
  Future<int> deleteWithId({required String table, required int? id}) async {
    if (id == null) {
      throw DatabaseOperationException('Cannot operate with null id');
    }

    return _executeWithErrorHandling(
      operation: () async {
        final database = await _database;
        return _deleteById(database, table, id);
      },
      errorMessage: 'Failed to delete entity with id $id from table: $table',
    );
  }

  @override
  Future<int> deleteWithArgs({
    required String table,
    required Map<String, dynamic> args,
  }) async {
    if (args.isEmpty) {
      throw DatabaseOperationException(
        'Cannot delete with empty arguments - this would delete all rows',
      );
    }

    return _executeWithErrorHandling(
      operation: () async {
        final database = await _database;
        await _validateTableExists(database, table);

        final whereClause = _buildWhereClause(args);
        return await database.delete(
          table,
          where: whereClause.condition,
          whereArgs: whereClause.arguments,
        );
      },
      errorMessage: 'Failed to delete with args from table: $table',
    );
  }

  @visibleForTesting
  @override
  Future<bool> tableExists(
    DatabaseExecutor database,
    String tableName,
  ) async {
    return _executeWithErrorHandling(
      operation: () async {
        final tables = await database.query('sqlite_master');
        return tables.any((table) => table['name'] == tableName);
      },
      errorMessage: 'Failed to check if table exists: $tableName',
    );
  }

  @override
  Future<void> close() async {
    return _executeWithErrorHandling(
      operation: () async {
        final db = await _database;
        await db.close();
      },
      errorMessage: 'Failed to close database connection',
    );
  }

  Future<int> _insert(DatabaseExecutor database, Entity entity) async {
    await _ensureTableExists(database, entity);

    return await database.insert(
      entity.table,
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> _deleteById(
    DatabaseExecutor database,
    String table,
    int? id,
  ) async {
    _validateNotNull(id, 'id');
    await _validateTableExists(database, table);

    return await database.delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _ensureTableExists(
    DatabaseExecutor database,
    Entity entity,
  ) async {
    final exists = await tableExists(database, entity.table);
    if (!exists) {
      await database.execute(entity.createTable());
    }
  }

  void _validateNotNull(Object? value, String paramName) {
    if (value == null) {
      throw DatabaseOperationException('Cannot operate with null $paramName');
    }
  }

  Future<void> _validateTableExists(
    DatabaseExecutor database,
    String table,
  ) async {
    final exists = await tableExists(database, table);
    if (!exists) {
      throw TableNotFoundException(table);
    }
  }

  _WhereClause _buildWhereClause(
    Map<String, dynamic> conditions, {
    WhereOperator operator = WhereOperator.and,
  }) {
    final separator = operator == WhereOperator.and ? ' AND ' : ' OR ';
    final condition = conditions.keys.map((key) => '$key = ?').join(separator);
    final arguments = conditions.values.toList();

    return _WhereClause(condition: condition, arguments: arguments);
  }

  Future<T> _executeWithErrorHandling<T>({
    required Future<T> Function() operation,
    required String errorMessage,
  }) async {
    try {
      return await operation();
    } catch (e) {
      if (e is DaoException) rethrow;
      throw DatabaseOperationException(errorMessage, cause: e);
    }
  }
}

class _WhereClause {
  final String condition;
  final List<dynamic> arguments;

  const _WhereClause({
    required this.condition,
    required this.arguments,
  });
}

enum WhereOperator {
  and,
  or,
}
