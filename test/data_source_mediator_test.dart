import 'dart:io';

import 'package:flutter_core/data_source_mediator.dart';
import 'package:flutter_core/datasources/data_source.dart';
import 'package:flutter_core/datasources/remote/response/reponse.dart';
import 'package:flutter_test/flutter_test.dart';

// Test models
class UserModel {
  final String id;
  final String name;

  UserModel({required this.id, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'UserModel(id: $id, name: $name)';
}

class UserEntity {
  final String id;
  final String name;

  UserEntity({required this.id, required this.name});
}

class UserDto {
  final String id;
  final String name;

  UserDto({required this.id, required this.name});
}

void main() {
  group('DataSourceMediator -', () {
    late UserModel testUser;
    late UserEntity testEntity;
    late UserDto testDto;
    late Response<UserDto> successResponse;
    late Response<UserDto> errorResponse;

    setUp(() {
      testUser = UserModel(id: '1', name: 'Test User');
      testEntity = UserEntity(id: '1', name: 'Test User');
      testDto = UserDto(id: '1', name: 'Test User');
      successResponse = Response<UserDto>(
        data: testDto,
        status: HttpStatus.ok,
        message: 'Success',
      );
      errorResponse = Response<UserDto>(
        data: testDto,
        status: HttpStatus.badRequest,
        message: 'Bad Request',
      );
    });

    group('Constructor', () {
      test('creates mediator with both strategies', () {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => testUser,
        );

        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator<UserModel, UserDto, UserEntity>(
          localDataSource: localStrategy,
          remoteDataSource: remoteStrategy,
        );

        expect(mediator, isNotNull);
      });

      test('creates mediator with only local strategy', () {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => testUser,
        );

        final mediator = DataSourceMediator<UserModel, Never, UserEntity>(
          localDataSource: localStrategy,
        );

        expect(mediator, isNotNull);
      });

      test('creates mediator with only remote strategy', () {
        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator<UserModel, UserDto, Never>(
          remoteDataSource: remoteStrategy,
        );

        expect(mediator, isNotNull);
      });
    });

    group('Factory constructors', () {
      test('local factory creates mediator with only local strategy', () {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => testUser,
        );

        final mediator = DataSourceMediator.local(
          localDataSource: localStrategy,
        );

        expect(mediator, isNotNull);
      });

      test('remote factory creates mediator with only remote strategy', () {
        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteDataSource: remoteStrategy,
        );

        expect(mediator, isNotNull);
      });
    });

    group('execute - Local Strategy', () {
      test('yields data when local fetch succeeds', () async {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => testUser,
        );

        final mediator = DataSourceMediator.local(
          localDataSource: localStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Data<UserModel?>>());
        expect((results[0] as Data<UserModel?>).data, testUser);
      });

      test('yields Data with null when local fetch returns null', () async {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => null,
          mapper: (entity) => testUser,
        );

        final mediator = DataSourceMediator.local(
          localDataSource: localStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Data<UserModel?>>());
        expect((results[0] as Data<UserModel?>).data, isNull);
      });

      test('yields error when local fetch throws exception', () async {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => throw Exception('Database error'),
          mapper: (entity) => testUser,
        );

        final mediator = DataSourceMediator.local(
          localDataSource: localStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Failure>());
        expect((results[0] as Failure).message, contains('Local fetch error'));
        expect((results[0] as Failure).message, contains('Database error'));
      });
    });

    group('execute - Remote Strategy', () {
      test('yields data when remote fetch succeeds', () async {
        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteDataSource: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Data<UserModel?>>());
        expect((results[0] as Data<UserModel?>).data, testUser);
      });

      test('includes message in data when available', () async {
        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteDataSource: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Data<UserModel?>>());
        expect((results[0] as Data<UserModel?>).message, 'Success');
      });

      test('yields Failure when remote fetch throws exception', () async {
        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => throw Exception('Network error'),
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteDataSource: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Failure>());
        expect((results[0] as Failure).message, contains('Remote fetch error'));
        expect((results[0] as Failure).message, contains('Network error'));
      });

      test('yields Failure when response throws for non-success status',
          () async {
        final noMessageResponse = Response<UserDto>(
          data: testDto,
          status: 500,
          message: null,
        );

        // InternalClient throws on 500, so simulate that
        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => throw Exception('Internal Server Error'),
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteDataSource: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Failure>());
        expect((results[0] as Failure).type, ErrorType.unknown);
      });

      test('yields Data with null when mapper returns null', () async {
        final remoteStrategy = RemoteDataSource<UserModel?, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => null,
        );

        final mediator = DataSourceMediator.remote(
          remoteDataSource: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Data<UserModel?>>());
        expect((results[0] as Data<UserModel?>).data, isNull);
      });

      test('calls saveCallResult when provided and fetch succeeds', () async {
        bool saveCalled = false;
        Response<UserDto>? savedResponse;

        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteDataSource: remoteStrategy,
          saveCallResult: (response) async {
            saveCalled = true;
            savedResponse = response;
          },
        );

        await mediator.execute().toList();

        expect(saveCalled, true);
        expect(savedResponse, successResponse);
      });

      test('does not call saveCallResult when fetch throws exception',
          () async {
        bool saveCalled = false;

        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => throw Exception('Network error'),
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteDataSource: remoteStrategy,
          saveCallResult: (response) async {
            saveCalled = true;
          },
        );

        await mediator.execute().toList();

        expect(saveCalled, false);
      });
    });

    group('execute - Both Strategies', () {
      test('yields local data first, then remote data', () async {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => UserModel(id: '1', name: 'Local User'),
        );

        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => UserModel(id: '1', name: 'Remote User'),
        );

        final mediator = DataSourceMediator<UserModel, UserDto, UserEntity>(
          localDataSource: localStrategy,
          remoteDataSource: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 2);
        expect(results[0], isA<Data<UserModel?>>());
        expect((results[0] as Data<UserModel?>).data?.name, 'Local User');
        expect(results[1], isA<Data<UserModel?>>());
        expect((results[1] as Data<UserModel?>).data?.name, 'Remote User');
      });

      test('yields only remote data when local returns null', () async {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => null,
          mapper: (entity) => testUser,
        );

        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator<UserModel, UserDto, UserEntity>(
          localDataSource: localStrategy,
          remoteDataSource: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Data<UserModel?>>());
      });

      test('yields local data and remote error', () async {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => testUser,
        );

        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => errorResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator<UserModel, UserDto, UserEntity>(
          localDataSource: localStrategy,
          remoteDataSource: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 2);
        expect(results[0], isA<Data<UserModel?>>());
        expect(results[1], isA<Failure>());
      });

      test('saves remote data to local when saveCallResult is provided',
          () async {
        bool saveCalled = false;

        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => testUser,
        );

        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator<UserModel, UserDto, UserEntity>(
          localDataSource: localStrategy,
          remoteDataSource: remoteStrategy,
          saveCallResult: (response) async {
            saveCalled = true;
          },
        );

        await mediator.execute().toList();

        expect(saveCalled, true);
      });
    });

    group('execute - Edge Cases', () {
      test('handles empty mediator (no strategies)', () async {
        final mediator = DataSourceMediator<UserModel, UserDto, UserEntity>();

        final results = await mediator.execute().toList();

        expect(results.length, 0);
      });

      test('creates new stream on each execute call', () async {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => testUser,
        );

        final mediator = DataSourceMediator.local(
          localDataSource: localStrategy,
        );

        // Each execute() call should create a new stream
        final results1 = await mediator.execute().toList();
        final results2 = await mediator.execute().toList();

        expect(results1.length, 1);
        expect(results2.length, 1);
        expect((results1[0] as Data<UserModel?>).data, testUser);
        expect((results2[0] as Data<UserModel?>).data, testUser);
      });

      test('throws error when listening to same stream twice', () async {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => testUser,
        );

        final mediator = DataSourceMediator.local(
          localDataSource: localStrategy,
        );

        final stream = mediator.execute();

        // First listen should work
        final results1 = await stream.toList();
        expect(results1.length, 1);

        // Second listen on same stream should throw
        expect(
          () => stream.toList(),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Result Types -', () {
      test('Data should contain data and optional message', () {
        final data = Data(testUser, message: 'Success message');

        expect(data.data, equals(testUser));
        expect(data.message, equals('Success message'));
      });

      test('Data should work without message', () {
        final data = Data(testUser);

        expect(data.data, equals(testUser));
        expect(data.message, isNull);
      });

      test('Failure should be an Exception', () {
        final failure = Failure('Error occurred', type: ErrorType.unknown);

        expect(failure, isA<Exception>());
        expect(failure, isA<Result>());
      });

      test('Failure toString should include message', () {
        final failure = Failure('Custom error', type: ErrorType.networkError);

        expect(failure.toString(), contains('Failure'));
        expect(failure.toString(), contains('Custom error'));
      });
    });

    group('SaveCallResult Error Handling -', () {
      test('yields failure when saveCallResult throws exception', () async {
        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteDataSource: remoteStrategy,
          saveCallResult: (response) async {
            throw Exception('Save failed');
          },
        );

        final results = await mediator.execute().toList();

        expect(results.length, 2);
        expect(results[0], isA<Data<UserModel?>>());
        expect(results[1], isA<Failure>());
        expect((results[1] as Failure).message,
            contains('Save call result error'));
      });

      test('yields data before saveCallResult error', () async {
        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteDataSource: remoteStrategy,
          saveCallResult: (response) async {
            throw Exception('Save error');
          },
        );

        final results = await mediator.execute().toList();

        // Should get data first, then failure from save
        expect(results.length, 2);
        final firstResult = results[0] as Data<UserModel?>;
        expect(firstResult.data, equals(testUser));
      });

      test('continues execution after saveCallResult error', () async {
        bool saveAttempted = false;

        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteDataSource: remoteStrategy,
          saveCallResult: (response) async {
            saveAttempted = true;
            throw Exception('Save failed');
          },
        );

        final results = await mediator.execute().toList();

        expect(saveAttempted, isTrue);
        expect(results.length, 2); // Data + Failure from save error
      });
    });

    group('Complex Scenarios -', () {
      test('handles local success and remote success with save', () async {
        List<String> executionOrder = [];

        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async {
            executionOrder.add('local_fetch');
            return testEntity;
          },
          mapper: (entity) => testUser,
        );

        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async {
            executionOrder.add('remote_fetch');
            return successResponse;
          },
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator<UserModel, UserDto, UserEntity>(
          localDataSource: localStrategy,
          remoteDataSource: remoteStrategy,
          saveCallResult: (response) async {
            executionOrder.add('save');
          },
        );

        final results = await mediator.execute().toList();

        expect(results.length, 2);
        expect(executionOrder, ['local_fetch', 'remote_fetch', 'save']);
      });

      test('handles concurrent executions independently', () async {
        int fetchCount = 0;

        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async {
            fetchCount++;
            await Future.delayed(const Duration(milliseconds: 10));
            return testEntity;
          },
          mapper: (entity) => testUser,
        );

        final mediator = DataSourceMediator.local(
          localDataSource: localStrategy,
        );

        // Execute concurrently
        final future1 = mediator.execute().toList();
        final future2 = mediator.execute().toList();
        final future3 = mediator.execute().toList();

        await Future.wait([future1, future2, future3]);

        expect(fetchCount, equals(3));
      });

      test('handles different data types in stream', () async {
        final localStrategy = LocalDataSource<int, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => int.parse(entity.id),
        );

        final mediator = DataSourceMediator.local(
          localDataSource: localStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect((results[0] as Data<int?>).data, equals(1));
      });

      test('preserves response metadata throughout stream', () async {
        final customResponse = Response<UserDto>(
          data: testDto,
          status: HttpStatus.ok,
          message: 'Operation completed successfully',
        );

        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => customResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteDataSource: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        final data = results[0] as Data<UserModel?>;
        expect(data.message, equals('Operation completed successfully'));
      });

      test('handles nullable data types correctly', () async {
        final localStrategy = LocalDataSource<UserModel?, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => entity.name.isEmpty ? null : testUser,
        );

        final mediator = DataSourceMediator.local(
          localDataSource: localStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect((results[0] as Data<UserModel?>).data, isNotNull);
      });
    });

    group('Performance and Memory -', () {
      test('handles large number of results efficiently', () async {
        final items = List.generate(
          100,
          (i) => UserEntity(id: '$i', name: 'User $i'),
        );

        int index = 0;
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => items[index++ % items.length],
          mapper: (entity) => UserModel(id: entity.id, name: entity.name),
        );

        final mediator = DataSourceMediator.local(
          localDataSource: localStrategy,
        );

        // Execute multiple times
        for (int i = 0; i < 100; i++) {
          final results = await mediator.execute().toList();
          expect(results.length, 1);
        }

        expect(index, equals(100));
      });

      test('does not leak memory with multiple executions', () async {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => testUser,
        );

        final mediator = DataSourceMediator.local(
          localDataSource: localStrategy,
        );

        // Execute many times to check for memory leaks
        for (int i = 0; i < 50; i++) {
          await mediator.execute().toList();
        }

        // If we got here without memory issues, test passes
        expect(true, isTrue);
      });
    });
  });
}
