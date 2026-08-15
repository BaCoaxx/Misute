#include-once
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiEdit.au3>
#include <GuiListView.au3>
#include <GuiRichEdit.au3>
#include <ListViewConstants.au3>
#include <ProgressConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>

#include "Config.au3"
#include "Log.au3"
#include "BotState.au3"
#include "Maps.au3"
#include "BotController.au3"

#cs ----------------------------------------------------------------------------

    GUI.au3

    The display. Built in the same style as the original Misute window: an outer
    group, a character selector, a colour coded rich edit console and the run /
    total time labels, with the vanquish specific panels added around them.

    Two rules keep this replaceable:

        1. Event handlers never do bot work. They call StartBot(), RequestStop()
           or a Bot_* helper and return immediately.
        2. Everything shown here is read from BotState.au3 and Maps.au3. The GUI
           is never told what to display by the controller.

    GUIOnEventMode is used (as in the original), so a click is handled between
    two statements of the main loop. Because the controller is a tick machine,
    the window keeps repainting and the buttons stay responsive while the bot
    runs.

#ce ----------------------------------------------------------------------------

#Region Controls
Global $g_hMainGui = 0
Global $g_hLogEdit = 0

Global $g_idCharacterCombo = 0
Global $g_idStartButton = 0
Global $g_idStopButton = 0
Global $g_idRefreshButton = 0
Global $g_idRenderingCheckbox = 0

Global $g_idStatusValue = 0
Global $g_idZoneValue = 0
Global $g_idOutpostValue = 0
Global $g_idAttemptValue = 0
Global $g_idActivityValue = 0

Global $g_idRunTimeValue = 0
Global $g_idTotalTimeValue = 0
Global $g_idZoneTimeValue = 0
Global $g_idTimeoutValue = 0
Global $g_idModeValue = 0

Global $g_idProgressBar = 0
Global $g_idProgressLabel = 0
Global $g_idRemainingValue = 0
Global $g_idVanquishedValue = 0
Global $g_idFailedValue = 0

Global $g_idMapList = 0
#EndRegion Controls

#Region GUI state
Global $g_iGuiRevision = -1
Global $g_hGuiRefreshTimer = 0
Global $g_iGuiLogLines = 0
Global $g_bGuiLogRebuilding = False
Global $g_bGuiExitRequested = False
Global $g_sGuiMapSignature = ""

Global Const $eLVCOL_MAP = 0
Global Const $eLVCOL_REGION = 1
Global Const $eLVCOL_STATUS = 2
Global Const $eLVCOL_ATTEMPTS = 3
Global Const $eLVCOL_DETAIL = 4
#EndRegion GUI state

#Region Creation
;~ Description: Builds the window and starts showing log output. Call once.
Func GUI_Create()
	$g_hMainGui = GUICreate($VQ_BOT_TITLE & " " & $VQ_BOT_VERSION, 540, 660, -1, -1, -1, _
			BitOR($WS_EX_TOPMOST, $WS_EX_WINDOWEDGE))

	GUICtrlCreateGroup($VQ_BOT_TITLE, 8, 7, 524, 644)

	; --- character selection and the main buttons --------------------------
	GUICtrlCreateGroup("Select Your Character", 16, 24, 250, 49)
	If $g_bLoadLoggedChars Then
		$g_idCharacterCombo = GUICtrlCreateCombo($g_sTargetCharacter, 24, 40, 234, 25, _
				BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
		GUICtrlSetData($g_idCharacterCombo, Bot_GetLoggedCharNames())
	Else
		$g_idCharacterCombo = GUICtrlCreateInput($g_sTargetCharacter, 24, 40, 234, 25)
	EndIf
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	$g_idStartButton = GUICtrlCreateButton("Start", 274, 38, 72, 25)
	GUICtrlSetOnEvent($g_idStartButton, "GUI_OnStart")

	$g_idStopButton = GUICtrlCreateButton("Stop", 350, 38, 72, 25)
	GUICtrlSetOnEvent($g_idStopButton, "GUI_OnStop")

	$g_idRefreshButton = GUICtrlCreateButton("Refresh", 426, 38, 90, 25)
	GUICtrlSetOnEvent($g_idRefreshButton, "GUI_OnRefreshCharacters")

	; --- what the bot is doing ---------------------------------------------
	GUICtrlCreateGroup("Bot Status", 16, 80, 320, 122)
	GUICtrlCreateLabel("Status:", 24, 100, 70, 17)
	$g_idStatusValue = GUICtrlCreateLabel("Idle", 96, 100, 232, 17)
	GUICtrlCreateLabel("Zone:", 24, 118, 70, 17)
	$g_idZoneValue = GUICtrlCreateLabel("-", 96, 118, 232, 17)
	GUICtrlCreateLabel("Outpost:", 24, 136, 70, 17)
	$g_idOutpostValue = GUICtrlCreateLabel("-", 96, 136, 232, 17)
	GUICtrlCreateLabel("Attempt:", 24, 154, 70, 17)
	$g_idAttemptValue = GUICtrlCreateLabel("-", 96, 154, 232, 17)
	GUICtrlCreateLabel("Activity:", 24, 172, 70, 17)
	$g_idActivityValue = GUICtrlCreateLabel("-", 96, 172, 232, 17)
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	; --- timers -------------------------------------------------------------
	GUICtrlCreateGroup("Timers", 344, 80, 172, 122)
	GUICtrlCreateLabel("Run Time:", 352, 100, 62, 17)
	$g_idRunTimeValue = GUICtrlCreateLabel("00:00:00", 420, 100, 88, 17)
	GUICtrlCreateLabel("Total Time:", 352, 118, 62, 17)
	$g_idTotalTimeValue = GUICtrlCreateLabel("00:00:00", 420, 118, 88, 17)
	GUICtrlCreateLabel("Zone Time:", 352, 136, 62, 17)
	$g_idZoneTimeValue = GUICtrlCreateLabel("00:00:00", 420, 136, 88, 17)
	GUICtrlCreateLabel("Timeout in:", 352, 154, 62, 17)
	$g_idTimeoutValue = GUICtrlCreateLabel("--:--:--", 420, 154, 88, 17)
	$g_idModeValue = GUICtrlCreateLabel("", 352, 174, 156, 17)
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	; --- progress through the map list --------------------------------------
	GUICtrlCreateGroup("Progress", 16, 208, 500, 66)
	$g_idProgressBar = GUICtrlCreateProgress(24, 228, 320, 18, $PBS_SMOOTH)
	$g_idProgressLabel = GUICtrlCreateLabel("0 / 0 maps", 352, 230, 156, 17)
	$g_idRemainingValue = GUICtrlCreateLabel("Remaining: 0", 24, 250, 140, 17)
	$g_idVanquishedValue = GUICtrlCreateLabel("Vanquished: 0", 170, 250, 140, 17)
	$g_idFailedValue = GUICtrlCreateLabel("Failed: 0", 316, 250, 140, 17)
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	; --- the map list -------------------------------------------------------
	GUICtrlCreateGroup("Maps", 16, 280, 500, 158)
	$g_idMapList = GUICtrlCreateListView("Map|Region|Status|Att.|Detail", 24, 296, 484, 134, -1, _
			BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES))
	_GUICtrlListView_SetColumnWidth($g_idMapList, $eLVCOL_MAP, 140)
	_GUICtrlListView_SetColumnWidth($g_idMapList, $eLVCOL_REGION, 70)
	_GUICtrlListView_SetColumnWidth($g_idMapList, $eLVCOL_STATUS, 80)
	_GUICtrlListView_SetColumnWidth($g_idMapList, $eLVCOL_ATTEMPTS, 40)
	_GUICtrlListView_SetColumnWidth($g_idMapList, $eLVCOL_DETAIL, 130)
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	; --- log console (same colour coded rich edit as the original) ----------
	GUICtrlCreateGroup("Activity Log", 16, 444, 500, 148)
	$g_hLogEdit = _GUICtrlRichEdit_Create($g_hMainGui, "", 24, 460, 484, 124, _
			BitOR($ES_AUTOVSCROLL, $ES_MULTILINE, $WS_VSCROLL, $ES_READONLY), $WS_EX_STATICEDGE)
	_GUICtrlRichEdit_SetBkColor($g_hLogEdit, 0xFFFFFF)
	GUICtrlCreateGroup("", -99, -99, 1, 1)

	; --- footer -------------------------------------------------------------
	$g_idRenderingCheckbox = GUICtrlCreateCheckbox("Rendering?", 24, 600, 100, 17)
	GUICtrlSetOnEvent($g_idRenderingCheckbox, "GUI_OnToggleRendering")
	GUICtrlSetState($g_idRenderingCheckbox, $GUI_CHECKED)

	; The banner is optional - the window works with or without the image.
	If FileExists(@ScriptDir & "\Misute.jpg") Then
		GUICtrlCreatePic(@ScriptDir & "\Misute.jpg", 320, 592, 196, 54)
	ElseIf FileExists(@ScriptDir & "\..\Misute.jpg") Then
		GUICtrlCreatePic(@ScriptDir & "\..\Misute.jpg", 320, 592, 196, 54)
	EndIf

	GUISetOnEvent($GUI_EVENT_CLOSE, "GUI_OnClose")
	GUISetState(@SW_SHOW)

	; From now on every log line appears in the console, including the ones
	; written before the window existed.
	Log_RegisterSink("GUI_OnLogLine")
	Log_ReplayTo("GUI_OnLogLine")

	GUI_BuildMapList()
	$g_hGuiRefreshTimer = TimerInit()
	GUI_Update(True)

	Return $g_hMainGui
EndFunc   ;==>GUI_Create

Func GUI_Shutdown()
	Log_ClearSink()

	; The rich edit control has to be released before its parent window.
	If $g_hLogEdit <> 0 Then _GUICtrlRichEdit_Destroy($g_hLogEdit)
	If $g_hMainGui <> 0 Then GUIDelete($g_hMainGui)
	$g_hMainGui = 0
	$g_hLogEdit = 0
EndFunc   ;==>GUI_Shutdown
#EndRegion Creation

#Region Event handlers
;~ Handlers only ever ask the controller for something. No bot logic lives here.

Func GUI_OnStart()
	If State_IsBusy() Then Return

	Local $sCharacter = GUICtrlRead($g_idCharacterCombo)
	StartBot($sCharacter)
	GUI_Update(True)
EndFunc   ;==>GUI_OnStart

Func GUI_OnStop()
	RequestStop()
	GUI_Update(True)
EndFunc   ;==>GUI_OnStop

Func GUI_OnRefreshCharacters()
	If State_IsBusy() Then Return

	Local $sNames = Bot_GetLoggedCharNames()
	GUICtrlSetData($g_idCharacterCombo, "")
	GUICtrlSetData($g_idCharacterCombo, $sNames)
	Log_Info("Character list refreshed.")
EndFunc   ;==>GUI_OnRefreshCharacters

Func GUI_OnToggleRendering()
	Bot_SetRendering(GUICtrlRead($g_idRenderingCheckbox) = $GUI_CHECKED)
EndFunc   ;==>GUI_OnToggleRendering

;~ Description: Closing the window asks the bot to stop first; Main.au3 exits
;~              once the workflow has come to a safe halt.
Func GUI_OnClose()
	$g_bGuiExitRequested = True

	If Bot_IsActive() Then
		Log_Status("Close requested - stopping the bot before exiting.")
		RequestStop()
	EndIf
EndFunc   ;==>GUI_OnClose

Func GUI_IsExitRequested()
	Return $g_bGuiExitRequested
EndFunc   ;==>GUI_IsExitRequested
#EndRegion Event handlers

#Region Refresh
;~ Description: Repaints the window. Called from the main loop; only does work
;~              when the bot state changed or the refresh interval elapsed, so
;~              the labels do not flicker and the CPU stays idle.
Func GUI_Update($bForce = False)
	If $g_hMainGui = 0 Then Return

	Local $iRevision = State_GetRevision()

	If Not $bForce Then
		Local $iSinceRepaint = TimerDiff($g_hGuiRefreshTimer)
		If $iSinceRepaint < $GUI_MIN_REPAINT_MS Then Return
		If $iRevision = $g_iGuiRevision And $iSinceRepaint < $GUI_REFRESH_MS Then Return
	EndIf

	$g_iGuiRevision = $iRevision
	$g_hGuiRefreshTimer = TimerInit()

	GUI_UpdateStatusPanel()
	GUI_UpdateTimers()
	GUI_UpdateProgress()
	GUI_UpdateMapList()
	GUI_UpdateButtons()
	GUI_UpdateTitle()
EndFunc   ;==>GUI_Update

;~ Description: Lets a long, blocking adapter call keep the window alive; see
;~              State_Yield(). Registered by Main.au3.
Func GUI_Pump()
	GUI_Update(True)
EndFunc   ;==>GUI_Pump

Func GUI_UpdateStatusPanel()
	GUI_SetText($g_idStatusValue, State_GetStatusText())
	GUI_SetText($g_idZoneValue, GUI_OrDash(State_GetCurrentMapName()))
	GUI_SetText($g_idOutpostValue, GUI_OrDash(State_GetCurrentOutpostName()))

	Local $sAttempt = "-"
	If State_GetAttempt() > 0 Then
		$sAttempt = State_GetAttempt() & " of " & State_GetAttemptMax()
	EndIf
	GUI_SetText($g_idAttemptValue, $sAttempt)

	GUI_SetText($g_idActivityValue, GUI_OrDash(State_GetActivity()))
EndFunc   ;==>GUI_UpdateStatusPanel

Func GUI_UpdateTimers()
	GUI_SetText($g_idRunTimeValue, State_FormatDuration(State_GetRunElapsedMs()))
	GUI_SetText($g_idTotalTimeValue, State_FormatDuration(State_GetTotalElapsedMs()))

	If State_IsZoneTimerRunning() Then
		GUI_SetText($g_idZoneTimeValue, State_FormatDuration(State_GetZoneElapsedMs()))
		GUI_SetText($g_idTimeoutValue, State_FormatDuration(State_GetZoneRemainingMs()))
	Else
		GUI_SetText($g_idZoneTimeValue, "00:00:00")
		GUI_SetText($g_idTimeoutValue, "--:--:--")
	EndIf

	Local $sMode = ($g_bSimulationMode) ? "SIMULATION MODE - no game attached" : ""
	If State_IsConnected() And Not $g_bSimulationMode Then $sMode = "Connected"
	GUI_SetText($g_idModeValue, $sMode)
	GUICtrlSetColor($g_idModeValue, ($g_bSimulationMode) ? 0x9900CC : 0x1C7A1C)
EndFunc   ;==>GUI_UpdateTimers

Func GUI_UpdateProgress()
	Local $iTotal = State_GetMapsTotal()
	Local $iDone = State_GetMapsVanquished() + State_GetMapsFailed()

	If GUICtrlRead($g_idProgressBar) <> State_GetProgressPercent() Then
		GUICtrlSetData($g_idProgressBar, State_GetProgressPercent())
	EndIf

	GUI_SetText($g_idProgressLabel, $iDone & " / " & $iTotal & " maps")
	GUI_SetText($g_idRemainingValue, "Remaining: " & State_GetMapsRemaining())
	GUI_SetText($g_idVanquishedValue, "Vanquished: " & State_GetMapsVanquished())
	GUI_SetText($g_idFailedValue, "Failed: " & State_GetMapsFailed())
EndFunc   ;==>GUI_UpdateProgress

Func GUI_UpdateButtons()
	Local $bBusy = State_IsBusy()

	GUI_SetControlEnabled($g_idStartButton, Not $bBusy)
	GUI_SetControlEnabled($g_idStopButton, $bBusy And Not State_IsStopRequested())
	GUI_SetControlEnabled($g_idRefreshButton, Not $bBusy)
	GUI_SetControlEnabled($g_idCharacterCombo, Not $bBusy)
EndFunc   ;==>GUI_UpdateButtons

Func GUI_UpdateTitle()
	Local $sTitle = $VQ_BOT_TITLE & " " & $VQ_BOT_VERSION
	If State_GetCharacterName() <> "" Then $sTitle &= " - " & State_GetCharacterName()

	If WinGetTitle($g_hMainGui) <> $sTitle Then WinSetTitle($g_hMainGui, "", $sTitle)
EndFunc   ;==>GUI_UpdateTitle
#EndRegion Refresh

#Region Map list
;~ Description: One row per map, created once. Only the cells that change are
;~              rewritten afterwards, which avoids the flicker of rebuilding.
Func GUI_BuildMapList()
	_GUICtrlListView_DeleteAllItems($g_idMapList)

	For $i = 0 To Maps_Count() - 1
		_GUICtrlListView_AddItem($g_idMapList, Maps_GetName($i))
		_GUICtrlListView_AddSubItem($g_idMapList, $i, Maps_GetRegion($i), $eLVCOL_REGION)
		_GUICtrlListView_AddSubItem($g_idMapList, $i, Maps_StatusText(Maps_GetStatus($i)), $eLVCOL_STATUS)
		_GUICtrlListView_AddSubItem($g_idMapList, $i, "0", $eLVCOL_ATTEMPTS)
		_GUICtrlListView_AddSubItem($g_idMapList, $i, Maps_GetOutpostName($i), $eLVCOL_DETAIL)
	Next
EndFunc   ;==>GUI_BuildMapList

Func GUI_UpdateMapList()
	; Reading the list view is far more expensive than reading the map array, so
	; the rows are only touched when something in the array actually moved.
	Local $sSignature = ""
	For $i = 0 To Maps_Count() - 1
		$sSignature &= Maps_GetStatus($i) & "," & Maps_GetAttempts($i) & "," & Maps_GetLastResult($i) & "|"
	Next

	If $sSignature = $g_sGuiMapSignature Then Return
	$g_sGuiMapSignature = $sSignature

	For $i = 0 To Maps_Count() - 1
		GUI_SetListViewCell($i, $eLVCOL_STATUS, Maps_StatusText(Maps_GetStatus($i)))
		GUI_SetListViewCell($i, $eLVCOL_ATTEMPTS, String(Maps_GetAttempts($i)))

		Local $sDetail = Maps_GetLastResult($i)
		If $sDetail = "" Then $sDetail = Maps_GetOutpostName($i)
		GUI_SetListViewCell($i, $eLVCOL_DETAIL, $sDetail)
	Next
EndFunc   ;==>GUI_UpdateMapList

Func GUI_SetListViewCell($iRow, $iColumn, $sText)
	If _GUICtrlListView_GetItemText($g_idMapList, $iRow, $iColumn) = $sText Then Return
	_GUICtrlListView_SetItemText($g_idMapList, $iRow, $sText, $iColumn)
EndFunc   ;==>GUI_SetListViewCell
#EndRegion Map list

#Region Log console
;~ Description: Log sink. Registered with Log_RegisterSink() so the bot can log
;~              without knowing a window exists.
Func GUI_OnLogLine($sLine, $iLevel)
	If $g_hLogEdit = 0 Then Return

	_GUICtrlRichEdit_SetSel($g_hLogEdit, -1, -1)
	_GUICtrlRichEdit_SetCharColor($g_hLogEdit, Log_LevelColour($iLevel))
	_GUICtrlRichEdit_AppendText($g_hLogEdit, @CRLF & $sLine)
	_GUICtrlEdit_Scroll($g_hLogEdit, 1)

	$g_iGuiLogLines += 1
	If $g_iGuiLogLines > $GUI_LOG_MAX_LINES And Not $g_bGuiLogRebuilding Then GUI_RebuildLog()
EndFunc   ;==>GUI_OnLogLine

;~ Description: Redraws the console from the log ring buffer. Keeps memory flat
;~              during unattended runs that produce thousands of lines.
Func GUI_RebuildLog()
	$g_bGuiLogRebuilding = True

	_GUICtrlRichEdit_SetText($g_hLogEdit, "")
	$g_iGuiLogLines = 0
	Log_ReplayTo("GUI_OnLogLine")

	$g_bGuiLogRebuilding = False
EndFunc   ;==>GUI_RebuildLog
#EndRegion Log console

#Region Small helpers
;~ Description: Writes a label only when the text actually changed.
Func GUI_SetText($idControl, $sText)
	If $idControl = 0 Then Return
	If GUICtrlRead($idControl) = $sText Then Return
	GUICtrlSetData($idControl, $sText)
EndFunc   ;==>GUI_SetText

Func GUI_SetControlEnabled($idControl, $bEnabled)
	If $idControl = 0 Then Return
	GUICtrlSetState($idControl, ($bEnabled) ? $GUI_ENABLE : $GUI_DISABLE)
EndFunc   ;==>GUI_SetControlEnabled

Func GUI_OrDash($sText)
	Return ($sText = "") ? "-" : $sText
EndFunc   ;==>GUI_OrDash
#EndRegion Small helpers
