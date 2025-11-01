/// @desc Base Animus sensor definition with optional sampling interval.
/// @param {Real|Undefined} interval_seconds
/// @returns {Animus_Sensor}
function Animus_Sensor(interval_seconds) constructor {
    interval = max(0, is_real(interval_seconds) ? interval_seconds : 0);
    last_tick = -1;
    last_value = undefined;
    _accumulator = 0;

    /// @desc Called by the hub to allow the sensor to gather data.
    /// @param {Animus_Memory} memory
    /// @returns {Void}
    sense = function(memory) {};

    /// @desc Internal scheduler used by the hub.
    /// @param {Real} dt
    /// @returns {Bool}
    _should_sample = function(dt) {
        if (interval <= 0) {
            return true;
        }
        _accumulator += dt;
        if (_accumulator + 1e-6 >= interval) {
            _accumulator -= interval;
            return true;
        }
        return false;
    };

    /// @desc Invoked by the hub when sampling is due.
    /// @param {Animus_Memory} memory
    /// @param {Real} dt
    /// @returns {Void}
    tick = function(memory, dt) {
        if (_should_sample(dt)) {
            sense(memory);
            last_tick = Animus_Core.is_callable(memory._now) ? memory._now() : last_tick + 1;
        }
    };
}
