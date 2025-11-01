/// @desc Declarative Animus belief definition with optional memory integration.
/// @param {String} name
/// @param {Struct|String|Function|Undefined} config
/// @param {Function|Undefined} evaluator
/// @returns {Animus_Belief}
function Animus_Belief(name, config, evaluator) constructor {
    var normalize_config = function(config_value, evaluator_value) {
        var result = {
            memory_key: undefined,
            selector: undefined,
            evaluator: undefined,
            initial_value: undefined,
            truth_map: undefined,
            debounce_ticks: 0,
            auto_clean: true,
            post_evaluate: undefined
        };

        if (is_struct(config_value)) {
            if (variable_struct_exists(config_value, "memory_key")) {
                result.memory_key = string(variable_struct_get(config_value, "memory_key"));
            }
            if (variable_struct_exists(config_value, "selector")) {
                result.selector = variable_struct_get(config_value, "selector");
            }
            if (variable_struct_exists(config_value, "evaluate")) {
                result.evaluator = variable_struct_get(config_value, "evaluate");
            } else if (variable_struct_exists(config_value, "evaluator")) {
                result.evaluator = variable_struct_get(config_value, "evaluator");
            }
            if (variable_struct_exists(config_value, "truth_map")) {
                result.truth_map = variable_struct_get(config_value, "truth_map");
            }
            if (variable_struct_exists(config_value, "debounce_ticks")) {
                result.debounce_ticks = max(0, floor(variable_struct_get(config_value, "debounce_ticks")));
            }
            if (variable_struct_exists(config_value, "auto_clean")) {
                result.auto_clean = bool(variable_struct_get(config_value, "auto_clean"));
            }
            if (variable_struct_exists(config_value, "post_evaluate")) {
                result.post_evaluate = variable_struct_get(config_value, "post_evaluate");
            }
            if (variable_struct_exists(config_value, "initial_value")) {
                result.initial_value = variable_struct_get(config_value, "initial_value");
            } else if (variable_struct_exists(config_value, "default_value")) {
                result.initial_value = variable_struct_get(config_value, "default_value");
            }
            if (variable_struct_exists(config_value, "thunk")) {
                var thunk = variable_struct_get(config_value, "thunk");
                if (Animus_Core.is_callable(thunk)) {
                    result.selector = function(memory, previous) {
                        return thunk();
                    };
                }
            }
        } else if (is_string(config_value)) {
            result.memory_key = string(config_value);
        } else if (Animus_Core.is_callable(config_value)) {
            result.selector = function(memory, previous) {
                return config_value();
            };
        } else if (!is_undefined(config_value)) {
            result.memory_key = string(config_value);
        }

        if (Animus_Core.is_callable(evaluator_value)) {
            result.evaluator = evaluator_value;
        }

        if (Animus_Core.is_callable(result.selector) == false && is_string(result.memory_key)) {
            var key = result.memory_key;
            result.selector = function(memory, previous) {
                if (is_struct(memory) && Animus_Core.is_callable(memory.get)) {
                    return memory.get(key);
                }
                if (is_struct(memory) && variable_struct_exists(memory, key)) {
                    return variable_struct_get(memory, key);
                }
                return previous;
            };
        }

        if (Animus_Core.is_callable(result.selector) == false) {
            result.selector = function(memory, previous) {
                return previous;
            };
        }

        if (Animus_Core.is_callable(result.evaluator) == false) {
            result.evaluator = function(value, source, belief) {
                return bool(value);
            };
        }

        return result;
    };

    var memory_now = function(source) {
        if (is_struct(source) && Animus_Core.is_callable(source._now)) {
            return source._now();
        }
        return 0;
    };

    var identity = new _Animus_Component(name);

    component_id = identity.component_id;
    component_name = identity.component_name;

    is_equal = function(other) {
        return identity.is_equal(other);
    };

    name = is_string(name) ? name : "Belief";

    var normalized = normalize_config(config, evaluator);

    memory_key = normalized.memory_key;
    selector = normalized.selector;
    evaluator_fn = normalized.evaluator;
    truth_map = normalized.truth_map;
    debounce_ticks = normalized.debounce_ticks;
    auto_clean = normalized.auto_clean;
    post_evaluate = normalized.post_evaluate;
    cached_value = normalized.initial_value;

    memory_source = undefined;
    _last_tick_evaluated = -1;
    _last_result = false;

    var map_truth = function(value) {
        if (!is_struct(truth_map)) {
            return value;
        }
        var key = string(value);
        if (variable_struct_exists(truth_map, key)) {
            return variable_struct_get(truth_map, key);
        }
        return value;
    };

    var read_value = function(source) {
        var now_tick = memory_now(source);
        if (debounce_ticks > 0 && _last_tick_evaluated >= 0) {
            if ((now_tick - _last_tick_evaluated) < debounce_ticks) {
                return cached_value;
            }
        }
        return selector(source, cached_value);
    };

    /// @desc Binds the belief to a memory source.
    /// @param {Animus_Memory} memory
    /// @returns {Void}
    bind = function(memory) {
        memory_source = memory;
    };

    /// @desc Unbinds the belief from its memory source.
    /// @returns {Void}
    unbind = function() {
        memory_source = undefined;
    };

    /// @desc Evaluates the belief immediately against the provided memory (or bound memory).
    /// @param {Animus_Memory|Struct|Undefined} memory
    /// @returns {Bool}
    evaluate_now = function(memory) {
        var source = is_undefined(memory) ? memory_source : memory;
        var raw_value = read_value(source);
        cached_value = raw_value;
        var mapped_value = map_truth(raw_value);
        var result = evaluator_fn(mapped_value, source, self);
        var now_tick = memory_now(source);
        _last_tick_evaluated = now_tick;
        _last_result = bool(result);

        if (!is_undefined(memory_key) && !is_undefined(source) && auto_clean) {
            if (Animus_Core.is_callable(source.clean)) {
                source.clean(memory_key);
            }
        }

        if (Animus_Core.is_callable(post_evaluate)) {
            post_evaluate(mapped_value, source, self, now_tick);
        }
        return _last_result;
    };

    /// @desc Returns the last evaluated result.
    /// @returns {Bool}
    is_true = function() {
        return bool(_last_result);
    };
}
