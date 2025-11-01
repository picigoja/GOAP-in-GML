/// @desc Creates a declarative Animus Goal definition
/// @param {String} name
/// @param {Array} desired_effects   // Array<PredicateStruct>
/// @param {Real|Function} priority  // number or (memory)->Real
/// @returns {Animus_Goal}
function Animus_Goal(name, desired_effects, priority) constructor {
    var identity = new _Animus_Component(name);

    component_id = identity.component_id;
    component_name = identity.component_name;

    is_equal = function(other) {
        return identity.is_equal(other);
    };

    name = is_string(name) ? name : "Goal";
    desired_effects = Animus_Predicate.normalize_list(desired_effects, "condition");

    var priority_fn;
    if (Animus_Core.is_callable(priority)) {
        priority_fn = priority;
    } else if (is_real(priority)) {
        var base_priority = priority;
        priority_fn = function(memory) {
            return base_priority;
        };
    } else {
        priority_fn = function(memory) {
            return 0;
        };
    }

    priority = function(memory) {
        return priority_fn(memory);
    };

    is_relevant = function(memory) {
        return true;
    };

    tags = [];

    /// @desc Returns true when goal effects are satisfied by state.
    /// @param {Struct} state
    /// @returns {Bool}
    matches_state = function(state) {
        var len = array_length(desired_effects);
        for (var i = 0; i < len; ++i) {
            if (!Animus_Predicate.evaluate(state, desired_effects[i])) {
                return false;
            }
        }
        return true;
    };

    /// @desc Provides a human-readable description of the goal.
    /// @returns {String}
    describe = function() {
        return "[Animus_Goal name=" + string(name) + "]";
    };
}
