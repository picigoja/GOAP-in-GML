/// @desc Confirms Animus_Goal matches_state and priority behaviour.
function test_animus_goal_matches_state__exact_effects() {
    var testcase = scr_test_case("Animus_Goal matches_state exact effects");
    var memory = scr_test_fixture_memory_stub();
    var goal = new Animus_Goal("Sate Hunger", ["!agent.hungry"], function(mem) {
        return mem.get("agent.hungry", true) ? 5 : 1;
    });

    var state = {};
    variable_struct_set(state, "agent.hungry", true);
    variable_struct_set(state, "agent.has_food", false);

    testcase.expect_true(goal.is_relevant(memory), "goal should be relevant by default");
    testcase.expect_equal(goal.priority(memory), 5, "priority should reflect memory state");
    testcase.expect_true(!goal.matches_state(state), "state should not yet satisfy goal");

    var effects = Animus_Predicate.normalize_list(["!agent.hungry"], "effect");
    Animus_Predicate.apply_effect(state, effects[0]);
    testcase.expect_true(goal.matches_state(state), "state should satisfy goal after effect");

    memory.write("agent.hungry", false);
    testcase.expect_equal(goal.priority(memory), 1, "priority should drop after hunger resolved");

    var result = testcase.result();
    result.suite = "unit";
    result.module = "Animus_Goal";
    return result;
}
