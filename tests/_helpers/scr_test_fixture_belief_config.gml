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
            post_evaluate: function(memory, result) {
                memory.write("agent.last_belief", result);
            }
        },
        evaluator: function(memory) {
            return memory.get("agent.hungry", false);
        }
    };
}
