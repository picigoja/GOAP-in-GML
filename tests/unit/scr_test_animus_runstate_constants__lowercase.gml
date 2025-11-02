/// @desc Ensures Animus_RunState constants are lowercase strings.
function test_animus_runstate_constants__lowercase() {
    var testcase = scr_test_case("Animus_RunState lowercase constants");
    var constants = [
        Animus_RunState.RUNNING,
        Animus_RunState.SUCCESS,
        Animus_RunState.FAILED,
        Animus_RunState.INTERRUPTED,
        Animus_RunState.TIMEOUT
    ];
    for (var i = 0; i < array_length(constants); ++i) {
        var value = constants[i];
        testcase.expect_true(is_string(value), "run state should be string");
        testcase.expect_equal(value, string_lower(value), "run state should be lowercase");
    }
    var result = testcase.result();
    result.suite = "unit";
    result.module = "Animus_RunState";
    return result;
}
