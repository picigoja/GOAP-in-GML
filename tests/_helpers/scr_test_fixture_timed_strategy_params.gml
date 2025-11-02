/// @desc Supplies parameter variations for Strategy_Timed timeout scenarios.
function scr_test_fixture_timed_strategy_params() {
    return {
        fast_success: {
            target_s: 0.5,
            expected_s: 0.5
        },
        soft_timeout: {
            target_s: 2.0,
            expected_s: 2.0,
            soft_timeout_s: 0.75,
            on_fail: function(ctx) {
                if (!is_struct(ctx) || !is_struct(ctx.memory)) return;
                if (Animus_Core.is_callable(ctx.memory.write)) {
                    ctx.memory.write("strategy.last_fail", "soft_timeout");
                }
            }
        }
    };
}
