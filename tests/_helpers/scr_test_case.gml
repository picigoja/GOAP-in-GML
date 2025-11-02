globalvar Animus_Outcome;
if (!is_struct(Animus_Outcome)) {
    Animus_Outcome = {
        success: "success",
        fail: "fail",
        timeout: "timeout",
        blocked: "blocked"
    };
}

/// @desc Utility for building structured test assertions.
function scr_test_case(name) {
    var failures = [];
    var notes = [];
    return {
        name: string(name),
        record_note: function(message) {
            array_push(notes, string(message));
        },
        expect_true: function(condition, message) {
            if (!condition) {
                array_push(failures, string(message));
                return false;
            }
            return true;
        },
        expect_equal: function(actual, expected, message) {
            if (actual != expected) {
                var info = string(message) + " (expected=" + string(expected) + ", actual=" + string(actual) + ")";
                array_push(failures, info);
                return false;
            }
            return true;
        },
        expect_struct_equal: function(actual, expected, message) {
            var same = json_stringify(actual) == json_stringify(expected);
            if (!same) {
                var info = string(message) + " (expected=" + json_stringify(expected) + ", actual=" + json_stringify(actual) + ")";
                array_push(failures, info);
            }
            return same;
        },
        fail: function(message) {
            array_push(failures, string(message));
        },
        result: function() {
            return {
                name: string(name),
                passed: array_length(failures) == 0,
                failures: failures,
                notes: notes,
                outcome: array_length(failures) == 0 ? Animus_Outcome.success : Animus_Outcome.fail
            };
        }
    };
}
