/// @desc Provides helper constructors for Animus_Action tests.
function scr_test_fixture_action_context() {
    var base_state = {};
    variable_struct_set(base_state, "agent.hungry", true);
    variable_struct_set(base_state, "agent.energy", 20);

    var callable_cost = function(state) {
        var hunger = true;
        if (is_struct(state) && variable_struct_exists(state, "agent.hungry")) {
            hunger = variable_struct_get(state, "agent.hungry");
        }
        return hunger ? 5 : 1;
    };

    return {
        base_state: base_state,
        make_constant_action: function() {
            return new Animus_Action("Gather", [], [], 3);
        },
        make_callable_action: function() {
            return new Animus_Action("Eat", [], [], callable_cost);
        },
        make_invalid_cost_action: function() {
            return new Animus_Action("Wander", [], [], "unknown");
        }
    };
}
