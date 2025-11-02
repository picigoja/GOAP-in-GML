/// @desc Checks default Animus_ActionStrategy behaviour.
function test_animus_actionstrategy_defaults__running() {
    var testcase = scr_test_case("Animus_ActionStrategy defaults");
    var fixture = scr_test_fixture_strategy_context();
    var strategy = fixture.make_strategy();
    var ctx = fixture.context;

    strategy.start(ctx);
    var update_state = strategy.update(ctx, 0.1);
    testcase.expect_equal(update_state, Animus_RunState.RUNNING, "default update should return RUNNING");

    var captured_reason = undefined;
    strategy.stop = function(context, reason) { captured_reason = reason; };
    strategy.interrupt(ctx, "blocked");
    testcase.expect_equal(captured_reason, "blocked", "interrupt should delegate to stop");

    testcase.expect_true(array_length(strategy.get_reservation_keys(ctx)) == 0, "default reservations should be empty");
    testcase.expect_equal(strategy.reservation_keys(ctx), strategy.get_reservation_keys(ctx), "alias should match primary");
    testcase.expect_equal(strategy.expected_duration(ctx), strategy.get_expected_duration(ctx), "duration alias should match");

    var result = testcase.result();
    result.suite = "unit";
    result.module = "Animus_ActionStrategy";
    return result;
}
