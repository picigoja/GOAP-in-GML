/// @desc Creates a new Animus Action (planning record)
/// @param {String} name
/// @param {Array} preconditions    // Array<PredicateStruct>
/// @param {Array} effects          // Array<PredicateStruct>
/// @param {Real|Function} cost     // number or (state)->Real
/// @returns {Animus_Action}
function Animus_Action(name, preconditions, effects, cost) constructor {
    var identity = new _Animus_Component(name);

    component_id = identity.component_id;
    component_name = identity.component_name;

        // CHORE: test strategy change — noop comment added to trigger CI suggestions
    is_equal = function(other) {
        return identity.is_equal(other);
    };

    name = is_string(name) ? name : "Action";

    preconditions = Animus_Predicate.normalize_list(preconditions, "condition");
    effects = Animus_Predicate.normalize_list(effects, "effect");

    var cost_fn;
    if (Animus_Core.is_callable(cost)) {
        cost_fn = cost;
    } else if (is_real(cost)) {
        var constant_cost = cost;
        cost_fn = function(state) {
            return constant_cost;
        };
    } else {
        cost_fn = function(state) {
            return 1;
        };
    }

    cost = function(state) {
        return cost_fn(state);
    };

    estimate_heuristic_to = function(goal, state) {
        return 0;
    };

    /// @desc Provides a debug representation of the action.
    /// @returns {String}
    describe = function() {
        return "[Animus_Action name=" + string(name) + " cost=" + string(cost({})) + "]";
    };
}
