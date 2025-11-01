
/// @desc Animus executor run state constants.
function Animus_RunState() constructor {
    /// @desc Action still in progress.
    /// @returns {String}
    static RUNNING = "running";

    /// @desc Action completed successfully.
    /// @returns {String}
    static SUCCESS = "success";

    /// @desc Action failed.
    /// @returns {String}
    static FAILED = "failed";

    /// @desc Action interrupted externally.
    /// @returns {String}
    static INTERRUPTED = "interrupted";

    /// @desc Action timed out.
    /// @returns {String}
    static TIMEOUT = "timeout";
}

Animus_RunState();
