/// @file GOAP_Executor.gml
/// @desc Minimal runtime executor for GOAP plans. Calls ActionStrategy only.

function GOAP_Executor() constructor {
  // Internal state
  plan_ref = undefined;   // planner-returned plan object/struct
  step_index = -1;        // current action index in plan
  active_strategy = undefined;   // instance of GOAP_ActionStrategy for current action
  status = "idle";        // "idle" | "starting" | "running" | "stopping" | "finished" | "failed" | "interrupted"
  elapsed_in_step = 0;     // accumulates dt for current action

  // Sticky execution context (provided at start)
  _agent = undefined;
  _world = undefined;
  _blackboard = undefined;
  _memory = undefined;

  // --- Public API ---

  start = function(_plan, _agent_ref, _world_ref, _bb_ref, _mem_ref) {
    plan_ref = _plan;
    _agent = _agent_ref;
    _world = _world_ref;
    _blackboard = _bb_ref;
    _memory = _mem_ref;

    step_index = -1;
    active_strategy = undefined;
    elapsed_in_step = 0;
    status = "starting";

    // Advance immediately to first action
    return _advance_to_next_action();
  };

  tick = function(_dt) {
    // Deterministic: caller supplies dt. No direct time reads here.
    if (status == "finished" || status == "failed" || status == "interrupted" || plan_ref == undefined) {
      return status;
    }

    // Lazy-advance if we're between actions
    if (status == "starting" && is_undefined(active_strategy)) {
      if (!_advance_to_next_action()) {
        // No more actions -> finished
        status = "finished";
        return status;
      }
    }

    if (status == "running") {
      // Update current action
      elapsed_in_step += _dt;

      var _ctx = _make_context();
      // Runtime-only: Strategy drives lifecycles
      var _result = active_strategy.update(_ctx, _dt);

      // Normalize undefined -> "running"
      if (is_undefined(_result)) _result = "running";

      // Outcome handling
      if (_result == "running") {
        return status; // keep going
      } else if (_result == "success") {
        // Cleanly stop and advance
        status = "stopping";
        active_strategy.stop(_ctx, "success");
        active_strategy = undefined;
        elapsed_in_step = 0;

        // Move to next action or finish
        if (!_advance_to_next_action()) {
          status = "finished";
        }
        return status;
      } else if (_result == "failed") {
        // Stop and mark failed
        status = "stopping";
        active_strategy.stop(_ctx, "failed");
        active_strategy = undefined;
        status = "failed";
        return status;
      } else if (_result == "interrupted") {
        // Stop and mark interrupted
        status = "stopping";
        active_strategy.stop(_ctx, "interrupted");
        active_strategy = undefined;
        status = "interrupted";
        return status;
      } else {
        // Defensive: treat unknown as failure
        status = "stopping";
        active_strategy.stop(_ctx, "invalid_result");
        active_strategy = undefined;
        status = "failed";
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
    if (plan_ref == undefined) {
      status = "interrupted";
      return;
    }
    var _ctx = _make_context();
    if (!is_undefined(active_strategy)) {
      active_strategy.stop(_ctx, string(_reason));
      active_strategy = undefined;
    }
    status = "interrupted";
  };

  // --- Internals ---

  _advance_to_next_action = function() {
    if (plan_ref == undefined) return false;
    if (!is_struct(plan_ref) || !variable_struct_exists(plan_ref, "actions")) return false;

    var _actions = plan_ref.actions;
    if (!is_array(_actions)) return false;

    step_index += 1;
    if (step_index >= array_length(_actions)) {
      // No more actions
      active_strategy = undefined;
      status = "finished";
      return false;
    }

    var _action = _actions[step_index];

    // Instantiate per-action runtime adapter
    active_strategy = new GOAP_ActionStrategy(_action);
    elapsed_in_step = 0;

    // Start the action
    var _ctx = _make_context();
    status = "running";
    // Allow start to set up resources; it returns void
    active_strategy.start(_ctx);

    return true;
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
