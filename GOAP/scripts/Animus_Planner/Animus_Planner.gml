/// @desc Planner entry point. Returns canonical plan or undefined.
/// @param {Animus_Agent} agent
/// @param {Array} goals
/// @param {Animus_Memory} memory
/// @param {Animus_Goal|Undefined} last_goal
/// @returns {Struct|Undefined}
function Animus_Planner() constructor {
    config = {
        max_expansions: 2000,
        max_depth: 64,
        time_budget_ms: 8,
        reopen_closed_on_better_g: true
    };

    reuse_policy = {
        allow_reuse: true,
        allow_partial: true
    };

    last_plan = undefined;

    var build_initial_state = function(memory, referenced_keys) {
        var state = {};
        if (is_struct(memory) && Animus_Core.is_callable(memory.keys)) {
            var memory_keys = memory.keys();
            var len = array_length(memory_keys);
            for (var i = 0; i < len; ++i) {
                var key = memory_keys[i];
                var value = memory.get(key, undefined);
                variable_struct_set(state, key, value);
                referenced_keys[$ key] = true;
            }
        }
        return state;
    };

    var clone_state = function(state) {
        var copy = {};
        if (!is_struct(state)) {
            return copy;
        }
        var keys = variable_struct_get_names(state);
        var len = array_length(keys);
        for (var i = 0; i < len; ++i) {
            var key = keys[i];
            var value = variable_struct_get(state, key);
            if (is_array(value)) {
                var arr_len = array_length(value);
                var arr_copy = array_create(arr_len);
                for (var j = 0; j < arr_len; ++j) {
                    arr_copy[j] = value[j];
                }
                variable_struct_set(copy, key, arr_copy);
            } else {
                variable_struct_set(copy, key, value);
            }
        }
        return copy;
    };

    var state_hash = function(state) {
        if (!is_struct(state)) {
            return "{}";
        }
        var keys = variable_struct_get_names(state);
        array_sort(keys, function(a, b) {
            if (a == b) return 0;
            return (a < b) ? -1 : 1;
        });
        var builder = "";
        var len = array_length(keys);
        for (var i = 0; i < len; ++i) {
            var key = keys[i];
            var value = variable_struct_get(state, key);
            if (i > 0) {
                builder += "|";
            }
            builder += string(key) + ":" + string(value);
        }
        return builder;
    };

    var heuristic_to_goal = function(goal, state) {
        if (!is_struct(goal) || !variable_struct_exists(goal, "desired_effects")) {
            return 0;
        }
        var desired = goal.desired_effects;
        var unsatisfied = 0;
        var len = array_length(desired);
        for (var i = 0; i < len; ++i) {
            if (!Animus_Predicate.evaluate(state, desired[i])) {
                unsatisfied += 1;
            }
        }
        return unsatisfied;
    };

    var action_applicable = function(action, state) {
        if (!is_struct(action) || !variable_struct_exists(action, "preconditions")) {
            return false;
        }
        var preconditions = action.preconditions;
        var len = array_length(preconditions);
        for (var i = 0; i < len; ++i) {
            if (!Animus_Predicate.evaluate(state, preconditions[i])) {
                return false;
            }
        }
        return true;
    };

    var apply_action_effects = function(state, action) {
        var effects = action.effects;
        var len = array_length(effects);
        for (var i = 0; i < len; ++i) {
            Animus_Predicate.apply_effect(state, effects[i]);
        }
    };

    var add_keys_from_action = function(action, referenced_keys) {
        var keys = Animus_Predicate.extract_keys_from_action(action);
        var len = array_length(keys);
        for (var i = 0; i < len; ++i) {
            referenced_keys[$ keys[i]] = true;
        }
    };

    var clone_key_set = function(source_keys) {
        var clone = {};
        if (!is_struct(source_keys)) {
            return clone;
        }
        var names = variable_struct_get_names(source_keys);
        var len = array_length(names);
        for (var i = 0; i < len; ++i) {
            var key_name = string(names[i]);
            if (key_name == "") {
                continue;
            }
            clone[$ key_name] = true;
        }
        return clone;
    };

    var build_referenced_keys_meta = function(source_keys) {
        var list = [];
        if (is_struct(source_keys)) {
            list = variable_struct_get_names(source_keys);
        }
        var lookup = clone_key_set(source_keys);
        return { list: list, lookup: lookup };
    };

    var generate_plan_struct = function(goal, actions, cost, meta) {
        var plan_struct = {
            goal: goal,
            actions: actions,
            cost: cost,
            meta: meta
        };

        plan_struct.to_string = function() {
            var goal_name = (is_struct(goal) && variable_struct_exists(goal, "name")) ? goal.name : "<unnamed>";
            return "[Animus_Plan goal=" + string(goal_name) + " cost=" + string(cost) + " steps=" + string(array_length(actions)) + "]";
        };

        plan_struct.debug_json = function() {
            var payload = {
                goal: (is_struct(goal) && variable_struct_exists(goal, "name")) ? goal.name : undefined,
                cost: cost,
                actions: actions,
                meta: meta
            };
            return json_stringify(payload, false);
        };

        return plan_struct;
    };

    var should_reuse_plan = function(plan, memory) {
        if (!reuse_policy.allow_reuse) {
            return false;
        }
        if (!is_struct(plan) || !is_struct(plan.meta)) {
            return false;
        }
        var meta = plan.meta;
        if (variable_struct_exists(meta, "is_partial") && meta.is_partial) {
            return false;
        }
        var keys = [];
        var key_lookup = undefined;
        if (variable_struct_exists(meta, "referenced_keys")) {
            var source = meta.referenced_keys;
            if (is_array(source)) {
                keys = source;
            } else if (is_struct(source)) {
                if (variable_struct_exists(source, "list") || variable_struct_exists(source, "lookup")) {
                    if (variable_struct_exists(source, "list") && is_array(source.list)) {
                        keys = source.list;
                    }
                    if (variable_struct_exists(source, "lookup") && is_struct(source.lookup)) {
                        key_lookup = source.lookup;
                    }
                } else {
                    key_lookup = source;
                }
            }
        }
        if ((!is_array(keys) || array_length(keys) == 0) && is_struct(key_lookup)) {
            keys = variable_struct_get_names(key_lookup);
        }
        var built_at_tick = variable_struct_exists(meta, "built_at_tick") ? meta.built_at_tick : -1;
        var len = array_length(keys);
        for (var i = 0; i < len; ++i) {
            var key = keys[i];
            if (is_undefined(key)) {
                continue;
            }
            var key_name = string(key);
            if (key_name == "") {
                continue;
            }
            if (memory.is_dirty(key_name)) {
                return false;
            }
            if (memory.last_updated(key_name) > built_at_tick) {
                return false;
            }
        }
        return true;
    };

    var search_plan = function(request) {
        var goal = request.goal;
        var actions = request.actions;
        var initial_state = request.state;
        var referenced_keys = request.referenced_keys;
        var start_time = request.start_time;
        var memory = request.memory;

        var open = ds_priority_create();
        var open_best = ds_map_create();
        var closed = ds_map_create();

        var nodes_expanded = 0;
        var nodes_generated = 0;
        var open_peak = 0;
        var best_node = undefined;
        var best_score = 1e30;
        var budget_exhausted = false;

        var start_node = {
            state: clone_state(initial_state),
            g: 0,
            h: heuristic_to_goal(goal, initial_state),
            depth: 0,
            via_action: undefined,
            parent: undefined
        };
        start_node.f = start_node.g + start_node.h;
        ds_priority_add(open, start_node, start_node.f);
        ds_map_add(open_best, state_hash(start_node.state), start_node.g);
        nodes_generated += 1;

        while (!ds_priority_empty(open)) {
            if (config.max_expansions >= 0 && nodes_expanded >= config.max_expansions) {
                budget_exhausted = true;
                break;
            }
            if (config.time_budget_ms > 0) {
                var elapsed = current_time - start_time;
                if (elapsed > config.time_budget_ms) {
                    budget_exhausted = true;
                    break;
                }
            }

            var current = ds_priority_delete_min(open);
            nodes_expanded += 1;

            if (heuristic_to_goal(goal, current.state) == 0) {
                best_node = current;
                best_score = current.f;
                break;
            }

            var hash = state_hash(current.state);
            if (ds_map_exists(closed, hash)) {
                ds_map_replace(closed, hash, true);
            } else {
                ds_map_add(closed, hash, true);
            }

            var open_size = ds_priority_size(open);
            if (open_size > open_peak) {
                open_peak = open_size;
            }

            if (config.max_depth > 0 && current.depth >= config.max_depth) {
                continue;
            }

            var action_count = array_length(actions);
            for (var ai = 0; ai < action_count; ++ai) {
                var action = actions[ai];
                if (!action_applicable(action, current.state)) {
                    continue;
                }
                add_keys_from_action(action, referenced_keys);
                var next_state = clone_state(current.state);
                apply_action_effects(next_state, action);
                var next_hash = state_hash(next_state);
                if (ds_map_exists(closed, next_hash)) {
                    continue;
                }
                var step_cost = action.cost(current.state);
                if (!is_real(step_cost)) {
                    step_cost = 1;
                }
                var next_g = current.g + step_cost;
                var best_g_known = ds_map_exists(open_best, next_hash) ? ds_map_find_value(open_best, next_hash) : 1e30;
                if (!config.reopen_closed_on_better_g && next_g >= best_g_known) {
                    continue;
                }
                if (next_g < best_g_known) {
                    if (ds_map_exists(open_best, next_hash)) {
                        ds_map_replace(open_best, next_hash, next_g);
                    } else {
                        ds_map_add(open_best, next_hash, next_g);
                    }
                }
                var next_h = heuristic_to_goal(goal, next_state);
                var next_node = {
                    state: next_state,
                    g: next_g,
                    h: next_h,
                    f: next_g + next_h,
                    depth: current.depth + 1,
                    via_action: action,
                    parent: current
                };
                ds_priority_add(open, next_node, next_node.f);
                nodes_generated += 1;
                if (next_node.f < best_score) {
                    best_node = next_node;
                    best_score = next_node.f;
                }
            }
        }

        ds_priority_destroy(open);
        ds_map_destroy(open_best);
        ds_map_destroy(closed);

        var is_partial = false;
        var partial_reason = undefined;

        if (is_undefined(best_node)) {
            return undefined;
        }

        if (heuristic_to_goal(goal, best_node.state) != 0) {
            is_partial = true;
            partial_reason = budget_exhausted ? "budget_exhausted" : "no_solution";
            if (!reuse_policy.allow_partial) {
                return undefined;
            }
        }

        var actions_taken = [];
        var walker = best_node;
        while (!is_undefined(walker) && !is_undefined(walker.via_action)) {
            array_insert(actions_taken, 0, walker.via_action);
            walker = walker.parent;
        }

        return {
            node: best_node,
            actions: actions_taken,
            cost: best_node.g,
            nodes_expanded: nodes_expanded,
            nodes_generated: nodes_generated,
            open_peak: open_peak,
            is_partial: is_partial,
            reason: partial_reason,
            budget_exhausted: budget_exhausted
        };
    };

    self.plan = function(agent, goals, memory, last_goal) {
        if (is_struct(memory) == false) {
            Animus_Core.raise("Animus_Planner requires a memory instance", true);
        }

        if (reuse_policy.allow_reuse && !is_undefined(last_plan)) {
            if (should_reuse_plan(last_plan, memory)) {
                return last_plan;
            }
        }

        var referenced_keys = {};
        var initial_state = build_initial_state(memory, referenced_keys);

        var actions = [];
        if (is_struct(agent) && variable_struct_exists(agent, "actions")) {
            actions = agent.actions;
        }
        if (!is_array(actions)) {
            actions = [];
        }

        var normalized_actions = [];
        var action_count = array_length(actions);
        for (var i = 0; i < action_count; ++i) {
            var action = actions[i];
            if (!is_struct(action)) {
                continue;
            }
            action.preconditions = Animus_Predicate.normalize_list(action.preconditions, "condition");
            action.effects = Animus_Predicate.normalize_list(action.effects, "effect");
            add_keys_from_action(action, referenced_keys);
            array_push(normalized_actions, action);
        }

        var candidate_goals = is_array(goals) ? goals : [];
        var prioritized_goals = [];
        var goal_count = array_length(candidate_goals);
        for (var gi = 0; gi < goal_count; ++gi) {
            var goal = candidate_goals[gi];
            if (!is_struct(goal)) {
                continue;
            }
            if (Animus_Core.is_callable(goal.is_relevant) && !goal.is_relevant(memory)) {
                continue;
            }
            var priority_value = 0;
            if (Animus_Core.is_callable(goal.priority)) {
                priority_value = goal.priority(memory);
            }
            goal.desired_effects = Animus_Predicate.normalize_list(goal.desired_effects, "condition");
            add_keys_from_action({ preconditions: [], effects: goal.desired_effects }, referenced_keys);
            array_push(prioritized_goals, { goal: goal, priority: priority_value });
        }

        array_sort(prioritized_goals, function(a, b) {
            if (a.priority == b.priority) {
                return 0;
            }
            return (a.priority > b.priority) ? -1 : 1;
        });

        var best_plan = undefined;
        var start_time = current_time;

        var memory_tick = Animus_Core.is_callable(memory._now) ? memory._now() : 0;

        var goal_attempts = array_length(prioritized_goals);
        for (var attempt = 0; attempt < goal_attempts; ++attempt) {
            var entry = prioritized_goals[attempt];
            var goal = entry.goal;

            if (goal.matches_state(initial_state)) {
                var referenced_meta = build_referenced_keys_meta(referenced_keys);
                var meta = {
                    built_at_tick: memory_tick,
                    elapsed_ms: current_time - start_time,
                    nodes_expanded: 0,
                    nodes_generated: 0,
                    open_peak: 0,
                    referenced_keys: referenced_meta,
                    is_partial: false,
                    budget: { nodes: config.max_expansions, ms: config.time_budget_ms },
                    reason: undefined
                };
                var empty_plan = generate_plan_struct(goal, [], 0, meta);
                last_plan = empty_plan;
                return empty_plan;
            }

            var request = {
                goal: goal,
                actions: normalized_actions,
                state: initial_state,
                referenced_keys: referenced_keys,
                start_time: start_time,
                memory: memory
            };

            var search_result = search_plan(request);
            if (is_undefined(search_result)) {
                continue;
            }

            var referenced_meta = build_referenced_keys_meta(referenced_keys);
            var meta = {
                built_at_tick: memory_tick,
                elapsed_ms: current_time - start_time,
                nodes_expanded: search_result.nodes_expanded,
                nodes_generated: search_result.nodes_generated,
                open_peak: search_result.open_peak,
                referenced_keys: referenced_meta,
                is_partial: search_result.is_partial,
                budget: { nodes: config.max_expansions, ms: config.time_budget_ms },
                reason: search_result.reason
            };

            var plan_struct = generate_plan_struct(goal, search_result.actions, search_result.cost, meta);
            best_plan = plan_struct;
            if (!search_result.is_partial) {
                break;
            }
        }

        last_plan = best_plan;
        return best_plan;
    };
}
