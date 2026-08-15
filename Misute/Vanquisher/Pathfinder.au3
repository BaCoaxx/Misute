#include-once
#include "Config.au3"
#include "Log.au3"
#include "BotState.au3"
#include "GuildWars.au3"

#cs ----------------------------------------------------------------------------

    Pathfinder.au3

    Adapter around the pathfinder. The controller only ever uses the small API
    below, so whatever the real pathfinder looks like stays contained here.

    The API is deliberately "begin then step":

        Pathfinder_BeginTravel(...)     starts a job and returns immediately
        Pathfinder_Step()               moves the job on a little, returns status
        Pathfinder_Abort()              stops whatever is running

    That shape is what keeps the GUI alive and the stop button responsive: the
    controller polls Pathfinder_Step() once per tick instead of blocking.

    IF YOUR PATHFINDER IS BLOCKING (one call that only returns when it arrives)
    you have two options:
        a) call it inside Pathfinder_Step() and return $ePATH_COMPLETE/$ePATH_FAILED
           from that single call, and sprinkle State_Yield() into any wait loops
           so the GUI keeps repainting, or
        b) keep a cursor over the route's waypoints and move one waypoint per
           Pathfinder_Step() call, which is the better behaved option.

#ce ----------------------------------------------------------------------------

#Region Job status
Global Const $ePATH_IDLE = 0        ; nothing running
Global Const $ePATH_RUNNING = 1     ; still working
Global Const $ePATH_COMPLETE = 2    ; arrived / route finished
Global Const $ePATH_FAILED = 3      ; could not do it
#EndRegion Job status

#Region Job types
Global Const $ePATHJOB_NONE = 0
Global Const $ePATHJOB_TRAVEL = 1   ; map travel to an outpost
Global Const $ePATHJOB_EXIT = 2     ; walk from an outpost into the zone
Global Const $ePATHJOB_ROUTE = 3    ; run the zone's vanquish route
#EndRegion Job types

#Region State
Global $g_bPathInitialised = False
Global $g_iPathStatus = $ePATH_IDLE
Global $g_iPathJob = $ePATHJOB_NONE
Global $g_sPathDescription = ""
Global $g_sPathLastError = ""
Global $g_iPathTargetMapId = 0
Global $g_bPathTargetIsOutpost = True

;~ Simulation only.
Global $g_hSimPathTimer = 0
Global $g_iSimPathDurationMs = 0
Global $g_bSimPathWillFail = False
#EndRegion State

#Region Lifecycle
;~ Description: Prepares the pathfinder once per run.
Func Pathfinder_Init()
	$g_iPathStatus = $ePATH_IDLE
	$g_iPathJob = $ePATHJOB_NONE
	$g_sPathLastError = ""

	If $g_bSimulationMode Then
		$g_bPathInitialised = True
		Return True
	EndIf

	; INTEGRATION POINT: load/attach the pathfinder here if it needs it.
	$g_bPathInitialised = True
	Return True
EndFunc   ;==>Pathfinder_Init

;~ Description: False when the pathfinder cannot be used, so the controller can
;~              fail an attempt instead of hanging.
Func Pathfinder_IsAvailable()
	If $g_bSimulationMode Then Return True

	; INTEGRATION POINT: report whether the pathfinder is loaded and usable.
	Return $g_bPathInitialised
EndFunc   ;==>Pathfinder_IsAvailable
#EndRegion Lifecycle

#Region Jobs
;~ Description: Starts travelling to an outpost. Returns True when the job was
;~              accepted; the controller then polls Pathfinder_Step().
Func Pathfinder_BeginTravel($iOutpostId, $sOutpostName)
	Pathfinder_BeginJob($ePATHJOB_TRAVEL, "Travelling to " & $sOutpostName, $iOutpostId, True, $SIM_TRAVEL_MS)

	If $g_bSimulationMode Then Return True

	; --- INTEGRATION POINT -------------------------------------------------
	; Ask the pathfinder (or the API) to travel to $iOutpostId, for example
	; RndTravel($iOutpostId) from GwAu3_AddOns.au3. Do not wait for arrival
	; here - arrival is detected in Pathfinder_Step().
	; -----------------------------------------------------------------------

	Pathfinder_FailJob("Travel is not wired up yet (Pathfinder_BeginTravel).")
	Return False
EndFunc   ;==>Pathfinder_BeginTravel

;~ Description: Starts walking out of the current outpost into the zone.
Func Pathfinder_BeginExitOutpost($iMapId, $sMapName, $sRoute)
	Pathfinder_BeginJob($ePATHJOB_EXIT, "Leaving " & $sMapName & " outpost", $iMapId, False, $SIM_EXIT_OUTPOST_MS)

	If $g_bSimulationMode Then Return True

	; --- INTEGRATION POINT -------------------------------------------------
	; Ask the pathfinder to walk to the zone entrance for $sRoute / $iMapId.
	; -----------------------------------------------------------------------

	Pathfinder_FailJob("Leaving the outpost is not wired up yet (Pathfinder_BeginExitOutpost).")
	Return False
EndFunc   ;==>Pathfinder_BeginExitOutpost

;~ Description: Starts running a zone's vanquish route.
Func Pathfinder_BeginRoute($sRoute, $sMapName)
	Pathfinder_BeginJob($ePATHJOB_ROUTE, "Running the " & $sMapName & " route", 0, False, $SIM_ZONE_MS)

	If $g_bSimulationMode Then Return True

	; --- INTEGRATION POINT -------------------------------------------------
	; Hand $sRoute to the pathfinder. Pathfinder_ResolveRoute() below turns the
	; route name into whatever your data actually is (a waypoint array from a
	; function of that name, or the name itself as a pathfinder route id).
	; -----------------------------------------------------------------------

	Pathfinder_FailJob("Zone routing is not wired up yet (Pathfinder_BeginRoute).")
	Return False
EndFunc   ;==>Pathfinder_BeginRoute

;~ Description: Moves the current job on and reports where it is up to. Must
;~              always return quickly.
Func Pathfinder_Step()
	If $g_iPathStatus <> $ePATH_RUNNING Then Return $g_iPathStatus

	If $g_bSimulationMode Then Return PathfinderSim_Step()

	; --- INTEGRATION POINT -------------------------------------------------
	; One slice of pathfinder work, then report:
	;   Return $ePATH_RUNNING   still going
	;   Return $ePATH_COMPLETE  arrived / route finished
	;   Return Pathfinder_FailJob("reason")  gave up
	;
	; Arrival for a travel job is best confirmed with the game adapter, eg
	;   If GW_IsInOutpost() And GW_GetCurrentMapId() = $g_iPathTargetMapId Then
	;       Return Pathfinder_CompleteJob()
	;   EndIf
	; -----------------------------------------------------------------------

	Return Pathfinder_FailJob("Pathfinder_Step() is not wired up yet.")
EndFunc   ;==>Pathfinder_Step

;~ Description: Stops the pathfinder. Called on failure, timeout and stop.
Func Pathfinder_Abort()
	If $g_iPathJob <> $ePATHJOB_NONE Then Log_Info("Pathfinder aborted: " & $g_sPathDescription)

	$g_iPathStatus = $ePATH_IDLE
	$g_iPathJob = $ePATHJOB_NONE
	$g_sPathDescription = ""
	$g_hSimPathTimer = 0

	If $g_bSimulationMode Then Return True

	; INTEGRATION POINT: tell the pathfinder to stop moving the character.
	Return True
EndFunc   ;==>Pathfinder_Abort
#EndRegion Jobs

#Region Queries
Func Pathfinder_GetStatus()
	Return $g_iPathStatus
EndFunc   ;==>Pathfinder_GetStatus

Func Pathfinder_GetJob()
	Return $g_iPathJob
EndFunc   ;==>Pathfinder_GetJob

;~ Description: Short "what is it doing" text for the GUI/log.
Func Pathfinder_GetProgressText()
	If $g_iPathStatus <> $ePATH_RUNNING Then Return $g_sPathDescription

	Local $iPercent = Pathfinder_GetProgressPercent()
	If $iPercent < 0 Then Return $g_sPathDescription
	Return $g_sPathDescription & " (" & $iPercent & "%)"
EndFunc   ;==>Pathfinder_GetProgressText

;~ Description: Progress through the current job, or -1 when unknown.
Func Pathfinder_GetProgressPercent()
	If $g_bSimulationMode Then
		If $g_hSimPathTimer = 0 Or $g_iSimPathDurationMs <= 0 Then Return -1
		Local $iPercent = Int((TimerDiff($g_hSimPathTimer) / $g_iSimPathDurationMs) * 100)
		Return ($iPercent > 100) ? 100 : $iPercent
	EndIf

	; INTEGRATION POINT (optional): waypoint index / total waypoints.
	Return -1
EndFunc   ;==>Pathfinder_GetProgressPercent

Func Pathfinder_GetLastError()
	Return $g_sPathLastError
EndFunc   ;==>Pathfinder_GetLastError

;~ Description: Turns a route name from Maps.au3 into route data.
;~              If a function with that name exists it is called and its return
;~              value used (handy for "Func Route_RegentValley()" waypoint
;~              arrays). Otherwise the name is passed through unchanged for a
;~              pathfinder that works from route ids.
Func Pathfinder_ResolveRoute($sRoute)
	If $sRoute = "" Then Return SetError(1, 0, "")

	Local $vRoute = Call($sRoute)
	If @error = 0xDEAD And @extended = 0xBEEF Then Return $sRoute

	Return $vRoute
EndFunc   ;==>Pathfinder_ResolveRoute
#EndRegion Queries

#Region Internal
;~ Description: Common bookkeeping when any job starts.
Func Pathfinder_BeginJob($iJobType, $sDescription, $iTargetMapId, $bTargetIsOutpost, $iSimDurationMs)
	$g_iPathJob = $iJobType
	$g_iPathStatus = $ePATH_RUNNING
	$g_sPathDescription = $sDescription
	$g_sPathLastError = ""
	$g_iPathTargetMapId = $iTargetMapId
	$g_bPathTargetIsOutpost = $bTargetIsOutpost

	$g_hSimPathTimer = TimerInit()
	$g_iSimPathDurationMs = $iSimDurationMs
	$g_bSimPathWillFail = ($g_bSimulationMode And Random(1, 100, 1) <= $SIM_PATH_FAIL_PERCENT)
EndFunc   ;==>Pathfinder_BeginJob

Func Pathfinder_CompleteJob()
	$g_iPathStatus = $ePATH_COMPLETE
	Return $ePATH_COMPLETE
EndFunc   ;==>Pathfinder_CompleteJob

;~ Description: Records why a job failed and returns the failed status, so call
;~              sites can do "Return Pathfinder_FailJob(...)".
Func Pathfinder_FailJob($sReason)
	$g_sPathLastError = $sReason
	$g_iPathStatus = $ePATH_FAILED
	Return $ePATH_FAILED
EndFunc   ;==>Pathfinder_FailJob
#EndRegion Internal

#Region Simulation
;~ Description: Simulated pathfinder: jobs take a while, sometimes fail, and
;~              move the simulated character when they finish.
Func PathfinderSim_Step()
	If $g_hSimPathTimer = 0 Then Return Pathfinder_FailJob("Simulated pathfinder had no job.")

	Local $iElapsed = TimerDiff($g_hSimPathTimer)

	; A simulated failure happens part way through, like a real one would.
	If $g_bSimPathWillFail And $iElapsed > ($g_iSimPathDurationMs / 2) Then
		Return Pathfinder_FailJob("Simulated pathfinder failure during: " & $g_sPathDescription)
	EndIf

	If $iElapsed < $g_iSimPathDurationMs Then Return $ePATH_RUNNING

	Switch $g_iPathJob
		Case $ePATHJOB_TRAVEL
			GW_SimSetLocation($g_iPathTargetMapId, True)
		Case $ePATHJOB_EXIT
			GW_SimSetLocation($g_iPathTargetMapId, False)
	EndSwitch

	Return Pathfinder_CompleteJob()
EndFunc   ;==>PathfinderSim_Step
#EndRegion Simulation
