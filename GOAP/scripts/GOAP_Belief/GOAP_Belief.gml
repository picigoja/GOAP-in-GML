/// @param {String} _name
/// @param {String|Function|Struct} _memory_config
/// @param {Function|Undefined} _maybe_evaluator
/// @param {Struct.Vector2} _location
function GOAP_Belief(_name, _memory_config = undefined, _maybe_evaluator = undefined, _location = new Vector2()) :
    _GOAP_Component(_name) constructor {
    var _legacy_condition = undefined;
    var _config_struct    = undefined;
    var _is_callable = function(_value) {
        return is_function(_value) || is_method(_value);
    };

    location      = _location;
    memory_key    = undefined;
    selector      = undefined;
    evaluator     = undefined;
    cached_value  = undefined;
    memory_source = undefined;
    condition     = undefined; // legacy accessor

    if (is_struct(_memory_config)) {
        _config_struct = _memory_config;
        if (variable_struct_exists(_config_struct, "memory_key")) {
            memory_key = variable_struct_get(_config_struct, "memory_key");
        }
        if (variable_struct_exists(_config_struct, "selector")) {
            selector = variable_struct_get(_config_struct, "selector");
        }
        if (variable_struct_exists(_config_struct, "evaluator")) {
            evaluator = variable_struct_get(_config_struct, "evaluator");
        }
        if (variable_struct_exists(_config_struct, "condition")) {
            _legacy_condition = variable_struct_get(_config_struct, "condition");
        }
    } else if (_is_callable(_memory_config) && is_undefined(_maybe_evaluator)) {
        // Legacy constructor: (_name, condition_fn, location)
        _legacy_condition = _memory_config;
    } else if (is_string(_memory_config) || is_real(_memory_config)) {
        memory_key = _memory_config;
        if (_is_callable(_maybe_evaluator)) {
            evaluator = _maybe_evaluator;
        }
    } else if (!_is_callable(_memory_config) && !is_undefined(_memory_config)) {
        // Support numeric ids or other keys by stringifying
        memory_key = _memory_config;
        if (_is_callable(_maybe_evaluator)) {
            evaluator = _maybe_evaluator;
        }
    } else if (_is_callable(_memory_config) && _is_callable(_maybe_evaluator)) {
        // Advanced usage: custom selector + evaluator
        selector  = _memory_config;
        evaluator = _maybe_evaluator;
    }

    if (!is_undefined(memory_key)) {
        memory_key = string(memory_key);
    }

    if (!is_function(selector) && !is_method(selector)) {
        if (is_undefined(memory_key)) {
            selector = function(_source, _default_value) { return _default_value; };
        } else {
            selector = function(_source, _default_value) {
                if (is_instanceof(_source, GOAP_Memory)) {
                    return _source.read(memory_key, _default_value);
                }

                if (is_struct(_source) && variable_struct_exists(_source, memory_key)) {
                    var _bit = variable_struct_get(_source, memory_key);
                    if (is_struct(_bit) && variable_struct_exists(_bit, "value")) {
                        return _bit.value;
                    }
                    return _bit;
                }

                return _default_value;
            };
        }
    }

    if (!is_function(evaluator) && !is_method(evaluator)) {
        evaluator = function(_value, _source, _belief) { return bool(_value); };
    }

    if (_is_callable(_legacy_condition)) {
        condition = _legacy_condition;
    } else {
        condition = function() {
            return evaluator(cached_value, memory_source, self);
        };
    }

    read_value_from = function(_source, _default_value = cached_value) {
        return selector(_source, _default_value);
    };

    bind_to_memory = function(_memory, _subscribe = true) {
        if (memory_source == _memory) return;

        if (!is_undefined(memory_source) && !is_undefined(memory_key)) {
            memory_source.unsubscribe(memory_key, self);
        }

        memory_source = _memory;
        if (is_undefined(memory_key) || is_undefined(memory_source)) return;

        if (_subscribe) {
            memory_source.subscribe(memory_key, self);
        }
        cached_value = memory_source.read(memory_key, cached_value);
    };

    unbind_memory = function() {
        if (is_undefined(memory_source) || is_undefined(memory_key)) return;
        memory_source.unsubscribe(memory_key, self);
        memory_source = undefined;
    };

    /// @param {Struct.GOAP_Memory|Struct} _memory_snapshot
    /// @returns {Bool}
    evaluate = function(_memory_snapshot = undefined) {
        var _source = _memory_snapshot;
        if (is_undefined(_source)) {
            _source = memory_source;
        }

        if (!is_undefined(memory_key) && !is_undefined(_source)) {
            var _value = read_value_from(_source, cached_value);
            cached_value = _value;
            var _result = evaluator(_value, _source, self);
            if (is_instanceof(_source, GOAP_Memory)) {
                _source.mark_clean(memory_key);
            }
            return _result;
        }

        if (_is_callable(condition)) {
            return condition();
        }

        return false;
    };

    on_memory_update = function(_listener_key, _memory_key, _value, _dirty, _timestamp) {
        if (!is_undefined(memory_key) && _memory_key == memory_key) {
            cached_value = _value;
        }
    };

    reset_cache = function(_value = undefined) {
        cached_value = _value;
    };

    has_memory = function() {
        return !is_undefined(memory_key);
    };

    get_cached_value = function() {
        return cached_value;
    };
}
