import 'package:equatable/equatable.dart';

/// Base class for all events in the Manufacturing Order (MO) Graph / Analytics feature
abstract class MoGraphEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Event to load or reload the data needed for MO graphs/charts
class LoadGraphData extends MoGraphEvent {
  final List<dynamic> moItems;
  final String filter;

  /// Creates event to load graph data with optional filtering criteria
  LoadGraphData({required this.moItems, this.filter = 'product_qty'});

  @override
  List<Object?> get props => [moItems, filter];
}

/// Event to switch between different chart visualization types
class ChangeChartType extends MoGraphEvent {
  final ChartType chartType;

  /// Creates event to change the active chart visualization style
  ChangeChartType(this.chartType);

  @override
  List<Object?> get props => [chartType];
}

/// Supported chart visualization types for MO analytics
enum ChartType { bar, line }
