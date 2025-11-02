/// @desc Verifies _Animus_Component identity behavior.
function test__animus_component_identity__increments() {
    scr_test_fixture_component_reset();
    var testcase = scr_test_case("_Animus_Component identity increments");

    var first = new _Animus_Component("First");
    var second = new _Animus_Component("Second");

    testcase.expect_equal(first.component_id, 0, "first component should start at id 0");
    testcase.expect_equal(second.component_id, 1, "second component should increment id");
    testcase.expect_true(!first.is_equal(second), "distinct components should not compare equal");
    testcase.expect_true(first.is_equal(first), "component should equal itself");

    var result = testcase.result();
    result.suite = "unit";
    result.module = "_Animus_Component";
    return result;
}
