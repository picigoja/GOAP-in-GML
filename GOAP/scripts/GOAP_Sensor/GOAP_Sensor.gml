function GOAP_Sensor(_interval_ms) constructor {
    interval_ms = is_undefined(_interval_ms) ? undefined : _interval_ms;
    _accum_ms   = 0;
    id          = undefined;
    keys        = [];

    // Override in concrete sensor implementations.
    sample = function(_context) {
        return undefined;
    };

    poll = function(_dt, _context, _memory) {
        if (is_undefined(_memory)) {
            return 0;
        }

        if (is_undefined(interval_ms)) {
            return _sample_and_push(_context, _memory);
        }

        _accum_ms += (_dt * 1000);
        if (_accum_ms + 0.0001 >= interval_ms) {
            _accum_ms -= interval_ms;
            return _sample_and_push(_context, _memory);
        }

        return 0;
    };

    _sample_and_push = function(_context, _memory) {
        var _out = sample(_context);
        if (is_undefined(_out)) {
            return 0;
        }

        if (!is_array(_out)) {
            _out = [_out];
        }

        var _count = 0;
        for (var i = 0; i < array_length(_out); ++i) {
            var r = _out[i];
            if (!is_struct(r)) {
                continue;
            }
            if (is_undefined(r.key)) {
                continue;
            }

            var _src = variable_struct_exists(r, "source") ? r.source : "sensor";
            var _conf = variable_struct_exists(r, "confidence") ? r.confidence : 1.0;

            _memory.set(r.key, r.value, _src, _conf);
            _count += 1;
        }
        return _count;
    };
}
