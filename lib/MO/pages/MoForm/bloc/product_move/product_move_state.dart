/// Base class for all states emitted by `ProductMoveBloc`.
///
/// Defines the possible UI states for the Product Move / Inventory Moves page:
/// - Initial: before any data is loaded
/// - Loading: while fetching detailed move line records
/// - Loaded: when move lines (including lot/serial info) are successfully loaded
/// - Error: if loading fails (network, Odoo error, parsing issue, etc.)
///
/// All states extend this class for type safety in `BlocBuilder`.
abstract class ProductMoveState {}

/// Initial/empty state before any move line data is requested.
///
/// Usually only shown for a brief moment (or as fallback).
class ProductMoveInitial extends ProductMoveState {}

/// Loading state emitted while detailed move lines are being fetched from Odoo.
///
/// Typically displays a centered loading indicator (e.g., rotating dots).
class ProductMoveLoading extends ProductMoveState {}

/// Success state containing detailed move line records for traceability.
///
/// After loading completes, the bloc emits this state with:
/// • `moveLines`: list of move line data (each entry is a list of lines for one move)
class ProductMoveLoaded extends ProductMoveState {
  final List<dynamic> moveLines;

  ProductMoveLoaded({required this.moveLines});
}

/// Error state emitted when loading move lines fails.
///
/// Displays a user-friendly error message (e.g., "Failed to load inventory moves").
class ProductMoveError extends ProductMoveState {
  final String message;

  ProductMoveError({required this.message});
}
