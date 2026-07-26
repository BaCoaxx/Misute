#include-once
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <Date.au3>
#include <GuiListBox.au3>
#include <ProgressConstants.au3>
#include <GuiTab.au3>
#include <TabConstants.au3>

; Main Form
$MainGui = GUICreate($BotTitle, 316, 470, 244, 170, -1, BitOR($WS_EX_TOPMOST,$WS_EX_WINDOWEDGE))

; Combo Boxes For Character Selection & Farms
$Group3 = GUICtrlCreateGroup("Misute", 8, 7, 300, 456, -1,  $WS_EX_TRANSPARENT)
$Group1 = GUICtrlCreateGroup("Select Your Character", 16, 24, 160, 49)

Global $GUINameCombo
If $doLoadLoggedChars Then
    $GUINameCombo = GUICtrlCreateCombo($g_s_MainCharName, 24, 40, 144, 25, BitOR($CBS_DROPDOWN,$CBS_AUTOHSCROLL))
    GUICtrlSetData(-1, Scanner_GetLoggedCharNames())
Else
    $GUINameCombo = GUICtrlCreateInput($g_s_MainCharName, 24, 40, 144, 25)
EndIf
GUICtrlCreateGroup("", -99, -99, 1, 1)

; Buttons/Checkboxes
Global Enum _
    $WORKFLOW_STATE_CHARACTER_SELECT = 0, _
    $WORKFLOW_STATE_CONNECTED, _
    $WORKFLOW_STATE_SCANNED, _
    $WORKFLOW_STATE_RUNNING

Global $g_iWorkflowState = $WORKFLOW_STATE_CHARACTER_SELECT
Global $g_aZoneTabListControls[0][3]
Global $GUIConnectButton = GUICtrlCreateButton("Connect", 185, 38, 57, 25)
GUICtrlSetOnEvent($GUIConnectButton, "GuiButtonHandler")
$GUIRefreshButton = GUICtrlCreateButton("Refresh", 246, 38, 57, 25)
GUICtrlSetOnEvent($GUIRefreshButton, "GuiButtonHandler")
$GUIScanMapsButton = GUICtrlCreateButton("Scan Maps", 185, 68, 57, 25)
GUICtrlSetOnEvent($GUIScanMapsButton, "GuiButtonHandler")
$GUIStartButton = GUICtrlCreateButton("Start", 246, 68, 57, 25)
GUICtrlSetOnEvent($GUIStartButton, "GuiButtonHandler")
$GUIToggleRendering = GUICtrlCreateCheckbox("Rendering?", 30, 439, 105, 17)
GUICtrlSetOnEvent($GUIToggleRendering, "GuiButtonHandler")
GUICtrlSetState($GUIToggleRendering, $GUI_DISABLE)

; Zone Selection
Global $GUIZoneTab = GUICtrlCreateTab(16, 86, 284, 154)
CreateZoneSelectionControls()

; RichEdit Output Box
$g_h_EditText = _GUICtrlRichEdit_Create($MainGui, "", 16, 248, 284, 108, BitOR($ES_AUTOVSCROLL, $ES_MULTILINE, $WS_VSCROLL, $ES_READONLY), $WS_EX_STATICEDGE)
_GUICtrlRichEdit_SetBkColor($g_h_EditText, $COLOR_WHITE)

; Images/Labels
$Pic1 = GUICtrlCreatePic("Misute.jpg", 30, 363, 256, 71)
$Label3 = GUICtrlCreateLabel("Run Time:", 194, 101, 53, 17)
$Label4 = GUICtrlCreateLabel("Total Time:", 190, 118, 57, 17)
$RunTimeLbl = GUICtrlCreateLabel("00:00:00", 249, 101, 46, 17)
$TotalTimeLbl = GUICtrlCreateLabel("00:00:00", 249, 118, 46, 17)
GUICtrlCreateGroup("", -99, -99, 1, 1)

GUISetOnEvent($GUI_EVENT_CLOSE, "GuiButtonHandler")
GUISetState(@SW_SHOW)
SetWorkflowState($WORKFLOW_STATE_CHARACTER_SELECT)

Func GuiButtonHandler()
    Switch @GUI_CtrlId
        Case $GUIConnectButton
            If $Bot_Core_Initialized Then Return
            If InitializeBot() Then
                WinSetTitle($MainGui, "", player_GetCharname())
                GUICtrlSetState($GUINameCombo, $GUI_DISABLE)
                GUICtrlSetState($GUIToggleRendering, $GUI_ENABLE)
                SetWorkflowState($WORKFLOW_STATE_CONNECTED)
                LogStatus("Connected. Scan maps to build the available zone list.")
            EndIf

        Case $GUIScanMapsButton
            If Not $Bot_Core_Initialized Then
                LogWarn("Connect before scanning maps.")
                Return
            EndIf

            If ScanKnownZones() Then
                RefreshZoneSelectionLists(True)
                SetWorkflowState($WORKFLOW_STATE_SCANNED)
            EndIf

        Case $GUIStartButton
            If Not $g_bMapsScanned Then
                LogWarn("Scan maps before starting a vanquish plan.")
                Return
            EndIf

            If Not $IsRunning Then
                Local $aSelectedZones
                If GetSelectedZones($aSelectedZones) = 0 Then
                    LogWarn("Select at least one available zone before starting.")
                    Return
                EndIf

                If Not BuildRunPlan($aSelectedZones) Then Return

                GUICtrlSetState($GUIStartButton, $GUI_DISABLE)
                GUICtrlSetData($GUIStartButton, "Stop")
                GUICtrlSetState($GUIStartButton, $GUI_ENABLE)
                SetWorkflowState($WORKFLOW_STATE_RUNNING)
                SetRunningState(True)
            Else
                GUICtrlSetState($GUIStartButton, $GUI_DISABLE)
                GUICtrlSetData($GUIStartButton, "Pausing...")
                LogStatus("Bot will pause, please wait..")
                SetRunningState(False)
            EndIf

        Case $GUIRefreshButton
            GUICtrlSetData($GUINameCombo, "")
            GUICtrlSetData($GUINameCombo, Scanner_GetLoggedCharNames())

        Case $GUIToggleRendering
            Ui_ToggleRendering()

        Case $GUI_EVENT_CLOSE
            Exit
    EndSwitch
EndFunc

Func InitializeBot()
    Local $g_s_MainCharName = GUICtrlRead($GUINameCombo)
    If $g_s_MainCharName=="" Then
        If Core_Initialize(ProcessExists("gw.exe"), True) = 0 Then
            MsgBox(0, "Error", "Guild Wars is not running.")
            Return False
        EndIf
    ElseIf $ProcessID Then
        $proc_id_int = Number($ProcessID, 2)
        If Core_Initialize($proc_id_int, True) = 0 Then
            MsgBox(0, "Error", "Could not Find a ProcessID or somewhat '"&$proc_id_int&"'  "&VarGetType($proc_id_int)&"'")
            If ProcessExists($proc_id_int) Then
                ProcessClose($proc_id_int)
            EndIf
            Return False
        EndIf
    Else
        If Core_Initialize($g_s_MainCharName, True) = 0 Then
            MsgBox(0, "Error", "Could not Find a Guild Wars client with a Character named '"&$g_s_MainCharName&"'")
            Return False
        EndIf
    EndIf

    $Bot_Core_Initialized = True
    Return True
EndFunc

Func UpdateStats()
    GUICtrlSetData($RunTimeLbl, FormatElapsedTime($RunTime))
EndFunc

Func UpdateTotalTime()
    GUICtrlSetData($TotalTimeLbl, FormatElapsedTime($TotalTime))
EndFunc

Func ResetStart($sStatus = "Bot paused.")
    SetRunningState(False)
    GUICtrlSetData($GUIStartButton, "Start")
    RefreshZoneSelectionLists(True)
    SetWorkflowState($WORKFLOW_STATE_SCANNED)
    If $sStatus <> "" Then LogStatus($sStatus)
    Sleep(500)
EndFunc

Func SetWorkflowState($iState)
    $g_iWorkflowState = $iState

    GUICtrlSetState($GUIConnectButton, $GUI_ENABLE)
    GUICtrlSetState($GUIRefreshButton, $GUI_ENABLE)
    GUICtrlSetState($GUIScanMapsButton, $GUI_DISABLE)
    GUICtrlSetState($GUIStartButton, $GUI_DISABLE)

    Switch $iState
        Case $WORKFLOW_STATE_CHARACTER_SELECT
            GUICtrlSetState($GUINameCombo, $GUI_ENABLE)

        Case $WORKFLOW_STATE_CONNECTED
            GUICtrlSetState($GUIConnectButton, $GUI_DISABLE)
            GUICtrlSetState($GUIRefreshButton, $GUI_DISABLE)
            GUICtrlSetState($GUIScanMapsButton, $GUI_ENABLE)
            GUICtrlSetState($GUINameCombo, $GUI_DISABLE)

        Case $WORKFLOW_STATE_SCANNED
            GUICtrlSetState($GUIConnectButton, $GUI_DISABLE)
            GUICtrlSetState($GUIRefreshButton, $GUI_DISABLE)
            GUICtrlSetState($GUIScanMapsButton, $GUI_DISABLE)
            GUICtrlSetState($GUIStartButton, $GUI_ENABLE)
            GUICtrlSetState($GUINameCombo, $GUI_DISABLE)

        Case $WORKFLOW_STATE_RUNNING
            GUICtrlSetState($GUIConnectButton, $GUI_DISABLE)
            GUICtrlSetState($GUIRefreshButton, $GUI_DISABLE)
            GUICtrlSetState($GUIScanMapsButton, $GUI_DISABLE)
            GUICtrlSetState($GUIStartButton, $GUI_ENABLE)
            GUICtrlSetState($GUINameCombo, $GUI_DISABLE)
    EndSwitch
EndFunc

Func CreateZoneSelectionControls()
    Local $aTabNames[0]

    For $i = 0 To ZoneRegistry_Count() - 1
        Local $sTabName = ZoneRegistry_GetValue($i, $ZONE_REGISTRY_TAB_NAME)
        Local $iTabIndex = _FindZoneTabIndex($aTabNames, $sTabName)
        If $iTabIndex <> -1 Then ContinueLoop

        $iTabIndex = UBound($aTabNames)
        ReDim $aTabNames[$iTabIndex + 1]
        $aTabNames[$iTabIndex] = $sTabName

        ReDim $g_aZoneTabListControls[$iTabIndex + 1][3]
        GUICtrlCreateTabItem($sTabName)
        Local $iListId = GUICtrlCreateList("", 24, 112, 268, 104, BitOR($LBS_EXTENDEDSEL, $WS_BORDER, $WS_VSCROLL))
        $g_aZoneTabListControls[$iTabIndex][0] = $sTabName
        $g_aZoneTabListControls[$iTabIndex][1] = $iListId
        $g_aZoneTabListControls[$iTabIndex][2] = GUICtrlGetHandle($iListId)
    Next

    GUICtrlCreateTabItem("")
    RefreshZoneSelectionLists(False)
EndFunc

Func RefreshZoneSelectionLists($bHideUnavailable)
    For $i = 0 To UBound($g_aZoneTabListControls) - 1
        _GUICtrlListBox_ResetContent($g_aZoneTabListControls[$i][2])
    Next

    For $i = 0 To ZoneRegistry_Count() - 1
        If $bHideUnavailable And Not ZoneRegistry_IsSelectable($i) Then ContinueLoop

        Local $iTabIndex = FindZoneListControlIndex(ZoneRegistry_GetValue($i, $ZONE_REGISTRY_TAB_NAME))
        If $iTabIndex = -1 Then ContinueLoop

        _GUICtrlListBox_AddString($g_aZoneTabListControls[$iTabIndex][2], ZoneRegistry_GetValue($i, $ZONE_REGISTRY_DISPLAY_NAME))
    Next
EndFunc

Func GetSelectedZones(ByRef $aSelectedZones)
    ReDim $aSelectedZones[0]
    Local $iSelectedCount = 0

    For $i = 0 To UBound($g_aZoneTabListControls) - 1
        Local $aSelections = _GUICtrlListBox_GetSelItems($g_aZoneTabListControls[$i][2])
        If @error Or Not IsArray($aSelections) Then ContinueLoop

        For $ii = 1 To $aSelections[0]
            ReDim $aSelectedZones[$iSelectedCount + 1]
            $aSelectedZones[$iSelectedCount] = _GUICtrlListBox_GetText($g_aZoneTabListControls[$i][2], $aSelections[$ii])
            $iSelectedCount += 1
        Next
    Next

    Return $iSelectedCount
EndFunc

Func FindZoneListControlIndex($sTabName)
    For $i = 0 To UBound($g_aZoneTabListControls) - 1
        If $g_aZoneTabListControls[$i][0] = $sTabName Then Return $i
    Next
    Return -1
EndFunc

Func _FindZoneTabIndex(ByRef $aTabNames, $sTabName)
    For $i = 0 To UBound($aTabNames) - 1
        If $aTabNames[$i] = $sTabName Then Return $i
    Next
    Return -1
EndFunc
