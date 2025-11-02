/// @desc Supplies a deterministic time source for Animus_Debug tests.
function scr_test_fixture_timer_stub() {
    var current = 0;
    return {
        now: function() { return current; },
        advance: function(ms) { current += ms; return current; },
        reset: function() { current = 0; }
    };
}
