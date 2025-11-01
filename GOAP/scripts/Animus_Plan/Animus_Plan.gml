/// @desc Presentation wrapper around canonical planner output.
/// @param {Struct} plan_struct
/// @returns {Animus_Plan}
function Animus_Plan(plan_struct) constructor {
    plan_ref = plan_struct;

    /// @desc Checks that the wrapped plan is valid.
    /// @returns {Bool}
    is_valid = function() {
        return is_struct(plan_ref) && variable_struct_exists(plan_ref, "goal") && variable_struct_exists(plan_ref, "actions");
    };

    /// @desc Returns the plan goal.
    /// @returns {Animus_Goal|Undefined}
    goal = function() {
        return is_valid() ? plan_ref.goal : undefined;
    };

    /// @desc Returns the ordered action list.
    /// @returns {Array}
    actions = function() {
        return is_valid() ? plan_ref.actions : [];
    };

    /// @desc Returns plan cost.
    /// @returns {Real|Undefined}
    cost = function() {
        return is_valid() ? plan_ref.cost : undefined;
    };

    /// @desc Number of actions in the plan.
    /// @returns {Real}
    length = function() {
        return array_length(actions());
    };

    /// @desc Returns meta information.
    /// @returns {Struct|Undefined}
    meta = function() {
        return is_valid() ? plan_ref.meta : undefined;
    };

    /// @desc Serialises to stable JSON.
    /// @returns {String}
    to_json = function() {
        if (!is_valid()) {
            return json_stringify({ plan_valid: false }, false);
        }
        var meta_struct = meta();
        var payload = {
            goal: goal(),
            cost: cost(),
            actions: actions(),
            meta: meta_struct
        };
        return json_stringify(payload, false);
    };

    /// @desc Human-readable description.
    /// @returns {String}
    to_pretty_string = function() {
        if (!is_valid()) {
            return "[Animus_Plan invalid]";
        }
        var lines = [];
        var goal_ref = goal();
        var goal_name = (is_struct(goal_ref) && variable_struct_exists(goal_ref, "name")) ? goal_ref.name : "<unnamed>";
        var acts = actions();
        var count = array_length(acts);
        array_push(lines, "Goal: " + string(goal_name));
        array_push(lines, "Cost: " + string(cost()));
        array_push(lines, "Steps:");
        for (var i = 0; i < count; ++i) {
            var action = acts[i];
            var action_name = (is_struct(action) && variable_struct_exists(action, "name")) ? action.name : "action_" + string(i);
            array_push(lines, "  " + string(i) + ": " + action_name);
        }
        var meta_struct = meta();
        if (is_struct(meta_struct)) {
            array_push(lines, "Meta:");
            var keys = variable_struct_get_names(meta_struct);
            array_sort(keys, function(a, b) {
                if (a == b) return 0;
                return (a < b) ? -1 : 1;
            });
            var meta_len = array_length(keys);
            for (var m = 0; m < meta_len; ++m) {
                var key = keys[m];
                array_push(lines, "  " + key + ": " + string(variable_struct_get(meta_struct, key)));
            }
        }
        var output = "";
        var line_count = array_length(lines);
        for (var n = 0; n < line_count; ++n) {
            if (n > 0) {
                output += "\n";
            }
            output += lines[n];
        }
        return output;
    };
}
