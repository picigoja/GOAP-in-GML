
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
