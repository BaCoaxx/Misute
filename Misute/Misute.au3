#RequireAdmin
#include "../../API/_GwAu3.au3"
#include "GwAu3_AddOns.au3"
#include "Zones.au3"

#Region Declarations

; =======================
; Globals
; =======================

Global Const $doLoadLoggedChars = True
Opt("GUIOnEventMode", 1)
Opt("GUICloseOnESC", False)
Opt("ExpandVarStrings", 1)

Global $ProcessID = ""
Global $g_b_DebugMode = False
Global Const $BotTitle = "Misute"
Global $BotRunning = False
Global $IsRunning = False
Global $Bot_Core_Initialized = False
Global $g_bMapsScanned = False
Global $Zones_To_Run[0]
Global $g_aRunPlanZoneIndexes[0]


$g_bAutoStart = False  ; Flag for auto-start
$g_s_MainCharName  = ""

; =======================
; Logging
; =======================

Global Const $g_s_LogFile = @ScriptDir & "\console_log.txt"
FileDelete($g_s_LogFile)
OnAutoItExitRegister("_OnExitLog")

#EndRegion Declaration

; =======================
; Command line arguments
; =======================

For $i = 1 To $CmdLine[0]
    If $CmdLine[$i] = "-character" And $i < $CmdLine[0] Then
        $g_s_MainCharName = $CmdLine[$i + 1]
        $g_bAutoStart = True
        ExitLoop
    EndIf
Next

#include "GUI.au3"

; =======================
; Startup info
; =======================

LogInfo("Based on GWA2")
LogInfo("GWA2 - Created by: " & $GC_S_GWA2_CREATOR)
LogInfo("GWA2 - Build date: " & $GC_S_GWA2_BUILD_DATE & @CRLF)
LogInfo("GwAu3 - Created by: " & $GC_S_UPDATOR)
LogInfo("GwAu3 - Build date: " & $GC_S_BUILD_DATE)
LogInfo("GwAu3 - Version: " & $GC_S_VERSION)
LogInfo("GwAu3 - Last Update: " & $GC_S_LAST_UPDATE & @CRLF)
Core_AutoStart()
RunAutoStartWorkflow()

While True
    If $Bot_Core_Initialized And $IsRunning Then
        Main()
    Else
        Sleep(250)
    EndIf
WEnd

; =======================
; Functions
; =======================

Func Main()
    ExecuteRunPlan()
EndFunc

Func SetRunningState($bRunning)
    $IsRunning = $bRunning
    $BotRunning = $bRunning
EndFunc

Func ScanKnownZones()
    Local $sReason = ""
    Local $iAvailableCount = 0

    LogStatus("Scanning map availability for " & ZoneRegistry_Count() & " zone(s).")
    For $i = 0 To ZoneRegistry_Count() - 1
        Local $iScanState = ZoneRegistry_DetectScanState($i, $sReason)
        ZoneRegistry_SetScanState($i, $iScanState)

        Switch $iScanState
            Case $ZONE_SCAN_AVAILABLE
                $iAvailableCount += 1
                LogInfo(ZoneRegistry_GetValue($i, $ZONE_REGISTRY_DISPLAY_NAME) & ": available")
            Case $ZONE_SCAN_VANQUISHED
                LogStatus(ZoneRegistry_GetValue($i, $ZONE_REGISTRY_DISPLAY_NAME) & ": " & $sReason)
            Case Else
                LogWarn(ZoneRegistry_GetValue($i, $ZONE_REGISTRY_DISPLAY_NAME) & ": " & $sReason)
        EndSwitch
    Next

    $g_bMapsScanned = True
    LogStatus("Scan complete. " & $iAvailableCount & " zone(s) available to run.")
    Return True
EndFunc

Func BuildRunPlan(ByRef $aSelectedZones)
    ReDim $Zones_To_Run[UBound($aSelectedZones)]
    ReDim $g_aRunPlanZoneIndexes[0]

    Local $iResolvedCount = 0
    For $i = 0 To UBound($aSelectedZones) - 1
        $Zones_To_Run[$i] = $aSelectedZones[$i]

        Local $sZoneKey = NormalizeZoneKey($aSelectedZones[$i])
        Local $iZoneIndex = ZoneRegistry_FindIndexByKey($sZoneKey)
        LogInfo("Selected zone: " & $aSelectedZones[$i] & " -> " & $sZoneKey)

        If $iZoneIndex = -1 Then
            LogWarn("No pathing map associated with " & $aSelectedZones[$i] & ". Skipping.")
            ContinueLoop
        EndIf

        Local $aCoords
        If Not ZoneRegistry_CopyPathArray($iZoneIndex, $aCoords) Then
            LogWarn("Zone registry entry " & $sZoneKey & " does not resolve to a pathing array. Skipping.")
            ContinueLoop
        EndIf

        ReDim $g_aRunPlanZoneIndexes[$iResolvedCount + 1]
        $g_aRunPlanZoneIndexes[$iResolvedCount] = $iZoneIndex
        $iResolvedCount += 1

        LogInfo("Resolved " & $sZoneKey & " -> " & ZoneRegistry_GetValue($iZoneIndex, $ZONE_REGISTRY_PATH_ARRAY))
    Next

    If $iResolvedCount = 0 Then
        LogWarn("No valid zones were resolved from the current selection.")
        Return False
    EndIf

    ReDim $g_aRunPlanZoneIndexes[$iResolvedCount]
    LogStatus("Run plan ready with " & $iResolvedCount & " zone(s).")
    Return True
EndFunc

Func ExecuteRunPlan()
    If UBound($g_aRunPlanZoneIndexes) = 0 Then
        ResetStart("No queued zones to run.")
        Return
    EndIf

    If Not IsFunc("VanqArea") Then
        ResetStart("VanqArea() is unavailable; unable to execute the selected run plan.")
        Return
    EndIf

    LogStatus("Starting vanquish plan.")
    For $i = 0 To UBound($g_aRunPlanZoneIndexes) - 1
        If Not $IsRunning Then ExitLoop

        Local $iZoneIndex = $g_aRunPlanZoneIndexes[$i]
        Local $sDisplayName = ZoneRegistry_GetValue($iZoneIndex, $ZONE_REGISTRY_DISPLAY_NAME)
        Local $sStartMapConstant = ZoneRegistry_GetValue($iZoneIndex, $ZONE_REGISTRY_START_MAP)
        Local $iStartMapId = ZoneRegistry_ResolveMapId($sStartMapConstant)
        Local $sScanReason = ""

        LogStatus("Preparing zone " & ($i + 1) & "/" & UBound($g_aRunPlanZoneIndexes) & ": " & $sDisplayName)

        Local $iScanState = ZoneRegistry_DetectScanState($iZoneIndex, $sScanReason)
        ZoneRegistry_SetScanState($iZoneIndex, $iScanState)
        If $iScanState <> $ZONE_SCAN_AVAILABLE Then
            LogWarn($sDisplayName & " is no longer available: " & $sScanReason & ". Skipping.")
            ContinueLoop
        EndIf

        If $iStartMapId <= 0 Then
            LogWarn("Starting outpost not found for " & $sDisplayName & ". Skipping.")
            ContinueLoop
        EndIf

        If Not IsFunc("Map_IsMapUnlocked") Then
            LogWarn("Map_IsMapUnlocked() is unavailable, unable to verify " & $sDisplayName & ". Skipping.")
            ContinueLoop
        EndIf

        If Not Map_IsMapUnlocked($iStartMapId) Then
            LogWarn("Starting outpost not found/unlocked, unable to vanquish " & $sDisplayName)
            ContinueLoop
        EndIf

        Local $aCurrentZoneCoords
        If Not ZoneRegistry_CopyPathArray($iZoneIndex, $aCurrentZoneCoords) Then
            LogWarn("Unable to resolve pathing array for " & $sDisplayName & ". Skipping.")
            ContinueLoop
        EndIf

        LogInfo("Travelling to starting outpost for " & $sDisplayName)
        RndTravel($iStartMapId)
        Sleep(3000)
        LogStatus("Starting zone: " & $sDisplayName)
        VanqArea($aCurrentZoneCoords)

        $iScanState = ZoneRegistry_DetectScanState($iZoneIndex, $sScanReason)
        ZoneRegistry_SetScanState($iZoneIndex, $iScanState)
        LogStatus("Finished zone: " & $sDisplayName)
    Next

    If $IsRunning Then
        ResetStart("Run plan complete.")
    Else
        ResetStart("Run plan paused.")
    EndIf
EndFunc

Func RunAutoStartWorkflow()
    If Not $g_bAutoStart Then Return

    LogStatus("Auto-start requested, connecting and scanning maps.")
    If Not InitializeBot() Then Return

    WinSetTitle($MainGui, "", player_GetCharname())
    GUICtrlSetState($GUINameCombo, $GUI_DISABLE)
    GUICtrlSetState($GUIToggleRendering, $GUI_ENABLE)
    SetWorkflowState($WORKFLOW_STATE_CONNECTED)

    If ScanKnownZones() Then
        RefreshZoneSelectionLists(True)
        SetWorkflowState($WORKFLOW_STATE_SCANNED)
        LogStatus("Auto-start setup complete. Select zones and press Start.")
    EndIf
EndFunc

; =======================
; Crash Logging
; =======================

Func _OnExitLog()
    Local $code = @exitCode
    Local $msg = "Script terminated. ExitCode=" & $code
    Local $hFile = FileOpen($g_s_LogFile, $FO_APPEND)
    If $hFile <> -1 Then
        FileWrite($hFile, _
            @CRLF & "[" & @HOUR & ":" & @MIN & ":" & @SEC & "] [EXIT] " & _
            $msg)
        FileClose($hFile)
    EndIf
EndFunc
