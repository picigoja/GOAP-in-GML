/// @desc Returns a context with an invalid navigation path for invariant failure tests.
function scr_test_fixture_invalid_nav_path() {
    var context = scr_test_fixture_strategy_context().context;
    context.blackboard.path_valid = false;
    context.blackboard.distance = 10;
    return context;
}
