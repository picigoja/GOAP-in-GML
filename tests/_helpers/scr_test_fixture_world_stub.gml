/// @desc Provides a deterministic world stub for integration tests.
function scr_test_fixture_world_stub() {
    return {
        name: "TestWorld",
        tick_count: 0,
        advance: function() {
            self.tick_count += 1;
        }
    };
}
