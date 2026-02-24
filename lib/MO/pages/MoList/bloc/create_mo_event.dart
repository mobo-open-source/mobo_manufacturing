import 'package:equatable/equatable.dart';

/// Base class for all events related to creating a Manufacturing Order (MO)
abstract class CreateMOEvent extends Equatable {
  const CreateMOEvent();

  @override
  List<Object> get props => [];
}

/// Event to trigger loading of initial data needed for MO creation screen/form
class LoadCreateMOData extends CreateMOEvent {}

/// Event to submit and create a new Manufacturing Order
class CreateManufacturingOrder extends CreateMOEvent {
  final Map<String, dynamic> moData;

  const CreateManufacturingOrder(this.moData);

  @override
  List<Object> get props => [moData];
}