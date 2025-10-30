/// @param {String} _name
/// @param {Struct|String|Real|Function|Undefined} _memory_config
/// @param {Function|Undefined} _maybe_evaluator
/// @param {Struct.Vector2} _location
function GOAP_Belief(_name, _memory_config = undefined, _maybe_evaluator = undefined, _location = new Vector2()) :
    _GOAP_Component(_name) constructor {
    var _is_callable = function(_value) {
        return is_function(_value) || is_method(_value);
    };

    var _normalize_config = function(_config, _fallback_evaluator) {
        var _result = {
            memory_key    : undefined,
            selector      : undefined,
            evaluator     : undefined,
            initial_value : undefined,
        };

        if (is_undefined(_config)) {
            return _result;
        }

        if (is_struct(_config)) {
            if (variable_struct_exists(_config, "memory_key")) {
                _result.memory_key = variable_struct_get(_config, "memory_key");
            }
            if (variable_struct_exists(_config, "selector")) {
                _result.selector = variable_struct_get(_config, "selector");
            }
            if (variable_struct_exists(_config, "evaluator")) {
                _result.evaluator = variable_struct_get(_config, "evaluator");
            }
            if (variable_struct_exists(_config, "default_value")) {
                _result.initial_value = variable_struct_get(_config, "default_value");
            } else if (variable_struct_exists(_config, "initial_value")) {
                _result.initial_value = variable_struct_get(_config, "initial_value");
            }
            return _result;
        }

        if (_is_callable(_config) && _is_callable(_fallback_evaluator)) {
            _result.selector  = _config;
            _result.evaluator = _fallback_evaluator;
            return _result;
        }

        if (_is_callable(_config)) {
            var _condition = _config;
            _result.evaluator = function(_value, _source, _belief) {
                return bool(_condition());
            };
            return _result;
        }

        if (is_string(_config) || is_real(_config)) {
            _result.memory_key = _config;
            if (_is_callable(_fallback_evaluator)) {
                _result.evaluator = _fallback_evaluator;
            }
            return _result;
        }

        _result.memory_key = _config;
        if (_is_callable(_fallback_evaluator)) {
            _result.evaluator = _fallback_evaluator;
        }
        return _result;
    };

    var _options = _normalize_config(_memory_config, _maybe_evaluator);

    location      = _location;
    memory_key    = undefined;
    selector      = _options.selector;
    evaluator     = _options.evaluator;
    cached_value  = _options.initial_value;
    memory_source = undefined;

    if (!is_undefined(_options.memory_key)) {
        if (is_string(_options.memory_key)) {
            memory_key = _options.memory_key;
        } else {
            memory_key = string(_options.memory_key);
        }
    }

    if (!_is_callable(selector)) {
        if (!is_undefined(memory_key)) {
            var _key_copy = memory_key;
            selector = function(_source, _default_value) {
                if (is_undefined(_source)) {
                    return _default_value;
                }

                if (is_instanceof(_source, GOAP_Memory)) {
                    return _source.read(_key_copy, _default_value);
                }

                if (is_struct(_source) && variable_struct_exists(_source, _key_copy)) {
                    var _bit = variable_struct_get(_source, _key_copy);
                    if (is_struct(_bit) && variable_struct_exists(_bit, "value")) {
                        return _bit.value;
                    }
                    return _bit;
                }

                return _default_value;
            };
        } else {
            selector = function(_source, _default_value) {
                return _default_value;
            };
        }
    }

    if (!_is_callable(evaluator)) {
        evaluator = function(_value, _source, _belief) {
            return bool(_value);
        };
    }

    read_value_from = function(_source, _default_value = cached_value) {
        return selector(_source, _default_value);
    };

    bind_to_memory = function(_memory, _subscribe = true) {
        if (memory_source == _memory) {
            return;
        }

        if (!is_undefined(memory_source) && !is_undefined(memory_key)) {
            memory_source.unsubscribe(memory_key, self);
        }

        memory_source = _memory;

        if (is_undefined(memory_key) || is_undefined(memory_source)) {
            return;
        }

        if (_subscribe) {
            memory_source.subscribe(memory_key, self);
        }

        cached_value = memory_source.read(memory_key, cached_value);
    };

    unbind_memory = function() {
        if (is_undefined(memory_source) || is_undefined(memory_key)) {
            return;
        }
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

        var _value = read_value_from(_source, cached_value);
        cached_value = _value;

        var _result = evaluator(_value, _source, self);

        if (!is_undefined(_source) && is_instanceof(_source, GOAP_Memory) && !is_undefined(memory_key)) {
            _source.mark_clean(memory_key);
        }

        return bool(_result);
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
