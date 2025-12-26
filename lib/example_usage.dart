import 'package:flutter_core/data_source_mediator.dart';
import 'package:flutter_core/datasources/local/local_data_source_strategy.dart';
import 'package:flutter_core/datasources/remote/remote_data_source_strategy.dart';
import 'package:flutter_core/datasources/remote/response/reponse.dart';

/// Example usage demonstrating how to use the refactored strategy pattern.
void exampleUsage() async {
  // Example 1: Creating a local data source strategy
  final localStrategy = LocalDataSourceStrategy<UserModel, UserEntity>(
    fetchFromLocal: () async {
      // Your database/cache fetch logic here
      final entity = await database.getUserEntity();
      return entity;
    },
    mapper: (entity) {
      // Convert entity to model
      return UserModel.fromEntity(entity);
    },
  );

  // Example 2: Creating a remote data source strategy
  final remoteStrategy = RemoteDataSourceStrategy<UserModel, UserDto>(
    fetchFromRemote: () async {
      // Your API call logic here
      final response = await apiClient.getUser();
      return response;
    },
    mapper: (wrapper) {
      // Convert network response to model
      final dto = wrapper.data;
      return UserModel.fromDto(dto);
    },
  );

  // Example 3: Creating the mediator with both strategies
  final mediator = DataSourceMediator<UserModel, UserDto>(
    localStrategy: localStrategy,
    remoteStrategy: remoteStrategy,
    saveCallResult: (wrapper) async {
      // Save the fresh data to database
      final dto = wrapper.metadata;
      await database.saveUser(UserEntity.fromDto(dto));
    },
  );

  // Example 4: Execute and listen to data updates
  final stream = mediator.execute();

  await for (final result in stream) {
    if (result is Data<UserModel>) {
      print('Received data: ${result.data}');
      print('User: ${result.data.name}');
    } else if (result is Error) {
      print('Error: ${result.message}');
    }
  }

  // Alternative: Using listen() for non-blocking stream consumption
  stream.listen(
    (result) {
      if (result is Data<UserModel>) {
        print('Received data: ${result.data}');
      } else if (result is Error) {
        print('Error: ${result.message}');
      }
    },
    onError: (error) {
      print('Stream error: $error');
    },
    onDone: () {
      print('Stream completed');
    },
  );
}

// Example model classes (for demonstration)
class UserModel {
  final String id;
  final String name;

  UserModel({required this.id, required this.name});

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(id: entity.id, name: entity.name);
  }

  factory UserModel.fromDto(UserDto dto) {
    return UserModel(id: dto.userId, name: dto.userName);
  }
}

class UserEntity {
  final String id;
  final String name;

  UserEntity({required this.id, required this.name});

  factory UserEntity.fromDto(UserDto dto) {
    return UserEntity(id: dto.userId, name: dto.userName);
  }
}

class UserDto {
  final String userId;
  final String userName;

  UserDto({required this.userId, required this.userName});
}

// Mock classes for the example
class database {
  static Future<UserEntity> getUserEntity() async => throw UnimplementedError();
  static Future<void> saveUser(UserEntity entity) async =>
      throw UnimplementedError();
}

class apiClient {
  static Future<Response<UserDto>> getUser() async =>
      throw UnimplementedError();
}
