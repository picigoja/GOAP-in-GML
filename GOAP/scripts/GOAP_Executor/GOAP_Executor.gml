/// @file GOAP_Executor.gml
/// @desc Minimal runtime executor for GOAP plans. Calls ActionStrategy only.

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
