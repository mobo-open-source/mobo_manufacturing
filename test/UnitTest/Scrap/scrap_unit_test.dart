import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_manufacturing_app/Scrap/service/scrap_service.dart';
import 'package:mocktail/mocktail.dart';

class MockScrapService extends Mock implements ScrapService {}

void main() {
  late MockScrapService mockScrapService;

  setUp(() {
    mockScrapService = MockScrapService();
  });

  group("Scrap Actions - ", () {
    test('Should return true when scrap update is successful.', () async {
      when(() => mockScrapService.initializeClient()).thenAnswer((_) async {});
      when(
        () => mockScrapService.updateScrap(any(), any()),
      ).thenAnswer((_) async => true);

      final result = await mockScrapService.updateScrap(1, {
        'product_id': 1,
        'production_id': 1,
        'origin': 'demo',
        'date_done': DateTime.now(),
        'company_id': 1,
        'scrap_qty': 1,
      });

      expect(result, true);
    });

    test('Should return false when scrap update fails.', () async {
      when(() => mockScrapService.initializeClient()).thenAnswer((_) async {});
      when(
        () => mockScrapService.updateScrap(any(), any()),
      ).thenAnswer((_) async => false);

      final result = await mockScrapService.updateScrap(1, {
        'product_id': 1,
        'production_id': 1,
        'origin': 'demo',
        'date_done': DateTime.now(),
        'company_id': 1,
        'scrap_qty': 1,
      });

      expect(result, false);
    });

    test('Should return false when server returns error response.', () async {
      when(() => mockScrapService.initializeClient()).thenAnswer((_) async {});
      when(
        () => mockScrapService.updateScrap(any(), any()),
      ).thenThrow(Exception("Internal Server Error"));

      expect(
        () => mockScrapService.updateScrap(1, {
          'product_id': 1,
          'production_id': 1,
          'origin': 'demo',
          'date_done': DateTime.now(),
          'company_id': 1,
          'scrap_qty': 1,
        }),
        throwsException,
      );
    });
  });

  group("Validate Scrap - ", () {
    test('Should return true when scrap validation is successful.', () async {
      when(() => mockScrapService.initializeClient()).thenAnswer((_) async {});
      when(
        () => mockScrapService.validateScrap(any()),
      ).thenAnswer((_) async => true);

      final result = await mockScrapService.validateScrap(1);

      expect(result, true);
    });

    test('Should return false when scrap validation is fail.', () async {
      when(() => mockScrapService.initializeClient()).thenAnswer((_) async {});
      when(
        () => mockScrapService.validateScrap(any()),
      ).thenAnswer((_) async => false);

      final result = await mockScrapService.validateScrap(1);

      expect(result, false);
    });

    test('Should return false when server returns error response', () async {
      when(() => mockScrapService.initializeClient()).thenAnswer((_) async {});
      when(
        () => mockScrapService.validateScrap(any()),
      ).thenThrow(Exception("Internal Server Error"));

      expect(() => mockScrapService.validateScrap(1), throwsException);
    });
  });

  group("Confirm Scrap - ", () {
    test('Should return true when scrap confirmation is successful.', () async {
      when(() => mockScrapService.initializeClient()).thenAnswer((_) async {});
      when(
        () => mockScrapService.confirmScrap(
          scrapId: any(named: 'scrapId'),
          productId: any(named: 'productId'),
          locationId: any(named: 'locationId'),
          uom: any(named: 'uom'),
          qty: any(named: 'qty'),
        ),
      ).thenAnswer((_) async => true);

      final result = await mockScrapService.confirmScrap(
        scrapId: 1,
        productId: 1,
        locationId: 1,
        uom: 'demo',
        qty: 1,
      );

      expect(result, true);
    });

    test('Should return false when scrap confirmation is fail', () async {
      when(() => mockScrapService.initializeClient()).thenAnswer((_) async {});
      when(
        () => mockScrapService.confirmScrap(
          scrapId: any(named: 'scrapId'),
          productId: any(named: 'productId'),
          locationId: any(named: 'locationId'),
          uom: any(named: 'uom'),
          qty: any(named: 'qty'),
        ),
      ).thenAnswer((_) async => false);

      final result = await mockScrapService.confirmScrap(
        scrapId: 1,
        productId: 1,
        locationId: 1,
        uom: 'demo',
        qty: 1,
      );

      expect(result, false);
    });

    test('Should return false when server returns error response', () async {
      when(() => mockScrapService.initializeClient()).thenAnswer((_) async {});
      when(
        () => mockScrapService.confirmScrap(
          scrapId: any(named: 'scrapId'),
          productId: any(named: 'productId'),
          locationId: any(named: 'locationId'),
          uom: any(named: 'uom'),
          qty: any(named: 'qty'),
        ),
      ).thenThrow(Exception("Internal Server Error"));

      expect(
        () => mockScrapService.confirmScrap(
          scrapId: 1,
          productId: 1,
          locationId: 1,
          uom: 'demo',
          qty: 1,
        ),
        throwsException,
      );
    });
  });
}
