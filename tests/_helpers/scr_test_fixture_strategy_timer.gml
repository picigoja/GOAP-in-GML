/// @desc Provides parameter presets for Strategy_Timed tests.
function scr_test_fixture_strategy_timer() {
    var params = {
        target_s: 2.0,
        expected_s: 2.0,
        soft_timeout_s: 1.0,
        on_start: function(context) {
            context.elapsed = 0;
        },
        on_success: function(context) {
            context.completed = true;
        }
    };

    var context = scr_test_fixture_strategy_context().context;

    return {
        params: params,
        context: context
    };
}
