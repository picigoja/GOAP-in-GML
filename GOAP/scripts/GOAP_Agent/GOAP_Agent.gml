function GOAP_Agent() constructor {
  // Identity
  name = "Agent";

  // Core references
  planner = undefined;           // GOAP_Planner
  memory = undefined;            // GOAP_Memory
  executor = undefined;          // GOAP_Executor (optional; not used here)

  // Agent knowledge
  beliefs = [];                  // array or map of GOAP_Belief
  goals = [];                    // array of GOAP_Goal
  actions = [];                  // optional: catalog for UI/debug only

  // Planning state (read-only for others)
  last_goal = undefined;
  last_plan = undefined;         // planner result object
  last_plan_tick = 0;

  // Orchestration config
  config = {
    perception_period: 1,        // ticks
    planning_period: 1           // ticks
  };

  // Internal timers
  _next_perception_tick = 0;
  _next_planning_tick = 0;

  // ----- Binding -----
  bind = function(_planner, _memory, _executor_optional) {
    planner = _planner;
    memory = _memory;
    executor = _executor_optional; // may be undefined; executor not used here
    return self;
  };

  set_goals = function(_goals_array) {
    goals = _goals_array;
    return self;
  };

  set_actions = function(_actions_array) {
    actions = _actions_array;
    return self;
  };

  set_beliefs = function(_beliefs_collection) {
    beliefs = _beliefs_collection;
    return self;
  };

  bind_beliefs_to_memory = function() {
    if (is_undefined(memory)) { return; }
    // supports array or struct/map of beliefs
    if (is_array(beliefs)) {
      var _len = array_length(beliefs);
      for (var _i = 0; _i < _len; ++_i) {
        var _b = beliefs[_i];
        if (is_method(_b, bind_to_memory)) { _b.bind_to_memory(memory); }
      }
      return;
    }
    if (is_struct(beliefs)) {
      var _keys = variable_struct_get_names(beliefs);
      var _klen = array_length(_keys);
      for (var _j = 0; _j < _klen; ++_j) {
        var _bk = _keys[_j];
        var _b2 = variable_struct_get(beliefs, _bk);
        if (is_method(_b2, bind_to_memory)) { _b2.bind_to_memory(memory); }
      }
    }
  };

  // ----- Perception (sensing hook only) -----
  tick_perception = function() {
    // Intentionally empty: actual sensors live elsewhere (SensorBus).
    // Keep this as a scheduling hook to trigger sensor ticks or lightweight reads.
  };

  // ----- Planning (no execution) -----
  tick_planning = function() {
    if (is_undefined(planner) || is_undefined(memory)) { return; }
    if (!is_array(goals)) { return; }

    // Planner call uses the new signature
    var _plan = planner.plan(self, goals, memory, last_goal);

    if (!is_undefined(_plan)) {
      last_plan = _plan;
      last_goal = _plan.goal;
      last_plan_tick = memory._now();
      on_plan(_plan);
    }
  };

  // Callback when a new/updated plan is available (no execution here)
  on_plan = function(_plan) {
    // Optionally write a status into memory (only on change).
    if (!is_undefined(memory)) {
      var _current_goal_name = is_struct(_plan) && variable_struct_exists(_plan, "goal") ? _plan.goal.name : undefined;
      var _prev = memory.read("agent.plan.goal_name", undefined);
      if (_prev != _current_goal_name) {
        memory.write("agent.plan.goal_name", _current_goal_name, "agent", 0.9);
      }
    }
  };

  // ----- Update loop entrypoint (or call these separately from your Step) -----
  tick = function() {
    if (is_undefined(memory)) { return; }
    var _now = memory._now();

    if (_now >= _next_perception_tick) {
      _next_perception_tick = _now + config.perception_period;
      tick_perception();
    }

    if (_now >= _next_planning_tick) {
      _next_planning_tick = _now + config.planning_period;
      tick_planning();
    }
  };

  // ----- Deprecated/removed execution methods (intentionally absent) -----
  // No perform_action(), no update_action(), no stop_action(), no invariant checks.
  // Execution belongs to GOAP_Executor bound externally.
}
