/// @desc Defines canonical Animus actions used across tests.
function scr_test_fixture_agent_actions() {
    var get_food = new Animus_Action("Get Food", [], ["agent.has_food"], 2);
    get_food.create_strategy = function(action_ref) {
        return Strategy_Timed(action_ref, {
            target_s: 1.5,
            expected_s: 1.5,
            on_success: function(ctx) {
                if (is_struct(ctx) && is_struct(ctx.memory)) {
                    if (Animus_Core.is_callable(ctx.memory.write)) {
                        var inventory = ctx.memory.get("agent.food_inventory", 0);
                        ctx.memory.write("agent.food_inventory", inventory + 1);
                        ctx.memory.write("agent.has_food", true);
                    }
                }
            }
        });
    };

    var eat = new Animus_Action("Eat", ["agent.has_food"], ["!agent.hungry"], function(state) {
        var hungry = true;
        if (is_struct(state) && variable_struct_exists(state, "agent.hungry")) {
            hungry = variable_struct_get(state, "agent.hungry");
        }
        return (hungry ? 2 : 1);
    });
    eat.create_strategy = function(action_ref) {
        return Strategy_Instant(action_ref, {
            on_success: function(ctx) {
                if (!is_struct(ctx) || !is_struct(ctx.memory)) return;
                if (Animus_Core.is_callable(ctx.memory.write)) {
                    ctx.memory.write("agent.hungry", false);
                    var inventory = ctx.memory.get("agent.food_inventory", 0);
                    ctx.memory.write("agent.food_inventory", max(0, inventory - 1));
                    if (inventory <= 1) {
                        ctx.memory.write("agent.has_food", false);
                    }
                }
            }
        });
    };

    var move_to_cache = new Animus_Action("Move To Cache", [], [], 1);
    move_to_cache.create_strategy = function(action_ref) {
        return Strategy_Move(action_ref, {
            nav_key_fn: function(ctx) {
                return "nav.cache";
            },
            path_is_valid: function(ctx) {
                if (!is_struct(ctx) || !is_struct(ctx.blackboard)) {
                    return true;
                }
                if (!variable_struct_exists(ctx.blackboard, "path_valid")) {
                    return true;
                }
                return ctx.blackboard.path_valid;
            },
            reached_fn: function(ctx, arrive_dist) {
                if (!is_struct(ctx) || !is_struct(ctx.blackboard)) {
                    return false;
                }
                if (!variable_struct_exists(ctx.blackboard, "distance")) {
                    return false;
                }
                return ctx.blackboard.distance <= arrive_dist;
            },
            arrive_dist: 0,
            expected_s: 1.0,
            on_tick: function(ctx, dt) {
                if (is_struct(ctx) && is_struct(ctx.blackboard)) {
                    if (variable_struct_exists(ctx.blackboard, "distance")) {
                        ctx.blackboard.distance = max(0, ctx.blackboard.distance - dt * 3);
                    }
                }
            }
        });
    };

    return {
        actions: [move_to_cache, get_food, eat],
        get_food: get_food,
        eat: eat,
        move_to_cache: move_to_cache
    };
}
