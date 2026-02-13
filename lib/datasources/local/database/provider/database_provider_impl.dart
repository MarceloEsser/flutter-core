import 'dart:async';

import 'package:flutter_core/datasources/local/database/provider/database_provider.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseProviderImpl extends DatabaseProvider {
  final String _dbName;
  Database? _database;
  final int _version;
  DatabaseProviderImpl({required String dbName, int version = 1})
      : _dbName = dbName,
        _version = version;

  @override
  Future<String> get path async => await getDatabasesPath();

  @override
  Future<Database> get database async {
    if (_database != null) return _database!;
    try {
      _database = await openDatabase(
        join(await path, _dbName),
        version: _version,
      );
      if (_database == null) {
        throw Exception(
          "Database initialization failed, database instance is null after opening.",
        );
      }
    } catch (e) {
      throw Exception("Error opening database: $e");
    }
    return _database!;
  }

  @override
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }
}
