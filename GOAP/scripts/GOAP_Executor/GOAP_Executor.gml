/// @file GOAP_Executor.gml
/// @desc Minimal runtime executor for GOAP plans. Calls ActionStrategy only.

function ds_map_keys_like_struct(_s) {
  var _arr = [];
  if (is_undefined(_s)) {
    return _arr;
  }
  var _it = variable_struct_get_names(_s);
  var _len = array_length(_it);
  for (var _i = 0; _i < _len; ++_i) {
    array_push(_arr, _it[_i]);
  }
  return _arr;
}

function GOAP_Executor() constructor {
  // Internal state
  plan_ref = undefined;   // planner-returned plan object/struct
  step_index = -1;        // current action index in plan
  active_strategy = undefined;   // instance of GOAP_ActionStrategy for current action
  status = "idle";        // "idle" | "starting" | "running" | "stopping" | "finished" | "failed" | "interrupted"
  elapsed_in_step = 0;     // accumulates dt for current action
  reservation_bus = undefined;   // shared struct map of reservation key -> owner id
  held_reservations = [];         // array of currently held reservation keys
  _expected_duration = undefined; // expected duration hint for active action
  _owner_id = undefined;          // stable owner identifier for reservations
  plan_invalidated = false;       // sticky until cleared by agent
  on_plan_invalidated = undefined; // optional callback hook
  _last_invalidate_reason = undefined;
  logical_time = 0;               // logical clock advanced exclusively by caller-provided dt
  _rng_state = 0;                 // deterministic RNG state (uint32)
  _rng_inited = false;            // RNG initialization flag

  // Sticky execution context (provided at start)
  _agent = undefined;
  _world = undefined;
  _blackboard = undefined;
  _memory = undefined;
  _mem_listener = undefined;
  _mem_listener_attached = false;
  _mem_listener_mode = undefined;
  _belief_listener = undefined;
  _plan_stale = false;
  _relevant_keys = undefined;

  // Debug trace ring buffer (fixed capacity)
  _debug_cap = 256;
  _debug_buf = array_create(_debug_cap);
  _debug_head = 0;
  _debug_count = 0;
  _debug_enabled = true;

  const _DBG_T_TRANSITION = 0;
  const _DBG_T_ACTION_STEP = 1;
  const _DBG_T_INVARIANT_FAIL = 2;
  const _DBG_T_RESERVATION = 3;
  const _DBG_T_TIMEOUT = 4;

  for (var _dbg_i = 0; _dbg_i < _debug_cap; ++_dbg_i) {
    _debug_buf[_dbg_i] = { t: 0.0, ty: 0, a: 0, b: undefined };
  }

  _trace = function(_ty, _a, _b) {
    if (!_debug_enabled) return;
    var _entry = _debug_buf[_debug_head];
    _entry.t = logical_time;
    _entry.ty = _ty;
    _entry.a = _a;
    _entry.b = _b;
    _debug_head = (_debug_head + 1) mod _debug_cap;
    if (_debug_count < _debug_cap) {
      _debug_count += 1;
    }
  };

  _set_status = function(_new) {
    if (status != _new) {
      #if DEBUG
      show_debug_message("[GOAP_Executor] " + string(status) + " -> " + string(_new));
      #endif
      _trace(_DBG_T_TRANSITION, step_index, string(status) + "->" + string(_new));
      status = _new;
    }
  };

  var _clone_snapshot_value = function(_value) {
    if (is_array(_value)) {
      var _len = array_length(_value);
      var _copy = array_create(_len);
      for (var _i = 0; _i < _len; ++_i) {
        _copy[_i] = _clone_snapshot_value(_value[_i]);
      }
      return _copy;
    }
    if (is_struct(_value)) {
      var _clone = {};
      var _keys = variable_struct_get_names(_value);
      var _count = array_length(_keys);
      for (var _j = 0; _j < _count; ++_j) {
        var _key = _keys[_j];
        var _val = variable_struct_get(_value, _key);
        variable_struct_set(_clone, _key, _clone_snapshot_value(_val));
      }
      return _clone;
    }
    return _value;
  };

  // --- Public API ---

  start = function(_plan, _agent_ref, _world_ref, _bb_ref, _mem_ref, _bus_opt) {
    if (!is_undefined(_memory) && _memory != _mem_ref) {
      _detach_memory_listener();
    }

    plan_ref = _plan;
    _agent = _agent_ref;
    _world = _world_ref;
    _blackboard = _bb_ref;
    _memory = _mem_ref;
    _plan_stale = false;
    _relevant_keys = undefined;

    if (!is_undefined(plan_ref) && is_struct(plan_ref) && variable_struct_exists(plan_ref, "meta")) {
      var _meta = plan_ref.meta;
      if (is_struct(_meta) && variable_struct_exists(_meta, "referenced_keys")) {
        var _rk = _meta.referenced_keys;
        if (is_array(_rk)) {
          _relevant_keys = {};
          for (var _i = 0; _i < array_length(_rk); ++_i) {
            var _key_name = string(_rk[_i]);
            _relevant_keys[$ _key_name] = true;
          }
        }
      }
    }

    _ensure_memory_listener();

    reservation_bus = is_undefined(_bus_opt) ? {} : _bus_opt;
    held_reservations = [];
    _expected_duration = undefined;
    _owner_id = (is_struct(_agent) && variable_struct_exists(_agent, "id")) ? _agent.id : string(_agent);
    plan_invalidated = false;
    _last_invalidate_reason = undefined;

    step_index = -1;
    active_strategy = undefined;
    elapsed_in_step = 0;
    logical_time = 0;
    _set_status("starting");

    // Advance immediately to first action
    if (_advance_to_next_action()) {
      return true;
    }

    if (status == "starting") {
      _set_status("finished");
    }
    return false;
  };

  snapshot = function() {
    var _snap = {
      step_index : step_index,
      status : status,
      elapsed_in_step : elapsed_in_step,
      held_reservations : _clone_snapshot_value(held_reservations),
      logical_time : logical_time,
      rng_state : _rng_state,
      rng_inited : _rng_inited,
      plan_invalidated : plan_invalidated,
      invalid_reason : _last_invalidate_reason,
      plan_stale : _plan_stale,
      relevant_keys : ds_map_keys_like_struct(_relevant_keys),
      relevant_keys_defined : !is_undefined(_relevant_keys),
      trace_count : _debug_count,
      trace_head : _debug_head,
      trace_buf : _clone_snapshot_value(_debug_buf),
      expected_duration : _expected_duration
    };

    if (is_struct(plan_ref)) {
      if (variable_struct_exists(plan_ref, "debug_json")) {
        var _dbg_fn = plan_ref.debug_json;
        if (is_method(_dbg_fn)) {
          _snap.plan_debug = _dbg_fn();
        } else if (is_function(_dbg_fn)) {
          _snap.plan_debug = _dbg_fn();
        }
      }
      if (variable_struct_exists(plan_ref, "cost")) {
        _snap.plan_cost = plan_ref.cost;
      }
      if (variable_struct_exists(plan_ref, "meta")) {
        _snap.plan_meta = _clone_snapshot_value(plan_ref.meta);
      }
    }

    var _plan_actions = undefined;
    if (is_struct(plan_ref) && variable_struct_exists(plan_ref, "actions")) {
      _plan_actions = plan_ref.actions;
    }

    var _agent_actions = undefined;
    if (is_struct(_agent) && variable_struct_exists(_agent, "actions")) {
      _agent_actions = _agent.actions;
    }

    var _plan_goal = undefined;
    if (is_struct(plan_ref) && variable_struct_exists(plan_ref, "goal")) {
      _plan_goal = plan_ref.goal;
    }

    var _agent_goals = undefined;
    if (is_struct(_agent) && variable_struct_exists(_agent, "goals")) {
      _agent_goals = _agent.goals;
    }

    var _goal_index = undefined;
    var _goal_name = undefined;
    if (is_struct(_plan_goal)) {
      if (variable_struct_exists(_plan_goal, "name")) {
        _goal_name = _plan_goal.name;
      }
      if (is_array(_agent_goals)) {
        var _glen = array_length(_agent_goals);
        for (var _gi = 0; _gi < _glen; ++_gi) {
          if (_agent_goals[_gi] == _plan_goal) {
            _goal_index = _gi;
            break;
          }
        }
      }
    }

    _snap.plan_goal_index = _goal_index;
    _snap.plan_goal_name = _goal_name;

    var _indices = [];
    var _names = [];
    var _plan_len = 0;
    if (is_array(_plan_actions)) {
      _plan_len = array_length(_plan_actions);
      for (var _ai = 0; _ai < _plan_len; ++_ai) {
        var _act = _plan_actions[_ai];
        var _idx = undefined;
        if (is_array(_agent_actions)) {
          var _agent_len = array_length(_agent_actions);
          for (var _aj = 0; _aj < _agent_len; ++_aj) {
            if (_agent_actions[_aj] == _act) {
              _idx = _aj;
              break;
            }
          }
        }
        array_push(_indices, _idx);
        var _act_name = undefined;
        if (is_struct(_act) && variable_struct_exists(_act, "name")) {
          _act_name = _act.name;
        }
        array_push(_names, _act_name);
      }
    }

    _snap.plan_action_indices = _indices;
    _snap.plan_action_names = _names;
    _snap.plan_length = _plan_len;

    return _snap;
  };

  restore = function(_snap, _agent_ref, _world_ref, _bb_ref, _mem_ref, _bus_opt) {
    if (!is_struct(_snap)) {
      return false;
    }

    if (_mem_listener_attached) {
      _detach_memory_listener();
    }

    plan_ref = undefined;
    active_strategy = undefined;

    _agent = _agent_ref;
    _world = _world_ref;
    _blackboard = _bb_ref;
    _memory = _mem_ref;

    reservation_bus = is_undefined(_bus_opt) ? (is_undefined(reservation_bus) ? {} : reservation_bus) : _bus_opt;
    if (!is_struct(reservation_bus)) {
      reservation_bus = {};
    }

    _owner_id = (is_struct(_agent) && variable_struct_exists(_agent, "id")) ? _agent.id : string(_agent);

    var _agent_goals = undefined;
    if (is_struct(_agent) && variable_struct_exists(_agent, "goals")) {
      _agent_goals = _agent.goals;
    }

    var _plan_goal = undefined;
    if (is_array(_agent_goals) && is_real(_snap.plan_goal_index)) {
      var _goal_idx = floor(_snap.plan_goal_index);
      if (_goal_idx >= 0 && _goal_idx < array_length(_agent_goals)) {
        _plan_goal = _agent_goals[_goal_idx];
      }
    }
    if (is_undefined(_plan_goal) && is_string(_snap.plan_goal_name) && is_array(_agent_goals)) {
      var _goal_len = array_length(_agent_goals);
      for (var _gi = 0; _gi < _goal_len; ++_gi) {
        var _candidate_goal = _agent_goals[_gi];
        if (is_struct(_candidate_goal) && variable_struct_exists(_candidate_goal, "name")) {
          if (string(_candidate_goal.name) == string(_snap.plan_goal_name)) {
            _plan_goal = _candidate_goal;
            break;
          }
        }
      }
    }

    var _agent_actions = undefined;
    if (is_struct(_agent) && variable_struct_exists(_agent, "actions")) {
      _agent_actions = _agent.actions;
    }

    var _restored_actions = [];
    var _actions_missing = false;
    var _snap_indices = is_array(_snap.plan_action_indices) ? _snap.plan_action_indices : [];
    var _snap_names = is_array(_snap.plan_action_names) ? _snap.plan_action_names : [];
    var _target_len = 0;
    if (is_real(_snap.plan_length)) {
      _target_len = max(0, floor(_snap.plan_length));
    }
    if (_target_len < array_length(_snap_indices)) {
      _target_len = array_length(_snap_indices);
    }
    if (_target_len < array_length(_snap_names)) {
      _target_len = array_length(_snap_names);
    }

    for (var _ai = 0; _ai < _target_len; ++_ai) {
      var _resolved = undefined;
      if (is_array(_agent_actions)) {
        if (_ai < array_length(_snap_indices)) {
          var _idx_val = _snap_indices[_ai];
          if (is_real(_idx_val)) {
            var _idx_int = floor(_idx_val);
            if (_idx_int >= 0 && _idx_int < array_length(_agent_actions)) {
              _resolved = _agent_actions[_idx_int];
            }
          }
        }
        if (is_undefined(_resolved) && _ai < array_length(_snap_names)) {
          var _target_name = _snap_names[_ai];
          if (!is_undefined(_target_name)) {
            var _agent_len = array_length(_agent_actions);
            for (var _aj = 0; _aj < _agent_len; ++_aj) {
              var _candidate_action = _agent_actions[_aj];
              var _candidate_name = undefined;
              if (is_struct(_candidate_action) && variable_struct_exists(_candidate_action, "name")) {
                _candidate_name = _candidate_action.name;
              }
              if (_candidate_name == _target_name) {
                _resolved = _candidate_action;
                break;
              }
            }
          }
        }
      }

      if (is_undefined(_resolved) && _target_len > 0) {
        _actions_missing = true;
        break;
      }

      array_push(_restored_actions, _resolved);
    }

    if (_actions_missing) {
      _restored_actions = undefined;
    } else if (is_array(_restored_actions)) {
      var _restored_len = array_length(_restored_actions);
      for (var _ck = 0; _ck < _restored_len; ++_ck) {
        if (is_undefined(_restored_actions[_ck])) {
          _restored_actions = undefined;
          break;
        }
      }
    }

    if (is_array(_restored_actions)) {
      var _plan_meta_struct = {};
      if (is_struct(_snap.plan_meta)) {
        _plan_meta_struct = _clone_snapshot_value(_snap.plan_meta);
      }
      var _plan_cost_value = _snap.plan_cost;
      plan_ref = {
        goal : _plan_goal,
        actions : _restored_actions,
        cost : _plan_cost_value,
        meta : _plan_meta_struct
      };
      if (!is_real(plan_ref.cost)) {
        plan_ref.cost = 0;
      }
      variable_struct_set(plan_ref, "__plan_debug_cache", _snap.plan_debug);
      plan_ref.to_string = function() {
        var _goal_ref = self.goal;
        var _goal_name = (is_struct(_goal_ref) && variable_struct_exists(_goal_ref, "name")) ? string(_goal_ref.name) : "<goal>";
        return "GOAP Plan for " + _goal_name + " with " + string(array_length(self.actions)) + " actions at cost " + string(self.cost);
      };
      plan_ref.debug_json = function() {
        if (variable_struct_exists(self, "__plan_debug_cache") && !is_undefined(self.__plan_debug_cache)) {
          return self.__plan_debug_cache;
        }
        return json_stringify({ goal: self.goal, actions: self.actions, cost: self.cost, meta: self.meta }, false);
      };
    } else {
      var _planner = undefined;
      if (is_struct(_agent) && variable_struct_exists(_agent, "planner")) {
        _planner = _agent.planner;
      }
      if (!is_undefined(_planner) && variable_struct_exists(_planner, "plan")) {
        var _plan_method = _planner.plan;
        if (is_method(_plan_method)) {
          var _goals_for_plan = undefined;
          if (is_struct(_agent) && variable_struct_exists(_agent, "goals_to_check")) {
            _goals_for_plan = _agent.goals_to_check;
          }
          if (!is_array(_goals_for_plan) && is_struct(_agent) && variable_struct_exists(_agent, "goals")) {
            _goals_for_plan = _agent.goals;
          }
          var _last_goal_ref = undefined;
          if (is_struct(_agent) && variable_struct_exists(_agent, "last_goal")) {
            _last_goal_ref = _agent.last_goal;
          }
          var _new_plan = _plan_method(_agent, _goals_for_plan, _memory, _last_goal_ref);
          if (is_struct(_new_plan)) {
            plan_ref = _new_plan;
          }
        }
      }
    }

    var _restored_status = "idle";
    if (is_string(_snap.status)) {
      _restored_status = _snap.status;
    }

    var _restored_step = -1;
    if (is_real(_snap.step_index)) {
      _restored_step = floor(_snap.step_index);
    }
    if (_restored_step < -1) {
      _restored_step = -1;
    }

    var _plan_actions_valid = (is_struct(plan_ref) && variable_struct_exists(plan_ref, "actions") && is_array(plan_ref.actions));
    if (_plan_actions_valid) {
      var _len_actions = array_length(plan_ref.actions);
      if (_len_actions <= 0) {
        _restored_step = -1;
      } else if (_restored_step >= _len_actions) {
        _restored_step = _len_actions - 1;
      }
    } else {
      if (_restored_status == "running" || _restored_status == "stopping" || _restored_status == "starting") {
        _restored_status = "idle";
      }
      _restored_step = -1;
    }

    step_index = _restored_step;
    status = _restored_status;

    elapsed_in_step = is_real(_snap.elapsed_in_step) ? _snap.elapsed_in_step : 0;
    logical_time = is_real(_snap.logical_time) ? _snap.logical_time : 0;
    _rng_state = is_real(_snap.rng_state) ? _u32(_snap.rng_state) : 0;
    _rng_inited = (_snap.rng_inited == true);

    plan_invalidated = (_snap.plan_invalidated == true);
    _last_invalidate_reason = _snap.invalid_reason;
    _plan_stale = (_snap.plan_stale == true);

    _expected_duration = _snap.expected_duration;

    var _should_restore_keys = false;
    if (variable_struct_exists(_snap, "relevant_keys_defined")) {
      _should_restore_keys = (_snap.relevant_keys_defined == true);
    } else {
      if (is_array(_snap.relevant_keys) && array_length(_snap.relevant_keys) > 0) {
        _should_restore_keys = true;
      }
    }

    if (_should_restore_keys) {
      _relevant_keys = {};
      if (is_array(_snap.relevant_keys)) {
        var _rk_len = array_length(_snap.relevant_keys);
        for (var _rk = 0; _rk < _rk_len; ++_rk) {
          var _rk_value = _snap.relevant_keys[_rk];
          if (is_undefined(_rk_value)) {
            continue;
          }
          var _rk_name = string(_rk_value);
          if (_rk_name != "") {
            _relevant_keys[$ _rk_name] = true;
          }
        }
      }
    } else {
      _relevant_keys = undefined;
    }

    if (variable_struct_exists(_snap, "trace_buf") && !is_undefined(_snap.trace_buf)) {
      _debug_buf = _clone_snapshot_value(_snap.trace_buf);
      _debug_head = is_real(_snap.trace_head) ? floor(_snap.trace_head) : 0;
      _debug_count = is_real(_snap.trace_count) ? floor(_snap.trace_count) : 0;
      _debug_cap = array_length(_debug_buf);
      if (_debug_cap <= 0) {
        _debug_cap = 256;
        _debug_buf = array_create(_debug_cap);
        for (var _dbg_i = 0; _dbg_i < _debug_cap; ++_dbg_i) {
          _debug_buf[_dbg_i] = { t: 0.0, ty: 0, a: 0, b: undefined };
        }
        _debug_head = 0;
        _debug_count = 0;
      }
      if (_debug_count > _debug_cap) {
        _debug_count = _debug_cap;
      }
      if (_debug_head < 0) {
        _debug_head = (_debug_head mod _debug_cap + _debug_cap) mod _debug_cap;
      }
      if (_debug_head >= _debug_cap) {
        _debug_head = _debug_head mod _debug_cap;
      }
    }

    held_reservations = is_array(_snap.held_reservations) ? _clone_snapshot_value(_snap.held_reservations) : [];
    if (!is_struct(reservation_bus)) {
      reservation_bus = {};
    }
    if (!is_array(held_reservations)) {
      held_reservations = [];
    }
    var _held_len = array_length(held_reservations);
    for (var _hr = 0; _hr < _held_len; ++_hr) {
      var _res_key = held_reservations[_hr];
      if (!is_undefined(_res_key)) {
        reservation_bus[$ _res_key] = _owner_id;
      }
    }

    _mem_listener_attached = false;
    _mem_listener_mode = undefined;
    _ensure_memory_listener();

    active_strategy = undefined;
    var _has_actions = (is_struct(plan_ref) && variable_struct_exists(plan_ref, "actions") && is_array(plan_ref.actions));
    if (_has_actions && step_index >= 0 && step_index < array_length(plan_ref.actions) && ((_restored_status == "running") || (_restored_status == "stopping"))) {
      var _current_action = plan_ref.actions[step_index];
      active_strategy = new GOAP_ActionStrategy(_current_action);
      var _ctx_start = _make_context();
      if (is_undefined(_expected_duration)) {
        _expected_duration = active_strategy.get_expected_duration(_ctx_start);
      }
      active_strategy.start(_ctx_start);
    }

    return true;
  };

  tick = function(_dt) {
    // Deterministic: caller supplies dt. No direct time reads here.
    if (plan_ref == undefined) {
      return status;
    }

    if (status == "finished" || status == "failed" || status == "interrupted") {
      return status;
    }

    logical_time += _dt;

    // Lazy-advance if we're between actions
    if (status == "starting" && is_undefined(active_strategy)) {
      if (!_advance_to_next_action()) {
        // No more actions -> finished
        if (status == "starting") {
          _set_status("finished");
        }
        return status;
      }
    }

    if (status == "running") {
      // Update current action
      if (is_undefined(active_strategy)) {
        _release_reservations();
        _set_status("failed");
        return status;
      }

      var _ctx = _make_context();

      var _ok = active_strategy.invariant_check(_ctx);
      if (is_undefined(_ok) || !_ok) {
        var _inv_key = undefined;
        if (variable_struct_exists(active_strategy, "get_last_invariant_key")) {
          if (is_method(active_strategy, "get_last_invariant_key")) {
            _inv_key = active_strategy.get_last_invariant_key();
          } else {
            var _inv_fn = active_strategy.get_last_invariant_key;
            if (is_function(_inv_fn)) {
              _inv_key = _inv_fn();
            }
          }
        }
        _trace(_DBG_T_INVARIANT_FAIL, step_index, _inv_key);
        _set_status("stopping");
        active_strategy.stop(_ctx, "invariant_fail");
        _release_reservations();
        active_strategy = undefined;
        _invalidate_plan("invariant_fail", _ctx);
        _detach_memory_listener();
        _set_status("interrupted");
        return status;
      }

      elapsed_in_step += _dt;
      _ctx = _make_context();

      if (!is_undefined(_expected_duration) && is_real(_expected_duration) && elapsed_in_step > _expected_duration) {
        var _timeout_action = current_action();
        var _timeout_name = undefined;
        if (is_struct(_timeout_action) && variable_struct_exists(_timeout_action, "name")) {
          _timeout_name = _timeout_action.name;
        } else {
          _timeout_name = "action@" + string(step_index);
        }
        _trace(_DBG_T_TIMEOUT, step_index, _timeout_name);
        _set_status("stopping");
        active_strategy.stop(_ctx, "timeout");
        _release_reservations();
        active_strategy = undefined;
        _invalidate_plan("timeout", _ctx);
        _detach_memory_listener();
        _set_status("failed");
        return status;
      }

      // Runtime-only: Strategy drives lifecycles
      var _result = active_strategy.update(_ctx, _dt);

      // Normalize undefined -> "running"
      if (is_undefined(_result)) _result = "running";

      // Outcome handling
      if (_result == "running") {
        return status; // keep going
      } else if (_result == "success") {
        // Cleanly stop and advance
        _set_status("stopping");
        active_strategy.stop(_ctx, "success");
        _release_reservations();
        active_strategy = undefined;
        elapsed_in_step = 0;

        if (_plan_stale) {
          _plan_stale = false;
          _ctx = _make_context();
          _invalidate_plan("stale_memory", _ctx);
          _detach_memory_listener();
          _set_status("interrupted");
          return status;
        }

        var _has_next = false;
        if (plan_ref != undefined && is_struct(plan_ref) && variable_struct_exists(plan_ref, "actions")) {
          var _actions = plan_ref.actions;
          if (is_array(_actions)) {
            var _next_index = step_index + 1;
            if (_next_index < array_length(_actions)) {
              _has_next = true;
            }
          }
        }

        if (_has_next) {
          _set_status("starting");
          if (!_advance_to_next_action()) {
            if (status == "starting") {
              _set_status("finished");
            }
          }
        } else {
          _set_status("finished");
        }
        if (status == "finished") {
          _detach_memory_listener();
        }
        return status;
      } else if (_result == "failed") {
        // Stop and mark failed
        _set_status("stopping");
        active_strategy.stop(_ctx, "failed");
        _release_reservations();
        active_strategy = undefined;
        _invalidate_plan("action_failed", _ctx);
        _detach_memory_listener();
        _set_status("failed");
        return status;
      } else if (_result == "interrupted") {
        // Stop and mark interrupted
        _set_status("stopping");
        active_strategy.stop(_ctx, "interrupted");
        _release_reservations();
        active_strategy = undefined;
        _detach_memory_listener();
        _set_status("interrupted");
        return status;
      } else {
        // Defensive: treat unknown as failure
        _set_status("stopping");
        active_strategy.stop(_ctx, "invalid_result");
        _release_reservations();
        active_strategy = undefined;
        _detach_memory_listener();
        _set_status("failed");
        return status;
      }
    }

    return status;
  };

  is_running = function() {
    return (status == "starting" || status == "running" || status == "stopping");
  };

  current_action = function() {
    if (plan_ref == undefined) return undefined;
    if (step_index < 0) return undefined;
    if (!is_struct(plan_ref) || !variable_struct_exists(plan_ref, "actions")) return undefined;
    var _actions = plan_ref.actions;
    if (!is_array(_actions)) return undefined;
    if (step_index >= array_length(_actions)) return undefined;
    return _actions[step_index];
  };

  debug_trace_count = function() {
    return _debug_count;
  };

  debug_trace_capacity = function() {
    return _debug_cap;
  };

  debug_json = function() {
    var _out = {
      status : status,
      step_index : step_index,
      logical_time : logical_time,
      trace : []
    };

    var _n = _debug_count;
    var _start = (_debug_head - _n + _debug_cap) mod _debug_cap;
    for (var _i = 0; _i < _n; ++_i) {
      var _idx = (_start + _i) mod _debug_cap;
      var _entry = _debug_buf[_idx];
      array_push(_out.trace, {
        t : _entry.t,
        ty : _entry.ty,
        a : _entry.a,
        b : _entry.b
      });
    }
    return _out;
  };

  playback_to_string = function(_plan_opt) {
    var _s = "";
    var _plan_string = undefined;
    if (!is_undefined(_plan_opt) && is_struct(_plan_opt) && variable_struct_exists(_plan_opt, "to_string")) {
      if (is_method(_plan_opt, "to_string")) {
        _plan_string = _plan_opt.to_string();
      } else {
        var _to_string_fn = _plan_opt.to_string;
        if (is_function(_to_string_fn)) {
          _plan_string = _to_string_fn();
        }
      }
    }

    if (!is_undefined(_plan_string)) {
      _s += "[PLAN]\n" + _plan_string + "\n";
    }

    _s += "[TRACE]\n";
    var _n = _debug_count;
    var _start = (_debug_head - _n + _debug_cap) mod _debug_cap;

    for (var _j = 0; _j < _n; ++_j) {
      var _idx = (_start + _j) mod _debug_cap;
      var _e = _debug_buf[_idx];
      var _tag = "";
      switch (_e.ty) {
        case _DBG_T_TRANSITION:     _tag = "TRANS"; break;
        case _DBG_T_ACTION_STEP:    _tag = "STEP"; break;
        case _DBG_T_INVARIANT_FAIL: _tag = "INV!"; break;
        case _DBG_T_RESERVATION:    _tag = "RSRV"; break;
        case _DBG_T_TIMEOUT:        _tag = "TIME"; break;
        default:                    _tag = "????"; break;
      }
      _s += string_format(_e.t, 0, 3) + " | " + _tag + " | a=" + string(_e.a) + " | b=" + string(_e.b) + "\n";
    }
    return _s;
  };

  interrupt = function(_reason) {
    var _ctx = _make_context();
    if (!is_undefined(active_strategy)) {
      active_strategy.stop(_ctx, string(_reason));
      active_strategy = undefined;
    }
    _release_reservations();
    _detach_memory_listener();
    _set_status("interrupted");
  };

  clear_plan_invalidated = function() {
    plan_invalidated = false;
    _last_invalidate_reason = undefined;
    _plan_stale = false;
  };

  was_plan_invalidated = function() {
    return plan_invalidated;
  };

  get_invalidation_reason = function() {
    return _last_invalidate_reason;
  };

  // --- Internals ---

  _advance_to_next_action = function() {
    if (plan_ref == undefined) {
      active_strategy = undefined;
      return false;
    }
    if (!is_struct(plan_ref) || !variable_struct_exists(plan_ref, "actions")) {
      active_strategy = undefined;
      return false;
    }

    var _actions = plan_ref.actions;
    if (!is_array(_actions)) {
      active_strategy = undefined;
      return false;
    }

    step_index += 1;
    if (step_index >= array_length(_actions)) {
      active_strategy = undefined;
      return false;
    }

    var _action = _actions[step_index];
    var _dbg_name = undefined;
    if (is_struct(_action) && variable_struct_exists(_action, "name")) {
      _dbg_name = _action.name;
    } else {
      _dbg_name = "action@" + string(step_index);
    }

    // Instantiate per-action runtime adapter
    active_strategy = new GOAP_ActionStrategy(_action);
    elapsed_in_step = 0;
    held_reservations = [];
    _expected_duration = undefined;
    _trace(_DBG_T_ACTION_STEP, step_index, _dbg_name);

    var _ctx = _make_context();

    if (!is_struct(reservation_bus)) {
      reservation_bus = {};
    }

    var _keys = active_strategy.get_reservation_keys(_ctx);
    if (is_undefined(_keys)) {
      _keys = [];
    } else if (!is_array(_keys)) {
      _keys = [_keys];
    }

    for (var _i = 0; _i < array_length(_keys); _i++) {
      var _key = _keys[_i];
      if (variable_struct_exists(reservation_bus, _key)) {
        var _owner = reservation_bus[$ _key];
        if (_owner != _owner_id) {
          _trace(_DBG_T_RESERVATION, step_index, string(_key));
          active_strategy = undefined;
          _release_reservations();
          _set_status("stopping");
          _set_status("interrupted");
          return false;
        }
      }
    }

    for (var _j = 0; _j < array_length(_keys); _j++) {
      var _acquired_key = _keys[_j];
      reservation_bus[$ _acquired_key] = _owner_id;
      array_push(held_reservations, _acquired_key);
    }

    _expected_duration = active_strategy.get_expected_duration(_ctx);

    // Start the action
    _ctx = _make_context();
    _set_status("running");
    // Allow start to set up resources; it returns void
    active_strategy.start(_ctx);

    return true;
  };

  _release_reservations = function() {
    if (!is_struct(reservation_bus)) {
      reservation_bus = {};
    }

    if (is_array(held_reservations)) {
      for (var _r = 0; _r < array_length(held_reservations); _r++) {
        var _res_key = held_reservations[_r];
        if (variable_struct_exists(reservation_bus, _res_key) && reservation_bus[$ _res_key] == _owner_id) {
          variable_struct_remove(reservation_bus, _res_key);
        }
      }
    }
    held_reservations = [];
    _expected_duration = undefined;
  };

  _ensure_memory_listener = function() {
    if (is_undefined(_memory)) {
      return;
    }

    if (is_undefined(_mem_listener)) {
      var _executor_ref = self;
      _mem_listener = function(_key, _old_bit, _new_bit) {
        if (is_undefined(_executor_ref.plan_ref)) {
          return;
        }
        if (!is_undefined(_executor_ref._relevant_keys)) {
          var _k = string(_key);
          if (!variable_struct_exists(_executor_ref._relevant_keys, _k)) {
            return;
          }
        }
        _executor_ref._plan_stale = true;
      };
    }

    if (_mem_listener_attached) {
      return;
    }

    var _has_add = false;
    if (!is_undefined(_memory) && variable_struct_exists(_memory, "add_listener")) {
      var _add = _memory.add_listener;
      if (is_function(_add) || is_method(_memory, "add_listener")) {
        _memory.add_listener(_mem_listener);
        _mem_listener_attached = true;
        _mem_listener_mode = "collection";
        _has_add = true;
      }
    }

    if (!_has_add) {
      if (!is_undefined(_memory)) {
        _memory.on_bit_changed = _mem_listener;
        _mem_listener_attached = true;
        _mem_listener_mode = "legacy";
      }
    }
  };

  _detach_memory_listener = function() {
    if (!_mem_listener_attached) {
      return;
    }
    if (is_undefined(_memory)) {
      _mem_listener_attached = false;
      _mem_listener_mode = undefined;
      return;
    }

    if (_mem_listener_mode == "collection") {
      if (variable_struct_exists(_memory, "remove_listener")) {
        var _rem = _memory.remove_listener;
        if (is_function(_rem) || is_method(_memory, "remove_listener")) {
          _memory.remove_listener(_mem_listener);
        }
      }
    } else if (_mem_listener_mode == "legacy") {
      if (variable_struct_exists(_memory, "on_bit_changed") && _memory.on_bit_changed == _mem_listener) {
        _memory.on_bit_changed = undefined;
      }
    }

    _mem_listener_attached = false;
    _mem_listener_mode = undefined;
  };

  _invalidate_plan = function(_reason, _ctx) {
    _plan_stale = false;
    if (!plan_invalidated) {
      plan_invalidated = true;
      _last_invalidate_reason = _reason;
      if (!is_undefined(on_plan_invalidated)) {
        if (is_method(on_plan_invalidated) || is_function(on_plan_invalidated)) {
          on_plan_invalidated(self, _reason, _ctx);
        }
      }
    }
  };

  _make_context = function() {
    // Runtime context kept minimal and explicit
    // Determinism hygiene: strategies must not read system clocks or global RNGs.
    // Use the provided logical_time and rng_* helpers exclusively.
    var _ctx = {
      agent : _agent,
      world : _world,
      blackboard : _blackboard,
      memory : _memory,
      plan : plan_ref,
      step_index : step_index,
      elapsed : elapsed_in_step,
      logical_time : logical_time,
      rng_float01 : method(self, rng_float01),
      rng_int : method(self, rng_int),
      rng_chance : method(self, rng_chance)
    };
    return _ctx;
  };

  // --- Deterministic RNG utilities ---

  seed = function(_seed_val) {
    _rng_state = _u32(_seed_val);
    _rng_inited = true;
  };

  rng_float01 = function() {
    if (!_rng_inited) {
      seed(5489);
    }
    _rng_step();
    // convert to [0,1)
    return _rng_state / 4294967296.0;
  };

  rng_int = function(_min, _max) {
    var _f = rng_float01();
    return _min + floor(_f * (1 + _max - _min));
  };

  rng_chance = function(_p01) {
    return rng_float01() < _p01;
  };

  _rng_step = function() {
    var x = _rng_state;
    x ^= (x << 13) & 0xffffffff;
    x ^= (x >> 17) & 0xffffffff;
    x ^= (x << 5) & 0xffffffff;
    _rng_state = _u32(x);
  };

  _u32 = function(_v) {
    return (_v & 0xffffffff);
  };
}
