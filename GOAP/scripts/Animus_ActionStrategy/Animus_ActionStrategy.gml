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

    /// @desc Called when the executor interrupts the strategy.
    /// @param {Struct} context
    /// @param {String} reason
    /// @returns {Void}
    interrupt = function(context, reason) {};

    /// @desc Optional expected duration hint.
    /// @param {Struct} context
    /// @returns {Real|Undefined}
    expected_duration = function(context) {
        return undefined;
    };

    /// @desc Optional reservation keys for conflict management.
    /// @param {Struct} context
    /// @returns {Array}
    reservation_keys = function(context) {
        return [];
    };
}
