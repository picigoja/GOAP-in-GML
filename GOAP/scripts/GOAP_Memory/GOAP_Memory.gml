function GOAP_Memory() constructor {
    data = {};          // key -> GOAP_MemoryBit
    update_tick = 0;

    tick = function() { update_tick += 1; };

    /// @param {String} _key
    /// @param {Any}    _default_value
    read = function(_key, _default_value, _ttl = -1) {
        if (!variable_struct_exists(data, _key)) return _default_value;
        var _bit = variable_struct_get(data, _key);
        if (_ttl >= 0 && (update_tick - _bit.last_updated) > _ttl) return _default_value;
        return _bit.value;
    };

    /// @param {String} _key
    /// @param {Any}    _value
    write = function(_key, _value) {
        var _changed = false;
    
        if (exists(_key)) {
            var _bit = variable_struct_get(data, _key);
            _changed = (_bit.value != _value) || is_array(_value) || is_struct(_value);
            if (_changed) {
                _bit.value        = _value;
                _bit.dirty        = true;
                _bit.last_updated = update_tick;
                _bit.notify_listeners(_key, _bit);
            } else {
                _bit.last_updated = update_tick;
            }
        } else {
            var _bit_new = new GOAP_MemoryBit(_value, update_tick);
            variable_struct_set(data, _key, _bit_new);
            _bit_new.notify_listeners(_key, _bit_new);
            _changed = true;
        }
        return _changed;
    };


    /// Readers (Beliefs/Planner) call this after consuming.
    /// @param {String} _key
    mark_clean = function(_key) {
        if (!exists(_key)) return false;
        var _bit = variable_struct_get(data, _key);
        _bit.dirty        = false;
        _bit.last_updated = update_tick;
        return true;
    };

    /// Shallow snapshot (treat as read-only).
    snapshot = function() {
        var _copy  = {};
        var _names = variable_struct_get_names(data);
        for (var i = 0; i < array_length(_names); i++) {
            var k = _names[i];
            variable_struct_set(_copy, k, variable_struct_get(data, k));
        }
        return _copy;
    };

    subscribe = function(_key, _other) {
        if !(is_instanceof(_other, GOAP_Belief) || is_instanceof(_other, GOAP_Sensor)) return false;
    
        if (!exists(_key)) {
            variable_struct_set(data, _key, new GOAP_MemoryBit(undefined, update_tick));
        }
        var _bit = variable_struct_get(data, _key);
        var _idx = array_get_index(_bit.listeners, _other);
        if (_idx < 0) array_push(_bit.listeners, _other);
        return true;
    };
    
    unsubscribe = function(_key, _other) {
        if !(is_instanceof(_other, GOAP_Belief) || is_instanceof(_other, GOAP_Sensor)) return false;
        if (!exists(_key)) return false;
    
        var _bit = variable_struct_get(data, _key);
        var _idx = array_get_index(_bit.listeners, _other);
        if (_idx >= 0) array_delete(_bit.listeners, _idx, 1);
        return (_idx >= 0);
    };
    
    exists = function(_key) {
        return variable_struct_exists(data, _key);
    };

    is_dirty = function(_key) {
        if (!exists(_key)) return false;
        return variable_struct_get(data, _key).dirty;
    };

}


/// @param {Any}  _value
/// @param {Real} _time_created
function GOAP_MemoryBit(_value = undefined, _time_created = 0) constructor {
    value        = _value;
    dirty        = true;
    listeners    = []; // Beliefs and/or Sensors
    last_updated = _time_created;

    notify_listeners = function(_key, _bit) {
        var _snapshot = array_create(array_length(listeners));
        array_copy(_snapshot, 0, listeners, 0, array_length(listeners));
        var _len = array_length(_snapshot);
        for (var _i = 0; _i < _len; _i++) {
            var _listener = _snapshot[_i];
            if (!is_undefined(_listener.on_memory_update)) {
                _listener.on_memory_update(_key, _key, _bit.value, _bit.dirty, _bit.last_updated);
            }
        }
    };
}
