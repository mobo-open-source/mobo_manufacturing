import 'package:flutter/material.dart';

/// Base class for all states emitted by `MOOverviewBloc`.
///
/// Defines the possible UI states for the Manufacturing Order Overview page:
/// - Loading: while building header and material widgets
/// - Loaded: when widgets are ready to display
/// - Error: if widget building fails
///
/// All states extend this class for type safety in `BlocBuilder`.
abstract class MOOverviewState {}

/// State emitted while the overview page is loading and preparing UI components.
///
/// Typically shown with a centered loading animation (e.g., rotating dots).
class MOOverviewLoading extends MOOverviewState {}

/// Success state containing pre-built Flutter widgets ready for display.
///
/// After loading completes, the bloc emits this state with:
/// • `headerCard`: summary card widget (MO details, status, dates, etc.)
/// • `materialTable`: table/list of components (stock moves)
class MOOverviewLoaded extends MOOverviewState {
  final Widget headerCard;
  final Widget materialTable;

  MOOverviewLoaded({required this.headerCard, required this.materialTable});
}

/// Error state emitted when widget building fails (e.g., invalid data, exception).
///
/// Displays a user-friendly error message in the center of the screen.
class MOOverviewError extends MOOverviewState {
  final String message;

  MOOverviewError({required this.message});
}
