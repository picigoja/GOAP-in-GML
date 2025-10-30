# GOAP-in-GML
Goal Oriented Action Planning system in GameMaker
git-amend's GOAP System originaly wirtten in C# for Unity reworked for GML by picigoja
git-amend's implementation: [Better AI in Unity - GOAP (Goal Oriented Action Planning)](https:youtu.be/T_sBYgP7_2k?si=J_V58RjAPR-CwhQ-)

### What is it:
A Goal Oriented Action Planning system for creating more complex NPC behaviours than what State Machines or Behaviour Trees could manage

### How it works:
Define Beliefs, Actions and Goals to the Agent. The Agent will take all of its Goals and sort out the ones that have any Beliefs among its Desired Effects whose evaluators resolve to true.

e.g.: Let's make a Goal "Do not die of hunger" and a Belief as its Desired Effect "Am I hungry?" for the Agent "Agent NPC Worker". 
When the Belief "Am I hungry?" 's Condition evaluates, then that would signal the Agent that the Goal "Do not die of hunger" became 
relevant and in the next planning phase it should include this Goal with its priority among the other Goals that have one or more evaluating Desired Effects

The Agent prioritizes the Goals that had any Desired Effects evaluating, selects the one with highest Priority, gets all the Actions
and matches each Action's Effects to the selected Goal's Desired Effects building a stack of Actions, each solving a part of Beliefs left
from previous Actions Preconditions and from (yet unsolved) Desired Effects from the selected Goal itself.
Note that the Agent searches backwards from Desired Effects, chaining Actions until all Preconditions are satisfied.

e.g.: from goals = [ Goal_1("Do not die of hunger", Desired Effects = ["Am I hungry?"], priority = 2), Goal_2("Do nothing", Desired Effects = [TRUE], priority = 1) ] 
the Agent would select Goal_1 as it's next Goal when its Desired Effect "Am I hungry?" is TRUE else the next Goal would be Goal_2 since Goal_1's priority is higher.
and from actions = [ Action_1("Eat",      Preconditions = ["Backpack contains food item?"], Effets = ["Am I hungry?"]), 
             Action_2("Get Food", Preconditions = [],                               Effets = ["Backpack contains food item?"])) ];
would link Action_1 and Action_2 after each other as a solution to Goal_1. 

After discovering every possible combination, the Agent chooses the cheapest stack and starts executing the last Action going backwards.

## Basic Components:

### Beliefs:
Beliefs are information about the World State. Create one by calling `new GOAP_Belief()`.

e.g.:
var _belief = new GOAP_Belief("Example Belief");

The Belief's name should help you identify the Belief and helps in planning connections with other Components. e.g.: `_belief.name = "Am I hungry?"`.

Every belief owns an evaluator that decides if the world state currently satisfies the belief. Evaluators can run against cached
values, arbitrary structs, or the shared `GOAP_Memory` component. The most common way to configure a belief is by supplying a
memory key and (optionally) a custom evaluator:

```
var _belief = new GOAP_Belief("Am I hungry?", {
    memory_key: "hunger",
    evaluator: function(_value) {
        return _value >= NPC_CRITICAL_HUNGER_LEVEL;
    },
    default_value: 0,
});
```

Passing a struct is the preferred approach, but strings and reals are treated as memory keys for convenience. You may also provide
custom selector/evaluator pairs for advanced scenarios where the value should be derived from something other than a single memory key.

It's Location is a Vector2 with an "x" and a "y" component, use as World coordinate to tie this Belief to a specific location.

Populate an Array with all your Beliefs and feed it to the Agent as initial Beliefs.

```
var _beliefs = [
    new GOAP_Belief("Am I hungry?", {
        memory_key: "hunger",
        evaluator: function(_value) { return _value >= NPC_CRITICAL_HUNGER_LEVEL; },
    }),
    new GOAP_Belief("Backpack contains food item?", {
        memory_key: "backpack_food",
        evaluator: function(_value) { return _value > 0; },
    }),
    // TODO Give example for Location
];
```

Other Components will refere to Your Beliefs according to the connections between them, defined later in Actions and Goals.

### Actions:
Actions are the way the Agent will change the World State. Create one by calling "new AgentAction()".

e.g.:
var _action = new AgentAction();

The Action's name should help you identify the Action.

e.g.: 
_action.name = "Eat";

This is how you define connections between Actions and Beliefs:
The Action's Preconditions are Beliefs in an Array but the AgentAction constructor expects 
_initial_preconditions Array of name strings and these name strings should match your Beliefs names. 

e.g.: 
_action.preconditions = ["Backpack contains food item?"];

and it's Effects are also Beliefs in an Array and again the AgentAction constructor expects 
_initial_effects Array of name strings and these name strings should match your Beliefs names. 

e.g.: 
_action.effects = ["Am I hungry?"];

Then the Agent in its start() method will match these name strings to your Beliefs and link the Belief to the Action thus creating connections between them.

With the Action's Cost parameter you can fine tune how the Agent will sort your Actions.

ActionStrategy:
Each Action has a Strategy and each Strategy has three method
start(), update(), and stop().
and two properties 
"is_complete" and "can_perform"
for you to implement. Note that you must set can_perform = true when the Action is available, otherwise the Agent will skip it.
You can use these methods to write your gameplay logic for your Actions and the Agent checks the 
properties whether the Action's Strategy is completed or not or can even perform in the first place?

e.g.:
_action.strategy.update = function() {
    npc.backpack.take_item_amount(food_item, 1);
    npc.set_hunger_level(NPC_HUNGER_LEVEL_MAX);
    is_complete = true;
}

TODO Give example for other methods and can_perform
  
Populate an Array with all your Actions and feed it to the Agent as initial Actions.

e.g.:
var _actions = [];

var _action = new AgentAction("Eat", ["Backpack contains food item?"], ["Am I hungry?"], ACTION_COST_LOW);
_action.strategy.update = function() {
npc.backpack.take_item_amount(food_item, 1);
npc.set_hunger_level(NPC_HUNGER_LEVEL_MAX);
is_complete = true;
};

var _action_1 = new AgentAction( ... );

...

array_push(_actions, _action, _action_1, ... );

### Goals:
Goals are a collection of Beliefs thats Conditions are desired to evaluate to TRUE. Create one by calling "new AgentGoal()".

e.g.: 
var _goal = new AgentGoal();

The Goal's name should help you identify the Goal.

e.g.: 
_goal.name = "Do not die of hunger";

This is how you define connections between Goals and Beliefs:
The Goal's Desired Effects are Beliefs in an Array but the AgentGoal constructor expects 
_initial_desired_effects Array of name strings and these name strings should match your Beliefs names.
Note that Desired Effects represent world states the Agent wants to achieve, not conditions that are currently true.

e.g.: 
_goal.initial_desired_effects = ["Am I hungry?"];

Then the Agent in its start() method will match these name strings to your Beliefs and link the Belief to the Goal thus creating connections between them.

With the Goal's priority parameter you can fine tune how the Agent will sort your Goals.

Populate an Array with all your Goals and feed it to the Agent as initial Goals.

e.g.:
var _goals = [];
var _goal = new AgentGoal("Do not die of hunger", ["Am I hungry?"], GOAL_PRIORITY_HIGH);
var _goal_1 = new AgentGoal( ... );
...
array_push(_goals, _goal, _goal_1, ... );

TODO Sensors

### Agent:
The Agent is the main component that hold Beliefs, Actions and Goals. Create one and give it a name by calling "new GoapAgent(_name)".
and give the Agent initial Beliefs, Actions and Goals described above.

e.g.: 
-- obj_npc Create event --
agent = new GoapAgent("Agent NPC Worker", _beliefs, _actions, _goals);

Call the Agent's methods at the right event.

agent.start();

-- obj_npc Step event --
agent.update();

and let the Agent do it's thing
