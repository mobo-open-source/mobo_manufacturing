import 'package:equatable/equatable.dart';

/// Base class for all events in the Manufacturing Order (MO) form BLoC.
///
/// All events must extend this class and implement proper `props` for correct
/// equality comparison (used by `flutter_bloc` to detect state changes).
abstract class MoFormEvent extends Equatable {
  const MoFormEvent();

  @override
  List<Object?> get props => [];
}

/// Triggers initial loading (or full refresh) of all data needed for the MO form.
///
/// Usually dispatched when entering the MO detail screen.
class LoadMoFormData extends MoFormEvent {
  final int moId;

  const LoadMoFormData(this.moId);

  @override
  List<Object?> get props => [moId];
}

/// Periodic tick event (fired every second) to increment duration of all running work orders.
///
/// Dispatched automatically by the global timer when at least one work order is in progress.
class TickWorkOrder extends MoFormEvent {}

/// Updates one or more header fields of the manufacturing order (product, quantity, dates, responsible, BOM…).
class UpdateManufacturingDetails extends MoFormEvent {
  /// Map of fields to update (Odoo-style field names as keys)
  final Map<String, dynamic> updatedDetails;
  final int moId;

  const UpdateManufacturingDetails(this.updatedDetails, this.moId);

  @override
  List<Object?> get props => [updatedDetails, moId];
}

/// Starts a work order (sets it to "In Progress" on backend and begins local timer tracking).
class StartWorkOrder extends MoFormEvent {
  final int moId;
  final int workOrderId;

  const StartWorkOrder(this.moId, this.workOrderId);

  @override
  List<Object?> get props => [moId, workOrderId];
}

/// Pauses a running work order (stops timer counting and updates backend).
class PauseWorkOrder extends MoFormEvent {
  final int moId;
  final int workOrderId;

  const PauseWorkOrder(this.moId, this.workOrderId);

  @override
  List<Object?> get props => [moId, workOrderId];
}

/// Marks a work order as completed ("Done") and stops local timer tracking.
class StopWorkOrder extends MoFormEvent {
  final int moId;
  final int workOrderId;

  const StopWorkOrder(this.moId, this.workOrderId);

  @override
  List<Object?> get props => [moId, workOrderId];
}

/// Blocks a work order (registers a stop/block at a work center with reason & description).
class BlockWorkOrder extends MoFormEvent {
  final int moId;
  final int workOrderId;
  final int? workCenterId;
  final int? reasonId;
  final String? description;

  const BlockWorkOrder({
    required this.moId,
    required this.workOrderId,
    this.workCenterId,
    this.reasonId,
    this.description,
  });

  @override
  List<Object?> get props => [
    moId,
    workOrderId,
    workCenterId,
    reasonId,
    description,
  ];
}

/// Removes block status from a work order at the specified work center.
class UnblockWorkOrder extends MoFormEvent {
  final int moId;
  final int workOrderId;
  final int? workCenterId;

  const UnblockWorkOrder(this.moId, this.workOrderId, this.workCenterId);

  @override
  List<Object?> get props => [moId, workOrderId, workCenterId];
}

/// Triggers scrapping of one or more components/materials of the MO.
class ScrapMo extends MoFormEvent {
  final Map<String, dynamic> scrapDetails;

  const ScrapMo(this.scrapDetails);

  @override
  List<Object?> get props => [scrapDetails];
}

/// Marks the entire manufacturing order as fully produced ("Produce All").
class ProduceAllMo extends MoFormEvent {
  final List<dynamic> moItem;

  const ProduceAllMo(this.moItem);

  @override
  List<Object?> get props => [moItem];
}

/// Performs an unbuild operation (reverse production / disassemble finished goods).
class UnbuildMo extends MoFormEvent {
  final List<dynamic> moItem;

  const UnbuildMo(this.moItem);

  @override
  List<Object?> get props => [moItem];
}

/// Cancels the manufacturing order.
class CancelMo extends MoFormEvent {
  final List<dynamic> moItem;

  const CancelMo(this.moItem);

  @override
  List<Object?> get props => [moItem];
}

/// Confirms the manufacturing order (usually moves from Draft → Confirmed).
class ConfirmMo extends MoFormEvent {
  final List<dynamic> moItem;

  const ConfirmMo(this.moItem);

  @override
  List<Object?> get props => [moItem];
}

/// Updates an existing component/stock move line (product, quantity, to-consume flag…).
class UpdateProductMove extends MoFormEvent {
  final int productMoveId;
  final int productId;
  final String productName;
  final double quantity;
  final double toConsume;

  const UpdateProductMove({
    required this.productMoveId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.toConsume,
  });

  @override
  List<Object?> get props => [
    productMoveId,
    productId,
    productName,
    quantity,
    toConsume,
  ];
}

/// Adds a new component/product line to the manufacturing order.
class AddProductToLine extends MoFormEvent {
  final int moId;
  final int productId;
  final String productName;
  final double toConsume;
  final double quantity;
  final int moProductId;

  const AddProductToLine({
    required this.moId,
    required this.productId,
    required this.productName,
    required this.toConsume,
    required this.quantity,
    required this.moProductId,
  });

  @override
  List<Object?> get props => [
    moId,
    productId,
    productName,
    toConsume,
    quantity,
    moProductId,
  ];
}

/// Deletes a component/stock move line from the manufacturing order.
class DeleteProductMove extends MoFormEvent {
  final int productMoveId;

  const DeleteProductMove(this.productMoveId);

  @override
  List<Object?> get props => [productMoveId];
}

/// Updates the consumed/picked quantity for a specific component move (real consumption tracking).
class UpdateConsume extends MoFormEvent {
  final int productMoveId;
  final bool picked;

  const UpdateConsume(this.productMoveId, this.picked);

  @override
  List<Object?> get props => [productMoveId, picked];
}

/// Informs the UI which field is currently being edited (used for focus/highlighting).
class UpdateEditingField extends MoFormEvent {
  final String? field;

  const UpdateEditingField(this.field);

  @override
  List<Object?> get props => [field];
}
