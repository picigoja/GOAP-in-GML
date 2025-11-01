/// @file GOAP_ActionStrategy.gml
/// @desc Optional per-action runtime adapter (no planning concerns).

function GOAP_ActionStrategy(_action_ref) constructor {
    action = _action_ref; // reference to GOAP_Action instance (planning data only)

    // Runtime-only hooks — these are invoked by the future Executor, not the Planner.
    start = function(context) {
        // context: { agent, world, blackboard, memory, reservations }
        // Optional: allocate runtime state for this specific action execution.
        // Keep empty by default.
    };

    update = function(context, dt) {
        // Return one of: "running" | "success" | "failed" | "interrupted"
        // Keep minimal; by default do nothing and keep running.
        return "running";
    };

    stop = function(context, reason) {
        // Cleanup after success/failure/interruption.
        // reason: string or enum for diagnostics
    };

    // Invariant checks are runtime concerns (checked by the Executor).
    invariant_check = function(context) {
        // Return true if still valid to continue, false to request interruption.
        return true;
    };

    // Optional runtime metadata — durations/reservations are read by Executor.
    get_expected_duration = function(context) {
        // Return a scalar (seconds) or undefined for unknown.
        return undefined;
    };

    get_reservation_keys = function(context) {
        // Return array of reservation IDs required during execution, or [].
        return [];
    };
}
