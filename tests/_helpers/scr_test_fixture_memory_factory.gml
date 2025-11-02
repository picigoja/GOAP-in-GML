/// @desc Factory helpers for Animus_Memory in tests.
function scr_test_fixture_memory_factory() {
    var create_empty = function() {
        return new Animus_Memory();
    };

    var create_without_dirty = function() {
        var memory = create_empty();
        memory.clean_all();
        return memory;
    };

    var create_with_basic_bits = function() {
        var memory = create_empty();
        memory.write("agent.hungry", true, { source: "fixture" }, 1);
        memory.write("agent.has_food", false, { source: "fixture" }, 0.8);
        memory.write("world.time", 120, { source: "fixture" }, 1);
        return memory;
    };

    var create_inventory_state = function(food_count) {
        var memory = create_without_dirty();
        memory.set("agent.food_inventory", max(0, food_count));
        return memory;
    };

    return {
        create_empty: create_empty,
        create_without_dirty: create_without_dirty,
        create_with_basic_bits: create_with_basic_bits,
        create_inventory_state: create_inventory_state
    };
}
