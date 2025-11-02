/// @desc Provides a predictable reservation bus for executor tests.
function scr_test_fixture_reservation_bus() {
    var store = {};
    return {
        store: store,
        acquire: function(key, owner) {
            if (!variable_struct_exists(store, key)) {
                variable_struct_set(store, key, owner);
                return true;
            }
            return variable_struct_get(store, key) == owner;
        },
        release: function(key, owner) {
            if (!variable_struct_exists(store, key)) {
                return;
            }
            if (variable_struct_get(store, key) == owner) {
                variable_struct_remove(store, key);
            }
        },
        keys: function() {
            return variable_struct_get_names(store);
        }
    };
}
