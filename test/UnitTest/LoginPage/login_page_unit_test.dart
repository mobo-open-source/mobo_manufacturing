import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_manufacturing_app/LoginPage/services/network_service.dart';
import 'package:mocktail/mocktail.dart';

class MockNetworkService extends Mock implements NetworkService {}

void main() {
  late MockNetworkService mockNetworkService;

  setUp(() {
    mockNetworkService = MockNetworkService();
  });

  group("NetworkService.fetchDatabaseList - ", () {

    test(
      'should return a list of database names when the server responds successfully',
      () async {
        when(
          () => mockNetworkService.fetchDatabaseList(any()),
        ).thenAnswer((_) async => ['db1', 'db2']);

        final result = await mockNetworkService.fetchDatabaseList(
          'https://demo.odoo.com',
        );

        expect(result, isA<List<String>>());
      },
    );

    test(
      'should return an empty list when the server responds with no databases',
      () async {
        when(
          () => mockNetworkService.fetchDatabaseList(any()),
        ).thenAnswer((_) async => []);

        final result = await mockNetworkService.fetchDatabaseList(
          'https://demo.odoo.com',
        );

        expect(result, isEmpty);
      },
    );

    test(
      'should throw an exception when the server responds with an error',
      () async {
        when(
          () => mockNetworkService.fetchDatabaseList(any()),
        ).thenThrow(Exception("Internal Server Error"));

        expect(
          () => mockNetworkService.fetchDatabaseList('https://demo.odoo.com'),
          throwsException,
        );
      },
    );
  });
}
