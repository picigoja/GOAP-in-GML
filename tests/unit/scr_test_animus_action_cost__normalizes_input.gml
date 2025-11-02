/// @desc Validates Animus_Action cost normalization.
function test_animus_action_cost__normalizes_input() {
    var testcase = scr_test_case("Animus_Action.cost normalization");
    scr_test_fixture_component_reset();
    var fixture = scr_test_fixture_action_context();
    var state = fixture.base_state;

    var constant_action = fixture.make_constant_action();
    testcase.expect_equal(constant_action.cost(state), 3, "constant cost should return input value");

    var callable_action = fixture.make_callable_action();
    testcase.expect_equal(callable_action.cost(state), 5, "callable cost should inspect state");
    variable_struct_set(state, "agent.hungry", false);
    testcase.expect_equal(callable_action.cost(state), 1, "callable cost should update with state change");

    var fallback_action = fixture.make_invalid_cost_action();
    testcase.expect_equal(fallback_action.cost(state), 1, "invalid cost inputs fall back to 1");

    var description = callable_action.describe();
    testcase.expect_true(string_pos(description, "Animus_Action") > 0, "describe should include label");
    testcase.expect_true(string_pos(description, "cost=") > 0, "describe should include cost");

    var result = testcase.result();
    result.suite = "unit";
    result.module = "Animus_Action";
    return result;
}
