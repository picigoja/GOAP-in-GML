/// @desc Provides sample predicate inputs and states for Animus_Predicate tests.
function scr_test_fixture_predicate_samples() {
    var state = {};
    variable_struct_set(state, "agent.has_food", true);
    variable_struct_set(state, "agent.hungry", true);
    variable_struct_set(state, "agent.energy", 75);

    var mixed_inputs = [
        "agent.has_food",
        ["agent.hungry", false, "eq"],
        { key: "agent.energy", op: "gt", value: 50 }
    ];

    var effect_inputs = [
        "!agent.has_food",
        { key: "agent.hunger", op: "unset" },
        ["agent.energy", 60, "lt"]
    ];

    var normalized_action = {
        preconditions: Animus_Predicate.normalize_list(mixed_inputs),
        effects: Animus_Predicate.normalize_list(effect_inputs, "effect")
    };

    return {
        state: state,
        mixed_inputs: mixed_inputs,
        effect_inputs: effect_inputs,
        normalized_action: normalized_action
    };
}
