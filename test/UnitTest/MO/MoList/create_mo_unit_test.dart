import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_manufacturing_app/MO/pages/MoList/bloc/create_mo_bloc.dart';
import 'package:mobo_manufacturing_app/MO/pages/MoList/bloc/create_mo_event.dart';
import 'package:mobo_manufacturing_app/MO/pages/MoList/bloc/create_mo_state.dart';
import 'package:mobo_manufacturing_app/MO/pages/MoList/service/mo_list_service.dart';
import 'package:mocktail/mocktail.dart';

class MockMoListService extends Mock implements MoListService {}

void main() {
  late MockMoListService mockMoListService;

  setUp(() {
    mockMoListService = MockMoListService();
  });

  group('CreateMOBloC - Manufacturing Order creation', () {
    blocTest<CreateMOBloC, CreateMOState>(
      'emits loading and success state when manufacturing order is created',
      build: () {
        when(() => mockMoListService.initializeClient()).thenAnswer((_) async {});
        when(
              () => mockMoListService.createNewManufacturingOrder(any()),
        ).thenAnswer((_) async => true);

        return CreateMOBloC(mockMoListService);
      },
      act: (bloc) => bloc.add(
        CreateManufacturingOrder({
          'moCreate': {
            'product_id': 1,
            'product_qty': 1,
            'bom_id': 1,
            'user_id': 1,
            'date_start': DateTime.now(),
            'date_finished': DateTime.now(),
          },
          'productData': {'product_id': 1, 'product_uom_qty': 1},
          'workOrderData': {
            'name': 'demo',
            'workcenter_id': 1,
            'duration_expected': 2,
            'product_uom_id': 1,
          },
        }),
      ),
      expect: () => [
        isA<CreateMOState>().having((s) => s.isLoading, 'loading', true),
        isA<CreateMOState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.isSuccess, 'success', true),
      ],
      verify: (_) {
        verify(
              () => mockMoListService.createNewManufacturingOrder(any()),
        ).called(1);
      },
    );

    blocTest<CreateMOBloC, CreateMOState>(
      'emits validation error when product_id is not set',
      build: () {
        when(() => mockMoListService.initializeClient())
            .thenAnswer((_) async {});
        return CreateMOBloC(mockMoListService);
      },
      act: (bloc) => bloc.add(
        CreateManufacturingOrder({
          'moCreate': {
            'product_qty': 1,
            'bom_id': 1,
            'user_id': 1,
          },
          'productData': {'product_uom_qty': 1},
          'workOrderData': {
            'name': 'demo',
            'workcenter_id': 1,
            'duration_expected': 2,
            'product_uom_id': 1,
          },
        }),
      ),
      expect: () => [
        isA<CreateMOState>().having((s) => s.isLoading, 'loading', true),
        isA<CreateMOState>()
            .having((s) => s.isLoading, 'loading', false)
            .having(
              (s) => s.errorMessage,
          'validation error',
          'Product is required',
        ),
      ],
      verify: (_) {
        verifyNever(
              () => mockMoListService.createNewManufacturingOrder(any()),
        );
      },
    );


    blocTest<CreateMOBloC, CreateMOState>(
      'emits loading and error state when manufacturing order creation is failed',
      build: () {
        when(() => mockMoListService.initializeClient()).thenAnswer((_) async {});
        when(
              () => mockMoListService.createNewManufacturingOrder(any()),
        ).thenAnswer((_) async => false);

        return CreateMOBloC(mockMoListService);
      },
      act: (bloc) => bloc.add(
        CreateManufacturingOrder({
          'moCreate': {
            'product_id': 1,
            'product_qty': 1,
            'bom_id': 1,
            'user_id': 1,
            'date_start': DateTime.now(),
            'date_finished': DateTime.now(),
          },
          'productData': {'product_id': 1, 'product_uom_qty': 1},
          'workOrderData': {
            'name': 'demo',
            'workcenter_id': 1,
            'duration_expected': 2,
            'product_uom_id': 1,
          },
        }),
      ),
      expect: () => [
        isA<CreateMOState>().having((s) => s.isLoading, 'loading', true),
        isA<CreateMOState>()
            .having((s) => s.isLoading, 'loading', false)
            .having(
              (s) => s.errorMessage,
          'error',
          'Failed to create Manufacturing Order',
        ),
      ],
    );

    blocTest<CreateMOBloC, CreateMOState>(
      'emits loading and error state when createNewManufacturingOrder throws',
      build: () {
        when(
              () => mockMoListService.createNewManufacturingOrder(any()),
        ).thenThrow(Exception('Server error'));
        return CreateMOBloC(mockMoListService);
      },
      act: (bloc) => bloc.add(
        CreateManufacturingOrder({
          'moCreate': {
            'product_id': 1,
            'product_qty': 1,
            'bom_id': 1,
            'user_id': 1,
            'date_start': DateTime.now(),
            'date_finished': DateTime.now(),
          },
          'productData': {'product_id': 1, 'product_uom_qty': 1},
          'workOrderData': {
            'name': 'demo',
            'workcenter_id': 1,
            'duration_expected': 2,
            'product_uom_id': 1,
          },
        }),
      ),
      expect: () => [
        isA<CreateMOState>().having((s) => s.isLoading, 'loading', true),
        isA<CreateMOState>()
            .having((s) => s.isLoading, 'loading', false)
            .having(
              (s) => s.errorMessage,
          'error',
          contains('Error creating Manufacturing Order'),
        ),
      ],
    );
  });
}
