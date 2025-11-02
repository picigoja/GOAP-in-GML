/// @desc Builds a baseline context struct for Animus_ActionStrategy tests.
function scr_test_fixture_strategy_context() {
    var memory = new Animus_Memory();
    memory.write("agent.hungry", true);

    var context = {
        agent: {},
        world: {},
        blackboard: {},
        memory: memory,
        plan: { goal: undefined, actions: [], meta: {} },
        step_index: 0,
        elapsed: 0,
        logical_time: 0,
        rng_float01: function() { return 0.5; },
        rng_int: function(min, max) { return min; }
    };

    return {
        context: context,
        make_strategy: function() {
            return new Animus_ActionStrategy("TestAction");
        }
    };
}
