function GOAP_Planner() constructor {
  config = { max_expansions: 2000, max_depth: 64, reopen_closed_on_better_g: true };
  reuse_policy = { allow_reuse: true, allow_partial: true };
  last_plan = undefined;

  var _self = self;
  var _can_introspect = !is_undefined(function_get_arg_count);

  var _has_method = function(_struct, _name) {
    if (!is_struct(_struct)) return false;
    if (!variable_struct_exists(_struct, _name)) return false;
    var _value = variable_struct_get(_struct, _name);
    return is_method(_value);
  };

  var _method_argc = function(_method) {
    if (!_can_introspect || !is_method(_method)) return 3;
    var _fn = method_get_function(_method);
    return function_get_arg_count(_fn);
  };

  var _invoke_method = function(_method, _arg1, _arg2, _arg3) {
    if (!is_method(_method)) return undefined;
    var _argc = _method_argc(_method);
    switch (_argc) {
      case 0: return _method();
      case 1: return _method(_arg1);
      case 2: return _method(_arg1, _arg2);
      default: return _method(_arg1, _arg2, _arg3);
    }
  };

  var _mark_referenced_key = function(_key) {
    if (is_undefined(_self._active_referenced_keys)) return;
    if (is_undefined(_key)) return;
    var _key_string = string(_key);
    if (_key_string == "") return;
    _self._active_referenced_keys[$ _key_string] = true;
  };

  var _normalize_predicate = function(_entry) {
    var _result = { key: undefined, value: true, negate: false };
    if (is_string(_entry)) {
      if (string_length(_entry) > 0 && string_copy(_entry, 1, 1) == "!") {
        _result.key = string_copy(_entry, 2, string_length(_entry) - 1);
        _result.value = false;
        _result.negate = true;
      } else {
        _result.key = _entry;
      }
    } else if (is_struct(_entry)) {
      if (variable_struct_exists(_entry, "key")) {
        _result.key = variable_struct_get(_entry, "key");
      } else if (variable_struct_exists(_entry, "name")) {
        _result.key = variable_struct_get(_entry, "name");
      }
      if (variable_struct_exists(_entry, "value")) {
        _result.value = variable_struct_get(_entry, "value");
      } else if (variable_struct_exists(_entry, "expected")) {
        _result.value = variable_struct_get(_entry, "expected");
      }
      if (variable_struct_exists(_entry, "negate")) {
        _result.negate = variable_struct_get(_entry, "negate");
      }
    } else if (is_array(_entry) && array_length(_entry) >= 1) {
      _result.key = _entry[0];
      if (array_length(_entry) >= 2) {
        _result.value = _entry[1];
      }
    }
    if (is_string(_result.key)) {
      _result.key = string(_result.key);
    }
    return _result;
  };

  var _state_get = function(_state, _key) {
    if (!is_struct(_state)) return undefined;
    if (!variable_struct_exists(_state, _key)) return undefined;
    return variable_struct_get(_state, _key);
  };

  var _state_set = function(_state, _key, _value) {
    variable_struct_set(_state, _key, _value);
  };

  var _state_remove = function(_state, _key) {
    if (variable_struct_exists(_state, _key)) {
      variable_struct_remove(_state, _key);
    }
  };

  var _copy_state = function(_state) {
    var _copy = {};
    if (!is_struct(_state)) return _copy;
    var _keys = variable_struct_get_names(_state);
    var _count = array_length(_keys);
    for (var _i = 0; _i < _count; ++_i) {
      var _k = _keys[_i];
      _state_set(_copy, _k, _state_get(_state, _k));
    }
    return _copy;
  };

  var _default_check_preconditions = function(_action, _state) {
    if (!is_struct(_action) || !variable_struct_exists(_action, "preconditions")) return true;
    var _preconditions = variable_struct_get(_action, "preconditions");
    if (!is_array(_preconditions)) return true;
    var _len = array_length(_preconditions);
    for (var _i = 0; _i < _len; ++_i) {
      var _predicate = _normalize_predicate(_preconditions[_i]);
      if (is_undefined(_predicate.key)) continue;
      _mark_referenced_key(_predicate.key);
      var _current = _state_get(_state, _predicate.key);
      var _expected = _predicate.value;
      if (_predicate.negate) {
        if (bool(_current)) return false;
      } else if (!is_undefined(_expected)) {
        if (is_string(_expected)) {
          if (_current != _expected) return false;
        } else if (is_real(_expected)) {
          if (_current != _expected) return false;
        } else {
          if (!bool(_current)) return false;
        }
      } else if (!bool(_current)) {
        return false;
      }
    }
    return true;
  };

  var _default_apply_effects = function(_action, _state) {
    var _result = _copy_state(_state);
    if (!is_struct(_action) || !variable_struct_exists(_action, "effects")) return _result;
    var _effects = variable_struct_get(_action, "effects");
    if (!is_array(_effects)) return _result;
    var _len = array_length(_effects);
    for (var _i = 0; _i < _len; ++_i) {
      var _predicate = _normalize_predicate(_effects[_i]);
      if (is_undefined(_predicate.key)) continue;
      _mark_referenced_key(_predicate.key);
      if (_predicate.negate) {
        _state_remove(_result, _predicate.key);
      } else {
        _state_set(_result, _predicate.key, _predicate.value);
      }
    }
    return _result;
  };

  var _default_action_cost = function(_action) {
    if (!is_struct(_action)) return 1;
    if (variable_struct_exists(_action, "cost_base")) return variable_struct_get(_action, "cost_base");
    if (variable_struct_exists(_action, "cost")) return variable_struct_get(_action, "cost");
    return 1;
  };

  var _goal_desired_array = function(_goal) {
    if (!is_struct(_goal)) return undefined;
    if (variable_struct_exists(_goal, "desired_effects")) {
      var _effects = variable_struct_get(_goal, "desired_effects");
      if (is_array(_effects)) return _effects;
    }
    return undefined;
  };

  var _goal_default_satisfied = function(_goal, _state) {
    var _desired = _goal_desired_array(_goal);
    if (is_undefined(_desired)) return true;
    var _len = array_length(_desired);
    for (var _i = 0; _i < _len; ++_i) {
      var _predicate = _normalize_predicate(_desired[_i]);
      if (is_undefined(_predicate.key)) continue;
      _mark_referenced_key(_predicate.key);
      var _value = _state_get(_state, _predicate.key);
      if (_predicate.negate) {
        if (bool(_value)) return false;
      } else if (!is_undefined(_predicate.value)) {
        if (is_string(_predicate.value) || is_real(_predicate.value)) {
          if (_value != _predicate.value) return false;
        } else if (!bool(_value)) {
          return false;
        }
      } else if (!bool(_value)) {
        return false;
      }
    }
    return true;
  };

  var _goal_unsatisfied_count = function(_goal, _state) {
    var _desired = _goal_desired_array(_goal);
    if (is_undefined(_desired)) return 0;
    var _len = array_length(_desired);
    var _count = 0;
    for (var _i = 0; _i < _len; ++_i) {
      var _predicate = _normalize_predicate(_desired[_i]);
      if (is_undefined(_predicate.key)) continue;
      _mark_referenced_key(_predicate.key);
      var _value = _state_get(_state, _predicate.key);
      var _satisfied = false;
      if (_predicate.negate) {
        _satisfied = !bool(_value);
      } else if (!is_undefined(_predicate.value)) {
        if (is_string(_predicate.value) || is_real(_predicate.value)) {
          _satisfied = (_value == _predicate.value);
        } else {
          _satisfied = bool(_value);
        }
      } else {
        _satisfied = bool(_value);
      }
      if (!_satisfied) _count += 1;
    }
    return _count;
  };

  var _action_apply = function(_action, _state, _beliefs, _memory) {
    if (_has_method(_action, "apply")) {
      return _invoke_method(_action.apply, _state, _beliefs, _memory);
    }
    return _default_apply_effects(_action, _state);
  };

  var _action_is_applicable = function(_action, _state, _beliefs, _memory) {
    if (_has_method(_action, "is_applicable")) {
      return bool(_invoke_method(_action.is_applicable, _state, _beliefs, _memory));
    }
    return _default_check_preconditions(_action, _state);
  };

  var _action_cost = function(_action, _state, _beliefs, _memory) {
    if (_has_method(_action, "cost")) {
      var _value = _invoke_method(_action.cost, _state, _beliefs, _memory);
      return is_real(_value) ? _value : _default_action_cost(_action);
    }
    return _default_action_cost(_action);
  };

  var _goal_is_satisfied = function(_goal, _state) {
    if (_has_method(_goal, "desired_satisfied")) {
      return bool(_invoke_method(_goal.desired_satisfied, _state));
    }
    return _goal_default_satisfied(_goal, _state);
  };

  var _estimate_default_unsatisfied = function(_goal, _state) {
    if (_has_method(_goal, "desired_satisfied")) {
      return _invoke_method(_goal.desired_satisfied, _state) ? 0 : 1;
    }
    var _desired = _goal_desired_array(_goal);
    if (!is_undefined(_desired)) {
      return _goal_unsatisfied_count(_goal, _state);
    }
    return 0;
  };

  var _estimate_goal_heuristic = function(_goal, _state, _actions) {
    var _h = _estimate_default_unsatisfied(_goal, _state);
    if (_has_method(_goal, "estimate_heuristic_from")) {
      var _value = _invoke_method(_goal.estimate_heuristic_from, _state);
      if (is_real(_value) && _value > _h) _h = _value;
    }
    if (is_array(_actions)) {
      var _alen = array_length(_actions);
      for (var _i = 0; _i < _alen; ++_i) {
        var _action = _actions[_i];
        if (_has_method(_action, "estimate_heuristic_to")) {
          var _value = _action.estimate_heuristic_to(_goal, _state);
          if (is_real(_value) && _value > _h) _h = _value;
        }
      }
    }
    return _h;
  };

  var _collect_goal_priority = function(_goal, _beliefs, _memory) {
    var _base = 0;
    if (!is_struct(_goal)) return _base;
    if (variable_struct_exists(_goal, "priority_base")) {
      _base += variable_struct_get(_goal, "priority_base");
    } else if (variable_struct_exists(_goal, "priority")) {
      _base += variable_struct_get(_goal, "priority");
    }
    if (_has_method(_goal, "priority_delta")) {
      var _value = _invoke_method(_goal.priority_delta, _beliefs, _memory);
      if (is_real(_value)) _base += _value;
    }
    return _base;
  };

  var _merge_referenced_keys = function(_target, _source) {
    if (!is_struct(_source)) return;
    var _names = variable_struct_get_names(_source);
    var _len = array_length(_names);
    for (var _i = 0; _i < _len; ++_i) {
      _target[$ _names[_i]] = true;
    }
  };

  plan = function(_agent, _goals, _memory, _most_recent_goal) {
    var _snapshot = _memory.snapshot(false);
    var _tick = _memory._now();
    var _beliefs = _build_belief_cache(_agent, _memory);
    var _initial_state = _make_initial_state(_snapshot);

    var _selection_referenced = {};
    _self._active_referenced_keys = _selection_referenced;
    var _selected_goals = _select_goals(_goals, _beliefs, _memory, _initial_state, _most_recent_goal);
    _self._active_referenced_keys = undefined;

    var _actions = [];
    if (is_struct(_agent) && variable_struct_exists(_agent, "actions")) {
      _actions = _agent.actions;
    }

    if (_should_reuse_last_plan(last_plan, _memory)) {
      var _reuse_refs = _copy_state(_selection_referenced);
      _self._active_referenced_keys = _reuse_refs;
      var _reuse_result = _revalidate_prefix(last_plan, _initial_state, _beliefs, _memory);
      _self._active_referenced_keys = undefined;
      if (!is_undefined(_reuse_result)) {
        if (is_struct(_reuse_result) && variable_struct_exists(_reuse_result, "actions") && array_length(_reuse_result.actions) == 0) {
          _reuse_result = undefined;
        }
      }
      if (is_undefined(_reuse_result) && !is_undefined(last_plan)) {
        var _final_state = _copy_state(_initial_state);
        var _acts = last_plan.actions;
        if (is_array(_acts)) {
          for (var _i = 0; _i < array_length(_acts); ++_i) {
            _final_state = _action_apply(_acts[_i], _final_state, _beliefs, _memory);
          }
        }
        last_plan.meta.built_at_tick = _tick;
        last_plan.meta.nodes_expanded = 0;
        last_plan.meta.nodes_generated = 0;
        last_plan.meta.open_peak = 0;
        last_plan.meta.state_hash_start = _state_hash(_initial_state);
        last_plan.meta.state_hash_end = _state_hash(_final_state);
        last_plan.meta.search_stats_json = _debug_stats_json({ nodes_expanded: 0, nodes_generated: 0, open_peak: 0 });
        return last_plan;
      }
    }

    var _goal_count = array_length(_selected_goals);
    for (var _g = 0; _g < _goal_count; ++_g) {
      var _goal = _selected_goals[_g];
      if (is_undefined(_goal)) continue;

      var _goal_referenced = _copy_state(_selection_referenced);
      _self._active_referenced_keys = _goal_referenced;

      var _goal_reference_match = (!is_undefined(last_plan) && last_plan.goal == _goal);
      var _prefix_result = undefined;
      if (_goal_reference_match && reuse_policy.allow_partial) {
        _prefix_result = _revalidate_prefix(last_plan, _initial_state, _beliefs, _memory);
      }

      var _search_state = _copy_state(_initial_state);
      var _prefix_actions = [];
      if (is_struct(_prefix_result) && variable_struct_exists(_prefix_result, "state")) {
        _search_state = _copy_state(_prefix_result.state);
        if (variable_struct_exists(_prefix_result, "prefix")) {
          _prefix_actions = _prefix_result.prefix;
        }
      }

      var _search_result = _search_a_star(_search_state, _goal, _actions, _beliefs, _memory);

      if (!is_undefined(_search_result) && is_struct(_search_result) && variable_struct_exists(_search_result, "actions")) {
        var _actions_combined = [];
        if (is_array(_prefix_actions)) {
          for (var _p = 0; _p < array_length(_prefix_actions); ++_p) {
            array_push(_actions_combined, _prefix_actions[_p]);
          }
        }
        var _result_actions = _search_result.actions;
        if (is_array(_result_actions)) {
          for (var _r = 0; _r < array_length(_result_actions); ++_r) {
            array_push(_actions_combined, _result_actions[_r]);
          }
        }

        var _plan_cost = 0;
        var _plan_state = _copy_state(_initial_state);
        for (var _a = 0; _a < array_length(_actions_combined); ++_a) {
          var _act = _actions_combined[_a];
          _plan_cost += _action_cost(_act, _plan_state, _beliefs, _memory);
          _plan_state = _action_apply(_act, _plan_state, _beliefs, _memory);
        }

        var _meta_referenced = {};
        _merge_referenced_keys(_meta_referenced, _goal_referenced);

        var _plan_struct = {
          goal: _goal,
          actions: _actions_combined,
          cost: _plan_cost,
          meta: {
            built_at_tick: _tick,
            nodes_expanded: _search_result.nodes_expanded,
            nodes_generated: _search_result.nodes_generated,
            open_peak: _search_result.open_peak,
            referenced_keys: _meta_referenced,
            state_hash_start: _state_hash(_initial_state),
            state_hash_end: _state_hash(_plan_state),
            search_stats_json: _debug_stats_json({ nodes_expanded: _search_result.nodes_expanded, nodes_generated: _search_result.nodes_generated, open_peak: _search_result.open_peak })
          },
          to_string: function() {
            var _goal_ref = self.goal;
            var _goal_name = (is_struct(_goal_ref) && variable_struct_exists(_goal_ref, "name")) ? string(_goal_ref.name) : "<goal>";
            return "GOAP Plan for " + _goal_name + " with " + string(array_length(self.actions)) + " actions at cost " + string(self.cost);
          },
          debug_json: function() {
            return json_stringify({ goal: self.goal, actions: self.actions, cost: self.cost, meta: self.meta }, false);
          }
        };

        last_plan = _plan_struct;
        _self._active_referenced_keys = undefined;
        return _plan_struct;
      }

      _self._active_referenced_keys = undefined;
    }

    last_plan = undefined;
    _self._active_referenced_keys = undefined;
    return undefined;
  };

  _build_belief_cache = function(_agent, _memory) {
    var _entries = [];
    var _name_lookup = {};
    var _stats = { hits: 0, misses: 0 };

    var _source = undefined;
    if (is_struct(_agent) && variable_struct_exists(_agent, "beliefs")) {
      _source = _agent.beliefs;
    }

    var _add_entry = function(_belief, _value) {
      var _name = undefined;
      if (is_struct(_belief)) {
        if (variable_struct_exists(_belief, "name")) {
          _name = string(_belief.name);
        } else if (variable_struct_exists(_belief, "id")) {
          _name = string(_belief.id);
        }
      } else if (is_string(_belief)) {
        _name = _belief;
      }
      var _entry = { ref: _belief, name: _name, value: _value };
      array_push(_entries, _entry);
      if (!is_undefined(_name)) {
        _name_lookup[$ _name] = _value;
      }
    };

    if (is_array(_source)) {
      var _len = array_length(_source);
      for (var _i = 0; _i < _len; ++_i) {
        var _belief = _source[_i];
        if (is_struct(_belief) && _has_method(_belief, "evaluate")) {
          var _value = _belief.evaluate(_memory);
          _add_entry(_belief, _value);
        }
      }
    } else if (is_struct(_source)) {
      var _keys = variable_struct_get_names(_source);
      var _count = array_length(_keys);
      for (var _j = 0; _j < _count; ++_j) {
        var _key = _keys[_j];
        var _belief = variable_struct_get(_source, _key);
        if (is_struct(_belief) && _has_method(_belief, "evaluate")) {
          var _value = _belief.evaluate(_memory);
          _add_entry(_belief, _value);
        }
      }
    }

    return {
      get: function(_identifier) {
        if (is_string(_identifier)) {
          var _key = string(_identifier);
          if (variable_struct_exists(_name_lookup, _key)) {
            _stats.hits += 1;
            return _name_lookup[$ _key];
          }
        }
        var _len_entries = array_length(_entries);
        for (var _i = 0; _i < _len_entries; ++_i) {
          var _entry = _entries[_i];
          if (_entry.ref == _identifier) {
            _stats.hits += 1;
            return _entry.value;
          }
        }
        _stats.misses += 1;
        return undefined;
      },
      stats: _stats
    };
  };

  _select_goals = function(_goals, _beliefs, _memory, _initial_state, _most_recent_goal) {
    var _candidates = [];
    if (!is_array(_goals)) return _candidates;
    var _len = array_length(_goals);
    for (var _i = 0; _i < _len; ++_i) {
      var _goal = _goals[_i];
      if (is_undefined(_goal)) continue;
      var _is_relevant = true;
      if (_has_method(_goal, "is_relevant")) {
        var _method = _goal.is_relevant;
        var _argc = _method_argc(_method);
        if (_argc >= 2) {
          _is_relevant = bool(_goal.is_relevant(_beliefs, _memory));
        } else if (_argc == 1) {
          _is_relevant = bool(_goal.is_relevant(_beliefs));
        } else {
          _is_relevant = bool(_goal.is_relevant());
        }
      }
      if (!_is_relevant) continue;
      var _priority = _collect_goal_priority(_goal, _beliefs, _memory);
      var _heuristic = 0;
      if (_has_method(_goal, "estimate_heuristic_from")) {
        var _value = _invoke_method(_goal.estimate_heuristic_from, _initial_state);
        if (is_real(_value)) _heuristic = _value;
      }
      array_push(_candidates, { goal: _goal, priority: _priority, heuristic: _heuristic });
    }

    array_sort(_candidates, function(_a, _b) {
      if (_a.priority != _b.priority) return (_a.priority > _b.priority) ? -1 : 1;
      if (!is_undefined(_most_recent_goal)) {
        var _a_recent = (_a.goal == _most_recent_goal);
        var _b_recent = (_b.goal == _most_recent_goal);
        if (_a_recent != _b_recent) return _a_recent ? -1 : 1;
      }
      if (_a.heuristic != _b.heuristic) return (_a.heuristic < _b.heuristic) ? -1 : 1;
      return 0;
    });

    var _sorted = [];
    for (var _k = 0; _k < array_length(_candidates); ++_k) {
      array_push(_sorted, _candidates[_k].goal);
    }
    return _sorted;
  };

  _make_initial_state = function(_memory_snapshot) {
    var _state = {};
    if (!is_struct(_memory_snapshot)) return _state;
    var _keys = variable_struct_get_names(_memory_snapshot);
    var _len = array_length(_keys);
    for (var _i = 0; _i < _len; ++_i) {
      var _key = _keys[_i];
      _state_set(_state, _key, variable_struct_get(_memory_snapshot, _key));
    }
    return _state;
  };

  _search_a_star = function(_initial_state, _goal, _actions, _beliefs, _memory) {
    var _open = ds_priority_create();
    var _closed = ds_map_create();
    var _nodes_expanded = 0;
    var _nodes_generated = 0;
    var _open_count = 0;

    var _root_state = _copy_state(_initial_state);
    var _root_h = _estimate_goal_heuristic(_goal, _root_state, _actions);
    var _root = { state: _root_state, g: 0, f: _root_h, parent: undefined, via_action: undefined, depth: 0 };
    ds_priority_add(_open, _root, _root.f);
    _open_count += 1;
    var _open_peak = 1;

    var _expansions = 0;
    var _max_expansions = config.max_expansions;
    var _max_depth = config.max_depth;

    var _result = undefined;

    while (!ds_priority_empty(_open)) {
      if (_expansions >= _max_expansions) break;
      var _current = ds_priority_delete_min(_open);
      _open_count -= 1;
      _nodes_expanded += 1;
      _expansions += 1;

      var _hash_current = _state_hash(_current.state);
      if (ds_map_exists(_closed, _hash_current)) {
        var _best_g = ds_map_find_value(_closed, _hash_current);
        if (_current.g >= _best_g) {
          continue;
        }
      }
      if (ds_map_exists(_closed, _hash_current)) {
        ds_map_replace(_closed, _hash_current, _current.g);
      } else {
        ds_map_add(_closed, _hash_current, _current.g);
      }

      if (_goal_is_satisfied(_goal, _current.state)) {
        _result = _current;
        break;
      }

      if (_current.depth >= _max_depth) continue;

      if (is_array(_actions)) {
        var _len_actions = array_length(_actions);
        for (var _i = 0; _i < _len_actions; ++_i) {
          var _action = _actions[_i];
          if (is_undefined(_action)) continue;
          if (!_action_is_applicable(_action, _current.state, _beliefs, _memory)) continue;
          var _next_state = _action_apply(_action, _current.state, _beliefs, _memory);
          if (!is_struct(_next_state)) continue;
          var _g = _current.g + _action_cost(_action, _current.state, _beliefs, _memory);
          var _h = _estimate_goal_heuristic(_goal, _next_state, _actions);
          var _f = _g + _h;
          var _next_node = { state: _next_state, g: _g, f: _f, parent: _current, via_action: _action, depth: _current.depth + 1 };
          var _hash_next = _state_hash(_next_state);
          var _should_add = true;
          if (ds_map_exists(_closed, _hash_next)) {
            var _best_closed = ds_map_find_value(_closed, _hash_next);
            if (_g >= _best_closed) {
              _should_add = false;
            } else if (!config.reopen_closed_on_better_g) {
              _should_add = false;
            }
          }
          if (_should_add) {
            ds_priority_add(_open, _next_node, _f);
            _open_count += 1;
            if (_open_count > _open_peak) _open_peak = _open_count;
            _nodes_generated += 1;
          }
        }
      }
    }

    var _plan = undefined;
    if (!is_undefined(_result)) {
      var _actions_taken = [];
      var _walker = _result;
      while (!is_undefined(_walker) && !is_undefined(_walker.via_action)) {
        array_insert(_actions_taken, 0, _walker.via_action);
        _walker = _walker.parent;
      }
      _plan = {
        actions: _actions_taken,
        cost: _result.g,
        final_state: _result.state,
        nodes_expanded: _nodes_expanded,
        nodes_generated: _nodes_generated,
        open_peak: _open_peak
      };
    }

    ds_priority_destroy(_open);
    ds_map_destroy(_closed);

    return _plan;
  };

  _state_hash = function(_state) {
    if (!is_struct(_state)) return "{}";
    var _keys = variable_struct_get_names(_state);
    array_sort(_keys, function(_a, _b) {
      if (_a == _b) return 0;
      return (_a < _b) ? -1 : 1;
    });
    var _builder = "";
    var _len = array_length(_keys);
    for (var _i = 0; _i < _len; ++_i) {
      var _key = _keys[_i];
      var _value = variable_struct_get(_state, _key);
      if (_i > 0) _builder += "|";
      _builder += string(_key) + ":" + string(_value);
    }
    return _builder;
  };

  _should_reuse_last_plan = function(_last, _memory) {
    if (!reuse_policy.allow_reuse) return false;
    if (is_undefined(_last)) return false;
    if (!is_struct(_last) || !variable_struct_exists(_last, "meta")) return false;
    var _meta = _last.meta;
    if (!is_struct(_meta) || !variable_struct_exists(_meta, "referenced_keys")) return false;
    var _keys_struct = _meta.referenced_keys;
    if (!is_struct(_keys_struct)) return false;
    var _keys = variable_struct_get_names(_keys_struct);
    var _len = array_length(_keys);
    var _built_tick = variable_struct_exists(_meta, "built_at_tick") ? _meta.built_at_tick : -1;
    for (var _i = 0; _i < _len; ++_i) {
      var _key = _keys[_i];
      if (_memory.is_dirty(_key)) return false;
      if (_memory.last_updated(_key) > _built_tick) return false;
    }
    return true;
  };

  _revalidate_prefix = function(_last, _initial_state, _beliefs, _memory) {
    if (!reuse_policy.allow_partial) return undefined;
    if (is_undefined(_last)) return undefined;
    if (!is_struct(_last) || !variable_struct_exists(_last, "actions")) return undefined;
    var _actions = _last.actions;
    if (!is_array(_actions) || array_length(_actions) == 0) return undefined;
    var _current_state = _copy_state(_initial_state);
    var _prefix = [];
    var _len = array_length(_actions);
    for (var _i = 0; _i < _len; ++_i) {
      var _action = _actions[_i];
      if (!_action_is_applicable(_action, _current_state, _beliefs, _memory)) {
        var _remaining = [];
        for (var _r = _i; _r < _len; ++_r) {
          array_push(_remaining, _actions[_r]);
        }
        return { state: _current_state, prefix: _prefix, actions: _remaining };
      }
      _current_state = _action_apply(_action, _current_state, _beliefs, _memory);
      array_push(_prefix, _action);
    }
    return undefined;
  };

  _debug_stats_json = function(_stats) {
    return json_stringify(_stats, false);
  };
}
