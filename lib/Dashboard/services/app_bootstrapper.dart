import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../../../Dashboard/services/settings_storage_service.dart';
import '../../MO/pages/MoForm/bloc/mo_form/mo_form_bloc.dart';
import '../../MO/pages/MoForm/bloc/product_move/product_move_bloc.dart';
import '../../MO/pages/MoForm/bloc/traceability/traceability_bloc.dart';
import '../../MO/pages/MoForm/service/mo_form_service.dart';
import '../../MO/pages/MoList/bloc/create_mo_bloc.dart';
import '../../MO/pages/MoList/bloc/mo_list_bloc.dart';
import '../../MO/pages/MoList/bloc/mo_list_event.dart';
import '../../MO/pages/MoList/service/mo_list_service.dart';
import '../../MO/services/manufacturing_order_service.dart';
import '../../Scrap/bloc/scrap_bloc.dart';
import '../../Scrap/bloc/scrap_event.dart';
import '../../WorkOrders/providers/work_order_provider.dart';
import '../../WorkOrders/service/work_order_service.dart';

/// Central bootstrapper responsible for injecting global Providers and Blocs.
///
/// This class ensures that all required application-wide state managers
/// (Providers and BLoCs) are initialized and available in the widget tree.
///
/// Responsibilities:
///   • Register global ChangeNotifiers (e.g., WorkOrderProvider)
///   • Register feature-specific Blocs (MO, Scrap, Traceability, etc.)
///   • Control eager vs lazy initialization of dependencies
///   • Provide helper method to refresh core blocs when needed
///
/// Usage:
///   Wrap the root widget with [AppBootstrapper.provideAll]
///
/// Example:
///   return AppBootstrapper.provideAll(
///     child: MyApp(),
///   );
class AppBootstrapper {

  /// Wraps the given widget with all required Providers and BlocProviders.
  ///
  /// Initializes application-wide dependencies and injects them into the
  /// widget tree using MultiProvider and MultiBlocProvider.
  ///
  /// Initialization Behavior:
  ///   • WorkOrderProvider → eagerly initialized and preloaded
  ///   • MOListBloc → eagerly loads first page of Manufacturing Orders
  ///   • ScrapBloc → eagerly loads first page of Scrap items
  ///   • Other Blocs → lazily initialized when first accessed
  ///
  /// Parameters:
  ///   • [child] - Root widget that requires access to global providers/blocs
  ///
  /// Returns:
  ///   A widget tree wrapped with required dependency providers.
  static Widget provideAll({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) {
            final provider = WorkOrderProvider(WorkOrderService());
            provider.initialize();

            return provider;
          },
          lazy: false,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<MOListBloc>(
            create: (context) => MOListBloc(ManufacturingOrderService())
              ..add(const FetchMOList(page: 0)),
            lazy: false,
          ),

          BlocProvider<MoFormBloc>(
            create: (context) => MoFormBloc(
              MoFormService(),
              SettingsStorageService(),
            ),
            lazy: true,
          ),

          BlocProvider<CreateMOBloC>(
            create: (context) => CreateMOBloC(MoListService()),
            lazy: true,
          ),

          BlocProvider<ProductMoveBloc>(
            create: (context) => ProductMoveBloc(
              moItem: [],
              moveProducts: [],
            ),
            lazy: true,
          ),

          BlocProvider<TraceabilityBloc>(
            create: (context) => TraceabilityBloc(
              moItem: [],
              moveProducts: [],
            ),
            lazy: true,
          ),
          BlocProvider<ScrapBloc>(
            create: (context) => ScrapBloc()
              ..add(const LoadScrapItems(page: 0)),
            lazy: false,
          ),
        ],
        child: child,
      ),
    );
  }

  /// Reloads critical application data across main feature blocs.
  ///
  /// Typically used after:
  ///   • Login / Logout
  ///   • Company switch
  ///   • Manual refresh triggers
  ///
  /// Actions Performed:
  ///   • Reloads Manufacturing Order list (page 0)
  ///   • Reloads Scrap items list (page 0)
  ///   • Re-initializes Work Order provider data
  ///
  /// Parameters:
  ///   • [context] - Build context used to access registered blocs/providers
  static void reloadAppBlocs(BuildContext context) {
    context.read<MOListBloc>().add(const FetchMOList(page: 0));
    context.read<ScrapBloc>().add(LoadScrapItems(page: 0));
    context.read<WorkOrderProvider>().initialize();
  }
}