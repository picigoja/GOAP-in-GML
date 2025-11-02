/// @desc Installs a stub for Animus_Core.raise to capture messages during tests.
function scr_test_fixture_assert_listener() {
    var previous = Animus_Core.raise;
    var calls = [];
    Animus_Core.raise = function(message, fatal) {
        var info = {
            message: is_string(message) ? message : string(message),
            fatal: bool(fatal)
        };
        array_push(calls, info);
        return undefined;
    };
    return {
        calls: function() { return calls; },
        restore: function() {
            Animus_Core.raise = previous;
        },
        last_call: function() {
            var total = array_length(calls);
            if (total <= 0) {
                return undefined;
            }
            return calls[total - 1];
        }
    };
}
