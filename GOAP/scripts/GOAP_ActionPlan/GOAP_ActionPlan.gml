/// @param {String} _name
/// @param {Struct.AgentGoal} _goal
/// @param {Array<Struct.AgentAction>} _actions
/// @param {Real} _total_cost
function GOAP_Plan(_name, _goal, _actions = [], _total_cost = 0) constructor {
    name       = _name;
    goal       = _goal;
    actions    = _actions;
    total_cost = _total_cost;
}