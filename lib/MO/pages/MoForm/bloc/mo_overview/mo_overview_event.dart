/// Base class for all events in the `MOOverviewBloc`.
///
/// All events related to the Manufacturing Order Overview page must extend this class.
/// Currently, only one event exists (initial data loading and widget building).
abstract class MOOverviewEvent {}

/// Triggers the initial loading and preparation of UI components for the MO Overview page.
///
/// When this event is added to the bloc:
/// • Emits loading state
/// • Builds the header card and material table widgets
/// • Emits loaded state with pre-built widgets (or error if building fails)
///
/// This is the only event currently used — dispatched automatically on bloc creation.
class LoadMOOverviewEvent extends MOOverviewEvent {}
