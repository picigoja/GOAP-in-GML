/// @file GOAP_StrategyTemplates.gml
/// @desc Canonical Strategy patterns. Runtime only; no planning concerns.

/// Common helper to bind the action and return a Strategy-shaped struct
function _MakeBaseStrategy(_action_ref) {
    var _S = new GOAP_ActionStrategy(_action_ref); // keeps shape & defaults
    // Ensure all required fns exist, even if overridden later
    if (!is_callable(_S.start))                  _S.start                  = function(_) {};
    if (!is_callable(_S.update))                 _S.update                 = function(_, __) { return "running"; };
    if (!is_callable(_S.stop))                   _S.stop                   = function(_, __) {};
    if (!is_callable(_S.invariant_check))        _S.invariant_check        = function(_) { return true; };
    if (!is_callable(_S.get_expected_duration))  _S.get_expected_duration  = function(_) { return undefined; };
    if (!is_callable(_S.get_reservation_keys))   _S.get_reservation_keys   = function(_) { return []; };
    if (!is_callable(_S.get_last_invariant_key)) _S.get_last_invariant_key = function() { return undefined; };
    return _S;
}

/// Instant action: returns "success" on first update
/// Params (struct, optional): { on_start?(ctx), on_success?(ctx), invariant_fn?(ctx)->bool }
function Strategy_Instant(_action_ref, _params) {
    var S = _MakeBaseStrategy(_action_ref);
    var _done = false;

    var _opts = is_struct(_params) ? _params : {};
    var _invariant_fn = is_callable(_opts.invariant_fn) ? _opts.invariant_fn : undefined;
    var _on_start     = is_callable(_opts.on_start) ? _opts.on_start : undefined;
    var _on_success   = is_callable(_opts.on_success) ? _opts.on_success : undefined;

    S.start = function(ctx) {
        _done = false;
        if (is_callable(_on_start)) _on_start(ctx);
    };
    S.update = function(ctx, dt) {
        if (!_done) {
            _done = true;
            if (is_callable(_on_success)) _on_success(ctx);
            return "success";
        }
        return "success";
    };
    S.invariant_check = function(ctx) {
        return is_callable(_invariant_fn) ? !!_invariant_fn(ctx) : true;
    };
    return S;
}

/// Timed action: success after target_s; optional soft_timeout_s < expected_s
/// Params: { target_s:real, expected_s?:real, soft_timeout_s?:real,
///           on_start?(ctx), on_tick?(ctx,elapsed), on_success?(ctx), on_fail?(ctx),
///           invariant_fn?(ctx)->bool }
function Strategy_Timed(_action_ref, _params) {
    var S = _MakeBaseStrategy(_action_ref);
    var _opts = is_struct(_params) ? _params : {};

    var _target_s       = max(0, is_real(_opts.target_s) ? _opts.target_s : 0);
    var _expected_s     = variable_struct_exists(_opts, "expected_s") ? _opts.expected_s : _target_s;
    var _soft_timeout_s = variable_struct_exists(_opts, "soft_timeout_s") ? _opts.soft_timeout_s : undefined;

    var _elapsed = 0;
    var _invariant_fn = is_callable(_opts.invariant_fn) ? _opts.invariant_fn : undefined;
    var _on_start     = is_callable(_opts.on_start) ? _opts.on_start : undefined;
    var _on_tick      = is_callable(_opts.on_tick) ? _opts.on_tick : undefined;
    var _on_success   = is_callable(_opts.on_success) ? _opts.on_success : undefined;
    var _on_fail      = is_callable(_opts.on_fail) ? _opts.on_fail : undefined;

    S.start = function(ctx) {
        _elapsed = 0;
        if (is_callable(_on_start)) _on_start(ctx);
    };
    S.update = function(ctx, dt) {
        _elapsed += dt;
        if (is_callable(_on_tick)) _on_tick(ctx, _elapsed);

        if (!is_undefined(_soft_timeout_s) && _elapsed >= _soft_timeout_s && _elapsed < _target_s) {
            if (is_callable(_on_fail)) _on_fail(ctx);
            return "failed"; // internal soft timeout shorter than expected_s/target_s
        }

        if (_elapsed >= _target_s) {
            if (is_callable(_on_success)) _on_success(ctx);
            return "success";
        }
        return "running";
    };
    S.invariant_check = function(ctx) {
        return is_callable(_invariant_fn) ? !!_invariant_fn(ctx) : true;
    };
    S.get_expected_duration = function(ctx) {
        return _expected_s; // lets Executor enforce hard timeout if needed (Q3)
    };
    return S;
}

/// Move-style action with invariant & soft reservation
/// Params: {
///   nav_key_fn(ctx)->string,                 // reservation key (e.g., "nav:x_y" or path id)
///   path_is_valid(ctx)->bool,                // invariant probe
///   reached_fn(ctx, arrive_dist)->bool,      // arrival check
///   arrive_dist:real,                        // threshold
///   expected_s?:real,                        // hint for scheduler/timeout
///   on_start?(ctx), on_tick?(ctx,dt), on_stop?(ctx,reason), on_arrive?(ctx)
/// }
function Strategy_Move(_action_ref, _params) {
    var S = _MakeBaseStrategy(_action_ref);
    var _opts = is_struct(_params) ? _params : {};

    var _nav_key_fn  = _opts.nav_key_fn;
    var _path_ok_fn  = _opts.path_is_valid;
    var _reached_fn  = _opts.reached_fn;
    var _arrive_dist = max(0, is_real(_opts.arrive_dist) ? _opts.arrive_dist : 0);
    var _expected_s  = variable_struct_exists(_opts, "expected_s") ? _opts.expected_s : undefined;
    var _on_start    = is_callable(_opts.on_start) ? _opts.on_start : undefined;
    var _on_tick     = is_callable(_opts.on_tick) ? _opts.on_tick : undefined;
    var _on_stop     = is_callable(_opts.on_stop) ? _opts.on_stop : undefined;
    var _on_arrive   = is_callable(_opts.on_arrive) ? _opts.on_arrive : undefined;

    var _last_bad_key = undefined;

    S.start = function(ctx) {
        if (is_callable(_on_start)) _on_start(ctx);
    };

    S.update = function(ctx, dt) {
        if (is_callable(_on_tick)) _on_tick(ctx, dt);
        if (is_callable(_reached_fn) && _reached_fn(ctx, _arrive_dist)) {
            if (is_callable(_on_arrive)) _on_arrive(ctx);
            return "success";
        }
        return "running";
    };

    S.stop = function(ctx, reason) {
        if (is_callable(_on_stop)) _on_stop(ctx, reason);
    };

    S.invariant_check = function(ctx) {
        var _ok = is_callable(_path_ok_fn) ? !!_path_ok_fn(ctx) : true;
        if (!_ok) _last_bad_key = is_callable(_nav_key_fn) ? _nav_key_fn(ctx) : undefined;
        return _ok;
    };

    S.get_last_invariant_key = function() {
        return _last_bad_key;
    };

    S.get_expected_duration = function(ctx) {
        return _expected_s; // allows Executor timeout integration (Q3)
    };

    S.get_reservation_keys = function(ctx) {
        if (is_callable(_nav_key_fn)) {
            var _k = _nav_key_fn(ctx);
            return is_undefined(_k) ? [] : [_k];
        }
        return [];
    };

    return S;
}
