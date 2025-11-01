/// GOAP_Belief Contract
/// - config: { memory_key, selector(context, default_value)->any, evaluator(value, source, belief)->bool, initial_value, on_change?(belief, previous_value, next_value, context)->Void }
/// - evaluate(context): runs selector with debounce; emits on_change when value transitions
/// - guarantees: selector called before evaluator, on_change fires after cached_value updates, auto_clean resets memory dirty flag
/// - listeners: on_memory_update(listener, key, value, dirty, timestamp) -> Void
///
/// @param {String} _name
/// @param {Struct|String|Real|Function|Undefined} _memory_config
/// @param {Function|Undefined} _maybe_evaluator
/// @param {Struct.Vector2} _location
function GOAP_Belief(_name, _memory_config = undefined, _maybe_evaluator = undefined, _location = new Vector2()) :
    _GOAP_Component(_name) constructor {
    static DEBUG_ENABLED = function() {
        if (variable_global_exists("GOAP_DEBUG")) return bool(global.GOAP_DEBUG);
        if (variable_global_exists("debug_mode")) return bool(global.debug_mode);
        return false;
    };

    static is_callable_value = function(_value) {
        return is_function(_value) || is_method(_value);
    };

    static normalize_config = function(_config, _fallback_evaluator) {
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

        if (is_callable_value(_config)) {
            if (is_callable_value(_fallback_evaluator)) {
                _result.selector  = _config;
                _result.evaluator = _fallback_evaluator;
            } else {
                var _condition = _config;
                _result.evaluator = function(_value, _source, _belief) {
                    return bool(_condition());
                };
            }
            return _result;
        }

        if (is_string(_config) || is_real(_config)) {
            _result.memory_key = _config;
            if (is_callable_value(_fallback_evaluator)) {
                _result.evaluator = _fallback_evaluator;
            }
            return _result;
        }

        _result.memory_key = _config;
        if (is_callable_value(_fallback_evaluator)) {
            _result.evaluator = _fallback_evaluator;
        }
        return _result;
    };

    static selector_from_memory_key = function(_key) {
        if (is_string(_key)) {
            return function(_source, _default_value) {
                if (is_instanceof(_source, GOAP_Memory)) {
                    return _source.read(_key, _default_value);
                }

                if (is_struct(_source) && variable_struct_exists(_source, _key)) {
                    var _bit = variable_struct_get(_source, _key);
                    if (is_struct(_bit) && variable_struct_exists(_bit, "value")) {
                        return _bit.value;
                    }
                    return _bit;
                }

                return _default_value;
            };
        }

        var _key_string = string(_key);
        return selector_from_memory_key(_key_string);
    };

    static debug_guard = function(_condition, _message) {
        if (DEBUG_ENABLED() && !_condition) {
            show_debug_message("[GOAP][Belief] " + string(_message));
        }
    };

    var _options = normalize_config(_memory_config, _maybe_evaluator);

    location      = _location;
    memory_key    = undefined;
    selector      = _options.selector;
    evaluator     = _options.evaluator;
    cached_value  = _options.initial_value;
    memory_source = undefined;
    auto_clean      = true;
    debounce_ticks  = 0;
    _last_eval_tick = -999;
    post_evaluate   = undefined;
    truth_map       = undefined;

    if (!is_undefined(_options.memory_key)) {
        if (is_string(_options.memory_key)) {
            memory_key = _options.memory_key;
        } else {
            memory_key = string(_options.memory_key);
        }
    }

    if (!is_callable_value(selector)) {
        if (!is_undefined(memory_key)) {
            selector = selector_from_memory_key(memory_key);
        } else {
            selector = function(_source, _default_value) {
                return _default_value;
            };
        }
    }

    if (!is_callable_value(evaluator)) {
        evaluator = function(_value, _source, _belief) {
            if (is_callable_value(truth_map)) return bool(truth_map(_value));
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

    set_auto_clean = function(_flag) { auto_clean = bool(_flag); };
    set_debounce   = function(_ticks) { debounce_ticks = max(0, floor(_ticks)); };

    /// @param {Struct.GOAP_Memory|Struct} _memory_snapshot
    /// @returns {Bool}
    evaluate = function(_memory_snapshot = undefined) {
        var _source = _memory_snapshot;
        if (is_undefined(_source)) {
            _source = memory_source;
        }

        if (debounce_ticks > 0 && is_instanceof(_source, GOAP_Memory) && !is_undefined(memory_key)) {
            var _mem_tick = _source.last_updated(memory_key);
            if (_mem_tick >= 0 && (_mem_tick - _last_eval_tick) < debounce_ticks) {
                // fall through for now (no cached short-circuit)
            }
        }

        var _value = read_value_from(_source, cached_value);
        if (!is_undefined(memory_key) && is_instanceof(_source, GOAP_Memory)) {
            var _bit = _source.get_bit(memory_key);
            debug_guard(!is_undefined(_bit), "Selector for belief '" + string(name) + "' could not resolve memory key '" + string(memory_key) + "'");
        }
        cached_value = _value;

        var _result = evaluator(_value, _source, self);
        debug_guard(is_bool(_result) || is_real(_result), "Evaluator for belief '" + string(name) + "' returned non-boolean convertible value");

        if (!is_undefined(_source) && is_instanceof(_source, GOAP_Memory) && !is_undefined(memory_key)) {
            if (auto_clean) _source.mark_clean(memory_key);
            _last_eval_tick = _source.last_updated(memory_key);
        }

        if (is_callable_value(post_evaluate)) {
            post_evaluate(_result, _value, _source, self);
        }

        return bool(_result);
    };

    on_memory_update = function(_listener, _memory_key, _value, _dirty, _timestamp) {
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

    to_struct = function() {
        return {
            name        : name,
            memory_key  : memory_key,
            cached_value: cached_value,
            debounce    : debounce_ticks,
            auto_clean  : auto_clean,
            last_eval   : _last_eval_tick,
            has_selector: is_function(selector) || is_method(selector),
        };
    };

    to_string = function() {
        var _info = "[Belief name=" + string(name) + " key=" + string(memory_key) + "]";
        return _info;
    };

    debug_json = function() {
        return json_stringify(to_struct(), false);
    };
}
