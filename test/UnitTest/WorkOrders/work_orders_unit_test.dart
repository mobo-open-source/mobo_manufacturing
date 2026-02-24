import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_manufacturing_app/WorkOrders/providers/work_order_provider.dart';
import 'package:mobo_manufacturing_app/WorkOrders/service/work_order_service.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkOrderService extends Mock implements WorkOrderService {}

void main() {
  late MockWorkOrderService mockWorkOrderService;
  late WorkOrderProvider workOrderProvider;

  setUp(() {
    mockWorkOrderService = MockWorkOrderService();
    workOrderProvider = WorkOrderProvider(mockWorkOrderService);
  });

  group("WorkOrderProvider - ", () {
    /// Start Work Order ///

    test('returns true after successfully starting a work order', () async {
      when(
        () => mockWorkOrderService.startWorkOrder(any()),
      ).thenAnswer((_) async => {'success': true});

      final result = await workOrderProvider.startWorkOrder(1, '00:00');
      expect(result, true);
      verify(() => mockWorkOrderService.startWorkOrder(1)).called(1);
    });

    test('returns false when starting a work order is failed', () async {
      when(() => mockWorkOrderService.startWorkOrder(any())).thenAnswer(
        (_) async => {
          'success': false,
          'error': 'Failed to start work order, Please try again later',
        },
      );

      final result = await workOrderProvider.startWorkOrder(1, '00:00');
      expect(result, false);
      verify(() => mockWorkOrderService.startWorkOrder(1)).called(1);
    });

    test(
      'should return false when starting a work order throws an exception',
      () async {
        when(
          () => mockWorkOrderService.startWorkOrder(any()),
        ).thenThrow(Exception('Internal Server Error'));

        final result = await workOrderProvider.startWorkOrder(1, '00:00');

        expect(result, false);
      },
    );

    /// Pause Work Order ///

    test('returns true after successfully pausing a work order', () async {
      when(
        () => mockWorkOrderService.pauseWorkOrder(any()),
      ).thenAnswer((_) async => {'success': true});

      final result = await workOrderProvider.pauseWorkOrder(1);
      expect(result, true);
      verify(() => mockWorkOrderService.pauseWorkOrder(1)).called(1);
    });

    test('returns false when pausing a work order is failed', () async {
      when(() => mockWorkOrderService.pauseWorkOrder(any())).thenAnswer(
        (_) async => {
          'success': false,
          'error': 'Failed to start work order, Please try again later',
        },
      );

      final result = await workOrderProvider.pauseWorkOrder(1);
      expect(result, false);
      verify(() => mockWorkOrderService.pauseWorkOrder(1)).called(1);
    });

    test(
      'should return false when pausing a work order throws an exception',
      () async {
        when(
          () => mockWorkOrderService.pauseWorkOrder(any()),
        ).thenThrow(Exception('Internal Server Error'));

        final result = await workOrderProvider.pauseWorkOrder(1);

        expect(result, false);
      },
    );

    /// Finish Work Order ///

    test('returns true after successfully finishing a work order', () async {
      when(
        () => mockWorkOrderService.stopWorkOrder(any()),
      ).thenAnswer((_) async => {'success': true});

      final result = await workOrderProvider.finishWorkOrder(1);
      expect(result, true);
      verify(() => mockWorkOrderService.stopWorkOrder(1)).called(1);
    });

    test('returns false when finishing a work order is failed', () async {
      when(() => mockWorkOrderService.stopWorkOrder(any())).thenAnswer(
        (_) async => {
          'success': false,
          'error': 'Failed to start work order, Please try again later',
        },
      );

      final result = await workOrderProvider.finishWorkOrder(1);
      expect(result, false);
      verify(() => mockWorkOrderService.stopWorkOrder(1)).called(1);
    });

    test(
      'should return false when finishing a work order throws an exception',
      () async {
        when(
          () => mockWorkOrderService.stopWorkOrder(any()),
        ).thenThrow(Exception('Internal Server Error'));

        final result = await workOrderProvider.finishWorkOrder(1);

        expect(result, false);
      },
    );
  });
}
