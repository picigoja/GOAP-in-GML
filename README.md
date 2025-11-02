# Animus (GOAP in GML)

Animus is a modular Goal Oriented Action Planning (GOAP) toolkit for GameMaker. It focuses on clean separation between declarative planning data (beliefs, goals, actions) and the runtime systems that execute the chosen plan (strategies, sensors, reservations). The project started as a port of git-amend’s Unity sample, but has evolved into a purpose-built GML framework with deterministic planning, plan reuse, and tooling for debugging agent behaviour.

Animus ships with compatibility aliases (`GOAP_*`) for the canonical constructors (Action, Goal, Belief, Memory, Planner) so existing prototypes continue to compile, but new work should use the `Animus_*` APIs shown below.

## Core Scripts
- `Animus_Core` – logging, assertions, helpers
- `Animus_Predicate` – canonical predicate representation (+ apply/evaluate helpers)
- `Animus_Belief` – declarative world state probes with optional memory binding
- `Animus_Goal` – desired world states and priority/evaluation hooks
- `Animus_Action` – planning records (preconditions, effects, dynamic costs)
- `Animus_Planner` – A* search with partial-plan support and reuse policy
- `Animus_Memory` – authoritative state store with dirty tracking & subscriptions
- `Animus_Executor` – runtime plan executor with reservations, tracing, and deterministic RNG
- `Animus_ActionStrategy` – interface between executor and gameplay logic
- `Animus_Sensor` / `Animus_SensorHub` – periodic sampling pipeline feeding memory
- `Animus_RunState` – shared status constants
- `Animus_Plan`, `Animus_Debug`, `Animus_StrategyTemplates` – plan wrappers, inspection helpers, and ready-made strategy patterns

## Quickstart
```gml
// Create shared state
memory = new Animus_Memory();
memory.write("agent.hunger", 75);
memory.write("agent.food_inventory", 0);

// Beliefs describe the world through Animus_Memory
var belief_hungry = new Animus_Belief("agent.hungry", {
    memory_key: "agent.hunger",
    evaluator: function(value) { return value >= NPC_CRITICAL_HUNGER; },
    default_value: 0,
});

var belief_has_food = new Animus_Belief("agent.has_food", {
    memory_key: "agent.food_inventory",
    evaluator: function(value) { return value > 0; },
});

var beliefs = [belief_hungry, belief_has_food];

// Actions change the world state
var action_get_food = new Animus_Action(
    "Get Food",
    [],
    [ ["agent.has_food", true] ],
    2
);

// The executor asks each action for a runtime strategy. You can return one of the templates.
action_get_food.build_strategy = function(ctx, action) {
    return Strategy_Timed(action, {
        target_s: 1.5,
        on_success: function(context) {
            context.memory.write("agent.food_inventory", 1, "ai", 1);
        }
    });
};

var action_eat = new Animus_Action(
    "Eat",
    [ ["agent.has_food", true] ],
    [ ["agent.hungry", false] ],
    function(state) { return (state["agent.hungry"] + 1); }
);

action_eat.build_strategy = function(ctx, action) {
    return Strategy_Instant(action, {
        on_success: function(context) {
            var mem = context.memory;
            mem.write("agent.hunger", 0, { source: "ai", confidence: 1 });
            mem.write("agent.food_inventory", max(0, mem.read("agent.food_inventory", 0) - 1));
        }
    });
};

var actions = [action_get_food, action_eat];

// Goals describe what we want
var goal_survive = new Animus_Goal(
    "Avoid Starvation",
    [ ["agent.hungry", false] ],
    function(mem) { return mem.read("agent.hungry", 0); }
);

var goals = [goal_survive];

// Wire everything into an agent
planner = new Animus_Planner();
executor = new Animus_Executor();
agent = new Animus_Agent();

agent.bind(planner, memory, executor);      // optional world/blackboard params available
agent.set_beliefs(beliefs);
agent.set_actions(actions);
agent.set_goals(goals);
agent.bind_beliefs_to_memory();

// In Step (or a dedicated AI controller)
agent.tick(_dt); // handles perception, planning, execution
```

### Predicates & Effects
`Animus_Predicate.normalize_list` accepts strings, arrays, or structs:
- `"agent.hungry"` → `{ key:"agent.hungry", op:"eq", value:true }`
- `"!agent.hungry"` → `{ key:"agent.hungry", op:"eq", value:false }`
- `[ "agent.hunger", 50, "gt" ]` → `{ key:"agent.hunger", op:"gt", value:50 }`

Effects support the same shapes; using `"!key"` or `{ unset:true }` clears a fact from the state.

### Memory helpers
- `memory.write(key, value, source_or_options?, confidence?)` wraps `set(...)`
- `memory.read(key, default)` wraps `get(...)`
- `memory.snapshot(include_metadata)` returns a deep copy of known keys (with or without metadata)
- Dirty tracking (`is_dirty`, `last_updated`) allows the planner to invalidate stale plans quickly.

### Strategies & Execution
The executor instantiates a strategy per plan step using the following rules:
1. If an action exposes `strategy` as a struct, that struct is used directly.
2. If an action exposes `build_strategy`, `create_strategy`, `strategy_factory`, `make_strategy`, or `strategy_builder`, the callable is invoked as `fn(context, action)`.
3. If none of the above exist, a default `Animus_ActionStrategy` instance is created.

Each strategy must implement (or inherit) the following methods:
- `start(context)` – called once when the action becomes active.
- `update(context, dt)` – returns one of `Animus_RunState` constants.
- `stop(context, reason)` – cleanup for completion, interruption, or failure.
- `invariant_check(context)` – return `false` to invalidate the current plan early.
- `get_expected_duration(context)` – optional duration hint for timeouts.
- `get_reservation_keys(context)` – optional set of resource keys for conflict handling.
- `get_last_invariant_key()` – optional human-readable debug hint.

`Animus_StrategyTemplates.gml` contains ready-made helpers such as `Strategy_Instant`, `Strategy_Timed`, and `Strategy_Move` that return fully shaped strategies on top of the new interface.

### Sensors & Perception
`Animus_Sensor` defines a simple base class with interval-aware sampling. The hub stores optional references (`agent`, `world`, `blackboard`, `memory`) and can be driven in two ways:
```gml
// Perception tick inside Animus_Agent.tick already calls this:
sensor_hub.tick(_dt);             // uses bound memory
// Legacy usage still supported:
sensor_hub.tick(memory, _dt);     // overrides the memory for this call
```
Add sensors with `sensor_hub.add_sensor(sensor)`. Each sensor receives the memory instance in `tick(memory, dt)` and should call `memory.write(...)` with new observations.

### Plan Inspection
- `Animus_Debug.dump_plan(plan)` → human-readable description
- `executor.debug_json()` → serialisable trace for tooling
- `executor.playback_to_string(plan)` → merged plan + trace log

### Compatibility Notes
- Existing code that references `GOAP_*` constructors (Action, Goal, Belief, Memory, Planner) continues to work; each now forwards to its `Animus_*` counterpart with runtime contract guards.
- `Animus_Core.assert_plan_shape(...)` and `Animus_Core.assert_run_state(...)` verify planner results and strategy return states, surfacing actionable errors when shapes drift.
- New code should adopt the Animus naming to avoid future removals of legacy aliases.
- Strategy shape changed: implement `stop`, `invariant_check`, `get_expected_duration`, and `get_reservation_keys` (templates updated accordingly).
- `Animus_Memory` gained `read`, `write`, and `snapshot` helpers; agent and executor now rely on them.

## Next Steps
- Review the sample strategy templates and adapt them to your gameplay needs.
- Use `reservation_bus` (provided during execution) to coordinate multi-agent resource access.
- Extend the sensor hub with domain sensors (LOS probes, blackboard synchronisers, etc.).
- Hook `Animus_Debug` helpers into your tooling UI or in-game debug overlays.

## Authoritative GML manual for generative models
When using language models to generate or edit GML, prefer the canonical GameMaker manual and idioms in:

- https://github.com/Git-Fg/GameMaker-Manual-Markdown_4GenerativeAI

Use this repo as the truth-source for language semantics, engine behaviors, and common GML idioms; reference it in PRs that include LM-assisted changes.
