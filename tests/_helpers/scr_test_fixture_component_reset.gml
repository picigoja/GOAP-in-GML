/// @desc Resets the internal component counter for deterministic tests.
function scr_test_fixture_component_reset() {
    if (variable_struct_exists(_Animus_Component, "__component_counter")) {
        _Animus_Component.__component_counter = 0;
    }
}
