/// @desc Validates Animus_Belief debounce and auto_clean behaviour.
function test_animus_belief_debounce__respects_interval() {
    var testcase = scr_test_case("Animus_Belief debounce respects interval");
    var memory_factory = scr_test_fixture_memory_factory();
    var memory = memory_factory.create_with_basic_bits();
    var belief_data = scr_test_fixture_belief_config();
    var belief = new Animus_Belief(belief_data.name, belief_data.config, belief_data.evaluator);
    belief.bind(memory);

    var first = belief.evaluate_now(memory);
    testcase.expect_true(first, "initial evaluation should be true");
    testcase.expect_true(!memory.is_dirty("agent.hungry"), "auto_clean should clear dirty flag");

    memory.write("agent.hungry", false);
    var second = belief.evaluate_now(memory);
    testcase.expect_true(second, "debounce should reuse cached value before interval");

    memory.tick();
    memory.tick();
    var third = belief.evaluate_now(memory);
    testcase.expect_true(!third, "evaluation after debounce window should reflect new value");
    testcase.expect_equal(memory.get("agent.last_belief", undefined), false, "post_evaluate should capture result in memory");

    var result = testcase.result();
    result.suite = "unit";
    result.module = "Animus_Belief";
    return result;
}
