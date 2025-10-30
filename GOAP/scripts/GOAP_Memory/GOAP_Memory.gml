function GOAP_MemoryBit(_initial_value = undefined) constructor {
    value        = _initial_value;
    dirty        = true;
    last_updated = 0;
    version      = 0;
    source       = undefined;
    confidence   = 1.0;
}

function GOAP_Memory() constructor {
    data        = {};
    subs        = {};
    update_tick = 0;

    tick = function() { update_tick += 1; };
    _now = function() { return update_tick; };

    _ensure_bit = function(_key, _default_value = undefined) {
        if (!variable_struct_exists(data, _key)) {
            var _bit = new GOAP_MemoryBit(_default_value);
            _bit.last_updated = _now();
            variable_struct_set(data, _key, _bit);
        }
        return variable_struct_get(data, _key);
    };

    _changed = function(_old, _new) {
        if (is_array(_new) || is_struct(_new)) return true;
        return _old != _new;
    };

    _listeners_for = function(_key) {
        if (!variable_struct_exists(subs, _key)) variable_struct_set(subs, _key, []);
        return variable_struct_get(subs, _key);
    };

    _notify = function(_key, _bit) {
        if (!variable_struct_exists(subs, _key)) return;
        var _arr = variable_struct_get(subs, _key);
        var _n = array_length(_arr);
        for (var i = 0; i < _n; i++) {
            var _listener = _arr[i];
            if (is_undefined(_listener)) continue;
            if (is_method(_listener, "on_memory_update")) {
                _listener.on_memory_update(_listener, _key, _bit.value, _bit.dirty, _bit.last_updated);
            }
        }
    };

    read = function(_key, _default_value = undefined) {
        if (!variable_struct_exists(data, _key)) return _default_value;
        var _bit = variable_struct_get(data, _key);
        return is_undefined(_bit.value) ? _default_value : _bit.value;
    };

    get_bit = function(_key) {
        if (!variable_struct_exists(data, _key)) return undefined;
        return variable_struct_get(data, _key);
    };

    write = function(_key, _value, _opts = undefined) {
        var _bit = _ensure_bit(_key);
        var _force = false;
        if (is_struct(_opts) && variable_struct_exists(_opts, "force_dirty")) {
            _force = _opts.force_dirty;
        }

        if (_changed(_bit.value, _value) || _force) {
            _bit.value        = _value;
            _bit.dirty        = true;
            _bit.last_updated = _now();
            _bit.version     += 1;

            if (is_struct(_opts) && variable_struct_exists(_opts, "source")) {
                _bit.source = _opts.source;
            }
            if (is_struct(_opts) && variable_struct_exists(_opts, "confidence")) {
                _bit.confidence = _opts.confidence;
            }

            _notify(_key, _bit);
        } else {
            _bit.last_updated = _now();
        }
    };

    mark_dirty = function(_key) {
        var _bit = _ensure_bit(_key);
        _bit.dirty        = true;
        _bit.last_updated = _now();
        _bit.version     += 1;
        _notify(_key, _bit);
    };

    mark_clean = function(_key) {
        if (!variable_struct_exists(data, _key)) return;
        var _bit = variable_struct_get(data, _key);
        if (_bit.dirty) _bit.dirty = false;
    };

    subscribe = function(_key, _listener) {
        var _arr = _listeners_for(_key);
        if (array_get_index(_arr, _listener) < 0) array_push(_arr, _listener);
    };

    unsubscribe = function(_key, _listener) {
        if (!variable_struct_exists(subs, _key)) return;
        var _arr = variable_struct_get(subs, _key);
        var _i = array_get_index(_arr, _listener);
        if (_i >= 0) array_delete(_arr, _i, 1);
    };

    erase = function(_key) {
        if (variable_struct_exists(subs, _key)) variable_struct_remove(subs, _key);
        if (variable_struct_exists(data, _key)) variable_struct_remove(data, _key);
    };

    snapshot = function(_as_bits = false) {
        var _out = {};
        var _keys = variable_struct_get_names(data);
        var _n = array_length(_keys);
        for (var i = 0; i < _n; i++) {
            var _k = _keys[i];
            var _bit = variable_struct_get(data, _k);
            variable_struct_set(_out, _k, _as_bits ? _bit : _bit.value);
        }
        return _out;
    };

    is_dirty = function(_key) {
        if (!variable_struct_exists(data, _key)) return false;
        return variable_struct_get(data, _key).dirty;
    };

    last_updated = function(_key) {
        if (!variable_struct_exists(data, _key)) return -1;
        return variable_struct_get(data, _key).last_updated;
    };
}
