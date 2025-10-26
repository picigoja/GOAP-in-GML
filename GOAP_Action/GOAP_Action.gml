/// @param {String} _name
/// @param {Array<String>} _preconditions
/// @param {Array<String>} _effects
/// @param {Real} _cost
function GOAP_Action(_name, _preconditions = [], _effects = [], _cost = 1) : _GOAP_Component(_name) constructor {
    preconditions = _preconditions;
    effects       = _effects;
    cost          = _cost;
    strategy      = new GOAP_Strategy();

    /// @return {Bool}
    is_complete = function() {
        return array_all(self.effects, function(_e) { return _e.evaluate(); });
    };

    /// @return {Bool}
    can_perform = function() {
        return array_all(self.preconditions, function(_p) { return _p.evaluate(); });
    };

    start  = function() { self.strategy.start();  };
    update = function() { self.strategy.update(); };
    stop   = function() { self.strategy.stop();   };
}
