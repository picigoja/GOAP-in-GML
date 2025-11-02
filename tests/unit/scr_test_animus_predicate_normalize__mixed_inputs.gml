/// @desc Ensures Animus_Predicate normalization and evaluation across mixed inputs.
function test_animus_predicate_normalize__mixed_inputs() {
    var testcase = scr_test_case("Animus_Predicate normalize mixed inputs");
    var fixture = scr_test_fixture_predicate_samples();

    var normalized = Animus_Predicate.normalize_list(fixture.mixed_inputs, "condition");
    testcase.expect_equal(array_length(normalized), 3, "mixed inputs should normalize into three predicates");
    if (array_length(normalized) == 3) {
        testcase.expect_equal(normalized[0].key, "agent.has_food", "string predicate keeps key");
        testcase.expect_equal(normalized[1].value, false, "array predicate maps value");
        testcase.expect_equal(normalized[2].op, "gt", "struct predicate preserves op");
    }

    var state = fixture.state;
    var eval_true = Animus_Predicate.evaluate(state, normalized[0]);
    testcase.expect_true(eval_true, "state should satisfy has_food predicate");
    var eval_false = Animus_Predicate.evaluate(state, normalized[1]);
    testcase.expect_true(!eval_false, "state should fail hungry=false until updated");

    var effects = Animus_Predicate.normalize_list(fixture.effect_inputs, "effect");
    var mutated = {}; // clone state to apply effects
    var names = variable_struct_get_names(state);
    for (var i = 0; i < array_length(names); ++i) {
        var key = names[i];
        variable_struct_set(mutated, key, variable_struct_get(state, key));
    }
    for (var j = 0; j < array_length(effects); ++j) {
        Animus_Predicate.apply_effect(mutated, effects[j]);
    }
    testcase.expect_true(!variable_struct_exists(mutated, "agent.has_food"), "effect unset should remove key");
    testcase.expect_true(variable_struct_exists(mutated, "agent.energy"), "lt effect should set energy");

    var action = fixture.normalized_action;
    action.effects = effects;
    var keys = Animus_Predicate.extract_keys_from_action(action);
    testcase.expect_true(array_length(keys) >= 2, "extract keys should gather predicate names");

    var result = testcase.result();
    result.suite = "unit";
    result.module = "Animus_Predicate";
    return result;
}
