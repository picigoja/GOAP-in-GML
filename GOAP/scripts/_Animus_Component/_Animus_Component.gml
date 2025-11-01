/// @desc Base component providing immutable identity.
/// @param {String} name
/// @returns {_Animus_Component}
function _Animus_Component(name) constructor {
    static __component_counter = 0;

    Animus_Core.assert(!is_undefined(name), "_Animus_Component requires a name");

    component_id = __component_counter;
    __component_counter += 1;

    component_name = name;

    /// @desc Checks identity equality.
    /// @param {_Animus_Component} other
    /// @returns {Bool}
    is_equal = function(other) {
        if (!is_struct(other)) {
            return false;
        }
        if (!is_instanceof(other, _Animus_Component)) {
            return false;
        }
        if (!variable_struct_exists(other, "component_id")) {
            return false;
        }
        return component_id == other.component_id;
    };

    /// @desc Stable debug string.
    /// @returns {String}
    to_string = function() {
        return "_Animus_Component#" + string(component_id) + "(" + string(component_name) + ")";
    };
}
