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

  // Sticky execution context (provided at start)
  _agent = undefined;
  _world = undefined;
  _blackboard = undefined;
  _memory = undefined;

  _set_status = function(_new) {
    if (status != _new) {
      #if DEBUG
      show_debug_message("[GOAP_Executor] " + string(status) + " -> " + string(_new));
      #endif
      status = _new;
    }
  };

  // --- Public API ---

  start = function(_plan, _agent_ref, _world_ref, _bb_ref, _mem_ref, _bus_opt) {
    plan_ref = _plan;
    _agent = _agent_ref;
    _world = _world_ref;
    _blackboard = _bb_ref;
    _memory = _mem_ref;

    reservation_bus = is_undefined(_bus_opt) ? {} : _bus_opt;
    held_reservations = [];
    _expected_duration = undefined;
    _owner_id = (is_struct(_agent) && variable_struct_exists(_agent, "id")) ? _agent.id : string(_agent);
    plan_invalidated = false;
    _last_invalidate_reason = undefined;

    step_index = -1;
    active_strategy = undefined;
    elapsed_in_step = 0;
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
        _set_status("stopping");
        active_strategy.stop(_ctx, "invariant_fail");
        _release_reservations();
        active_strategy = undefined;
        _invalidate_plan("invariant_fail", _ctx);
        _set_status("interrupted");
        return status;
      }

      elapsed_in_step += _dt;
      _ctx = _make_context();

      if (!is_undefined(_expected_duration) && is_real(_expected_duration) && elapsed_in_step > _expected_duration) {
        _set_status("stopping");
        active_strategy.stop(_ctx, "timeout");
        _release_reservations();
        active_strategy = undefined;
        _invalidate_plan("timeout", _ctx);
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
        return status;
      } else if (_result == "failed") {
        // Stop and mark failed
        _set_status("stopping");
        active_strategy.stop(_ctx, "failed");
        _release_reservations();
        active_strategy = undefined;
        _invalidate_plan("action_failed", _ctx);
        _set_status("failed");
        return status;
      } else if (_result == "interrupted") {
        // Stop and mark interrupted
        _set_status("stopping");
        active_strategy.stop(_ctx, "interrupted");
        _release_reservations();
        active_strategy = undefined;
        _set_status("interrupted");
        return status;
      } else {
        // Defensive: treat unknown as failure
        _set_status("stopping");
        active_strategy.stop(_ctx, "invalid_result");
        _release_reservations();
        active_strategy = undefined;
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

  interrupt = function(_reason) {
    var _ctx = _make_context();
    if (!is_undefined(active_strategy)) {
      active_strategy.stop(_ctx, string(_reason));
      active_strategy = undefined;
    }
    _release_reservations();
    _set_status("interrupted");
  };

  clear_plan_invalidated = function() {
    plan_invalidated = false;
    _last_invalidate_reason = undefined;
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

    // Instantiate per-action runtime adapter
    active_strategy = new GOAP_ActionStrategy(_action);
    elapsed_in_step = 0;
    held_reservations = [];
    _expected_duration = undefined;

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

  _invalidate_plan = function(_reason, _ctx) {
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
    var _ctx = {
      agent : _agent,
      world : _world,
      blackboard : _blackboard,
      memory : _memory,
      plan : plan_ref,
      step_index : step_index,
      elapsed : elapsed_in_step
    };
    return _ctx;
  };
}
