import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_manufacturing_app/Dashboard/services/settings_storage_service.dart';
import 'package:mobo_manufacturing_app/MO/pages/MoForm/bloc/mo_form/mo_form_bloc.dart';
import 'package:mobo_manufacturing_app/MO/pages/MoForm/bloc/mo_form/mo_form_event.dart';
import 'package:mobo_manufacturing_app/MO/pages/MoForm/bloc/mo_form/mo_form_state.dart';
import 'package:mobo_manufacturing_app/MO/pages/MoForm/service/mo_form_service.dart';
import 'package:mocktail/mocktail.dart';

class MockMoFormService extends Mock implements MoFormService {}

class MockSettingsStorageService extends Mock
    implements SettingsStorageService {}

void main() {
  late MockMoFormService mockMoFormService;
  late MockSettingsStorageService mockSettingsStorageService;

  setUp(() {
    mockMoFormService = MockMoFormService();
    mockSettingsStorageService = MockSettingsStorageService();
  });

  group("Manufacturing Update - ", () {
    /// Manufacturing Update ///

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and success state when manufacturing order is updated',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.updateManufacturingDetails(any(), any()),
        ).thenAnswer((_) async => true);
        when(() => mockMoFormService.loadMo(any())).thenAnswer(
          (_) async => [
            {'id': 1},
          ],
        );

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        UpdateManufacturingDetails({
          'product_id': 1,
          'bom_id': 1,
          'user_id': 1,
          'product_qty': 1,
          'qty_produced': 1,
          'date_start': DateTime.now(),
          'date_finished': DateTime.now(),
        }, 1),
      ),
      expect: () => [
        const MoFormState(isLoading: true),

        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.moItem.isNotEmpty, 'moItem', true),
      ],
      verify: (_) {
        verify(
          () => mockMoFormService.updateManufacturingDetails(any(), any()),
        ).called(1);
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and error state when manufacturing order update is failed',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.updateManufacturingDetails(any(), any()),
        ).thenAnswer((_) async => false);
        when(() => mockMoFormService.loadMo(any())).thenAnswer(
          (_) async => [
            {'id': 1},
          ],
        );

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        UpdateManufacturingDetails({
          'product_id': 1,
          'bom_id': 1,
          'user_id': 1,
          'product_qty': 1,
          'qty_produced': 1,
          'date_start': DateTime.now(),
          'date_finished': DateTime.now(),
        }, 1),
      ),
      expect: () => [
        const MoFormState(isLoading: true),

        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Failed to update manufacturing details',
            )
            .having((s) => s.moItem.isEmpty, 'moItem', true),
      ],
      verify: (_) {
        verify(
          () => mockMoFormService.updateManufacturingDetails(any(), any()),
        ).called(1);
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and error state when exception is thrown',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.updateManufacturingDetails(any(), any()),
        ).thenThrow(Exception('Network error'));

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        UpdateManufacturingDetails({
          'product_id': 1,
          'bom_id': 1,
          'user_id': 1,
          'product_qty': 1,
          'qty_produced': 1,
          'date_start': DateTime.now(),
          'date_finished': DateTime.now(),
        }, 1),
      ),
      expect: () => [
        const MoFormState(isLoading: true),

        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Network error'),
            ),
      ],
      verify: (_) {
        verify(
          () => mockMoFormService.updateManufacturingDetails(any(), any()),
        ).called(1);
        verifyNever(() => mockMoFormService.loadMo(any()));
      },
    );
  });

  group("Work order actions - ", () {
    /// Start work order ///

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and success state when work order is started',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.startWorkOrder(any(), any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockMoFormService.loadWorkOrders(any()),
        ).thenAnswer((_) async => []);

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(StartWorkOrder(1, 10)),
      expect: () => [
        const MoFormState(isLoading: true),

        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.workOrderStarted[10], 'workOrderStarted', true)
            .having(
              (s) => s.workOrderStartTimes.containsKey(10),
              'workOrderStartTimes',
              true,
            ),
      ],
      verify: (_) {
        verify(() => mockMoFormService.startWorkOrder(1, 10)).called(1);
        verify(() => mockMoFormService.loadWorkOrders(1)).called(1);
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and error state when exception is thrown',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.startWorkOrder(any(), any()),
        ).thenThrow(Exception('Network error'));

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(StartWorkOrder(1, 10)),
      expect: () => [
        const MoFormState(isLoading: true),

        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Network error'),
            ),
      ],
      verify: (_) {
        verify(() => mockMoFormService.startWorkOrder(1, 10)).called(1);
      },
    );

    /// Pause work order ///

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and success state when work order is paused',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.pauseWorkOrder(any(), any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockMoFormService.loadWorkOrders(any()),
        ).thenAnswer((_) async => []);

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(PauseWorkOrder(1, 10)),
      expect: () => [
        const MoFormState(isLoading: true),
        const MoFormState(isLoading: false, workOrders: []),
      ],
      verify: (_) {
        verify(() => mockMoFormService.pauseWorkOrder(1, 10)).called(1);
        verify(() => mockMoFormService.loadWorkOrders(1)).called(1);
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and error state when exception is thrown',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.pauseWorkOrder(any(), any()),
        ).thenThrow(Exception('Network error'));

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(PauseWorkOrder(1, 10)),
      expect: () => [
        const MoFormState(isLoading: true),

        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Network error'),
            ),
      ],
      verify: (_) {
        verify(() => mockMoFormService.pauseWorkOrder(1, 10)).called(1);
      },
    );

    /// Stop work order ///

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and success state when work order is stopped',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.stopWorkOrder(any(), any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockMoFormService.loadWorkOrders(any()),
        ).thenAnswer((_) async => []);

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(StopWorkOrder(1, 10)),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>(),
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(() => mockMoFormService.stopWorkOrder(1, 10)).called(1);
        verify(() => mockMoFormService.loadWorkOrders(1)).called(1);
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and error state when exception is thrown',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.stopWorkOrder(any(), any()),
        ).thenThrow(Exception('Network error'));

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(StopWorkOrder(1, 10)),
      expect: () => [
        const MoFormState(isLoading: true),

        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Network error'),
            ),
      ],
      verify: (_) {
        verify(() => mockMoFormService.stopWorkOrder(1, 10)).called(1);
      },
    );
  });

  group("Manufacturing button actions - ", () {
    /// Unbuild MO ///

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and success state when unbuild manufacturing',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.unbuildMo(any()),
        ).thenAnswer((_) async => true);
        when(() => mockMoFormService.loadMo(any())).thenAnswer((_) async => []);

        when(
          () => mockMoFormService.loadUnbuildOrders(any()),
        ).thenAnswer((_) async => []);

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        UnbuildMo([
          {"id": 1},
        ]),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(
          () => mockMoFormService.unbuildMo([
            {'id': 1},
          ]),
        ).called(1);
        verify(() => mockMoFormService.loadMo(1)).called(1);
        verify(() => mockMoFormService.loadUnbuildOrders(1)).called(1);
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and error state when unbuild manufacturing',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.unbuildMo(any()),
        ).thenAnswer((_) async => false);

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        UnbuildMo([
          {"id": 1},
        ]),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Failed to unbuild manufacturing order',
            ),
      ],
      verify: (_) {
        verify(
          () => mockMoFormService.unbuildMo([
            {'id': 1},
          ]),
        ).called(1);
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and error state when exception is thrown',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.unbuildMo(any()),
        ).thenThrow(Exception('Network error'));

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        UnbuildMo([
          {"id": 1},
        ]),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Network error'),
            ),
      ],
      verify: (_) {
        verify(
          () => mockMoFormService.unbuildMo([
            {'id': 1},
          ]),
        ).called(1);
      },
    );

    /// Cancel MO ///
    blocTest<MoFormBloc, MoFormState>(
      'emits loading and success state when cancel manufacturing',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.cancelMo(any()),
        ).thenAnswer((_) async => true);
        when(() => mockMoFormService.loadMo(any())).thenAnswer((_) async => []);

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        CancelMo([
          {"id": 1},
        ]),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(() => mockMoFormService.cancelMo(1)).called(1);
        verify(() => mockMoFormService.loadMo(1)).called(1);
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and error state when cancel manufacturing',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.cancelMo(any()),
        ).thenAnswer((_) async => false);

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        CancelMo([
          {'id': 1},
        ]),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(() => mockMoFormService.cancelMo(1)).called(1);
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and error state when exception is thrown',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.cancelMo(any()),
        ).thenThrow(Exception("Network error"));

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        CancelMo([
          {'id': 1},
        ]),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Network error'),
            ),
      ],
      verify: (_) {
        verify(() => mockMoFormService.cancelMo(1)).called(1);
      },
    );

    /// Confirm MO ///
    blocTest<MoFormBloc, MoFormState>(
      'emits loading and success state when confirm manufacturing order',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.confirmMo(any()),
        ).thenAnswer((_) async => true);
        when(() => mockMoFormService.loadMo(any())).thenAnswer((_) async => []);
        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        ConfirmMo([
          {'id': 1},
        ]),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(() => mockMoFormService.confirmMo(1)).called(1);
        verify(() => mockMoFormService.loadMo(1)).called(1);
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and error state when confirm manufacturing order',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.confirmMo(any()),
        ).thenAnswer((_) async => false);
        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        ConfirmMo([
          {'id': 1},
        ]),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(() => mockMoFormService.confirmMo(1)).called(1);
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and error state when exception is thrown',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.confirmMo(any()),
        ).thenThrow(Exception("Network error"));

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        ConfirmMo([
          {'id': 1},
        ]),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Network error'),
            ),
      ],
      verify: (_) {
        verify(() => mockMoFormService.confirmMo(1)).called(1);
      },
    );

    /// Produce All MO ///
    blocTest<MoFormBloc, MoFormState>(
      'emits loading and success state when produce all manufacturing order',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.produceAll(any()),
        ).thenAnswer((_) async => true);
        when(() => mockMoFormService.loadMo(any())).thenAnswer((_) async => []);
        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        ProduceAllMo([
          {'id': 1},
        ]),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(() => mockMoFormService.produceAll(1)).called(1);
        verify(() => mockMoFormService.loadMo(1)).called(1);
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and error state when produce all manufacturing order',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.produceAll(any()),
        ).thenAnswer((_) async => false);
        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        ProduceAllMo([
          {'id': 1},
        ]),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(() => mockMoFormService.produceAll(1)).called(1);
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emits loading and error state when exception is thrown',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.produceAll(any()),
        ).thenThrow(Exception("Network error"));

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        ProduceAllMo([
          {'id': 1},
        ]),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Network error'),
            ),
      ],
      verify: (_) {
        verify(() => mockMoFormService.produceAll(1)).called(1);
      },
    );
  });

  group('Product line actions - ', () {
    /// Update product line ///

    blocTest<MoFormBloc, MoFormState>(
      'emit loading and success state when product line updated',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.updateProductMove(
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockMoFormService.loadProductMoves(any()),
        ).thenAnswer((_) async => []);
        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        UpdateProductMove(
          productMoveId: 1,
          productId: 1,
          productName: 'demo',
          quantity: 1,
          toConsume: 1,
        ),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.moveProducts, 'moveProducts', []),
      ],
      verify: (_) {
        verify(
          () => mockMoFormService.updateProductMove(
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        );
        verify(() => mockMoFormService.loadProductMoves(any()));
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emit loading and error state when exception is thrown',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.updateProductMove(
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenThrow(Exception('Network error'));

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        UpdateProductMove(
          productMoveId: 1,
          productId: 1,
          productName: 'demo',
          quantity: 1,
          toConsume: 1,
        ),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Network error'),
            ),
      ],
      verify: (_) {
        verify(
          () => mockMoFormService.updateProductMove(
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        );
      },
    );

    /// Add product line ///

    blocTest<MoFormBloc, MoFormState>(
      'emit loading and success state when product line added',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.addProductToLine(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async => 1);
        when(
          () => mockMoFormService.loadProductMoves(any()),
        ).thenAnswer((_) async => []);
        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        AddProductToLine(
          moId: 1,
          productId: 1,
          productName: 'demo',
          toConsume: 1,
          quantity: 1,
          moProductId: 1,
        ),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.moveProducts, 'moveProducts', []),
      ],
      verify: (_) {
        verify(
          () => mockMoFormService.addProductToLine(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        );
        verify(() => mockMoFormService.loadProductMoves(any()));
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emit loading and error state when exception is thrown',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.addProductToLine(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenThrow(Exception('Network error'));

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(
        AddProductToLine(
          moId: 1,
          productId: 1,
          productName: 'demo',
          toConsume: 1,
          quantity: 1,
          moProductId: 1,
        ),
      ),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Network error'),
            ),
      ],
      verify: (_) {
        verify(
          () => mockMoFormService.addProductToLine(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        );
      },
    );

    /// Delete product line ///

    blocTest<MoFormBloc, MoFormState>(
      'emit loading and success state when product line deleted',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.deleteProductMove(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockMoFormService.loadProductMoves(any()),
        ).thenAnswer((_) async => []);
        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(DeleteProductMove(1)),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.moveProducts, 'moveProducts', []),
      ],
      verify: (_) {
        verify(() => mockMoFormService.deleteProductMove(any()));
        verify(() => mockMoFormService.loadProductMoves(any()));
      },
    );

    blocTest<MoFormBloc, MoFormState>(
      'emit loading and error state when exception is thrown',
      build: () {
        when(
          () => mockMoFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockMoFormService.deleteProductMove(any()),
        ).thenThrow(Exception('Network error'));

        return MoFormBloc(mockMoFormService, mockSettingsStorageService);
      },
      act: (bloc) => bloc.add(DeleteProductMove(1)),
      expect: () => [
        isA<MoFormState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MoFormState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Network error'),
            ),
      ],
      verify: (_) {
        verify(() => mockMoFormService.deleteProductMove(any()));
      },
    );
  });
}
