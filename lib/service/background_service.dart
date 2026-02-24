import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz;

import '../../MO/pages/MoForm/service/mo_form_service.dart';
import '../../MO/pages/MoList/service/hive/models.dart';

/// Manages a persistent background service to periodically sync and cache
/// essential Odoo reference data (products, BOMs, users, work centers) into Hive.
///
/// This allows the app to work offline or with reduced latency when creating/editing
/// Manufacturing Orders by providing fast local access to dropdown/select options.
///
/// Uses `flutter_background_service` for Android/iOS background execution.
@pragma('vm:entry-point')
class BackgroundService {
  static final service = FlutterBackgroundService();

  /// Initializes Hive with required adapters and opens necessary boxes.
  /// Must be called before any Hive operations in background or main isolate.
  static Future<void> initializeHive() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    // Register all Hive adapters (only once)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HiveProductAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HiveWorkCenterAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(HiveBomAdapter());
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(HiveUserModelAdapter());
    }

    // Open boxes if not already open
    if (!Hive.isBoxOpen('products')) {
      await Hive.openBox<HiveProduct>('products');
    }
    if (!Hive.isBoxOpen('bom')) await Hive.openBox<HiveBom>('bom');
    if (!Hive.isBoxOpen('users')) await Hive.openBox<HiveUserModel>('users');
    if (!Hive.isBoxOpen('workCenters')) {
      await Hive.openBox<HiveWorkCenter>('workCenters');
    }
  }

  /// Configures and starts the background service.
  ///
  /// - Android: runs in background (not foreground by default)
  /// - iOS: handles foreground/background transitions
  /// Initializes timezone and Hive before starting.
  static Future<void> initializeService() async {
    tz.initializeTimeZones();
    await initializeHive();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // Entry point for Android background execution
        onStart: onStart,
        autoStart: true,
        isForegroundMode: false,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Core background task: fetches latest reference data from Odoo and caches it in Hive.
  ///
  /// Clears old data before inserting fresh records to keep cache consistent.
  /// Closes boxes in `finally` block to avoid resource leaks in background.
  static Future<void> loadDataInBackground() async {
    try {
      final odooService = MoFormService();
      await odooService.initializeClient();

      final products = await odooService.loadProducts();
      final hiveProducts = products
          .map((p) => HiveProduct(id: p.id, name: p.name))
          .toList();

      final boms = await odooService.loadBom();
      final hiveBoms = boms
          .map((b) => HiveBom(id: b.id, name: b.name))
          .toList();

      final users = await odooService.loadUsers();
      final hiveUsers = users
          .map((u) => HiveUserModel(id: u.id, name: u.name))
          .toList();

      final workCenters = await odooService.loadWorkCenters();
      final hiveWorkCenters = workCenters
          .map((w) => HiveWorkCenter(id: w.id, name: w.name))
          .toList();

      final productBox = Hive.box<HiveProduct>('products');
      final bomBox = Hive.box<HiveBom>('bom');
      final userBox = Hive.box<HiveUserModel>('users');
      final workCenterBox = Hive.box<HiveWorkCenter>('workCenters');

      await productBox.clear();
      await productBox.addAll(hiveProducts);

      await bomBox.clear();
      await bomBox.addAll(hiveBoms);

      await userBox.clear();
      await userBox.addAll(hiveUsers);

      await workCenterBox.clear();
      await workCenterBox.addAll(hiveWorkCenters);
    } catch (e) {
    } finally {
      await Hive.box<HiveProduct>('products').close();
      await Hive.box<HiveBom>('bom').close();
      await Hive.box<HiveUserModel>('users').close();
      await Hive.box<HiveWorkCenter>('workCenters').close();
    }
  }
}

/// Android/iOS background entry point (runs in separate isolate).
///
/// Initializes Hive and performs data sync.
/// Listens for stop signal from main app if needed.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  await BackgroundService.initializeHive();
  await BackgroundService.loadDataInBackground();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

/// iOS background handler (very limited execution time).
///
/// Currently just returns true (minimal work allowed on iOS background).
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
