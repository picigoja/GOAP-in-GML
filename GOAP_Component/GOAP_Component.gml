/// @desc Basic component. *abstract*
/// @param {String} _name
function _GOAP_Component(_name) constructor {
    static component_number = 0;
    component_id = component_number;
    component_number++;

    name = _name;

    /// @param {Struct._GOAP_Component} _other_component
    is_equal = function(_other_component) {
        if !is_instanceof(_other_component, _GOAP_Component) return false;
        return bool(self.component_id == _other_component.component_id);
    };
}
