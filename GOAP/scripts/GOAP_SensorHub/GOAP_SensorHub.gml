function GOAP_SensorHub(_agent_ref, _world_ref, _blackboard_ref, _memory_ref) constructor {
    _agent      = _agent_ref;
    _world      = _world_ref;
    _blackboard = _blackboard_ref;
    _memory     = _memory_ref;
    _sensors    = [];

    add_sensor = function(_sensor) {
        if (is_undefined(_sensor)) {
            return;
        }
        array_push(_sensors, _sensor);
    };

    remove_sensor = function(_sensor) {
        if (array_length(_sensors) == 0) {
            return;
        }
        for (var i = 0; i < array_length(_sensors); ++i) {
            if (_sensors[i] == _sensor) {
                array_delete(_sensors, i, 1);
                break;
            }
        }
    };

    tick = function(_dt) {
        if (array_length(_sensors) == 0) {
            return;
        }

        var _ctx = {
            agent      : _agent,
            world      : _world,
            blackboard : _blackboard,
            memory     : _memory
        };

        for (var i = 0; i < array_length(_sensors); ++i) {
            var _sensor = _sensors[i];
            if (is_undefined(_sensor)) {
                continue;
            }
            if (!variable_struct_exists(_sensor, "poll")) {
                continue;
            }
            var _poll = _sensor.poll;
            if (!(is_function(_poll) || is_method(_sensor, "poll"))) {
                continue;
            }
            _poll(_dt, _ctx, _memory);
        }
    };
}
