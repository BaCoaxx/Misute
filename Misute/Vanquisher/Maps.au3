#include-once
#include "Config.au3"
#include "Log.au3"
#include "GuildWars.au3"

#cs ----------------------------------------------------------------------------

    Maps.au3

    The map database and the per-map runtime status.

    ADDING A MAP: add one Maps_Register() line to Maps_Load(). That is the only
    place map data lives - the controller never mentions a map by name.

    Each row holds:
        Name          the zone that is being vanquished
        MapID         the explorable area id used by the API (fill these in)
        OutpostName   the outpost the run starts from
        OutpostID     that outpost's map id, used for travelling
        Region        grouping only, shown in the GUI
        Route         the pathfinder route identifier for the zone
        Status        runtime: unknown / pending / active / vanquished / failed
        Attempts      runtime: how many attempts have been started
        LastResult    runtime: short text describing the last outcome

#ce ----------------------------------------------------------------------------

#Region Field layout
Global Const $eMAP_NAME = 0
Global Const $eMAP_MAP_ID = 1
Global Const $eMAP_OUTPOST_NAME = 2
Global Const $eMAP_OUTPOST_ID = 3
Global Const $eMAP_REGION = 4
Global Const $eMAP_ROUTE = 5
Global Const $eMAP_STATUS = 6
Global Const $eMAP_ATTEMPTS = 7
Global Const $eMAP_LAST_RESULT = 8
Global Const $eMAP_FIELDS = 9
#EndRegion Field layout

#Region Status values
Global Const $eMAPSTATUS_UNKNOWN = 0      ; not looked at yet this run
Global Const $eMAPSTATUS_PENDING = 1      ; needs vanquishing
Global Const $eMAPSTATUS_ACTIVE = 2       ; being worked on right now
Global Const $eMAPSTATUS_VANQUISHED = 3   ; confirmed complete
Global Const $eMAPSTATUS_FAILED = 4       ; gave up after $MAX_RETRIES
#EndRegion Status values

#Region Storage
;~ Used when the real map id for a row has not been filled in yet.
Global Const $MAP_ID_UNSET = -1

Global $g_aMaps[0][$eMAP_FIELDS]
#EndRegion Storage

#Region Map list
;~ Description: Builds the map database. Call once at startup.
;~
;~              The map ids below are $MAP_ID_UNSET on purpose: drop in the ids
;~              your API uses (or its map id constants) and the same rows start
;~              driving the real game. Names/outposts are the Tyria set as an
;~              example - extend, trim or replace the list freely.
Func Maps_Load()
	Local $iCount = 0

	;                  Zone name              MapID           Starting outpost       OutpostID       Region     Pathfinder route
	$iCount += Maps_Register("Old Ascalon", $MAP_ID_UNSET, "Ascalon City", $MAP_ID_UNSET, "Ascalon", "Route_OldAscalon")
	$iCount += Maps_Register("Regent Valley", $MAP_ID_UNSET, "Fort Ranik", $MAP_ID_UNSET, "Ascalon", "Route_RegentValley")
	$iCount += Maps_Register("The Breach", $MAP_ID_UNSET, "Sardelac Sanitarium", $MAP_ID_UNSET, "Ascalon", "Route_TheBreach")
	$iCount += Maps_Register("Ascalon Foothills", $MAP_ID_UNSET, "Sardelac Sanitarium", $MAP_ID_UNSET, "Ascalon", "Route_AscalonFoothills")
	$iCount += Maps_Register("Diessa Lowlands", $MAP_ID_UNSET, "Piken Square", $MAP_ID_UNSET, "Ascalon", "Route_DiessaLowlands")
	$iCount += Maps_Register("Eastern Frontier", $MAP_ID_UNSET, "Piken Square", $MAP_ID_UNSET, "Ascalon", "Route_EasternFrontier")
	$iCount += Maps_Register("Dragon's Gullet", $MAP_ID_UNSET, "Grendich Courthouse", $MAP_ID_UNSET, "Ascalon", "Route_DragonsGullet")
	$iCount += Maps_Register("Pockmark Flats", $MAP_ID_UNSET, "Grendich Courthouse", $MAP_ID_UNSET, "Ascalon", "Route_PockmarkFlats")
	$iCount += Maps_Register("North Kryta Province", $MAP_ID_UNSET, "Lion's Arch", $MAP_ID_UNSET, "Kryta", "Route_NorthKrytaProvince")
	$iCount += Maps_Register("Majesty's Rest", $MAP_ID_UNSET, "Lion's Arch", $MAP_ID_UNSET, "Kryta", "Route_MajestysRest")
	$iCount += Maps_Register("Watchtower Coast", $MAP_ID_UNSET, "Lion's Arch", $MAP_ID_UNSET, "Kryta", "Route_WatchtowerCoast")
	$iCount += Maps_Register("Nebo Terrace", $MAP_ID_UNSET, "Bergen Hot Springs", $MAP_ID_UNSET, "Kryta", "Route_NeboTerrace")

	Log_Info($iCount & " maps loaded from the map database.")
	Return $iCount
EndFunc   ;==>Maps_Load

;~ Description: Adds one map to the database. Returns 1 so Maps_Load() can count.
Func Maps_Register($sName, $iMapId, $sOutpostName, $iOutpostId, $sRegion, $sRoute)
	Local $iIndex = UBound($g_aMaps)
	ReDim $g_aMaps[$iIndex + 1][$eMAP_FIELDS]

	$g_aMaps[$iIndex][$eMAP_NAME] = $sName
	$g_aMaps[$iIndex][$eMAP_MAP_ID] = $iMapId
	$g_aMaps[$iIndex][$eMAP_OUTPOST_NAME] = $sOutpostName
	$g_aMaps[$iIndex][$eMAP_OUTPOST_ID] = $iOutpostId
	$g_aMaps[$iIndex][$eMAP_REGION] = $sRegion
	$g_aMaps[$iIndex][$eMAP_ROUTE] = $sRoute
	$g_aMaps[$iIndex][$eMAP_STATUS] = $eMAPSTATUS_UNKNOWN
	$g_aMaps[$iIndex][$eMAP_ATTEMPTS] = 0
	$g_aMaps[$iIndex][$eMAP_LAST_RESULT] = ""

	Return 1
EndFunc   ;==>Maps_Register
#EndRegion Map list

#Region Accessors
Func Maps_Count()
	Return UBound($g_aMaps)
EndFunc   ;==>Maps_Count

Func Maps_IsValidIndex($iIndex)
	Return ($iIndex >= 0 And $iIndex < UBound($g_aMaps))
EndFunc   ;==>Maps_IsValidIndex

Func Maps_GetField($iIndex, $iField)
	If Not Maps_IsValidIndex($iIndex) Then Return SetError(1, 0, "")
	Return $g_aMaps[$iIndex][$iField]
EndFunc   ;==>Maps_GetField

Func Maps_GetName($iIndex)
	Return Maps_GetField($iIndex, $eMAP_NAME)
EndFunc   ;==>Maps_GetName

Func Maps_GetMapId($iIndex)
	Return Maps_GetField($iIndex, $eMAP_MAP_ID)
EndFunc   ;==>Maps_GetMapId

Func Maps_GetOutpostName($iIndex)
	Return Maps_GetField($iIndex, $eMAP_OUTPOST_NAME)
EndFunc   ;==>Maps_GetOutpostName

Func Maps_GetOutpostId($iIndex)
	Return Maps_GetField($iIndex, $eMAP_OUTPOST_ID)
EndFunc   ;==>Maps_GetOutpostId

Func Maps_GetRegion($iIndex)
	Return Maps_GetField($iIndex, $eMAP_REGION)
EndFunc   ;==>Maps_GetRegion

Func Maps_GetRoute($iIndex)
	Return Maps_GetField($iIndex, $eMAP_ROUTE)
EndFunc   ;==>Maps_GetRoute

Func Maps_GetStatus($iIndex)
	If Not Maps_IsValidIndex($iIndex) Then Return SetError(1, 0, $eMAPSTATUS_UNKNOWN)
	Return $g_aMaps[$iIndex][$eMAP_STATUS]
EndFunc   ;==>Maps_GetStatus

Func Maps_SetStatus($iIndex, $iStatus)
	If Not Maps_IsValidIndex($iIndex) Then Return SetError(1, 0, False)
	$g_aMaps[$iIndex][$eMAP_STATUS] = $iStatus
	Return True
EndFunc   ;==>Maps_SetStatus

Func Maps_GetAttempts($iIndex)
	If Not Maps_IsValidIndex($iIndex) Then Return SetError(1, 0, 0)
	Return $g_aMaps[$iIndex][$eMAP_ATTEMPTS]
EndFunc   ;==>Maps_GetAttempts

;~ Description: Counts one more attempt at a map and returns the new total.
Func Maps_IncrementAttempts($iIndex)
	If Not Maps_IsValidIndex($iIndex) Then Return SetError(1, 0, 0)
	$g_aMaps[$iIndex][$eMAP_ATTEMPTS] += 1
	Return $g_aMaps[$iIndex][$eMAP_ATTEMPTS]
EndFunc   ;==>Maps_IncrementAttempts

Func Maps_GetLastResult($iIndex)
	Return Maps_GetField($iIndex, $eMAP_LAST_RESULT)
EndFunc   ;==>Maps_GetLastResult

Func Maps_SetLastResult($iIndex, $sText)
	If Not Maps_IsValidIndex($iIndex) Then Return SetError(1, 0, False)
	$g_aMaps[$iIndex][$eMAP_LAST_RESULT] = $sText
	Return True
EndFunc   ;==>Maps_SetLastResult

Func Maps_StatusText($iStatus)
	Switch $iStatus
		Case $eMAPSTATUS_PENDING
			Return "Pending"
		Case $eMAPSTATUS_ACTIVE
			Return "In progress"
		Case $eMAPSTATUS_VANQUISHED
			Return "Vanquished"
		Case $eMAPSTATUS_FAILED
			Return "Failed"
		Case Else
			Return "Unknown"
	EndSwitch
EndFunc   ;==>Maps_StatusText

Func Maps_FindByName($sName)
	For $i = 0 To UBound($g_aMaps) - 1
		If $g_aMaps[$i][$eMAP_NAME] = $sName Then Return $i
	Next
	Return -1
EndFunc   ;==>Maps_FindByName

Func Maps_CountByStatus($iStatus)
	Local $iCount = 0
	For $i = 0 To UBound($g_aMaps) - 1
		If $g_aMaps[$i][$eMAP_STATUS] = $iStatus Then $iCount += 1
	Next
	Return $iCount
EndFunc   ;==>Maps_CountByStatus

;~ Description: Clears the per-run fields. Called when a run starts so a second
;~              run in the same session is not affected by the first.
Func Maps_ResetRuntimeState()
	For $i = 0 To UBound($g_aMaps) - 1
		$g_aMaps[$i][$eMAP_STATUS] = $eMAPSTATUS_UNKNOWN
		$g_aMaps[$i][$eMAP_ATTEMPTS] = 0
		$g_aMaps[$i][$eMAP_LAST_RESULT] = ""
	Next
EndFunc   ;==>Maps_ResetRuntimeState
#EndRegion Accessors

#Region Vanquished status
;~ Description: Asks the game whether one map is already vanquished and records
;~              the answer as its status. This is the only place Maps.au3 talks
;~              to the game adapter.
Func Maps_RefreshVanquishedStatus($iIndex)
	If Not Maps_IsValidIndex($iIndex) Then Return SetError(1, 0, False)

	Local $bVanquished = GW_IsMapVanquished(Maps_GetMapId($iIndex), Maps_GetName($iIndex))
	If @error Then
		; Unknown status is treated as "needs doing" - better to walk a finished
		; zone than to silently skip one that is not done.
		Log_Warn("Could not read vanquished status for " & Maps_GetName($iIndex) & " - assuming it still needs doing.")
		$g_aMaps[$iIndex][$eMAP_STATUS] = $eMAPSTATUS_PENDING
		Return False
	EndIf

	$g_aMaps[$iIndex][$eMAP_STATUS] = ($bVanquished) ? $eMAPSTATUS_VANQUISHED : $eMAPSTATUS_PENDING
	Return $bVanquished
EndFunc   ;==>Maps_RefreshVanquishedStatus

;~ Description: Every map that still needs vanquishing, as an array of indices
;~              into the map database. This is what the work queue is built from.
Func GetUnvanquishedMaps()
	Local $aResult[UBound($g_aMaps)]
	Local $iFound = 0

	For $i = 0 To UBound($g_aMaps) - 1
		Switch $g_aMaps[$i][$eMAP_STATUS]
			Case $eMAPSTATUS_PENDING, $eMAPSTATUS_ACTIVE, $eMAPSTATUS_UNKNOWN
				$aResult[$iFound] = $i
				$iFound += 1
		EndSwitch
	Next

	ReDim $aResult[$iFound]
	Return $aResult
EndFunc   ;==>GetUnvanquishedMaps
#EndRegion Vanquished status
