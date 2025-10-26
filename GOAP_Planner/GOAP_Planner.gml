function GoapPlanner() constructor {

    /// @param {Struct.GoapAgent} _agent
    /// @param {Array<Struct.AgentGoal>} _goals
    /// @param {Struct.AgentGoal|Undefined} _most_recent_goal
    plan = function(_agent, _goals, _most_recent_goal) {
        var _achievable = array_filter(_goals, function(_g) { return _g.is_achieveable(); });

        array_sort(_achievable, function(a, b) { return b.priority - a.priority; });

        for (var i = 0; i < array_length(_achievable); i++) {
            var _goal     = _achievable[i];
            var _root     = new GOAP_Node(undefined, undefined, _goal.desired_effects, 0);
            var _visited  = ds_map_create();
            var _solutions = self.find_path(_root, _agent.actions, _visited);
            show_debug_message(json_stringify(_solutions, true));
            ds_map_destroy(_visited);

            if array_length(_solutions) > 0 {
                array_sort(_solutions, function(s1, s2) { return s1.cost - s2.cost; });
                var _best = _solutions[0];

                var _action_stack = [];
                for (var _walk = _best; !_walk.is_dead(); _walk = _walk.parent) {
                    array_push(_action_stack, _walk.action);
                }

                var _cost = _best.cost + (_goal.is_equal(_most_recent_goal) ? 1 : 0);
                var _plan_name = string(
                    "Agent {0}'s plan to Goal {1} through {2} Actions with a Cost of {3}",
                    _agent.name, _goal.name, array_length(_action_stack), _best.cost
                );
                return new GOAP_Plan(_plan_name, _goal, _action_stack, _cost);
            }
        }

        show_debug_message("No plan found!");
        return undefined;
    };

    function sign_effects(_effects) {
        var _ids = [];
        for (var i = 0; i < array_length(_effects); ++i) array_push(_ids, _effects[i].component_id);
        array_sort(_ids, function(a,b){ return a - b; });
        var _s = "";
        for (var j = 0; j < array_length(_ids); ++j) {
            if (j > 0) _s += ",";
            _s += string(_ids[j]);
        }
        return _s;
    }

    /// @return {Array<Struct.GOAP_Node>}
    find_path = function(_parent, _actions, _visited, _depth = 0, _max_depth = 32) {
        if (_depth > _max_depth) return;

        var _required = array_filter(_parent.required_effects, function(e){ return !e.evaluate(); });

        function _heuristic_unmet_count(_effects) {
            var c = 0;
            for (var i = 0; i < array_length(_effects); ++i) c += !(_effects[i].evaluate());
            return c;
        }

        // Lightweight A* ordering heuristic
        for (var i = 0; i < array_length(_actions); i++) {
            var swapped = false;
            for (var j = 0; j < array_length(_actions) - i - 1; j++) {
                var a = _actions[j];
                var b = _actions[j + 1];
                var nrA = array_union(array_difference(_parent.required_effects, a.effects), a.preconditions);
                var nrB = array_union(array_difference(_parent.required_effects, b.effects), b.preconditions);
                var fA = (_parent.cost + a.cost) + _heuristic_unmet_count(nrA);
                var fB = (_parent.cost + b.cost) + _heuristic_unmet_count(nrB);
                if fA > fB {
                    _actions[j]     = b;
                    _actions[j + 1] = a;
                    swapped = true;
                }
                if !swapped { break; }
            }
        }

        var _sig = sign_effects(_required) + "|" + string(_parent.action == undefined ? -1 : _parent.action.component_id);
        if (ds_map_exists(_visited, _sig)) { return; } else { ds_map_add(_visited, _sig, true); }

        var _solutions = [];
        if array_length(_required) == 0 {
            array_push(_solutions, _parent);
            return _solutions;
        }

        for (var k = 0; k < array_length(_actions); k++) {
            var act = _actions[k];
            if array_length(array_intersection(_required, act.effects)) == 0 { continue; }

            var new_required = array_difference(_required, act.effects);
            new_required     = array_union(new_required, act.preconditions);

            var node = new GOAP_Node(_parent, act, new_required, _parent.cost + act.cost);
            var s    = find_path(node, _actions, _visited, _depth + 1, _max_depth);
            if s != undefined {
                _solutions = array_union(_solutions, s);
            }
        }
        return _solutions;
    };
}
