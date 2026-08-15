#include-once
#include "Config.au3"
#include "Log.au3"
#include "BotState.au3"

#cs ----------------------------------------------------------------------------

    GuildWars.au3

    The game adapter: process connection and game-state questions.

    Everything the bot wants to know about the game goes through a function in
    this file, so the controller contains no API calls at all. Each function is
    either

        * simulated (while $g_bSimulationMode is True), or
        * marked with an "INTEGRATION POINT" comment where your real code goes.

    ------------------------------------------------------------------------
    WIRING UP THE REAL CLIENT
    ------------------------------------------------------------------------
    1. Uncomment the two includes below (the paths match Misute.au3, one folder
       deeper).
    2. Paste your existing connection code into Initialise().
    3. Fill in the other INTEGRATION POINT functions.
    4. Set $g_bSimulationMode = False in Config.au3.

    Nothing else in the project needs to change.

#ce ----------------------------------------------------------------------------

;~ #include "../../../API/_GwAu3.au3"
;~ #include "../GwAu3_AddOns.au3"

#Region Errors
Global Const $eGW_ERR_NOT_IMPLEMENTED = 1   ; integration point still empty
Global Const $eGW_ERR_NOT_CONNECTED = 2     ; asked something before connecting
#EndRegion Errors

#Region Simulation state
Global $g_bSimConnected = False
Global $g_iSimMapId = 0
Global $g_bSimInOutpost = True
Global $g_hSimZoneTimer = 0
Global $g_bSimZoneDoomed = False       ; this attempt will never finish
Global $g_iSimZoneFoes = 0
#EndRegion Simulation state

#Region Connection
;~ Description: Connects to the Guild Wars client and prepares the API.
;~
;~              INTEGRATION POINT - this is the placeholder for the connection
;~              code you already have. It is called once per run, from the
;~              controller's INITIALISING state, and must return quickly:
;~              True on success, or SetError(..., False) on failure.
Func Initialise($sCharacterName = "")
	If $g_bSimulationMode Then
		$g_bSimConnected = True
		$g_iSimMapId = 0
		$g_bSimInOutpost = True
		Return True
	EndIf

	; --- INTEGRATION POINT -------------------------------------------------
	; Your Core_Initialize() code goes here. It typically looks like this:
	;
	;   Local $iResult
	;   If $sCharacterName = "" Then
	;       $iResult = Core_Initialize(ProcessExists("gw.exe"), True)
	;   Else
	;       $iResult = Core_Initialize($sCharacterName, True)
	;   EndIf
	;   If $iResult = 0 Then Return SetError($eGW_ERR_NOT_CONNECTED, 0, False)
	;   Return True
	; -----------------------------------------------------------------------

	Return SetError($eGW_ERR_NOT_IMPLEMENTED, 0, False)
EndFunc   ;==>Initialise

;~ Description: Released on shutdown. Safe to call when never connected.
Func GW_Shutdown()
	If $g_bSimulationMode Then
		$g_bSimConnected = False
		Return True
	EndIf

	; INTEGRATION POINT: any teardown your API needs (usually nothing).
	Return True
EndFunc   ;==>GW_Shutdown

Func GW_IsConnected()
	If $g_bSimulationMode Then Return $g_bSimConnected

	; INTEGRATION POINT: return whether the API is attached to a client.
	Return False
EndFunc   ;==>GW_IsConnected

;~ Description: Name of the character the bot is driving, for the window title.
Func GW_GetCharacterName()
	If $g_bSimulationMode Then
		Return ($g_sTargetCharacter <> "") ? $g_sTargetCharacter : "Simulated Hero"
	EndIf

	; INTEGRATION POINT: eg Return player_GetCharname()
	Return ""
EndFunc   ;==>GW_GetCharacterName

;~ Description: Pipe separated character names for the GUI combo box, in the
;~              format GUICtrlSetData() expects.
Func GW_GetLoggedCharNames()
	If $g_bSimulationMode Then Return "Simulated Hero|Test Dummy"

	; INTEGRATION POINT: eg Return Scanner_GetLoggedCharNames()
	Return ""
EndFunc   ;==>GW_GetLoggedCharNames

;~ Description: Turns the client's rendering on/off to save CPU while botting.
Func GW_SetRendering($bEnabled)
	If $g_bSimulationMode Then
		Log_Info("Rendering would now be " & (($bEnabled) ? "enabled" : "disabled") & ".")
		Return True
	EndIf

	; INTEGRATION POINT: eg Ui_ToggleRendering()
	Return SetError($eGW_ERR_NOT_IMPLEMENTED, 0, False)
EndFunc   ;==>GW_SetRendering
#EndRegion Connection

#Region Location
Func GW_GetCurrentMapId()
	If $g_bSimulationMode Then Return $g_iSimMapId

	; INTEGRATION POINT: eg Return Map_GetMapID()
	Return SetError($eGW_ERR_NOT_IMPLEMENTED, 0, 0)
EndFunc   ;==>GW_GetCurrentMapId

;~ Description: True when the character is standing in a town or outpost.
Func GW_IsInOutpost()
	If $g_bSimulationMode Then Return $g_bSimInOutpost

	; INTEGRATION POINT: eg Return Map_GetInstanceInfo("Type") = 1
	Return SetError($eGW_ERR_NOT_IMPLEMENTED, 0, False)
EndFunc   ;==>GW_IsInOutpost

;~ Description: True when the character is in an explorable area.
Func GW_IsInExplorable()
	If $g_bSimulationMode Then Return Not $g_bSimInOutpost

	; INTEGRATION POINT: eg Return Map_GetInstanceInfo("Type") = 2
	Return SetError($eGW_ERR_NOT_IMPLEMENTED, 0, False)
EndFunc   ;==>GW_IsInExplorable

;~ Description: True when the map is finished loading and the bot may act.
Func GW_IsMapLoaded()
	If $g_bSimulationMode Then Return True

	; INTEGRATION POINT: eg Return Map_GetIsMapLoaded()
	Return SetError($eGW_ERR_NOT_IMPLEMENTED, 0, False)
EndFunc   ;==>GW_IsMapLoaded
#EndRegion Location

#Region Vanquish status
;~ Description: Has this map already been vanquished by this character?
;~              Used once per map during the "checking vanquished maps" phase.
;~
;~              INTEGRATION POINT - read the vanquished flag from the character's
;~              map completion data. Return True/False, or SetError() when the
;~              answer cannot be read (the caller then assumes "not done").
Func GW_IsMapVanquished($iMapId, $sMapName = "")
	If $g_bSimulationMode Then Return GWSim_IsMapVanquished($sMapName)

	; --- INTEGRATION POINT -------------------------------------------------
	; Your own status check goes here, for example a lookup of the map's
	; completion flags for the logged in character.
	; -----------------------------------------------------------------------

	Return SetError($eGW_ERR_NOT_IMPLEMENTED, 0, False)
EndFunc   ;==>GW_IsMapVanquished

;~ Description: Marks the start of an attempt so the adapter can reset any
;~              per-attempt bookkeeping (kill counters, simulated progress...).
Func GW_BeginZoneAttempt($iMapId, $sMapName = "")
	If $g_bSimulationMode Then
		GWSim_BeginZone($sMapName)
		Return True
	EndIf

	; INTEGRATION POINT (optional): reset any counters your checks rely on.
	Return True
EndFunc   ;==>GW_BeginZoneAttempt

;~ Description: Is the zone the character is standing in vanquished right now?
;~              Polled by the controller during and after the route.
Func GW_IsCurrentZoneVanquished()
	If $g_bSimulationMode Then Return (GWSim_GetFoesRemaining() <= 0)

	; --- INTEGRATION POINT -------------------------------------------------
	; Typically: the zone's remaining-foe counter has reached zero while in an
	; explorable area, or the client has shown the vanquish message.
	; -----------------------------------------------------------------------

	Return SetError($eGW_ERR_NOT_IMPLEMENTED, 0, False)
EndFunc   ;==>GW_IsCurrentZoneVanquished

;~ Description: Foes left in the current zone, used for progress logging only.
;~              Return -1 when the number is not available.
Func GW_GetFoesRemaining()
	If $g_bSimulationMode Then Return GWSim_GetFoesRemaining()

	; INTEGRATION POINT: eg the "foes to kill" value your API exposes.
	Return -1
EndFunc   ;==>GW_GetFoesRemaining
#EndRegion Vanquish status

#Region Party and recovery
Func GW_IsPartyDead()
	If $g_bSimulationMode Then Return False

	; INTEGRATION POINT: eg Return GetPartyDead()
	Return False
EndFunc   ;==>GW_IsPartyDead

;~ Description: Resigns the current instance, the usual way out of a bad state.
Func GW_Resign()
	If $g_bSimulationMode Then
		Log_Info("Resigning (simulated).")
		Return True
	EndIf

	; INTEGRATION POINT: eg Resign()
	Return SetError($eGW_ERR_NOT_IMPLEMENTED, 0, False)
EndFunc   ;==>GW_Resign

;~ Description: Gets the party back to an outpost after a failed attempt.
;~              Should return quickly; the controller polls GW_IsInOutpost().
Func GW_ReturnToOutpost()
	If $g_bSimulationMode Then
		$g_bSimInOutpost = True
		$g_hSimZoneTimer = 0
		Return True
	EndIf

	; INTEGRATION POINT: eg resign then travel/return to the nearest outpost.
	Return SetError($eGW_ERR_NOT_IMPLEMENTED, 0, False)
EndFunc   ;==>GW_ReturnToOutpost
#EndRegion Party and recovery

#Region Simulation helpers
;~ These exist so the framework can be run, watched and tested without the game.
;~ They are only ever reached while $g_bSimulationMode is True.

;~ Description: Deterministic "already vanquished?" answer, so repeated runs in
;~              simulation behave consistently.
Func GWSim_IsMapVanquished($sMapName)
	Local $iHash = 0
	For $i = 1 To StringLen($sMapName)
		$iHash = Mod($iHash * 31 + Asc(StringMid($sMapName, $i, 1)), 100)
	Next
	Return ($iHash < $SIM_VANQUISHED_PERCENT)
EndFunc   ;==>GWSim_IsMapVanquished

Func GWSim_BeginZone($sMapName)
	$g_hSimZoneTimer = TimerInit()
	$g_iSimZoneFoes = $SIM_ZONE_FOES
	$g_bSimZoneDoomed = (Random(1, 100, 1) <= $SIM_ZONE_FAIL_PERCENT)

	If $g_bSimZoneDoomed Then
		Log_Info("Simulation: this attempt at " & $sMapName & " will get stuck, so the timeout/retry path runs.")
	EndIf
EndFunc   ;==>GWSim_BeginZone

;~ Description: Simulated foe count, falling off over $SIM_ZONE_MS. A "doomed"
;~              attempt stalls with foes left so the zone timeout fires.
Func GWSim_GetFoesRemaining()
	If $g_hSimZoneTimer = 0 Then Return -1

	Local $fProgress = TimerDiff($g_hSimZoneTimer) / $SIM_ZONE_MS
	If $g_bSimZoneDoomed And $fProgress > 0.75 Then $fProgress = 0.75
	If $fProgress > 1 Then $fProgress = 1

	$g_iSimZoneFoes = Int($SIM_ZONE_FOES * (1 - $fProgress))
	Return $g_iSimZoneFoes
EndFunc   ;==>GWSim_GetFoesRemaining

;~ Description: Called by the simulated pathfinder when it "arrives" somewhere.
Func GW_SimSetLocation($iMapId, $bInOutpost)
	$g_iSimMapId = $iMapId
	$g_bSimInOutpost = $bInOutpost
EndFunc   ;==>GW_SimSetLocation
#EndRegion Simulation helpers
