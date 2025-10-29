/// @param {Struct.Node|Undefined} _parent
/// @param {Struct.AgentAction|Undefined} _action
/// @param {Array<Struct.AgentBelief>} _required_effects
/// @param {Real} _cost
function GOAP_Node(_parent, _action, _required_effects, _cost) constructor {
    parent           = _parent;
    action           = _action;
    required_effects = _required_effects;
    cost             = _cost;
    leaves           = [];

    is_dead = function() {
        return bool(array_length(self.leaves) == 0) && bool(self.action == undefined);
    };

    add_leaf = function(_new_leaf) { array_push(self.leaves, _new_leaf); };
}
