/// @desc Provides a pre-populated Animus_Memory instance for goal tests.
function scr_test_fixture_memory_stub() {
    var memory = new Animus_Memory();
    memory.write("agent.hungry", true);
    memory.write("agent.energy", 25);
    return memory;
}
