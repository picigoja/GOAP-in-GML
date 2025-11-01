function GOAP_Action() constructor {
  // ----- user-assignable fields (fallback STRIPS form) -----
  name = "Action";
  preconditions = [];  // array of pred
  effects = [];        // array of pred
  cost_base = 1;       // numeric fallback
  cost = undefined;    // may be function OR number; planner prefers function
  estimate_heuristic_to = undefined; // optional function(goal, state)->number

  // ----- deprecated legacy fields (ignored by planner) -----
  preconditions_belief = undefined;
  effects_belief = undefined;
  required_beliefs = undefined;
  can_perform = function() { return undefined; }; // deprecated
  is_complete = function() { return undefined; }; // deprecated

  // ===== Internal helpers =====
  var _state_get = function(_state, _k) {
    return variable_struct_exists(_state, _k) ? variable_struct_get(_state, _k) : undefined;
  };

  var _state_set = function(_state, _k, _v) {
    if (is_undefined(_v)) {
      if (!variable_struct_exists(_state, _k)) { return _state; }
    } else {
      if (_state_get(_state, _k) == _v) { return _state; }
    }
    var _out = _state;
    if (!variable_struct_exists(_out, "__goap_cow")) {
      _out = variable_struct_clone(_state);
      variable_struct_set(_out, "__goap_cow", true);
    }
    if (is_undefined(_v)) {
      if (variable_struct_exists(_out, _k)) { variable_struct_remove(_out, _k); }
    } else {
      variable_struct_set(_out, _k, _v);
    }
    return _out;
  };

  var _normalize_predicate = function(_entry) {
    // default normalized shape
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

  var _apply_effect = function(_state, _pred) {
    // "!flag" => unset or set false; {key,value} => set
    if (_pred.negate) {
      return _state_set(_state, _pred.key, undefined);
    }
    return _state_set(_state, _pred.key, _pred.value);
  };

  // ===== Default planning methods (may be overridden by user) =====
  is_applicable = is_undefined(is_applicable) ? function(_state, _beliefs, _memory) {
    var _list = preconditions;
    var _len = array_length(_list);
    for (var _i = 0; _i < _len; ++_i) {
      var _p = _normalize_predicate(_list[_i]);
      if (!_pred_ok(_p, _state)) { return false; }
    }
    return true;
  } : is_applicable;

  apply = is_undefined(apply) ? function(_state) {
    var _out = _state;
    var _list = effects;
    var _len = array_length(_list);
    for (var _i = 0; _i < _len; ++_i) {
      var _p = _normalize_predicate(_list[_i]);
      _out = _apply_effect(_out, _p);
    }
    if (_out != _state && variable_struct_exists(_out, "__goap_cow")) {
      variable_struct_remove(_out, "__goap_cow");
    }
    return _out;
  } : apply;

  cost = is_function(cost) ? cost : function(_state, _beliefs, _memory) {
    if (is_real(cost)) { return cost; }
    if (is_real(cost_base)) { return cost_base; }
    return 1;
  };

  estimate_heuristic_to = is_function(estimate_heuristic_to) ? estimate_heuristic_to : function(_goal, _state) { return 0; };
}
