/// @desc Coordinates a collection of Animus sensors.
/// @param {Animus_Agent|Undefined} agent
/// @param {Struct|Undefined} world
/// @param {Struct|Undefined} blackboard
/// @param {Animus_Memory|Undefined} memory
/// @returns {Animus_SensorHub}
function Animus_SensorHub(agent, world, blackboard, memory) constructor {
    sensors = [];
    _agent = agent;
    _world = world;
    _blackboard = blackboard;
    _memory = memory;

    /// @desc Updates the hub context references.
    /// @param {Animus_Agent|Undefined} agent_ref
    /// @param {Struct|Undefined} world_ref
    /// @param {Struct|Undefined} blackboard_ref
    /// @param {Animus_Memory|Undefined} memory_ref
    /// @returns {Animus_SensorHub}
    configure = function(agent_ref, world_ref, blackboard_ref, memory_ref) {
        _agent = agent_ref;
        _world = world_ref;
        _blackboard = blackboard_ref;
        _memory = memory_ref;
        return self;
    };

    /// @desc Assigns the memory source used for sampling.
    /// @param {Animus_Memory|Undefined} memory_ref
    /// @returns {Animus_SensorHub}
    set_memory = function(memory_ref) {
        _memory = memory_ref;
        return self;
    };

    /// @desc Retrieves the memory source currently bound.
    /// @returns {Animus_Memory|Undefined}
    get_memory = function() {
        return _memory;
    };

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

    /// @desc Returns a shallow context struct for sensors that need it.
    /// @returns {Struct}
    context = function() {
        return {
            agent: _agent,
            world: _world,
            blackboard: _blackboard,
            memory: _memory
        };
    };

    /// @desc Ticks all sensors, respecting their intervals.
    /// @param {Real} dt
    /// @returns {Void}
    tick = function(dt_or_memory, maybe_dt) {
        var memory_ref = _memory;
        var dt = 0;
        if (argument_count >= 2) {
            memory_ref = argument[0];
            dt = argument[1];
        } else if (argument_count == 1) {
            dt = dt_or_memory;
        }
        if (is_undefined(dt)) {
            dt = 0;
        }
        var length = array_length(sensors);
        for (var i = 0; i < length; ++i) {
            var sensor = sensors[i];
            if (is_struct(sensor) && Animus_Core.is_callable(sensor.tick)) {
                sensor.tick(memory_ref, dt);
            }
        }
    };
}

/// @desc Backward compatible constructor alias.
/// @returns {Animus_SensorHub}
function GOAP_SensorHub() constructor {
    var agent = argument_count > 0 ? argument[0] : undefined;
    var world = argument_count > 1 ? argument[1] : undefined;
    var blackboard = argument_count > 2 ? argument[2] : undefined;
    var memory = argument_count > 3 ? argument[3] : undefined;
    return Animus_SensorHub(agent, world, blackboard, memory);
}
