/// @desc Unit test for Animus_Core.assert false condition handling.
function test_animus_core_assert__false_condition() {
    var testcase = scr_test_case("Animus_Core.assert false condition");
    var stub = scr_test_fixture_assert_listener();

    Animus_Core.assert(true, "should not raise");
    testcase.expect_equal(array_length(stub.calls()), 0, "assert(true) should not trigger raise");

    Animus_Core.assert(false, "force failure");
    var call_log = stub.calls();
    testcase.expect_equal(array_length(call_log), 1, "assert(false) should trigger raise exactly once");
    if (array_length(call_log) > 0) {
        testcase.expect_equal(call_log[0].message, "force failure", "raise should receive provided message");
        testcase.expect_true(call_log[0].fatal, "assert should mark failure as fatal");
    }

    stub.restore();

    var fn = function() { return 42; };
    testcase.expect_true(Animus_Core.is_callable(fn), "plain function should be callable");
    var agent = new Animus_Agent();
    testcase.expect_true(Animus_Core.is_callable(method(agent, "tick")), "method references should be callable");

    var formatted = Animus_Core.pretty({ b: 2, a: 1 });
    testcase.expect_true(string_pos(formatted, "a:1") > 0 && string_pos(formatted, "b:2") > 0, "pretty should include sorted keys");

    var result = testcase.result();
    result.suite = "unit";
    result.module = "Animus_Core";
    return result;
}
