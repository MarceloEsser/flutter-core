import 'package:flutter_core/datasources/local/entity.dart';
import 'package:sqflite/sqflite.dart';

abstract class DataAccessObject {
  Future<int> insert<T extends Entity>({required T entity});

  Future<List<int>> insertAll<T extends Entity>({
    required List<T> entities,
  });

  Future<T?> get<T extends Entity>(
    int id, {
    required String table,
    required T Function(Map<String, Object?>) toEntity,
  });

  Future<List<T>> getAll<T extends Entity>({
    required String table,
    required T Function(Map<String, Object?>) toEntity,
    Map<String, dynamic>? args,
  });

  Future<bool> containsEntity<T extends Entity>({
    required T entity,
  });

  Future<int> delete<T extends Entity>(T? entity);

  Future<int> deleteWithId({required String table, required int? id});

  Future<int> deleteWithArgs({
    required String table,
    required Map<String, dynamic> args,
  });

  Future<bool> tableExists(DatabaseExecutor database, String tableName);

  Future<void> close();
}

sealed class DaoException implements Exception {
  final String message;
  final Object? cause;

  DaoException(this.message, {this.cause});

  @override
  String toString() =>
      'DaoException: $message${cause != null ? '\nCaused by: $cause' : ''}';
}

final class TableNotFoundException extends DaoException {
  final String tableName;

  TableNotFoundException(this.tableName)
      : super('Table "$tableName" does not exist');
}

final class DatabaseOperationException extends DaoException {
  DatabaseOperationException(super.message, {super.cause});
}

final class EntityNotFoundException extends DaoException {
  EntityNotFoundException(String message) : super(message);
}
