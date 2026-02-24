import 'package:hive/hive.dart';

part 'models.g.dart';

/// Lightweight Hive model for caching Product data locally.
///
/// Used to store frequently accessed products (e.g. for dropdowns in MO creation)
/// without hitting the Odoo backend every time.
@HiveType(typeId: 0)
class HiveProduct extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String name;

  HiveProduct({required this.id, required this.name});
}

/// Cached representation of a Work Center (mrp.workcenter).
///
/// Stores minimal data needed for work order selection/creation in MO form.
@HiveType(typeId: 1)
class HiveWorkCenter extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String name;

  HiveWorkCenter({required this.id, required this.name});
}

/// Minimal cached version of a Bill of Materials (mrp.bom).
///
/// Used for quick BOM selection when creating Manufacturing Orders.
@HiveType(typeId: 2)
class HiveBom extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String name;

  HiveBom({required this.id, required this.name});
}

/// Cached user model (res.users) for responsible person / operator selection.
@HiveType(typeId: 3)
class HiveUserModel extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String name;

  HiveUserModel({required this.id, required this.name});
}