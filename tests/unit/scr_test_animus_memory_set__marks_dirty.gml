/// @desc Confirms Animus_Memory.set marks dirty and snapshot clones.
function test_animus_memory_set__marks_dirty() {
    var testcase = scr_test_case("Animus_Memory set marks dirty");
    var memory_factory = scr_test_fixture_memory_factory();
    var memory = memory_factory.create_without_dirty();

    memory.set("agent.energy", 10, { confidence: 1.5 });
    testcase.expect_true(memory.is_dirty("agent.energy"), "set should mark key dirty");
    var bit = memory.get_bit("agent.energy");
    if (is_struct(bit)) {
        testcase.expect_equal(bit.confidence, 1, "confidence should clamp to 1");
        testcase.expect_true(bit.last_updated > 0, "last_updated should advance");
    }

    var inventory = [1, 2, [3, 4]];
    memory.set("agent.inventory", inventory);
    var snapshot_meta = memory.snapshot(true);
    var snap_inventory = variable_struct_get(snapshot_meta, "agent.inventory");
    testcase.expect_struct_equal(snap_inventory.value, inventory, "snapshot should clone array value");
    inventory[0] = 99;
    testcase.expect_true(variable_struct_get(snapshot_meta, "agent.inventory").value[0] == 1, "snapshot should be deep copy");

    memory.clean("agent.energy");
    testcase.expect_true(!memory.is_dirty("agent.energy"), "clean should clear dirty flag");

    var result = testcase.result();
    result.suite = "unit";
    result.module = "Animus_Memory";
    return result;
}
