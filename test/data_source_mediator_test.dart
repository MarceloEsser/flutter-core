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
  group('DataSourceMediator', () {
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
        metadata: testDto,
        status: 200,
        message: 'Success',
      );
      errorResponse = Response<UserDto>(
        metadata: testDto,
        status: 400,
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
          localStrategy: localStrategy,
          remoteStrategy: remoteStrategy,
        );

        expect(mediator, isNotNull);
      });

      test('creates mediator with only local strategy', () {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => testUser,
        );

        final mediator = DataSourceMediator<UserModel, Never, UserEntity>(
          localStrategy: localStrategy,
        );

        expect(mediator, isNotNull);
      });

      test('creates mediator with only remote strategy', () {
        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator<UserModel, UserDto, Never>(
          remoteStrategy: remoteStrategy,
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
          localStrategy: localStrategy,
        );

        expect(mediator, isNotNull);
      });

      test('remote factory creates mediator with only remote strategy', () {
        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteStrategy: remoteStrategy,
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
          localStrategy: localStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Data<UserModel>>());
        expect((results[0] as Data<UserModel>).data, testUser);
      });

      test('does not yield when local fetch returns null', () async {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => null,
          mapper: (entity) => testUser,
        );

        final mediator = DataSourceMediator.local(
          localStrategy: localStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 0);
      });

      test('yields error when local fetch throws exception', () async {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => throw Exception('Database error'),
          mapper: (entity) => testUser,
        );

        final mediator = DataSourceMediator.local(
          localStrategy: localStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Error>());
        expect((results[0] as Error).message, contains('Local fetch error'));
        expect((results[0] as Error).message, contains('Database error'));
      });
    });

    group('execute - Remote Strategy', () {
      test('yields data when remote fetch succeeds', () async {
        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteStrategy: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Data<UserModel>>());
        expect((results[0] as Data<UserModel>).data, testUser);
      });

      test('includes message in data when available', () async {
        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteStrategy: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Data<UserModel>>());
        expect((results[0] as Data<UserModel>).message, 'Success');
      });

      test('yields error when remote fetch fails', () async {
        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => errorResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteStrategy: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Error>());
        expect((results[0] as Error).message, 'Bad Request');
      });

      test('yields error with default message when response has no message',
          () async {
        final noMessageResponse = Response<UserDto>(
          metadata: testDto,
          status: 500,
          message: null,
        );

        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => noMessageResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteStrategy: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Error>());
        expect((results[0] as Error).message, 'Unknown error');
      });

      test('does not yield when mapper returns null', () async {
        final remoteStrategy = RemoteDataSource<UserModel?, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => null,
        );

        final mediator = DataSourceMediator.remote(
          remoteStrategy: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 0);
      });

      test('calls saveCallResult when provided and fetch succeeds', () async {
        bool saveCalled = false;
        Response<UserDto>? savedResponse;

        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => successResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteStrategy: remoteStrategy,
          saveCallResult: (response) async {
            saveCalled = true;
            savedResponse = response;
          },
        );

        await mediator.execute().toList();

        expect(saveCalled, true);
        expect(savedResponse, successResponse);
      });

      test('does not call saveCallResult when fetch fails', () async {
        bool saveCalled = false;

        final remoteStrategy = RemoteDataSource<UserModel, UserDto>(
          fetchFromRemote: () async => errorResponse,
          mapper: (response) => testUser,
        );

        final mediator = DataSourceMediator.remote(
          remoteStrategy: remoteStrategy,
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
          localStrategy: localStrategy,
          remoteStrategy: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 2);
        expect(results[0], isA<Data<UserModel>>());
        expect((results[0] as Data<UserModel>).data.name, 'Local User');
        expect(results[1], isA<Data<UserModel>>());
        expect((results[1] as Data<UserModel>).data.name, 'Remote User');
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
          localStrategy: localStrategy,
          remoteStrategy: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 1);
        expect(results[0], isA<Data<UserModel>>());
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
          localStrategy: localStrategy,
          remoteStrategy: remoteStrategy,
        );

        final results = await mediator.execute().toList();

        expect(results.length, 2);
        expect(results[0], isA<Data<UserModel>>());
        expect(results[1], isA<Error>());
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
          localStrategy: localStrategy,
          remoteStrategy: remoteStrategy,
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
          localStrategy: localStrategy,
        );

        // Each execute() call should create a new stream
        final results1 = await mediator.execute().toList();
        final results2 = await mediator.execute().toList();

        expect(results1.length, 1);
        expect(results2.length, 1);
        expect((results1[0] as Data<UserModel>).data, testUser);
        expect((results2[0] as Data<UserModel>).data, testUser);
      });

      test('throws error when listening to same stream twice', () async {
        final localStrategy = LocalDataSource<UserModel, UserEntity>(
          fetchFromLocal: () async => testEntity,
          mapper: (entity) => testUser,
        );

        final mediator = DataSourceMediator.local(
          localStrategy: localStrategy,
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
  });
}
