function GOAP_Goal() constructor {
  // ----- user-assignable fields -----
  name = "Goal";
  desired_effects = [];   // array of pred
  priority_base = 0;      // numeric base priority
  priority = undefined;   // LEGACY: if set (number), copy into priority_base at init time

  // optional methods (planner will detect presence)
  is_relevant = is_undefined(is_relevant) ? undefined : is_relevant;                         // fn(beliefs, memory)->bool
  desired_satisfied = is_undefined(desired_satisfied) ? undefined : desired_satisfied;       // fn(state)->bool
  priority_delta = is_undefined(priority_delta) ? undefined : priority_delta;                 // fn(beliefs, memory)->number
  estimate_heuristic_from = is_undefined(estimate_heuristic_from) ? undefined : estimate_heuristic_from; // fn(state)->number

  // ----- legacy compatibility (one-time normalize) -----
  if (is_real(priority)) { priority_base = priority; }

  // ===== Internal helpers =====
  var _state_get = function(_state, _k) {
    return variable_struct_exists(_state, _k) ? variable_struct_get(_state, _k) : undefined;
  };

  var _normalize_predicate = function(_entry) {
    var _p = { key: undefined, value: true, negate: false, op: "eq" };
    if (is_string(_entry)) {
      if (string_length(_entry) > 0 && string_copy(_entry, 1, 1) == "!") {
        _p.key = string_copy(_entry, 2, string_length(_entry) - 1);
        _p.negate = true;
        _p.value = false;
        _p.op = "eq";
        return _p;
      }
      _p.key = _entry;
      _p.value = true;
      return _p;
    }
    if (is_array(_entry)) {
      var _k = array_length(_entry) >= 1 ? _entry[0] : undefined;
      var _v = array_length(_entry) >= 2 ? _entry[1] : true;
      _p.key = string(_k);
      _p.value = _v;
      return _p;
    }
    if (is_struct(_entry)) {
      if (variable_struct_exists(_entry, "key")) { _p.key = string(variable_struct_get(_entry, "key")); }
      if (variable_struct_exists(_entry, "value")) { _p.value = variable_struct_get(_entry, "value"); }
      if (variable_struct_exists(_entry, "negate")) { _p.negate = (variable_struct_get(_entry, "negate") == true); }
      if (variable_struct_exists(_entry, "op")) { _p.op = string(variable_struct_get(_entry, "op")); }
      if (_p.negate) { _p.value = false; _p.op = "eq"; }
      return _p;
    }
    return _p;
  };

  var _pred_ok = function(_pred, _state) {
    var _sv = _state_get(_state, _pred.key);
    switch (_pred.op) {
      case "eq": return (_sv == _pred.value);
      case "ne": return (_sv != _pred.value);
      case "gt": return (is_real(_sv) && _sv >  _pred.value);
      case "ge": return (is_real(_sv) && _sv >= _pred.value);
      case "lt": return (is_real(_sv) && _sv <  _pred.value);
      case "le": return (is_real(_sv) && _sv <= _pred.value);
      default:   return (_sv == _pred.value);
    }
  };

  // ===== Preferred methods (fallbacks if undefined) =====
  // Provide default desired_satisfied(state) if not supplied:
  if (is_undefined(desired_satisfied)) {
    desired_satisfied = function(_state) {
      var _list = desired_effects;
      var _len = array_length(_list);
      for (var _i = 0; _i < _len; ++_i) {
        var _p = _normalize_predicate(_list[_i]);
        if (!_pred_ok(_p, _state)) { return false; }
      }
      return true;
    };
  }

  // Provide default is_relevant(beliefs, memory) if not supplied:
  if (is_undefined(is_relevant)) {
    // Default relevance: if there exists at least one desired effect not yet satisfied, the goal is relevant.
    is_relevant = function(_beliefs, _memory) {
      // memory is not used here (state relevance is assessed at planning time). Keep goal broadly available.
      return true;
    };
  }

  // Provide default priority_delta if not supplied:
  if (is_undefined(priority_delta)) {
    priority_delta = function(_beliefs, _memory) { return 0; };
  }

  // Provide default estimate_heuristic_from if not supplied:
  if (is_undefined(estimate_heuristic_from)) {
    estimate_heuristic_from = function(_state) {
      // fallback heuristic: number of unsatisfied desired effects
      var _count = 0;
      var _list = desired_effects;
      var _len = array_length(_list);
      for (var _i = 0; _i < _len; ++_i) {
        var _p = _normalize_predicate(_list[_i]);
        if (!_pred_ok(_p, _state)) { _count += 1; }
      }
      return _count;
    };
  }
}
