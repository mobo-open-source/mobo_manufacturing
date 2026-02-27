/// Base class for all states emitted by `TraceabilityBloc`.
///
/// Defines the possible UI states for the Traceability Report page:
/// - Initial: before any data is loaded
/// - Loading: while fetching product details and detailed move lines
/// - Loaded: when traceability data (product info + move lines with lot/serial) is ready
/// - Error: if loading fails (network issue, Odoo error, parsing failure, etc.)
///
/// All states extend this class for type safety in `BlocBuilder`.
abstract class TraceabilityState {}

/// Initial/empty state before traceability data loading begins.
///
/// Usually only visible for a brief moment (or as fallback).
class TraceabilityInitial extends TraceabilityState {}

/// Loading state emitted while product details and move lines are being fetched from Odoo.
///
/// Typically displays a centered loading indicator (e.g., rotating dots).
class TraceabilityLoading extends TraceabilityState {}

/// Success state containing all data needed for the traceability report.
///
/// After loading completes successfully, the bloc emits this state with:
/// • `productDetails`: detailed info about the main produced product
/// • `moveLines`: list of detailed move line records (each entry corresponds to one stock move)
class TraceabilityLoaded extends TraceabilityState {
  final List<dynamic> productDetails;
  final List<dynamic> moveLines;

  TraceabilityLoaded({required this.productDetails, required this.moveLines});
}

/// Error state emitted when loading traceability data fails.
///
/// Displays a user-friendly error message in the center of the screen.
class TraceabilityError extends TraceabilityState {
  final String message;

  TraceabilityError({required this.message});
}
