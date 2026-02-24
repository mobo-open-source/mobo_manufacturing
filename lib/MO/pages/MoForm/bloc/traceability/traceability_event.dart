/// Base class for all events in the `TraceabilityBloc`.
///
/// All events related to loading and managing traceability data (detailed move lines,
/// lot/serial numbers, etc.) for a Manufacturing Order must extend this class.
///
/// Currently, only one event exists: initial loading of product details and move lines
/// required for the traceability report.
abstract class TraceabilityEvent {}

/// Triggers the initial loading of traceability-related data for the MO.
///
/// When this event is dispatched to `TraceabilityBloc`:
/// • Emits loading state
/// • Fetches detailed product information for the main produced item
/// • Fetches detailed move line records (including lot/serial numbers) for each component move
/// • Combines results and emits loaded state (or error on failure)
///
/// This is the primary (and currently only) event used — automatically dispatched
/// when the `TraceabilityPage` is opened.
class LoadTraceabilityEvent extends TraceabilityEvent {}
