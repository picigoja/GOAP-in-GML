/// @param {String} _name
/// @param {Array<String>} _desired_effects
/// @param {Real} _priority
function GOAP_Goal(_name, _desired_effects = [], _priority = 0) : _GOAP_Component(_name) constructor {
    desired_effects = _desired_effects;
    priority     = _priority;
    is_last_goal = false;

    /// Goal becomes relevant if any desired effect is currently FALSE.
    is_relevant = function() {
        return array_any(self.desired_effects, function(_de) { return !_de.evaluate(); });
    };
}
