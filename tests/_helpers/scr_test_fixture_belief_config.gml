/// @desc Returns a canonical belief configuration for Animus_Belief tests.
function scr_test_fixture_belief_config() {
    return {
        name: "IsHungry",
        config: {
            memory_key: "agent.hungry",
            selector: function(memory) {
                return memory.get("agent.hungry", false);
            },
            debounce_ticks: 2,
            auto_clean: true,
            post_evaluate: function(mapped_value, source) {
                if (is_struct(source) && Animus_Core.is_callable(source.write)) {
                    source.write("agent.last_belief", mapped_value);
                }
            }
        },
        evaluator: function(memory) {
            return memory.get("agent.hungry", false);
        }
    };
}
