/// Main component GOAP Agent.
/// @param {String} _name
/// @param {Array<Struct.GOAP_Belief>} _beliefs
/// @param {Array<Struct.GOAP_Action>} _actions
/// @param {Array<Struct.GOAP_Goal>} _goals
function GOAP_Agent(_name, _beliefs = [], _actions = [], _goals = []) constructor {
    name = _name;
    beliefs = _beliefs;
    actions = _actions;
    goals   = _goals;
    
    memory       = new GOAP_Memory();
    sensors      = [];
    memory_clock = 0; // optional external tick source

    register_sensor = function(_sensor) {
        if (array_get_index(sensors, _sensor) >= 0) return;
        _sensor.attach(memory);
        array_push(sensors, _sensor);
    };

    tick_perception = function(_dt) {
        memory.tick();
        memory_clock += _dt;

        for (var _i = 0; _i < array_length(sensors); ++_i) {
            var _sensor = sensors[_i];
            if (!is_undefined(_sensor.poll)) {
                _sensor.poll(_dt, memory_clock);
            }
        }
    };

    get_memory = function() { return memory; };

    get_snapshot = function() {
        memory.tick();
        return memory.snapshot(); // planner receives read-only struct copy
    };

    acknowledge_effects = function(_effects_struct) {
        var _keys = variable_struct_get_names(_effects_struct);
        for (var _i = 0; _i < array_length(_keys); ++_i) {
            var _key = _keys[_i];
            memory.write(_key, variable_struct_get(_effects_struct, _key));
            memory.mark_clean(_key);
        }
    };

    on_memory_update = function(_listener_key, _memory_key, _value, _dirty, _timestamp) {
        // Optional agent-level hook for debugging or analytics
    };

    current_action = undefined;
    action_plan    = undefined;

    current_goal = undefined;
    last_goal    = undefined;

    planner = new GOAP_Planner();

    show_debug_message(string("GOAP Agent Created. Agent {0}, active", self.name));

    /// @param {String} _name
    component_find_name = function(_name) {
        static _n = _name;
        var _belief_index = array_find_index(self.beliefs, function(_b, _i) { return bool(_b.name == _n); });
        if _belief_index == -1 return noone;
        return self.beliefs[_belief_index];
    };

    /// @param {Real} _component_id
    component_find_id = function(_component_id) {
        static _id = _component_id;
        var _belief_index = array_find_index(self.beliefs, function(_b, _i) { return bool(_b.component_id == _id); });
        if _belief_index == -1 return noone;
        return self.beliefs[_belief_index];
    };

    /// @return {Bool}
    in_range_of = function(_first_position, _second_position, _range) {
        return bool(point_distance(_first_position.x, _first_position.y, _second_position.x, _second_position.y) <= _range);
    };

    start = function() {};

    update = function() {
        var _action_started = true;

        if self.current_action == undefined && self.action_plan == undefined {
            show_debug_message("Calculating any potential new plan");
            calculate_plan();
        }

        if self.action_plan != undefined && array_length(self.action_plan.actions) > 0 && self.current_action == undefined {
            self.current_action = array_shift(self.action_plan.actions);
            show_debug_message(string("Current action: {0}", self.current_action.name));
            _action_started = false;
        }

        if self.action_plan != undefined && self.current_action != undefined {
            if !_action_started {
                show_debug_message(string("GOAP Agent {0} started Action {1}", self.name, self.current_action.name));
                self.current_action.start();
                _action_started = true;
            }

            if self.current_action.is_complete() {
                show_debug_message(string("Action {0} is complete", self.current_action.name));
                self.current_action.stop();
                self.current_action = undefined;

                if array_length(self.action_plan.actions) == 0 {
                    show_debug_message("Plan complete");
                    replan();
                }
            } else if self.current_action.can_perform() {
                self.current_action.update();
            } else {
                show_debug_message("Plan invalidated, replanning");
                replan();
            }
        }
    };

    replan = function() {
        self.last_goal    = self.current_goal;
        self.current_goal = undefined;
        if (self.current_action != undefined) self.current_action.stop();
        self.current_action = undefined;
        self.action_plan    = undefined;
    };

    calculate_plan = function() {
        var _goals_to_check = self.goals;

        if self.current_goal != undefined {
            show_debug_message("Current goal exists, checking goals with higher priority");
            _goals_to_check = array_filter(self.goals, function(_goal) {
                var _priority_level = self.current_goal == undefined ? 0 : self.current_goal.priority;
                return bool(_goal.priority > _priority_level);
            });
        }

        var _plan = self.planner.plan(self, _goals_to_check, self.last_goal);
        if _plan != undefined {
            self.action_plan  = _plan;
            self.current_goal = _plan.goal;
            show_debug_message(self.action_plan.name);
        } else {
            show_debug_message("No valid plan found");
        }
    };
}
