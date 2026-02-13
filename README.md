# Flutter Core

A comprehensive Flutter package providing robust data layer infrastructure with local database management, HTTP client operations, and flexible data source coordination.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/flutter-%3E%3D3.0.0-blue.svg)](https://flutter.dev)

## 🚀 Features

- **Local Database Management**
  - Type-safe SQLite operations with automatic table creation
  - Transaction support for atomic batch operations
  - Comprehensive error handling with specific exceptions
  - Generic DAO pattern for CRUD operations

- **HTTP Client**
  - Built-in retry mechanism with exponential backoff
  - Support for GET, POST, PUT, DELETE, and Multipart requests
  - Automatic header management
  - Flexible authorization handling

- **Data Source Abstraction**
  - Local data source with entity ↔ model mapping
  - Remote data source with response handling
  - Stream-based data mediator for coordinating multiple sources
  - Cache-first or network-first strategies

- **Clean Architecture**
  - Separation of concerns
  - Dependency injection ready
  - Testable components
  - Extensible design

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_core:
    git:
      url: https://github.com/yourusername/flutter-core.git
      ref: main
```

Then run:

```bash
flutter pub get
```

## 🏗️ Architecture

### Core Components

```
flutter_core/
├── datasources/
│   ├── local/
│   │   ├── database/
│   │   │   ├── dao/              # Data Access Object
│   │   │   └── provider/         # Database Provider
│   │   └── entity.dart           # Entity base class
│   ├── remote/
│   │   ├── client/               # HTTP Client
│   │   ├── response/             # Response wrappers
│   │   └── service/              # Service layer
│   └── data_source.dart          # DataSource abstractions
├── data_source_mediator.dart     # Mediator pattern
└── resource.dart                  # Resource wrapper
```

## 📖 Usage

### Local Database Operations

#### 1. Define Your Entity

```dart
import 'package:flutter_core/datasources/local/entity.dart';

class UserEntity extends Entity {
  final int? _id;
  final String name;
  final String email;

  UserEntity(this._id, this.name, this.email);

  @override
  int? get id => _id;

  @override
  String get table => 'users';

  @override
  String createTable() => '''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT NOT NULL
    )
  ''';

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
  };

  factory UserEntity.fromMap(Map<String, dynamic> map) {
    return UserEntity(
      map['id'] as int?,
      map['name'] as String,
      map['email'] as String,
    );
  }
}
```

#### 2. Use the DAO

```dart
import 'package:flutter_core/datasources/local/database/dao/data_access_object.dart';
import 'package:flutter_core/datasources/local/database/dao/data_access_object_impl.dart';

class UserRepository {
  final DataAccessObject _dao;

  UserRepository(this._dao);

  // Insert a user
  Future<int> addUser(UserEntity user) async {
    return await _dao.insert(entity: user);
  }

  // Get user by ID
  Future<UserEntity?> getUser(int id) async {
    return await _dao.get<UserEntity>(
      id,
      table: 'users',
      toEntity: UserEntity.fromMap,
    );
  }

  // Get all users
  Future<List<UserEntity>> getAllUsers() async {
    return await _dao.getAll<UserEntity>(
      table: 'users',
      toEntity: UserEntity.fromMap,
    );
  }

  // Update user
  Future<int> updateUser(UserEntity user) async {
    return await _dao.insert(entity: user); // Uses replace strategy
  }

  // Delete user
  Future<int> deleteUser(UserEntity user) async {
    return await _dao.delete(user);
  }

  // Batch insert
  Future<List<int>> addUsers(List<UserEntity> users) async {
    return await _dao.insertAll(entities: users);
  }

  // Delete with custom conditions
  Future<int> deleteByEmail(String email) async {
    return await _dao.deleteWithArgs(
      table: 'users',
      args: {'email': email},
    );
  }
}
```

### HTTP Client Operations

#### 1. Setup the Client

```dart
import 'package:flutter_core/datasources/remote/client/internal_client.dart';
import 'package:flutter_core/datasources/remote/client/request/request.dart';

final client = InternalClient('api.example.com');

// GET request
final response = await client.send(
  request: () => Request.get(
    '/users',
    queryParameters: {'page': '1', 'limit': '10'},
  ),
);

// POST request
final postResponse = await client.send(
  request: () => Request.post(
    '/users',
    body: jsonEncode({'name': 'John', 'email': 'john@example.com'}),
    headers: {'Authorization': 'Bearer token'},
  ),
);

// PUT request
final putResponse = await client.send(
  request: () => Request.put(
    '/users/1',
    body: jsonEncode({'name': 'John Updated'}),
  ),
);

// DELETE request
final deleteResponse = await client.send(
  request: () => Request.delete('/users/1'),
);
```

#### 2. Multipart Upload

```dart
import 'package:flutter_core/datasources/remote/client/request/multipart_request.dart';
import 'package:http/http.dart' as http;

final file = http.MultipartFile.fromString(
  'document',
  'file content',
  filename: 'document.pdf',
);

final response = await client.send(
  request: () => MultipartRequest(
    path: '/upload',
    verb: RequestVerb.post,
    fields: {'title': 'My Document'},
    files: [file],
  ),
);
```

### Data Source Mediation

#### 1. Define Your Data Sources

```dart
import 'package:flutter_core/datasources/data_source.dart';
import 'package:flutter_core/data_source_mediator.dart';

// Local data source
final localDataSource = LocalDataSource<UserModel, UserEntity>(
  fetchFromLocal: () async {
    final entity = await dao.get<UserEntity>(
      userId,
      table: 'users',
      toEntity: UserEntity.fromMap,
    );
    return entity;
  },
  mapper: (entity) => UserModel(
    id: entity.id,
    name: entity.name,
    email: entity.email,
  ),
);

// Remote data source
final remoteDataSource = RemoteDataSource<UserModel, UserDto>(
  fetchFromRemote: () async {
    final response = await client.send(
      request: () => Request.get('/users/$userId'),
    );
    return Response<UserDto>(
      metadata: UserDto.fromJson(jsonDecode(response.body)),
      status: response.statusCode,
      message: 'Success',
    );
  },
  mapper: (response) => UserModel.fromDto(response.metadata!),
);
```

#### 2. Use the Mediator

```dart
// Cache-first with network fallback
final mediator = DataSourceMediator<UserModel, UserDto, UserEntity>(
  localStrategy: localDataSource,
  remoteStrategy: remoteDataSource,
  saveCallResult: (response) async {
    // Save remote data to local cache
    await dao.insert(
      entity: UserEntity.fromDto(response.metadata!),
    );
  },
);

// Listen to data stream
mediator.execute().listen((result) {
  result switch {
    Data(data: final user) => print('Got user: ${user.name}'),
    Failure(message: final msg) => print('Error: $msg'),
  };
});
```

#### 3. Strategy Variations

```dart
// Local only
final localOnly = DataSourceMediator.local(
  localStrategy: localDataSource,
);

// Remote only
final remoteOnly = DataSourceMediator.remote(
  remoteStrategy: remoteDataSource,
  saveCallResult: (response) async {
    // Optional: save to cache
  },
);
```

## 🛡️ Error Handling

The package provides comprehensive exception handling:

### Database Exceptions

```dart
try {
  final user = await dao.get<UserEntity>(
    1,
    table: 'users',
    toEntity: UserEntity.fromMap,
  );
} on TableNotFoundException catch (e) {
  print('Table not found: ${e.tableName}');
} on DatabaseOperationException catch (e) {
  print('Database error: ${e.message}');
  print('Cause: ${e.cause}');
}
```

### Exception Types

- `DaoException` - Base exception for DAO operations
- `TableNotFoundException` - Table doesn't exist in database
- `DatabaseOperationException` - General database operation failure
- `EntityNotFoundException` - Specific entity not found

## 🧪 Testing

The package includes comprehensive test coverage:

```bash
# Run all tests
flutter test

# Run specific test suite
flutter test test/datasources/local/database/dao/data_access_object_test.dart

# Run with coverage
flutter test --coverage
```

### Test Coverage

- ✅ DataAccessObject: 30+ tests
- ✅ InternalClient: 30+ tests
- ✅ DataSource: 32+ tests
- ✅ DataSourceMediator: 45+ tests
- ✅ Integration tests

See [TEST_SUMMARY.md](test/TEST_SUMMARY.md) for detailed coverage information.

## 🔧 Advanced Features

### Custom WHERE Operators

```dart
// AND operator (default)
await dao.deleteWithArgs(
  table: 'users',
  args: {'status': 'inactive', 'verified': false},
  // WHERE status = ? AND verified = ?
);

// For OR operations, extend the DAO or use raw queries
```

### Transaction Support

```dart
// Batch operations use transactions automatically
final ids = await dao.insertAll(entities: users);
// All succeed or all fail (atomic)
```

### Retry Configuration

The HTTP client includes automatic retry with exponential backoff:

- Retries: 3 attempts
- Conditions: 401 Unauthorized, 500 Internal Server Error
- Delay: Exponential (1s, 2s, 3s)

## 📋 Requirements

- Flutter SDK: >= 3.0.0
- Dart SDK: >= 3.0.0

### Dependencies

- `sqflite`: SQLite database
- `http`: HTTP client
- `logging`: Logging support

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with clean architecture principles
- Inspired by the repository pattern
- Follows Flutter best practices

## 📞 Support

For issues, questions, or suggestions:

- Open an issue on [GitHub](https://github.com/yourusername/flutter-core/issues)
- Read the [documentation](https://github.com/yourusername/flutter-core/wiki)

---

