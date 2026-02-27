/// Base class for all events in the `ProductMoveBloc`.
///
/// All events related to loading and managing inventory/stock move details
/// for a Manufacturing Order must extend this class.
///
/// Currently, only one event exists: initial loading of detailed move lines
/// (including lot/serial numbers) for both finished product and components.
abstract class ProductMoveEvent {}

/// Triggers the initial loading of detailed stock move line records.
///
/// When this event is dispatched to `ProductMoveBloc`:
/// • Emits loading state
/// • Fetches move lines for the finished product (via `finished_move_line_ids`)
/// • Fetches move lines for each component/raw material move
/// • Combines results and emits loaded state (or error on failure)
///
/// This is the primary (and currently only) event used — automatically dispatched
/// when the `ProductMovePage` is opened.
class LoadProductMoveEvent extends ProductMoveEvent {}
