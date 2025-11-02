/// @desc Validates Animus strategy templates for instant, timed, and move behaviours.
function test_animus_strategytemplates_timed__soft_timeout() {
    var testcase = scr_test_case("Animus_StrategyTemplates behaviour");
    var actions = scr_test_fixture_agent_actions();
    var ctx_fixture = scr_test_fixture_strategy_context();
    var context = ctx_fixture.context;
    var memory = context.memory;

    var instant_flag = { triggered: false };
    var instant = Strategy_Instant(actions.get_food, {
        on_success: function(ctx) { instant_flag.triggered = true; }
    });
    instant.start(context);
    var instant_state = instant.update(context, 0);
    testcase.expect_equal(instant_state, Animus_RunState.SUCCESS, "instant strategy should succeed on first update");
    testcase.expect_true(instant_flag.triggered, "instant strategy should invoke on_success");

    var timed_params = scr_test_fixture_timed_strategy_params();
    var timed = Strategy_Timed(actions.get_food, timed_params.soft_timeout);
    timed.start(context);
    var timed_state1 = timed.update(context, 0.4);
    testcase.expect_equal(timed_state1, Animus_RunState.RUNNING, "timed strategy should run before timeout");
    var timed_state2 = timed.update(context, 0.4);
    testcase.expect_equal(timed_state2, Animus_RunState.FAILED, "timed strategy should fail on soft timeout");
    testcase.expect_equal(memory.get("strategy.last_fail", undefined), "soft_timeout", "on_fail should annotate memory");

    var move_context = scr_test_fixture_strategy_context().context;
    move_context.blackboard.path_valid = false;
    move_context.blackboard.distance = 5;
    var move_strategy = Strategy_Move(actions.move_to_cache, {
        nav_key_fn: function(ctx) { return "nav.cache"; },
        path_is_valid: function(ctx) { return ctx.blackboard.path_valid; },
        reached_fn: function(ctx, dist) { return ctx.blackboard.distance <= dist; },
        arrive_dist: 0
    });
    move_strategy.start(move_context);
    var invariant_ok = move_strategy.invariant_check(move_context);
    testcase.expect_true(!invariant_ok, "move strategy should fail invariant when path invalid");
    testcase.expect_equal(move_strategy.get_last_invariant_key(), "nav.cache", "move strategy should cache bad nav key");

    var result = testcase.result();
    result.suite = "unit";
    result.module = "Animus_StrategyTemplates";
    return result;
}
