/// @desc Sets up an Animus agent with planner, memory, executor, and world stubs.
function scr_test_fixture_agent_bindings() {
    var planner = new Animus_Planner();
    var memory_factory = scr_test_fixture_memory_factory();
    var memory = memory_factory.create_with_basic_bits();
    var executor = new Animus_Executor();
    var agent = new Animus_Agent();
    var world = {};
    var blackboard = { distance: 3, path_valid: true };
    agent.bind(planner, memory, executor, world, blackboard);
    return {
        agent: agent,
        planner: planner,
        memory: memory,
        executor: executor,
        world: world,
        blackboard: blackboard
    };
}
