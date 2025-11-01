function GOAP_Plan(_planner_plan) constructor {
  // Canonical planner plan reference (read-only)
  plan = _planner_plan; // expected shape:
  // {
  //   goal, actions: [ ... ], cost,
  //   meta: { built_at_tick, nodes_expanded, nodes_generated, open_peak, state_hash_start, state_hash_end, referenced_keys },
  //   to_string: function(){...}, debug_json: function(){...}
  // }

  // Quick sanity
  valid = function() {
    return (is_struct(plan) && variable_struct_exists(plan, "goal") && variable_struct_exists(plan, "actions"));
  };

  // Accessors (view-only)
  goal = function() {
    return valid() ? plan.goal : undefined;
  };

  goal_name = function() {
    if (!valid()) { return undefined; }
    return (is_struct(plan.goal) && variable_struct_exists(plan.goal, "name")) ? plan.goal.name : undefined;
  };

  actions = function() {
    return valid() ? plan.actions : [];
  };

  actions_count = function() {
    return valid() ? array_length(plan.actions) : 0;
  };

  action_names = function() {
    if (!valid()) { return []; }
    var _arr = plan.actions;
    var _len = array_length(_arr);
    var _out = array_create(_len);
    for (var _i = 0; _i < _len; ++_i) {
      var _a = _arr[_i];
      _out[_i] = (is_struct(_a) && variable_struct_exists(_a, "name")) ? _a.name : string(_i);
    }
    return _out;
  };

  cost = function() {
    return valid() && is_real(plan.cost) ? plan.cost : undefined;
  };

  meta = function() {
    return valid() && variable_struct_exists(plan, "meta") ? plan.meta : undefined;
  };

  built_at_tick = function() {
    var _m = meta();
    return (is_struct(_m) && variable_struct_exists(_m, "built_at_tick")) ? _m.built_at_tick : undefined;
  };

  // View formatting (do not mutate underlying plan)
  to_string = function() {
    if (!valid()) { return "[GOAP_Plan invalid]"; }
    var _g = goal_name();
    var _c = cost();
    var _n = actions_count();
    return "[Plan goal=" + string(_g) + " cost=" + string(_c) + " steps=" + string(_n) + "]";
  };

  debug_json = function() {
    if (!valid()) { return json_stringify({ plan_valid:false }, false); }
    // Prefer planner’s own debug_json if available
    if (variable_struct_exists(plan, "debug_json") && is_method(plan, plan.debug_json)) {
      return plan.debug_json();
    }
    var _names = action_names();
    var _dbg = {
      goal: goal_name(),
      cost: cost(),
      len: actions_count(),
      actions: _names,
      meta: meta()
    };
    return json_stringify(_dbg, false);
  };
}

// Legacy-compatible alias constructor (returns GOAP_Plan instance)
function GOAP_ActionPlan(_planner_plan) {
  return new GOAP_Plan(_planner_plan);
}
