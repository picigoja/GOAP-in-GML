
/// @desc Debug helpers for Animus usage.
function Animus_Debug() constructor {
    static _newline = "\n";

    /// @desc Dumps a canonical plan into a user friendly string.
    /// @param {Struct} plan
    /// @returns {String}
    static dump_plan = function(plan) {
        if (!is_struct(plan)) {
            return "[Animus][Plan] <undefined>";
        }
        var buffer = "[Animus][Plan]" + _newline;
        if (variable_struct_exists(plan, "goal")) {
            var goal_ref = plan.goal;
            var goal_name = (is_struct(goal_ref) && variable_struct_exists(goal_ref, "name")) ? goal_ref.name : "<unnamed>";
            buffer += "Goal     : " + string(goal_name) + _newline;
        }
        if (variable_struct_exists(plan, "cost")) {
            buffer += "Cost     : " + string(plan.cost) + _newline;
        }
        if (variable_struct_exists(plan, "actions")) {
            var actions = plan.actions;
            var len = is_array(actions) ? array_length(actions) : 0;
            buffer += "Steps    : " + string(len) + _newline;
            for (var i = 0; i < len; ++i) {
                var action = actions[i];
                var action_name = (is_struct(action) && variable_struct_exists(action, "name")) ? action.name : "action_" + string(i);
                buffer += "  " + string(i) + ": " + action_name + _newline;
            }
        }
        if (variable_struct_exists(plan, "meta")) {
            var meta = plan.meta;
            if (is_struct(meta)) {
                if (variable_struct_exists(meta, "nodes_expanded")) {
                    buffer += "Expanded : " + string(meta.nodes_expanded) + _newline;
                }
                if (variable_struct_exists(meta, "nodes_generated")) {
                    buffer += "Generated: " + string(meta.nodes_generated) + _newline;
                }
                if (variable_struct_exists(meta, "elapsed_ms")) {
                    buffer += "Elapsed  : " + string(meta.elapsed_ms) + " ms" + _newline;
                }
                if (variable_struct_exists(meta, "is_partial") && meta.is_partial) {
                    buffer += "NOTE     : Partial plan" + _newline;
                }
            }
        }
        return buffer;
    };

    /// @desc Profiles an expression and returns elapsed milliseconds.
    /// @param {String} name
    /// @param {Function} fn
    /// @returns {Struct}
    static profile_block = function(name, fn) {
        var label = is_string(name) ? name : "profile";
        var callable = Animus_Core.is_callable(fn) ? fn : undefined;
        var start_ms = current_time;
        var result = undefined;
        if (!is_undefined(callable)) {
            result = callable();
        }
        var end_ms = current_time;
        var elapsed = (end_ms - start_ms);
        #if DEBUG
        Animus_Core.log("debug", "Profile[" + label + "] " + string(elapsed) + " ms");
        #endif
        return { ms: elapsed, result: result };
    };

    /// @desc Builds a trace string from an executor debug snapshot.
    /// @param {Animus_Executor} executor
    /// @param {Struct|Undefined} plan
    /// @returns {String}
    static playback_to_string = function(executor, plan) {
        if (is_undefined(executor)) {
            return "[Animus][Trace] <no executor>";
        }
        var trace = Animus_Core.is_callable(executor.debug_trace_snapshot) ? executor.debug_trace_snapshot() : [];
        var text = "";
        if (is_struct(plan) && Animus_Core.is_callable(plan.to_string)) {
            text += "[PLAN]" + _newline + plan.to_string() + _newline;
        }
        text += "[TRACE]" + _newline;
        if (!is_array(trace) || array_length(trace) == 0) {
            text += "<empty>" + _newline;
            return text;
        }
        var count = array_length(trace);
        for (var i = 0; i < count; ++i) {
            var entry = trace[i];
            var timestamp = (is_struct(entry) && variable_struct_exists(entry, "t")) ? entry.t : 0;
            var tag = (is_struct(entry) && variable_struct_exists(entry, "tag")) ? entry.tag : "????";
            var a = (is_struct(entry) && variable_struct_exists(entry, "a")) ? entry.a : "";
            var b = (is_struct(entry) && variable_struct_exists(entry, "b")) ? entry.b : "";
            text += string_format(timestamp, 0, 3) + " | " + tag + " | a=" + string(a) + " | b=" + string(b) + _newline;
        }
        return text;
    };
}

Animus_Debug();
