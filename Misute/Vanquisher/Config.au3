#include-once

#cs ----------------------------------------------------------------------------

    Config.au3

    Every tunable value used by the vanquisher lives in this file. Nothing in
    here does any work - it only declares constants and the handful of globals
    that describe "how the bot should behave".

    Change behaviour here, not in the controller.

#ce ----------------------------------------------------------------------------

#Region Identity
Global Const $VQ_BOT_TITLE = "Misute Vanquisher"
Global Const $VQ_BOT_VERSION = "1.0.0"
#EndRegion Identity

#Region Simulation
;~ Simulation mode lets the whole application run without Guild Wars.
;~ GuildWars.au3 and Pathfinder.au3 answer with fake but realistic data, so the
;~ GUI, the work queue, the retry logic and the zone timeout can all be tested.
;~ Set this to False once the real integration code has been pasted into the
;~ adapters (see the INTEGRATION POINT markers in GuildWars.au3/Pathfinder.au3).
Global $g_bSimulationMode = True

;~ Simulated durations / failure rates. Only used while $g_bSimulationMode.
Global Const $SIM_CONNECT_MS = 1200          ; time "connecting" to the client
Global Const $SIM_MAP_CHECK_MS = 120         ; time to read one map's status
Global Const $SIM_TRAVEL_MS = 5000           ; time to travel to an outpost
Global Const $SIM_EXIT_OUTPOST_MS = 2500     ; time to walk out of an outpost
Global Const $SIM_ZONE_MS = 25000            ; time to clear a zone
Global Const $SIM_ZONE_FOES = 180            ; foes at the start of a zone
Global Const $SIM_ZONE_FAIL_PERCENT = 20     ; chance a zone attempt gets stuck
Global Const $SIM_PATH_FAIL_PERCENT = 8      ; chance a pathfinder call fails
Global Const $SIM_VANQUISHED_PERCENT = 25    ; chance a map is already done
#EndRegion Simulation

#Region Retry and timeout
;~ How many attempts a single zone gets before it is marked as failed and the
;~ bot moves on. Attempt 1 + 2 retry, attempt 3 fails the map.
Global Const $MAX_RETRIES = 3

;~ The two hour per-attempt ceiling required by the workflow. A fresh timer is
;~ started for every attempt at a zone; see State_StartZoneTimer().
Global Const $ZONE_TIMEOUT_MS = 7200000      ; 2 hours

;~ Simulation shortens the ceiling so the timeout path can actually be observed.
Global Const $SIM_ZONE_TIMEOUT_MS = 60000    ; 1 minute

;~ The value the controller actually enforces.
Global $g_iZoneTimeoutMs = ($g_bSimulationMode) ? $SIM_ZONE_TIMEOUT_MS : $ZONE_TIMEOUT_MS

;~ Shorter ceilings for the individual steps inside an attempt. These stop the
;~ bot sitting in one step for the full two hours when something is obviously
;~ wrong (for example a travel that never completes).
Global Const $TRAVEL_TIMEOUT_MS = 180000     ; 3 minutes to reach an outpost
Global Const $EXIT_OUTPOST_TIMEOUT_MS = 90000 ; 90 seconds to leave an outpost
Global Const $CONFIRM_TIMEOUT_MS = 30000     ; 30 seconds to confirm a vanquish
Global Const $RECOVER_TIMEOUT_MS = 120000    ; 2 minutes to get back to safety

;~ If the pathfinder route finishes but the zone is not vanquished the route is
;~ run again. This caps how many times that happens per attempt.
Global Const $MAX_ROUTE_LOOPS = 3

;~ True  = a retried map goes to the back of the queue (other maps get a turn).
;~ False = a retried map is attempted again immediately.
Global Const $RETRY_AT_END_OF_QUEUE = True
#EndRegion Retry and timeout

#Region Pacing
;~ Main loop sleep. Small enough for a responsive GUI, large enough that the
;~ script does not burn a core while idle.
Global Const $TICK_SLEEP_MS = 25

;~ How often the GUI redraws time based fields (labels are otherwise only
;~ redrawn when the bot state actually changes).
Global Const $GUI_REFRESH_MS = 250

;~ How many maps are queried per tick while checking vanquished status. Keeping
;~ this low means a long map list does not freeze the GUI.
Global Const $MAPS_CHECKED_PER_TICK = 2

;~ How often "still vanquishing" progress is written to the log.
Global $g_iProgressLogIntervalMs = ($g_bSimulationMode) ? 4000 : 60000
#EndRegion Pacing

#Region Logging
Global Const $VQ_LOG_FILE = @ScriptDir & "\vanquish_log.txt"

;~ GwAu3_AddOns.au3 writes to $g_s_LogFile. Declaring it here means legacy log
;~ calls from the API end up in the same file instead of failing.
Global Const $g_s_LogFile = $VQ_LOG_FILE

;~ Number of log lines kept in memory so a GUI can be (re)attached and still
;~ show recent history.
Global Const $LOG_RING_SIZE = 400

;~ When the GUI console holds more lines than this it is re-rendered from the
;~ ring buffer, which keeps memory flat during unattended multi-day runs.
Global Const $GUI_LOG_MAX_LINES = 600
#EndRegion Logging

#Region Runtime options
;~ Set from the command line (-character "Name" [-autostart]).
Global $g_sTargetCharacter = ""
Global $g_bAutoStart = False

;~ True when the character combo should be filled from the API's scanner.
Global $g_bLoadLoggedChars = True
#EndRegion Runtime options
