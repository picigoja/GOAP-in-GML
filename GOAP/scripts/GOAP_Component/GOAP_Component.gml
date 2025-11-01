/// @file GOAP_Component.gml
/// @desc Minimal base component providing immutable identity and equality helpers.

/// @param {String} _name
/// @desc Abstract base constructor; consumers should extend via composition/inheritance.
function _GOAP_Component(_name) constructor {
    static __component_counter = 0;

    /// Guard against missing or malformed identifiers at construction time.
    if (variable_struct_exists(self, "component_id")) {
        show_error("_GOAP_Component(): component_id must not be reassigned.", true);
    }

    if (is_undefined(_name)) {
        show_error("_GOAP_Component(): name must be provided.", true);
    }

    component_id = __component_counter;
    __component_counter++;

    name = _name;

    /// @param {Struct._GOAP_Component} _other_component
    /// @returns {Bool} True when the identity of both components match.
    is_equal = function(_other_component) {
        if (!is_instanceof(_other_component, _GOAP_Component)) {
            return false;
        }
        if (!variable_struct_exists(_other_component, "component_id")) {
            return false;
        }
        return bool(component_id == _other_component.component_id);
    };

    /// @param {Struct._GOAP_Component} _other_component
    /// @returns {Bool} Alias for {@link is_equal} to satisfy external expectations.
    equals = function(_other_component) {
        return is_equal(_other_component);
    };

    /// @returns {String} Stable representation for debug logging.
    to_string = function() {
        return "_GOAP_Component#" + string(component_id) + " (" + string(name) + ")";
    };
}

#ifdef DEBUG
/// @desc Lightweight sanity check to verify identity behaviour during development builds.
function __debug__goap_component_identity() {
    var _component_a = new _GOAP_Component("__debug_component_a");
    var _component_b = new _GOAP_Component("__debug_component_b");

    if (!_component_a.equals(_component_a)) {
        show_error("_GOAP_Component DEBUG check failed: self equality broken.", true);
    }

    if (_component_a.equals(_component_b)) {
        show_error("_GOAP_Component DEBUG check failed: identity collision detected.", true);
    }

    show_debug_message(_component_a.to_string());
    show_debug_message(_component_b.to_string());
}
#endif
