/// @desc Verifies Animus_Debug helpers for profiling and trace playback.
function test_animus_debug_profile_block__elapsed_nonnegative() {
    var testcase = scr_test_case("Animus_Debug profile_block nonnegative");

    var profile = Animus_Debug.profile_block("noop", function() { return 123; });
    testcase.expect_true(profile.ms >= 0, "profile block should report non-negative time");
    testcase.expect_equal(profile.result, 123, "profile block should return callable result");

    var trace_text = Animus_Debug.playback_to_string({ debug_trace_snapshot: function() { return []; } }, undefined);
    testcase.expect_true(string_pos(trace_text, "<empty>") > 0, "empty trace should report placeholder");

    var result = testcase.result();
    result.suite = "unit";
    result.module = "Animus_Debug";
    return result;
}
