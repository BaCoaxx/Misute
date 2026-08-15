# Misute Vanquisher

An automated Guild Wars 1 vanquishing framework: a functional AutoIt GUI, a bot
controller that works through a queue of zones with retries and a two hour
per-attempt ceiling, and thin adapters where the Guild Wars and pathfinder code
gets plugged in.

It runs today. `$g_bSimulationMode` (in `Config.au3`) is `True` out of the box,
so the whole workflow - travel, leave the outpost, vanquish, confirm, retry,
time out, stop - can be watched in the GUI without the game running.

---

## Layout

```text
Misute/Vanquisher/
├── Main.au3            entry point: includes, startup, the application loop
├── GUI.au3             window, events, refresh, log console
├── BotController.au3   state machine, work queue, retries, timeout, stop
├── Maps.au3            map database and per-map status
├── GuildWars.au3       process connection and game-state adapter
├── Pathfinder.au3      pathfinder adapter
├── BotState.au3        shared state: the contract between GUI and controller
├── Config.au3          every tunable value
└── Log.au3             central logging
```

Dependencies only ever point downwards:

```text
        GUI.au3
           │  StartBot() / RequestStop(), reads BotState + Maps
           ▼
     BotController.au3
           │
     ┌─────┴─────┐
     ▼           ▼
 Maps.au3   Pathfinder.au3 ──► GuildWars.au3 ──► Guild Wars client
                                    ▲
                                    └── Maps.au3 (vanquished status only)

  BotState.au3 / Log.au3 / Config.au3 are used by everything and depend on
  nothing, so neither logging nor progress reporting couples the layers.
```

`BotState.au3`, `Log.au3` and `Config.au3` are the three files that were not in
the original sketch. AutoIt has no modules or interfaces, so they are what makes
the separation real:

* **`BotState.au3`** - the controller writes what it is doing here and the GUI
  reads it. The controller never names a GUI control, so the display can be
  replaced (or removed, or driven from a console) without touching the bot.
* **`Log.au3`** - the display registers a callback
  (`Log_RegisterSink("GUI_OnLogLine")`), so `LogMessage()` works whether or not
  a window exists. The last 400 lines are buffered, so a window created later
  still shows the history.
* **`Config.au3`** - retry counts, timeouts and pacing in one place.

---

## How the GUI and the controller talk

The GUI only ever *asks*:

```text
Start button ─► GUI_OnStart()  ─► StartBot($sCharacterName)
Stop button  ─► GUI_OnStop()   ─► RequestStop()
Rendering    ─► GUI_OnToggleRendering() ─► Bot_SetRendering()
Refresh      ─► GUI_OnRefreshCharacters() ─► Bot_GetLoggedCharNames()
```

and only ever *reads* `State_Get*()`, `Maps_Get*()` and the log lines it is
handed. No bot logic lives in an event handler, and no GUI call lives in the
controller.

### Why the controller is a tick machine

The original farm loop blocks (`Main()` runs until it decides to return), which
is what makes a bot window feel frozen and a stop button feel dead. Here,
`Main.au3` owns the loop:

```autoit
While True
    Bot_Tick()      ; one small slice of bot work, always returns quickly
    GUI_Update()    ; repaint anything that changed
    Sleep($TICK_SLEEP_MS)
WEnd
```

Because no step blocks:

* the window keeps repainting while the bot works,
* a stop request is noticed within milliseconds,
* the two hour zone timer is checked continuously rather than at the end of
  some long operation,
* AutoIt needs no threads (it has none).

If the real pathfinder code you paste in *does* block for several seconds, call
`State_Yield()` inside its wait loops; the host repaints and the GUI stays
alive. `State_Yield()` is a plain registered callback, so no GUI knowledge
leaks into the adapters.

---

## The state machine

```text
  IDLE ──Start──► INITIALISING ──► CHECKING ──► NEXT_MAP ──► TRAVELLING
                                       │            ▲            │
                                       │            │            ▼
                                  (all done)        │         LEAVING
                                       │            │            │
                                       ▼            │            ▼
                                   FINISHED         │       VANQUISHING
                                                    │            │
                                        CONFIRMING ─┘            │
                                             ▲                   │
                                             └───────────────────┘
                                                   (vanquish detected)

  any state ──failure/timeout──► RECOVERING ──► NEXT_MAP
  any state ──stop requested──► STOPPING ──► IDLE
  fatal problem ─────────────► ERROR (GUI stays open, Start works again)
```

| State | What happens |
|---|---|
| `INITIALISING` | `Initialise()`, then `Pathfinder_Init()` |
| `CHECKING` | reads the vanquished status of every map, a couple per tick, then builds the queue |
| `NEXT_MAP` | takes the front of the queue, counts an attempt, **starts a fresh two hour timer** |
| `TRAVELLING` | `TravelToOutpost()` then polls `Pathfinder_Step()` |
| `LEAVING` | `ExitOutpost()` then polls |
| `VANQUISHING` | `VanquishZone()`, polls `IsZoneVanquished()`, logs progress, reruns the route if it finishes early |
| `CONFIRMING` | re-checks the vanquish before ticking the map off |
| `RECOVERING` | aborts the pathfinder, returns to an outpost, then carries on |
| `STOPPING` | safe halt: pathfinder stopped, map handed back to the queue, bot idle |

---

## Map database

One map is one `Maps_Register()` line in `Maps_Load()` (`Maps.au3`) - the only
place map data lives:

```autoit
Maps_Register("Regent Valley", $MAP_ID_UNSET, "Fort Ranik", $MAP_ID_UNSET, "Ascalon", "Route_RegentValley")
;             zone name        zone map id    start outpost  outpost map id  region     pathfinder route
```

Each row also carries runtime fields the controller and GUI use: status
(unknown / pending / in progress / vanquished / failed), attempts, and a short
"last result" string.

The map ids ship as `$MAP_ID_UNSET`. Fill in the ids your API uses (or its map
id constants) and the same rows start driving the real game. The seeded list is
the Tyria set as an example - extend, trim or replace it.

`Route` is just a name. `Pathfinder_ResolveRoute()` calls a function of that
name if one exists (handy for `Func Route_RegentValley()` returning a waypoint
array) and otherwise passes the name straight through to a pathfinder that
works from route ids.

---

## Work queue, retries and the two hour rule

* **Queue** - a plain array of map indices, worked from the front. A map leaves
  the queue when it is confirmed vanquished or has finally failed. When the
  queue empties, the run finishes cleanly and the GUI says so.
* **Retries** - `MAX_RETRIES = 3` in `Config.au3`. Attempts 1 and 2 send the map
  to the **back** of the queue (so one bad zone does not block the rest);
  attempt 3 marks it failed and moves on. Failed maps are kept apart from
  vanquished ones and both are shown in the GUI.
* **Timeout** - `State_StartZoneTimer()` runs on every new attempt.
  `Bot_CheckZoneTimeout()` is called at the top of every tick of every state
  inside an attempt, so no matter where the bot gets stuck it cannot exceed
  `$ZONE_TIMEOUT_MS` (7,200,000 ms). A timeout is an ordinary failure: logged,
  counted as an attempt, recovered from, next map. Shorter per-step ceilings
  (travel, leaving, confirming, recovering) catch obvious hangs much sooner.
* **Every failure path** - pathfinder failure, dead party, timeout, unexpected
  state - funnels into `Bot_AttemptFailed()`, which is the single place that
  decides "retry" or "give up". That is what makes an infinite loop impossible.

## Stopping

`RequestStop()` only sets a flag. The next `Bot_Tick()` moves to `STOPPING`,
which stops the pathfinder, hands the in-progress map back to the queue as
pending, clears the timers and returns the bot to idle. The window stays open
and Start works again. Closing the window asks the bot to stop first and exits
once it has (with a 15 second grace period so a wedged adapter cannot keep the
application alive forever).

---

## Wiring up the real game

Everything game specific is behind two files, each function marked with an
`INTEGRATION POINT` comment.

1. **`GuildWars.au3`** - uncomment the two `#include` lines at the top (paths
   already match `Misute.au3`, one folder deeper), paste your connection code
   into `Initialise()`, then fill in `GW_IsMapVanquished()`,
   `GW_IsCurrentZoneVanquished()`, `GW_IsInOutpost()`, `GW_IsInExplorable()`,
   `GW_GetFoesRemaining()`, `GW_ReturnToOutpost()` and friends.
2. **`Pathfinder.au3`** - implement `Pathfinder_BeginTravel()`,
   `Pathfinder_BeginExitOutpost()`, `Pathfinder_BeginRoute()`,
   `Pathfinder_Step()` and `Pathfinder_Abort()`.
3. Fill in the map ids in `Maps_Load()`.
4. Set `$g_bSimulationMode = False` in `Config.au3`.

Nothing else changes: the controller, the queue, the retries, the timeout and
the GUI are all game agnostic.

### Simulation mode

While `$g_bSimulationMode` is `True` the adapters answer with fake data:
travel takes 5 s, leaving an outpost 2.5 s, a zone 25 s, one attempt in five
gets stuck (so the timeout and retry paths run), one pathfinder call in twelve
fails, and a quarter of the maps report as already vanquished. The zone ceiling
is shortened to `$SIM_ZONE_TIMEOUT_MS` (1 minute) so the two hour path can
actually be observed.

---

## Running

```text
AutoIt3.exe Main.au3
AutoIt3.exe Main.au3 -character "My Character"          ; preselects a client
AutoIt3.exe Main.au3 -character "My Character" -autostart
```

`Main.au3` keeps `#RequireAdmin` from the original script, since reading the
client's memory needs it.

Logs are written to `vanquish_log.txt` next to the script, reopened per line so
the file survives a crash, and mirrored into the GUI console with the same
colour coding the original window used.
