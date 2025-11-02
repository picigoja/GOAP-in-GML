/// @desc Bundles executor, plan, and memory fixtures for service tests.
function scr_test_fixture_executor_context() {
    var bindings = scr_test_fixture_agent_bindings();
    var actions = scr_test_fixture_agent_actions();
    var memory = bindings.memory;

    memory.write("agent.food_inventory", 0);
    memory.write("agent.has_food", false);
    memory.write("agent.hungry", true);

    var goal = new Animus_Goal("Sate Hunger", ["!agent.hungry"], function(mem) {
        return mem.get("agent.hungry", true) ? 10 : 0;
    });

    var plan_struct = {
        goal: goal,
        actions: [actions.move_to_cache, actions.get_food, actions.eat],
        cost: 4,
        meta: {
            built_at_tick: memory._now(),
            elapsed_ms: 0,
            nodes_expanded: 3,
            nodes_generated: 3,
            open_peak: 2,
            referenced_keys: ["agent.hungry", "agent.has_food", "agent.food_inventory"],
            is_partial: false,
            budget: { nodes: 2000, ms: 8 },
            reason: "success"
        }
    };

    var reservation = scr_test_fixture_reservation_bus();

    return {
        executor: bindings.executor,
        plan: plan_struct,
        agent: bindings.agent,
        world: bindings.world,
        blackboard: bindings.blackboard,
        memory: memory,
        reservation_bus: reservation
    };
}
