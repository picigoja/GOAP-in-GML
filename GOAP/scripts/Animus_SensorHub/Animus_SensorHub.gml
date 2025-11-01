/// @desc Coordinates a collection of Animus sensors.
/// @returns {Animus_SensorHub}
function Animus_SensorHub() constructor {
    sensors = [];

    /// @desc Adds a sensor to the hub.
    /// @param {Animus_Sensor} sensor
    /// @returns {Void}
    add_sensor = function(sensor) {
        if (is_undefined(sensor)) {
            return;
        }
        if (array_index_of(sensors, sensor) < 0) {
            array_push(sensors, sensor);
        }
    };

    /// @desc Removes a sensor from the hub.
    /// @param {Animus_Sensor} sensor
    /// @returns {Void}
    remove_sensor = function(sensor) {
        var index = array_index_of(sensors, sensor);
        if (index >= 0) {
            array_delete(sensors, index, 1);
        }
    };

    /// @desc Ticks all sensors, respecting their intervals.
    /// @param {Animus_Memory} memory
    /// @param {Real} dt
    /// @returns {Void}
    tick = function(memory, dt) {
        var length = array_length(sensors);
        for (var i = 0; i < length; ++i) {
            var sensor = sensors[i];
            if (is_struct(sensor) && Animus_Core.is_callable(sensor.tick)) {
                sensor.tick(memory, dt);
            }
        }
    };
}
