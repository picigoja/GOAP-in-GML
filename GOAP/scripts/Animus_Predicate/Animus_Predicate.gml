
/// @desc Predicate helpers for the Animus planning pipeline.
function Animus_Predicate() constructor {
    static _ops = ["eq", "ne", "gt", "ge", "lt", "le", "unset", "has"];

    static _normalize_entry = function(entry, mode) {
        var normalized = { key: "", op: "eq", value: true };
        if (is_string(mode)) {
            mode = string_lower(mode);
        } else {
            mode = "condition";
        }

        if (is_string(entry)) {
            var text = entry;
            if (string_length(text) > 0 && string_copy(text, 1, 1) == "!") {
                normalized.key = string_copy(text, 2, string_length(text) - 1);
                if (mode == "effect") {
                    normalized.op = "unset";
                    normalized.value = undefined;
                } else {
                    normalized.value = false;
                    normalized.op = "eq";
                }
            } else {
                normalized.key = text;
                normalized.value = true;
            }
            return normalized;
        }

        if (is_array(entry)) {
            var key_value = array_length(entry) >= 1 ? entry[0] : undefined;
            var val_value = array_length(entry) >= 2 ? entry[1] : true;
            var op_value = array_length(entry) >= 3 ? entry[2] : "eq";
            normalized.key = string(key_value);
            normalized.value = val_value;
            normalized.op = string_lower(string(op_value));
            return normalized;
        }

        if (is_struct(entry)) {
            if (variable_struct_exists(entry, "key")) {
                normalized.key = string(variable_struct_get(entry, "key"));
            } else if (variable_struct_exists(entry, "name")) {
                normalized.key = string(variable_struct_get(entry, "name"));
            }
            if (variable_struct_exists(entry, "value")) {
                normalized.value = variable_struct_get(entry, "value");
            } else if (variable_struct_exists(entry, "expected")) {
                normalized.value = variable_struct_get(entry, "expected");
            }
            if (variable_struct_exists(entry, "op")) {
                normalized.op = string_lower(string(variable_struct_get(entry, "op")));
            }
            if (variable_struct_exists(entry, "negate") && bool(variable_struct_get(entry, "negate"))) {
                if (mode == "effect") {
                    normalized.op = "unset";
                    normalized.value = undefined;
                } else {
                    normalized.op = "eq";
                    normalized.value = false;
                }
            }
            if (variable_struct_exists(entry, "unset") && bool(variable_struct_get(entry, "unset"))) {
                normalized.op = "unset";
                normalized.value = undefined;
            }
            return normalized;
        }

        if (!is_undefined(entry)) {
            normalized.value = entry;
        }
        return normalized;
    };

    /// @desc Normalizes an array of predicates into canonical structs.
    /// @param {Array} predicates
    /// @param {String} mode
    /// @returns {Array}
    static normalize_list = function(predicates, mode) {
        if (!is_array(predicates)) {
            return [];
        }
        var normalized = [];
        var len = array_length(predicates);
        for (var i = 0; i < len; ++i) {
            var pred = _normalize_entry(predicates[i], mode);
            if (is_string(pred.key) && pred.key != "") {
                var lowered = string_lower(pred.op);
                if (array_index_of(_ops, lowered) < 0) {
                    lowered = "eq";
                }
                pred.op = lowered;
                array_push(normalized, pred);
            }
        }
        return normalized;
    };

    static _state_has_key = function(state, key) {
        return is_struct(state) && variable_struct_exists(state, key);
    };

    static _state_read = function(state, key) {
        if (_state_has_key(state, key)) {
            return variable_struct_get(state, key);
        }
        return undefined;
    };

    /// @desc Evaluates a predicate against a state snapshot.
    /// @param {Struct} state
    /// @param {Struct} predicate
    /// @returns {Bool}
    static evaluate = function(state, predicate) {
        if (!is_struct(predicate)) {
            return false;
        }
        var lhs = _state_read(state, predicate.key);
        switch (predicate.op) {
            case "eq": return lhs == predicate.value;
            case "ne": return lhs != predicate.value;
            case "gt": return is_real(lhs) && lhs > predicate.value;
            case "ge": return is_real(lhs) && lhs >= predicate.value;
            case "lt": return is_real(lhs) && lhs < predicate.value;
            case "le": return is_real(lhs) && lhs <= predicate.value;
            case "unset": return !_state_has_key(state, predicate.key);
            case "has": return _state_has_key(state, predicate.key);
            default: return lhs == predicate.value;
        }
    };

    /// @desc Applies a predicate effect to a mutable state struct.
    /// @param {Struct} state
    /// @param {Struct} predicate
    /// @returns {Void}
    static apply_effect = function(state, predicate) {
        if (!is_struct(state) || !is_struct(predicate)) {
            return;
        }
        switch (predicate.op) {
            case "unset":
                if (_state_has_key(state, predicate.key)) {
                    variable_struct_remove(state, predicate.key);
                }
                break;
            default:
                variable_struct_set(state, predicate.key, predicate.value);
                break;
        }
    };

    /// @desc Extracts unique predicate keys referenced by an action.
    /// @param {Animus_Action} action
    /// @returns {Array}
    static extract_keys_from_action = function(action) {
        var out = [];
        var seen = {};
        if (!is_struct(action)) {
            return out;
        }
        var pre = variable_struct_exists(action, "preconditions") ? action.preconditions : undefined;
        var eff = variable_struct_exists(action, "effects") ? action.effects : undefined;
        var lists = [pre, eff];
        for (var idx = 0; idx < 2; ++idx) {
            var list_ref = lists[idx];
            if (!is_array(list_ref)) {
                continue;
            }
            var len = array_length(list_ref);
            for (var j = 0; j < len; ++j) {
                var pred = list_ref[j];
                if (!is_struct(pred) || !variable_struct_exists(pred, "key")) {
                    continue;
                }
                var key = string(pred.key);
                if (!variable_struct_exists(seen, key)) {
                    seen[$ key] = true;
                    array_push(out, key);
                }
            }
        }
        return out;
    };
}

Animus_Predicate();
