
/// @desc Core Animus utilities for error handling and logging.
function Animus_Core() constructor {
    static _levels = ["debug", "info", "warn", "error"];

    /// @desc Raises an Animus error, optionally fatal.
    /// @param {String} message
    /// @param {Bool} fatal
    /// @returns {Undefined}
    static raise = function(message, fatal) {
        var final_message = is_string(message) ? message : string(message);
        var fatal_flag = bool(fatal);
        show_error("[Animus] " + final_message, fatal_flag);
        return undefined;
    };

    /// @desc Asserts that a condition holds, otherwise raises.
    /// @param {Bool} condition
    /// @param {String} message
    /// @returns {Void}
    static assert = function(condition, message) {
        if (!condition) {
            var info = is_string(message) ? message : "Assertion failed";
            raise(info, true);
        }
    };

    /// @desc Checks if a value is callable.
    /// @param {Any} value
    /// @returns {Bool}
    static is_callable = function(value) {
        return is_function(value) || is_method(value);
    };

    /// @desc Validates the shape of a plan struct returned by the planner.
    /// @param {Struct|Undefined} plan
    /// @param {String|Undefined} context
    /// @returns {Void}
    static assert_plan_shape = function(plan, context) {
        if (is_undefined(plan)) {
            return;
        }
        var label = is_string(context) ? context : "Animus_Planner.plan";
        Animus_Core.assert(is_struct(plan), label + " expected plan struct");
        var has_actions = is_struct(plan) && variable_struct_exists(plan, "actions");
        Animus_Core.assert(has_actions && is_array(plan.actions), label + " expected plan.actions array");
        var has_meta = is_struct(plan) && variable_struct_exists(plan, "meta");
        Animus_Core.assert(has_meta && is_struct(plan.meta), label + " expected plan.meta struct");
        if (has_meta && variable_struct_exists(plan.meta, "referenced_keys")) {
            var keys_ref = plan.meta.referenced_keys;
            var valid_keys = is_array(keys_ref) || is_struct(keys_ref);
            Animus_Core.assert(valid_keys, label + " expected meta.referenced_keys array or struct");
        }
    };

    /// @desc Guards executor strategy return values.
    /// @param {Any} state
    /// @param {String|Undefined} action_name
    /// @returns {Void}
    static assert_run_state = function(state, action_name) {
        var valid = (state == "running") || (state == "success") || (state == "failed");
        var label = is_string(action_name) ? action_name : "<unknown>";
        Animus_Core.assert(valid, "[Animus_Executor] Strategy '" + label + "' returned invalid run state '" + string(state) + "'");
    };

    /// @desc Produces a readable string for debugging values.
    /// @param {Any} value
    /// @returns {String}
    static pretty = function(value) {
        return _pretty_internal(value, 0, 4);
    };

    /// @desc Emits a log entry to the debug console.
    /// @param {String} level
    /// @param {String} message
    /// @returns {Void}
    static log = function(level, message) {
        var lvl = string_lower(is_string(level) ? level : "info");
        if (array_index_of(_levels, lvl) < 0) {
            lvl = "info";
        }
        var final_message = is_string(message) ? message : string(message);
        show_debug_message("[Animus][" + lvl + "] " + final_message);
    };

    static _indent = function(depth) {
        var result = "";
        for (var i = 0; i < depth; ++i) {
            result += "  ";
        }
        return result;
    };

    static _pretty_internal = function(value, depth, max_depth) {
        if (depth >= max_depth) {
            return "<...>";
        }
        if (is_array(value)) {
            var len = array_length(value);
            var chunk = "[";
            for (var i = 0; i < len; ++i) {
                if (i > 0) {
                    chunk += ", ";
                }
                chunk += _pretty_internal(value[i], depth + 1, max_depth);
            }
            chunk += "]";
            return chunk;
        }
        if (is_struct(value)) {
            var keys = variable_struct_get_names(value);
            array_sort(keys, function(a, b) {
                if (a == b) return 0;
                return (a < b) ? -1 : 1;
            });
            var chunk = "{";
            var count = array_length(keys);
            for (var j = 0; j < count; ++j) {
                var key = keys[j];
                var formatted = _pretty_internal(variable_struct_get(value, key), depth + 1, max_depth);
                chunk += key + ":" + formatted;
                if (j < count - 1) {
                    chunk += ", ";
                }
            }
            chunk += "}";
            return chunk;
        }
        if (is_string(value)) {
            return "\"" + value + "\"";
        }
        return string(value);
    };
}

Animus_Core();

/// @desc Backward compatible GOAP_* constructor aliases.
function GOAP_Action(name, preconditions, effects, cost) constructor {
    return Animus_Action(name, preconditions, effects, cost);
}

function GOAP_Goal(name, desired_effects, priority) constructor {
    return Animus_Goal(name, desired_effects, priority);
}

function GOAP_Belief(name, config, evaluator) constructor {
    return Animus_Belief(name, config, evaluator);
}

function GOAP_Memory() constructor {
    return Animus_Memory();
}

function GOAP_Planner() constructor {
    var planner = new Animus_Planner();
    if (Animus_Core.is_callable(planner.plan)) {
        var original_plan = planner.plan;
        planner.plan = function(agent, goals, memory, last_goal) {
            var plan = original_plan(agent, goals, memory, last_goal);
            if (!is_undefined(plan)) {
                Animus_Core.assert_plan_shape(plan, "Animus_Planner.plan");
            }
            return plan;
        };
    }
    return planner;
}
