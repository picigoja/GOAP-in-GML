/// @param {String} _name
/// @param {Function} _condition
/// @param {Struct.Vector2} _location
function GOAP_Belief(_name, _condition = function() { return false; }, _location = new Vector2()) : _GOAP_Component(_name) constructor {
    condition = _condition;
    location  = _location;

    /// @returns {Bool}
    evaluate = function() { return self.condition(); };
}