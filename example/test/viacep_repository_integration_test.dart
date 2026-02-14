import 'dart:io';

import 'package:example/data/viacep/local/model/address_entity.dart';
import 'package:example/data/viacep/local/viacep_database.dart';
import 'package:example/data/viacep/remote/model/viacep_network.dart';
import 'package:example/data/viacep/remote/viacep_service.dart';
import 'package:example/data/viacep/repository/model/address.dart';
import 'package:flutter_core/data_source_mediator.dart';
import 'package:flutter_core/datasources/data_source.dart';
import 'package:flutter_core/datasources/local/database/dao/data_access_object.dart';
import 'package:flutter_core/datasources/remote/client/http_client_exception.dart';
import 'package:flutter_core/datasources/remote/response/reponse.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'viacep_repository_integration_test.mocks.dart';

@GenerateMocks([ViacepService, ViacepDatabase])
void main() {
  group('ViacepRepository Integration Tests -', () {
    late MockViacepService mockService;
    late MockViacepDatabase mockDatabase;
    late ViacepRepositoryTestImpl repository;

    setUp(() {
      mockService = MockViacepService();
      mockDatabase = MockViacepDatabase();
      repository = ViacepRepositoryTestImpl(mockService, mockDatabase);
    });

    group('Success Scenarios -', () {
      test('should emit cached data first, then network data', () async {
        // Arrange
        const zipCode = '01310-100';
        final cachedEntity = _createAddressEntity(
          zipCode,
          'Av Paulista (Cache)',
        );
        final networkData = _createAddressNetwork(
          zipCode,
          'Av Paulista (Network)',
        );

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => [cachedEntity]);

        when(mockService.fetchAddressByZipCode(zipCode)).thenAnswer(
          (_) async => Response<AddressNetwork?>(
            data: networkData,
            status: HttpStatus.ok,
            message: 'Success',
          ),
        );

        when(mockDatabase.saveAddress(any)).thenAnswer((_) async => 1);

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        expect(results, hasLength(2));

        // First emission: cached data
        expect(results[0], isA<Data<Address?>>());
        final cachedResult = results[0] as Data<Address?>;
        expect(cachedResult.data?.logradouro, 'Av Paulista (Cache)');

        // Second emission: network data
        expect(results[1], isA<Data<Address?>>());
        final networkResult = results[1] as Data<Address?>;
        expect(networkResult.data?.logradouro, 'Av Paulista (Network)');

        // Verify interactions
        verify(mockDatabase.getAddressByZipCode(zipCode)).called(1);
        verify(mockService.fetchAddressByZipCode(zipCode)).called(1);
        verify(mockDatabase.saveAddress(any)).called(1);
      });

      test('should emit network data when cache is empty', () async {
        // Arrange
        const zipCode = '01310-100';
        final networkData = _createAddressNetwork(zipCode, 'Av Paulista');

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenAnswer(
          (_) async => Response<AddressNetwork?>(
            data: networkData,
            status: HttpStatus.ok,
          ),
        );

        when(mockDatabase.saveAddress(any)).thenAnswer((_) async => 1);

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        expect(results, hasLength(2));

        // First emission: null cached data
        expect(results[0], isA<Data<Address?>>());
        final cachedResult = results[0] as Data<Address?>;
        expect(cachedResult.data, isNull);

        // Second emission: network data
        expect(results[1], isA<Data<Address?>>());
        final networkResult = results[1] as Data<Address?>;
        expect(networkResult.data?.logradouro, 'Av Paulista');
        expect(networkResult.data?.cep, zipCode);
      });

      test('should handle successful 201 Created response', () async {
        // Arrange
        const zipCode = '01310-100';
        final networkData = _createAddressNetwork(zipCode, 'Av Paulista');

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenAnswer(
          (_) async => Response<AddressNetwork?>(
            data: networkData,
            status: HttpStatus.created, // 201
          ),
        );

        when(mockDatabase.saveAddress(any)).thenAnswer((_) async => 1);

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        final networkResult = results.last as Data<Address?>;
        expect(networkResult.data, isNotNull);
        verify(mockDatabase.saveAddress(any)).called(1);
      });

      test('should save network data to cache successfully', () async {
        // Arrange
        const zipCode = '01310-100';
        final networkData = _createAddressNetwork(zipCode, 'Av Paulista');

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenAnswer(
          (_) async => Response<AddressNetwork?>(
            data: networkData,
            status: HttpStatus.ok,
          ),
        );

        when(mockDatabase.saveAddress(any)).thenAnswer((_) async => 1);

        // Act
        await repository.fetchAddressByZipCode(zipCode).toList();

        // Assert
        final captured = verify(mockDatabase.saveAddress(captureAny)).captured;
        expect(captured, hasLength(1));
        final savedEntity = captured[0] as AddressEntity;
        expect(savedEntity.cep, zipCode);
        expect(savedEntity.logradouro, 'Av Paulista');
      });

      test('should not fail if cache save fails', () async {
        // Arrange
        const zipCode = '01310-100';
        final networkData = _createAddressNetwork(zipCode, 'Av Paulista');

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenAnswer(
          (_) async => Response<AddressNetwork?>(
            data: networkData,
            status: HttpStatus.ok,
          ),
        );

        // Cache save fails
        when(
          mockDatabase.saveAddress(any),
        ).thenThrow(DatabaseOperationException('Failed to save to cache'));

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert - should still get network data despite cache save failure
        final networkResult = results.last as Data<Address?>;
        expect(networkResult.data, isNotNull);
        expect(networkResult.data?.logradouro, 'Av Paulista');
      });
    });

    group('HTTP Error Scenarios -', () {
      test('should emit Failure with notFound type for 404', () async {
        // Arrange
        const zipCode = '99999-999';

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenThrow(
          HttpStatusException(
            statusCode: HttpStatus.notFound,
            message: 'CEP not found',
          ),
        );

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        expect(results, hasLength(2));

        // Second emission should be failure
        expect(results[1], isA<Failure<Address?>>());
        final failure = results[1] as Failure<Address?>;
        expect(failure.type, ErrorType.notFound);
        expect(failure.statusCode, HttpStatus.notFound);
        expect(failure.message, contains('CEP not found'));
        expect(failure.cause, isA<HttpStatusException>());
      });

      test('should emit Failure with unauthorized type for 401', () async {
        // Arrange
        const zipCode = '01310-100';

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenThrow(
          HttpStatusException(
            statusCode: HttpStatus.unauthorized,
            message: 'Unauthorized access',
          ),
        );

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        final failure = results.last as Failure<Address?>;
        expect(failure.type, ErrorType.unauthorized);
        expect(failure.isAuthError, isTrue);
        expect(failure.shouldLogout, isTrue);
        expect(failure.statusCode, HttpStatus.unauthorized);
      });

      test('should emit Failure with forbidden type for 403', () async {
        // Arrange
        const zipCode = '01310-100';

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenThrow(
          HttpStatusException(
            statusCode: HttpStatus.forbidden,
            message: 'Access forbidden',
          ),
        );

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        final failure = results.last as Failure<Address?>;
        expect(failure.type, ErrorType.forbidden);
        expect(failure.isAuthError, isTrue);
        expect(failure.statusCode, HttpStatus.forbidden);
      });

      test('should emit Failure with serverError type for 500', () async {
        // Arrange
        const zipCode = '01310-100';

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenThrow(
          HttpStatusException(
            statusCode: HttpStatus.internalServerError,
            message: 'Internal server error',
          ),
        );

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        final failure = results.last as Failure<Address?>;
        expect(failure.type, ErrorType.serverError);
        expect(failure.statusCode, HttpStatus.internalServerError);
        expect(failure.isRetryable, isFalse);
      });

      test(
        'should emit Failure with serviceUnavailable type for 503',
        () async {
          // Arrange
          const zipCode = '01310-100';

          when(
            mockDatabase.getAddressByZipCode(zipCode),
          ).thenAnswer((_) async => []);

          when(mockService.fetchAddressByZipCode(zipCode)).thenThrow(
            HttpStatusException(
              statusCode: HttpStatus.serviceUnavailable,
              message: 'Service temporarily unavailable',
            ),
          );

          // Act
          final results = await repository
              .fetchAddressByZipCode(zipCode)
              .toList();

          // Assert
          final failure = results.last as Failure<Address?>;
          expect(failure.type, ErrorType.serviceUnavailable);
          expect(failure.statusCode, HttpStatus.serviceUnavailable);
          expect(
            failure.isRetryable,
            isTrue,
          ); // Service unavailable is retryable
        },
      );

      test('should emit Failure with badRequest type for 400', () async {
        // Arrange
        const zipCode = 'invalid';

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenThrow(
          HttpStatusException(
            statusCode: HttpStatus.badRequest,
            message: 'Invalid CEP format',
          ),
        );

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        final failure = results.last as Failure<Address?>;
        expect(failure.type, ErrorType.badRequest);
        expect(failure.statusCode, HttpStatus.badRequest);
      });

      test('should emit Failure with validationError type for 422', () async {
        // Arrange
        const zipCode = '00000-000';

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenThrow(
          HttpStatusException(
            statusCode: 422,
            message: 'CEP validation failed',
          ),
        );

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        final failure = results.last as Failure<Address?>;
        expect(failure.type, ErrorType.validationError);
        expect(failure.statusCode, 422);
      });
    });

    group('Network Error Scenarios -', () {
      test(
        'should emit Failure with networkError type for NetworkException',
        () async {
          // Arrange
          const zipCode = '01310-100';

          when(
            mockDatabase.getAddressByZipCode(zipCode),
          ).thenAnswer((_) async => []);

          when(
            mockService.fetchAddressByZipCode(zipCode),
          ).thenThrow(NetworkException('No internet connection'));

          // Act
          final results = await repository
              .fetchAddressByZipCode(zipCode)
              .toList();

          // Assert
          final failure = results.last as Failure<Address?>;
          expect(failure.type, ErrorType.networkError);
          expect(failure.message, contains('No internet connection'));
          expect(failure.isRetryable, isTrue);
          expect(failure.cause, isA<NetworkException>());
        },
      );

      test(
        'should emit Failure with networkTimeout type for TimeoutException',
        () async {
          // Arrange
          const zipCode = '01310-100';

          when(
            mockDatabase.getAddressByZipCode(zipCode),
          ).thenAnswer((_) async => []);

          when(
            mockService.fetchAddressByZipCode(zipCode),
          ).thenThrow(TimeoutException('Request timeout after 30s'));

          // Act
          final results = await repository
              .fetchAddressByZipCode(zipCode)
              .toList();

          // Assert
          final failure = results.last as Failure<Address?>;
          expect(failure.type, ErrorType.networkTimeout);
          expect(failure.message, contains('timeout'));
          expect(failure.isRetryable, isTrue);
          expect(failure.cause, isA<TimeoutException>());
        },
      );

      test(
        'should emit Failure with jsonParsingError type for JsonParseException',
        () async {
          // Arrange
          const zipCode = '01310-100';

          when(
            mockDatabase.getAddressByZipCode(zipCode),
          ).thenAnswer((_) async => []);

          when(mockService.fetchAddressByZipCode(zipCode)).thenThrow(
            JsonParseException(
              'Failed to parse JSON response',
              rawBody: '{"invalid json',
            ),
          );

          // Act
          final results = await repository
              .fetchAddressByZipCode(zipCode)
              .toList();

          // Assert
          final failure = results.last as Failure<Address?>;
          expect(failure.type, ErrorType.jsonParsingError);
          expect(failure.message, contains('parse JSON'));
          expect(failure.cause, isA<JsonParseException>());
        },
      );

      test(
        'should emit Failure with badRequest type for RequestFormatException',
        () async {
          // Arrange
          const zipCode = '01310-100';

          when(
            mockDatabase.getAddressByZipCode(zipCode),
          ).thenAnswer((_) async => []);

          when(
            mockService.fetchAddressByZipCode(zipCode),
          ).thenThrow(RequestFormatException('Invalid request format'));

          // Act
          final results = await repository
              .fetchAddressByZipCode(zipCode)
              .toList();

          // Assert
          final failure = results.last as Failure<Address?>;
          expect(failure.type, ErrorType.badRequest);
          expect(failure.message, contains('Invalid request format'));
        },
      );
    });

    group('Database Error Scenarios -', () {
      test(
        'should emit Failure with databaseError type for DatabaseOperationException',
        () async {
          // Arrange
          const zipCode = '01310-100';

          when(
            mockDatabase.getAddressByZipCode(zipCode),
          ).thenThrow(DatabaseOperationException('Database query failed'));

          // Also stub the remote call since the mediator will attempt both
          when(
            mockService.fetchAddressByZipCode(zipCode),
          ).thenThrow(NetworkException('Network error'));

          // Act
          final results = await repository
              .fetchAddressByZipCode(zipCode)
              .toList();

          // Assert
          expect(results, hasLength(2)); // Database failure + network failure

          // First emission: database error
          final databaseFailure = results[0] as Failure<Address?>;
          expect(databaseFailure.type, ErrorType.databaseError);
          expect(databaseFailure.message, contains('Database query failed'));
          expect(databaseFailure.cause, isA<DatabaseOperationException>());

          // Second emission: network error
          final networkFailure = results[1] as Failure<Address?>;
          expect(networkFailure.type, ErrorType.networkError);
        },
      );

      test(
        'should emit Failure with tableNotFound type for TableNotFoundException',
        () async {
          // Arrange
          const zipCode = '01310-100';

          when(
            mockDatabase.getAddressByZipCode(zipCode),
          ).thenThrow(TableNotFoundException('addresses'));

          // Act
          final results = await repository
              .fetchAddressByZipCode(zipCode)
              .toList();

          // Assert
          final failure = results[0] as Failure<Address?>;
          expect(failure.type, ErrorType.tableNotFound);
          expect(failure.message, contains('addresses'));
          expect(failure.cause, isA<TableNotFoundException>());
        },
      );

      test(
        'should emit Failure with entityNotFound type for EntityNotFoundException',
        () async {
          // Arrange
          const zipCode = '01310-100';

          when(
            mockDatabase.getAddressByZipCode(zipCode),
          ).thenThrow(EntityNotFoundException('Address not found in cache'));

          // Act
          final results = await repository
              .fetchAddressByZipCode(zipCode)
              .toList();

          // Assert
          final failure = results[0] as Failure<Address?>;
          expect(failure.type, ErrorType.entityNotFound);
          expect(failure.message, contains('Address not found'));
        },
      );

      test('should still fetch from network if cache fails', () async {
        // Arrange
        const zipCode = '01310-100';
        final networkData = _createAddressNetwork(zipCode, 'Av Paulista');

        // Cache fails
        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenThrow(DatabaseOperationException('Cache read failed'));

        // Network succeeds
        when(mockService.fetchAddressByZipCode(zipCode)).thenAnswer(
          (_) async => Response<AddressNetwork?>(
            data: networkData,
            status: HttpStatus.ok,
          ),
        );

        when(mockDatabase.saveAddress(any)).thenAnswer((_) async => 1);

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        expect(results, hasLength(2));

        // First emission: database error
        expect(results[0], isA<Failure<Address?>>());

        // Second emission: network success
        expect(results[1], isA<Data<Address?>>());
        final networkResult = results[1] as Data<Address?>;
        expect(networkResult.data?.logradouro, 'Av Paulista');
      });
    });

    group('Edge Cases -', () {
      test('should handle null network data', () async {
        // Arrange
        const zipCode = '01310-100';

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenAnswer(
          (_) async => Response<AddressNetwork?>(
            data: null, // Null data
            status: HttpStatus.ok,
          ),
        );

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        final networkResult = results.last as Data<Address?>;
        expect(networkResult.data, isNull);

        // Should not attempt to save null data
        verifyNever(mockDatabase.saveAddress(any));
      });

      test('should handle empty string fields in network data', () async {
        // Arrange
        const zipCode = '01310-100';
        final networkData = AddressNetwork(
          cep: zipCode,
          logradouro: '', // Empty string
          bairro: '',
          localidade: '',
          uf: '',
        );

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenAnswer(
          (_) async => Response<AddressNetwork?>(
            data: networkData,
            status: HttpStatus.ok,
          ),
        );

        when(mockDatabase.saveAddress(any)).thenAnswer((_) async => 1);

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        final networkResult = results.last as Data<Address?>;
        expect(networkResult.data?.cep, zipCode);
        expect(networkResult.data?.logradouro, '');
      });

      test(
        'should handle multiple addresses in cache (returns first)',
        () async {
          // Arrange
          const zipCode = '01310-100';
          final cachedEntities = [
            _createAddressEntity(zipCode, 'First Address'),
            _createAddressEntity(zipCode, 'Second Address'),
            _createAddressEntity(zipCode, 'Third Address'),
          ];

          when(
            mockDatabase.getAddressByZipCode(zipCode),
          ).thenAnswer((_) async => cachedEntities);

          when(mockService.fetchAddressByZipCode(zipCode)).thenAnswer(
            (_) async => Response<AddressNetwork?>(
              data: _createAddressNetwork(zipCode, 'Network Address'),
              status: HttpStatus.ok,
            ),
          );

          when(mockDatabase.saveAddress(any)).thenAnswer((_) async => 1);

          // Act
          final results = await repository
              .fetchAddressByZipCode(zipCode)
              .toList();

          // Assert
          final cachedResult = results[0] as Data<Address?>;
          expect(cachedResult.data?.logradouro, 'First Address');
        },
      );

      test('should preserve stackTrace in Failure', () async {
        // Arrange
        const zipCode = '01310-100';

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(
          mockService.fetchAddressByZipCode(zipCode),
        ).thenThrow(NetworkException('Network error'));

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        final failure = results.last as Failure<Address?>;
        expect(failure.stackTrace, isNotNull);
        expect(failure.cause, isA<NetworkException>());
      });

      test('should handle unknown exceptions as ErrorType.unknown', () async {
        // Arrange
        const zipCode = '01310-100';

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(
          mockService.fetchAddressByZipCode(zipCode),
        ).thenThrow(Exception('Unexpected error'));

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        final failure = results.last as Failure<Address?>;
        expect(failure.type, ErrorType.unknown);
        expect(failure.message, contains('Remote fetch error'));
      });

      test('should handle message in Data result', () async {
        // Arrange
        const zipCode = '01310-100';
        final networkData = _createAddressNetwork(zipCode, 'Av Paulista');

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenAnswer(
          (_) async => Response<AddressNetwork?>(
            data: networkData,
            status: HttpStatus.ok,
            message: 'Success message',
          ),
        );

        when(mockDatabase.saveAddress(any)).thenAnswer((_) async => 1);

        // Act
        final results = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        final networkResult = results.last as Data<Address?>;
        expect(networkResult.message, 'Success message');
      });
    });

    group('Stream Behavior -', () {
      test(
        'should emit results in correct order (local then remote)',
        () async {
          // Arrange
          const zipCode = '01310-100';
          final cachedEntity = _createAddressEntity(zipCode, 'Cached');
          final networkData = _createAddressNetwork(zipCode, 'Network');

          when(
            mockDatabase.getAddressByZipCode(zipCode),
          ).thenAnswer((_) async => [cachedEntity]);

          when(mockService.fetchAddressByZipCode(zipCode)).thenAnswer(
            (_) async => Response<AddressNetwork?>(
              data: networkData,
              status: HttpStatus.ok,
            ),
          );

          when(mockDatabase.saveAddress(any)).thenAnswer((_) async => 1);

          // Act
          final emissions = <String>[];
          await for (final result in repository.fetchAddressByZipCode(
            zipCode,
          )) {
            if (result is Data<Address?>) {
              emissions.add(result.data?.logradouro ?? 'null');
            } else if (result is Failure<Address?>) {
              emissions.add('failure: ${result.type}');
            }
          }

          // Assert
          expect(emissions, ['Cached', 'Network']);
        },
      );

      test('should be listenable multiple times', () async {
        // Arrange
        const zipCode = '01310-100';
        final networkData = _createAddressNetwork(zipCode, 'Av Paulista');

        when(
          mockDatabase.getAddressByZipCode(zipCode),
        ).thenAnswer((_) async => []);

        when(mockService.fetchAddressByZipCode(zipCode)).thenAnswer(
          (_) async => Response<AddressNetwork?>(
            data: networkData,
            status: HttpStatus.ok,
          ),
        );

        when(mockDatabase.saveAddress(any)).thenAnswer((_) async => 1);

        // Act - Listen twice
        final stream = repository.fetchAddressByZipCode(zipCode);
        final results1 = await stream.toList();

        // Second listen should trigger new fetch
        final results2 = await repository
            .fetchAddressByZipCode(zipCode)
            .toList();

        // Assert
        expect(results1, hasLength(greaterThanOrEqualTo(1)));
        expect(results2, hasLength(greaterThanOrEqualTo(1)));

        // Should be called twice (once per stream)
        verify(mockService.fetchAddressByZipCode(zipCode)).called(2);
      });

      test('should allow cancelling stream subscription', () async {
        // Arrange
        const zipCode = '01310-100';

        when(mockDatabase.getAddressByZipCode(zipCode)).thenAnswer((_) async {
          await Future.delayed(Duration(milliseconds: 100));
          return [];
        });

        when(mockService.fetchAddressByZipCode(zipCode)).thenAnswer((_) async {
          await Future.delayed(Duration(milliseconds: 200));
          return Response<AddressNetwork?>(
            data: _createAddressNetwork(zipCode, 'Av Paulista'),
            status: HttpStatus.ok,
          );
        });

        // Act
        final results = <Result<Address?>>[];
        final subscription = repository
            .fetchAddressByZipCode(zipCode)
            .listen(results.add);

        // Cancel after a short delay
        await Future.delayed(Duration(milliseconds: 50));
        await subscription.cancel();

        // Wait a bit more to ensure no more emissions
        await Future.delayed(Duration(milliseconds: 300));

        // Assert - Should not have received all emissions
        expect(results.length, lessThan(2));
      });
    });
  });
}

// Helper class to inject mocks
class ViacepRepositoryTestImpl {
  final ViacepService _service;
  final ViacepDatabase _database;

  ViacepRepositoryTestImpl(this._service, this._database);

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
          final result = await _database.getAddressByZipCode(zipCode);
          return result.firstOrNull;
        },
        mapper: (entity) => entity?.toModel(),
      ),
      saveCallResult: (network) async {
        final networkData = network.data;
        if (networkData != null) {
          await _database.saveAddress(networkData.toEntity());
        }
      },
    ).execute();
  }
}

// Helper functions to create test data
AddressEntity _createAddressEntity(String cep, String logradouro) {
  return AddressEntity(
    id: 1,
    cep: cep,
    logradouro: logradouro,
    bairro: 'Bela Vista',
    localidade: 'São Paulo',
    uf: 'SP',
    complemento: '',
    unidade: '',
    estado: 'São Paulo',
    regiao: 'Sudeste',
    ibge: '3550308',
    gia: '1004',
    ddd: '11',
    siafi: '7107',
  );
}

AddressNetwork _createAddressNetwork(String cep, String logradouro) {
  return AddressNetwork(
    cep: cep,
    logradouro: logradouro,
    bairro: 'Bela Vista',
    localidade: 'São Paulo',
    uf: 'SP',
    complemento: '',
    unidade: '',
    estado: 'São Paulo',
    regiao: 'Sudeste',
    ibge: '3550308',
    gia: '1004',
    ddd: '11',
    siafi: '7107',
  );
}
