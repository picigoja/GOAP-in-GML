/// @desc Runtime adapter for executing Animus actions.
/// @param {Animus_Action|Undefined} action
/// @returns {Animus_ActionStrategy}
function Animus_ActionStrategy(action) constructor {
    action_reference = action;

    /// @desc Called when execution begins.
    /// @param {Struct} context
    /// @returns {Void}
    start = function(context) {};

    /// @desc Called each tick, returns a run state constant.
    /// @param {Struct} context
    /// @param {Real} dt
    /// @returns {String}
    update = function(context, dt) {
        return Animus_RunState.RUNNING;
    };

    /// @desc Called when execution ends or is interrupted.
    /// @param {Struct} context
    /// @param {String} reason
    /// @returns {Void}
    stop = function(context, reason) {};

    /// @desc Optional invariant guard; return false to invalidate the plan.
    /// @param {Struct} context
    /// @returns {Bool}
    invariant_check = function(context) {
        return true;
    };

    /// @desc Optional expected duration hint.
    /// @param {Struct} context
    /// @returns {Real|Undefined}
    get_expected_duration = function(context) {
        return undefined;
    };

    /// @desc Optional reservation keys for conflict management.
    /// @param {Struct} context
    /// @returns {Array}
    get_reservation_keys = function(context) {
        return [];
    };

    /// @desc Optional accessor for the last invariant failure key.
    /// @returns {String|Undefined}
    get_last_invariant_key = function() {
        return undefined;
    };

    /// @desc Backward compatible interrupt hook (delegates to stop()).
    /// @param {Struct} context
    /// @param {String} reason
    /// @returns {Void}
    interrupt = function(context, reason) {
        stop(context, reason);
    };

    /// @desc Backward compatible expected duration alias.
    /// @param {Struct} context
    /// @returns {Real|Undefined}
    expected_duration = function(context) {
        return get_expected_duration(context);
    };

    /// @desc Backward compatible reservation keys alias.
    /// @param {Struct} context
    /// @returns {Array}
    reservation_keys = function(context) {
        return get_reservation_keys(context);
    };
}

/// @desc Backward compatible constructor alias.
/// @param {Animus_Action|Undefined} action
/// @returns {Animus_ActionStrategy}
function GOAP_ActionStrategy(action) constructor {
    return Animus_ActionStrategy(action);
}
