/// @desc State store for Animus agents with change notifications.
/// @returns {Animus_Memory}
function Animus_Memory() constructor {
    var MemoryBit = function(initial_value) constructor {
        value = initial_value;
        dirty = true;
        last_updated = 0;
        version = 0;
        source = undefined;
        confidence = 1.0;
    };

    bits = {};
    tick_counter = 0;
    subscribers = {};

    var ensure_bit = function(key, initial_value) {
        if (!variable_struct_exists(bits, key)) {
            var bit = new MemoryBit(initial_value);
            variable_struct_set(bits, key, bit);
        }
        return variable_struct_get(bits, key);
    };

    var clone_value = function(value) {
        if (is_array(value)) {
            var len = array_length(value);
            var out = array_create(len);
            for (var i = 0; i < len; ++i) {
                out[i] = clone_value(value[i]);
            }
            return out;
        }
        if (is_struct(value)) {
            var names = variable_struct_get_names(value);
            var count = array_length(names);
            var copy = {};
            for (var j = 0; j < count; ++j) {
                var k = names[j];
                variable_struct_set(copy, k, clone_value(variable_struct_get(value, k)));
            }
            return copy;
        }
        return value;
    };

    var notify = function(key, bit) {
        if (!variable_struct_exists(subscribers, key)) {
            return;
        }
        var listeners = variable_struct_get(subscribers, key);
        var count = array_length(listeners);
        for (var i = 0; i < count; ++i) {
            var listener = listeners[i];
            if (Animus_Core.is_callable(listener)) {
                listener(key, bit.value, bit.dirty, bit.last_updated);
            }
        }
    };

    /// @desc Advances the logical clock.
    /// @returns {Void}
    tick = function() {
        tick_counter += 1;
    };

    /// @desc Returns the current logical time tick.
    /// @returns {Real}
    _now = function() {
        return tick_counter;
    };

    /// @desc Retrieves a value by key.
    /// @param {String} key
    /// @param {Any} default_value
    /// @returns {Any}
    get = function(key, default_value) {
        if (!variable_struct_exists(bits, key)) {
            return default_value;
        }
        var bit = variable_struct_get(bits, key);
        return is_undefined(bit.value) ? default_value : bit.value;
    };

    /// @desc Stores a value and marks the bit dirty.
    /// @param {String} key
    /// @param {Any} value
    /// @param {Struct|Undefined} options
    /// @returns {Void}
    set = function(key, value, options) {
        var bit = ensure_bit(key, value);
        var old_value = bit.value;
        var changed = true;
        if (!is_array(value) && !is_struct(value)) {
            changed = (old_value != value);
        }
        if (changed) {
            tick_counter += 1;
            bit.value = value;
            bit.dirty = true;
            bit.last_updated = tick_counter;
            bit.version += 1;
            if (is_struct(options)) {
                if (variable_struct_exists(options, "source")) {
                    bit.source = variable_struct_get(options, "source");
                }
                if (variable_struct_exists(options, "confidence")) {
                    var conf = variable_struct_get(options, "confidence");
                    if (is_real(conf)) {
                        bit.confidence = clamp(conf, 0, 1);
                    }
                }
            }
            notify(key, bit);
        }
    };

    /// @desc Convenience alias for set(); accepts optional metadata parameters.
    /// @param {String} key
    /// @param {Any} value
    /// @param {Struct|String|Undefined} source_or_options
    /// @param {Real|Undefined} confidence
    /// @returns {Void}
    write = function(key, value, source_or_options, confidence) {
        var options = undefined;
        if (is_struct(source_or_options)) {
            options = source_or_options;
        } else if (!is_undefined(source_or_options) || !is_undefined(confidence)) {
            options = {};
            if (!is_undefined(source_or_options)) {
                options.source = source_or_options;
            }
            if (!is_undefined(confidence) && is_real(confidence)) {
                options.confidence = clamp(confidence, 0, 1);
            }
        }
        set(key, value, options);
    };

    /// @desc Convenience alias for get().
    /// @param {String} key
    /// @param {Any} default_value
    /// @returns {Any}
    read = function(key, default_value) {
        return get(key, default_value);
    };

    /// @desc Returns true when a key exists.
    /// @param {String} key
    /// @returns {Bool}
    has = function(key) {
        return variable_struct_exists(bits, key);
    };

    /// @desc Returns array of stored keys.
    /// @returns {Array}
    keys = function() {
        return variable_struct_get_names(bits);
    };

    /// @desc Marks a key as dirty without changing value.
    /// @param {String} key
    /// @returns {Void}
    mark_dirty = function(key) {
        var bit = ensure_bit(key, undefined);
        tick_counter += 1;
        bit.dirty = true;
        bit.last_updated = tick_counter;
        bit.version += 1;
        notify(key, bit);
    };

    /// @desc Marks a specific key clean.
    /// @param {String} key
    /// @returns {Void}
    clean = function(key) {
        if (!variable_struct_exists(bits, key)) {
            return;
        }
        var bit = variable_struct_get(bits, key);
        bit.dirty = false;
    };

    /// @desc Clears dirty flag on all bits.
    /// @returns {Void}
    clean_all = function() {
        var names = variable_struct_get_names(bits);
        var len = array_length(names);
        for (var i = 0; i < len; ++i) {
            var key = names[i];
            var bit = variable_struct_get(bits, key);
            bit.dirty = false;
        }
    };

    /// @desc Subscribes a listener to key updates.
    /// @param {String} key
    /// @param {Function} listener
    /// @returns {Void}
    subscribe = function(key, listener) {
        if (!variable_struct_exists(subscribers, key)) {
            variable_struct_set(subscribers, key, []);
        }
        var list = variable_struct_get(subscribers, key);
        if (array_index_of(list, listener) < 0) {
            array_push(list, listener);
        }
    };

    /// @desc Unsubscribes a listener from updates.
    /// @param {String} key
    /// @param {Function} listener
    /// @returns {Void}
    unsubscribe = function(key, listener) {
        if (!variable_struct_exists(subscribers, key)) {
            return;
        }
        var list = variable_struct_get(subscribers, key);
        var index = array_index_of(list, listener);
        if (index >= 0) {
            array_delete(list, index, 1);
        }
    };

    /// @desc Returns dirty flag for a key.
    /// @param {String} key
    /// @returns {Bool}
    is_dirty = function(key) {
        if (!variable_struct_exists(bits, key)) {
            return false;
        }
        var bit = variable_struct_get(bits, key);
        return bool(bit.dirty);
    };

    /// @desc Returns the last update tick.
    /// @param {String} key
    /// @returns {Real}
    last_updated = function(key) {
        if (!variable_struct_exists(bits, key)) {
            return -1;
        }
        var bit = variable_struct_get(bits, key);
        return bit.last_updated;
    };

    /// @desc Exposes the backing bit structure (read-only).
    /// @param {String} key
    /// @returns {Struct|Undefined}
    get_bit = function(key) {
        if (!variable_struct_exists(bits, key)) {
            return undefined;
        }
        return variable_struct_get(bits, key);
    };

    /// @desc Creates a snapshot of stored values or metadata.
    /// @param {Bool} include_metadata
    /// @returns {Struct}
    snapshot = function(include_metadata) {
        var with_meta = bool(include_metadata);
        var result = {};
        var names = variable_struct_get_names(bits);
        var len = array_length(names);
        for (var i = 0; i < len; ++i) {
            var key = names[i];
            var bit = variable_struct_get(bits, key);
            if (with_meta) {
                variable_struct_set(result, key, {
                    value: clone_value(bit.value),
                    dirty: bit.dirty,
                    last_updated: bit.last_updated,
                    version: bit.version,
                    source: bit.source,
                    confidence: bit.confidence
                });
            } else {
                variable_struct_set(result, key, clone_value(bit.value));
            }
        }
        return result;
    };
}
