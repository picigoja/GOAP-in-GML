function GOAP_Agent() constructor {
  // Identity
  name = "Agent";

  // Core references
  planner = undefined;           // GOAP_Planner
  memory = undefined;            // GOAP_Memory
  executor = undefined;          // GOAP_Executor (optional; not used here)
  world = undefined;             // external world reference
  blackboard = undefined;        // shared blackboard
  reservation_bus = undefined;   // shared reservation coordination map

  // Agent knowledge
  beliefs = [];                  // array or map of GOAP_Belief
  goals = [];                    // array of GOAP_Goal
  goals_to_check = [];           // alias for planner signature compatibility
  actions = [];                  // optional: catalog for UI/debug only

  // Planning state (read-only for others)
  last_goal = undefined;
  last_plan = undefined;         // planner result object
  last_plan_tick = 0;
  _active_plan = undefined;
  _last_snapshot = undefined;

  // Orchestration config
  config = {
    perception_period: 1,        // ticks
    planning_period: 1           // ticks
  };

  // Internal timers
  _next_perception_tick = 0;
  _next_planning_tick = 0;

  // ----- Binding -----
  bind = function(_planner, _memory, _executor_optional, _world_optional, _blackboard_optional) {
    planner = _planner;
    memory = _memory;
    executor = _executor_optional; // may be undefined; executor not used here
    if (argument_count > 3) { world = _world_optional; }
    if (argument_count > 4) { blackboard = _blackboard_optional; }
    return self;
  };

  set_goals = function(_goals_array) {
    goals = _goals_array;
    goals_to_check = _goals_array;
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
    if (is_undefined(planner) || is_undefined(memory)) { return undefined; }
    if (!is_array(goals_to_check)) { return undefined; }
    return _request_plan();
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
  tick = function(_dt) {
    if (is_undefined(_dt)) { _dt = 0; }
    if (is_undefined(memory)) { return; }
    var _now = memory._now();

    if (_now >= _next_perception_tick) {
      _next_perception_tick = _now + config.perception_period;
      tick_perception();
    }

    // Lazy planning tick: only trigger scheduled planning when idle
    if (_now >= _next_planning_tick && is_undefined(_active_plan)) {
      _next_planning_tick = _now + config.planning_period;
      var _queued_plan = tick_planning();
      if (!is_undefined(_queued_plan)) {
        _active_plan = _queued_plan;
      }
    }

    // Ensure executor exists
    if (is_undefined(executor)) {
      executor = new GOAP_Executor();
    }

    if (is_undefined(reservation_bus)) {
      reservation_bus = {};
    }

    // Ensure a current plan exists and executor is started
    if (is_undefined(_active_plan)) {
      var _initial_plan = _request_plan();
      if (!is_undefined(_initial_plan)) {
        _active_plan = _initial_plan;
        executor.clear_plan_invalidated();
        executor.start(_active_plan, self, world, blackboard, memory, reservation_bus);
      }
    } else if (executor.status == "idle" || is_undefined(executor.plan_ref)) {
      executor.clear_plan_invalidated();
      executor.start(_active_plan, self, world, blackboard, memory, reservation_bus);
    }

    if (!is_undefined(executor)) {
      executor.tick(_dt);
    }

    if (!is_undefined(executor) && (executor.was_plan_invalidated() || executor.status == "failed" || executor.status == "interrupted")) {
      var _replan = _request_plan();
      executor.clear_plan_invalidated();
      if (!is_undefined(_replan)) {
        _active_plan = _replan;
        executor.start(_active_plan, self, world, blackboard, memory, reservation_bus);
      } else {
        _active_plan = undefined;
      }
    }

    if (!is_undefined(executor) && executor.status == "finished") {
      var _next_plan = _request_plan();
      if (!is_undefined(_next_plan)) {
        _active_plan = _next_plan;
        executor.start(_active_plan, self, world, blackboard, memory, reservation_bus);
      } else {
        _active_plan = undefined;
      }
    }
  };

  // ----- Deprecated/removed execution methods (intentionally absent) -----
  // No perform_action(), no update_action(), no stop_action(), no invariant checks.
  // Execution belongs to GOAP_Executor bound externally.

  _request_plan = function() {
    if (is_undefined(planner) || is_undefined(memory)) { return undefined; }
    if (!is_array(goals_to_check)) { return undefined; }

    _last_snapshot = memory.snapshot(false);
    var _plan = planner.plan(self, goals_to_check, memory, last_goal);

    if (!is_undefined(_plan)) {
      last_plan = _plan;
      last_goal = _plan.goal;
      last_plan_tick = memory._now();
      on_plan(_plan);
    }

    return _plan;
  };
}
