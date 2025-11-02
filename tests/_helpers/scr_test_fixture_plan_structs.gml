/// @desc Supplies canonical plan structs for Animus_Plan tests.
function scr_test_fixture_plan_structs() {
    var goal = new Animus_Goal("Sate Hunger", ["!agent.hungry"], function(memory) {
        if (!is_struct(memory) || !Animus_Core.is_callable(memory.get)) {
            return 0;
        }
        return memory.get("agent.hungry", true) ? 5 : 1;
    });

    var gather = new Animus_Action("Gather", [], ["agent.has_food"], 2);
    var eat = new Animus_Action("Eat", ["agent.has_food"], ["!agent.hungry"], function(state) {
        var hungry = is_struct(state) && variable_struct_exists(state, "agent.hungry") ? variable_struct_get(state, "agent.hungry") : true;
        return hungry ? 1 : 0;
    });

    var plan_struct = {
        goal: goal,
        actions: [gather, eat],
        cost: 3,
        meta: {
            built_at_tick: 10,
            elapsed_ms: 1.2,
            nodes_expanded: 4,
            nodes_generated: 6,
            open_peak: 3,
            referenced_keys: ["agent.hungry", "agent.has_food"],
            is_partial: false,
            budget: { nodes: 2000, ms: 8 },
            reason: "success"
        }
    };

    var invalid_plan = {
        goal: undefined,
        actions: [],
        cost: undefined,
        meta: {
            built_at_tick: 0,
            elapsed_ms: 0,
            nodes_expanded: 0,
            nodes_generated: 0,
            open_peak: 0,
            referenced_keys: [],
            is_partial: true,
            budget: { nodes: 2000, ms: 8 },
            reason: "partial"
        }
    };

    return {
        valid_plan: plan_struct,
        invalid_plan: invalid_plan
    };
}
