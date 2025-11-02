/// @desc Tests Animus_Plan serialisation for invalid state and pretty meta ordering.
function test_animus_plan_to_json__invalid_flag() {
    var testcase = scr_test_case("Animus_Plan to_json invalid flag");
    var fixture = scr_test_fixture_plan_structs();

    var valid_plan = new Animus_Plan(fixture.valid_plan);
    testcase.expect_true(valid_plan.is_valid(), "valid plan should report true");
    testcase.expect_equal(valid_plan.length(), array_length(fixture.valid_plan.actions), "length should match actions");
    var pretty = valid_plan.to_pretty_string();
    var meta_index = string_pos(pretty, "Meta:");
    testcase.expect_true(meta_index > 0, "pretty string should include meta section");
    var budget_index = string_pos(pretty, "budget");
    var reason_index = string_pos(pretty, "reason");
    testcase.expect_true(budget_index < reason_index, "meta keys should be sorted alphabetically");

    var invalid_plan = new Animus_Plan(fixture.invalid_plan);
    testcase.expect_true(!invalid_plan.is_valid(), "invalid plan should report false");
    var json_text = invalid_plan.to_json();
    testcase.expect_equal(json_text, json_stringify({ plan_valid: false }, false), "invalid plan JSON should flag plan_valid false");

    var result = testcase.result();
    result.suite = "unit";
    result.module = "Animus_Plan";
    return result;
}
