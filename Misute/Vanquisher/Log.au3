#include-once
#include <FileConstants.au3>
#include "Config.au3"

#cs ----------------------------------------------------------------------------

    Log.au3

    Central logging. The bot logic calls LogMessage() (or one of the level
    helpers) and never touches a GUI control.

    A display registers itself once:

        Log_RegisterSink("GUI_OnLogLine")

    and is then called back with the formatted line and its level. The last
    $LOG_RING_SIZE lines are also kept in memory, so a display that is created
    (or recreated) later can replay the recent history with Log_ReplayTo().

#ce ----------------------------------------------------------------------------

#Region Levels
Global Const $eLOG_INFO = 0     ; general chatter
Global Const $eLOG_STATUS = 1   ; workflow progress the user cares about
Global Const $eLOG_EVENT = 2    ; milestones (zone started/finished)
Global Const $eLOG_WARN = 3     ; recoverable problem, a retry is coming
Global Const $eLOG_ERROR = 4    ; gave up on something
#EndRegion Levels

#Region State
Global $g_sLogSink = ""                      ; name of the display callback
Global $g_aLogRing[$LOG_RING_SIZE][2]        ; [line, level]
Global $g_iLogRingCount = 0                  ; lines currently held
Global $g_iLogRingHead = 0                   ; next slot to write
Global $g_bLogInSink = False                 ; guards against sink recursion
#EndRegion State

#Region Public API
;~ Description: Registers the function that displays log lines.
;~              Signature of the callback: Func MySink($sLine, $iLevel)
Func Log_RegisterSink($sFunctionName)
	$g_sLogSink = $sFunctionName
EndFunc   ;==>Log_RegisterSink

;~ Description: Removes the current display callback (used on shutdown).
Func Log_ClearSink()
	$g_sLogSink = ""
EndFunc   ;==>Log_ClearSink

;~ Description: Writes a line to the log file, the in-memory ring buffer and the
;~              registered display.
Func LogMessage($sText, $iLevel = $eLOG_INFO)
	Local $sLine = "[" & Log_TimeStamp() & "] [" & Log_LevelName($iLevel) & "] " & $sText

	Log_RingAdd($sLine, $iLevel)
	Log_WriteToFile($sLine)

	; A sink that logs would otherwise recurse forever.
	If $g_sLogSink <> "" And Not $g_bLogInSink Then
		$g_bLogInSink = True
		Call($g_sLogSink, $sLine, $iLevel)
		$g_bLogInSink = False
	EndIf

	Return $sLine
EndFunc   ;==>LogMessage

Func Log_Info($sText)
	Return LogMessage($sText, $eLOG_INFO)
EndFunc   ;==>Log_Info

Func Log_Status($sText)
	Return LogMessage($sText, $eLOG_STATUS)
EndFunc   ;==>Log_Status

Func Log_Event($sText)
	Return LogMessage($sText, $eLOG_EVENT)
EndFunc   ;==>Log_Event

Func Log_Warn($sText)
	Return LogMessage($sText, $eLOG_WARN)
EndFunc   ;==>Log_Warn

Func Log_Error($sText)
	Return LogMessage($sText, $eLOG_ERROR)
EndFunc   ;==>Log_Error

;~ Description: Replays the buffered history into a display callback. Called by
;~              the GUI right after it registers itself.
Func Log_ReplayTo($sFunctionName)
	If $sFunctionName = "" Then Return
	If $g_iLogRingCount = 0 Then Return

	Local $iStart = $g_iLogRingHead - $g_iLogRingCount
	If $iStart < 0 Then $iStart += $LOG_RING_SIZE

	For $i = 0 To $g_iLogRingCount - 1
		Local $iSlot = Mod($iStart + $i, $LOG_RING_SIZE)
		Call($sFunctionName, $g_aLogRing[$iSlot][0], $g_aLogRing[$iSlot][1])
	Next
EndFunc   ;==>Log_ReplayTo

Func Log_LevelName($iLevel)
	Switch $iLevel
		Case $eLOG_STATUS
			Return "STATUS"
		Case $eLOG_EVENT
			Return "EVENT"
		Case $eLOG_WARN
			Return "WARN"
		Case $eLOG_ERROR
			Return "ERROR"
		Case Else
			Return "INFO"
	EndSwitch
EndFunc   ;==>Log_LevelName

;~ Description: Colour used by a rich edit display for each level.
Func Log_LevelColour($iLevel)
	Switch $iLevel
		Case $eLOG_ERROR
			Return 0x322CCA ; red   (BGR)
		Case $eLOG_WARN
			Return 0x790984 ; purple
		Case $eLOG_STATUS
			Return 0xC76D09 ; orange/blue-ish, matches the original console
		Case $eLOG_EVENT
			Return 0x1C7A1C ; green
		Case Else
			Return 0x000000 ; black
	EndSwitch
EndFunc   ;==>Log_LevelColour

Func Log_TimeStamp()
	Return @HOUR & ":" & @MIN & ":" & @SEC
EndFunc   ;==>Log_TimeStamp

;~ Description: Starts a fresh log file and records the header.
Func Log_Start()
	FileDelete($VQ_LOG_FILE)
	LogMessage($VQ_BOT_TITLE & " " & $VQ_BOT_VERSION & " - log started " & @YEAR & "-" & @MON & "-" & @MDAY, $eLOG_INFO)
	If $g_bSimulationMode Then
		LogMessage("Simulation mode is ON - no Guild Wars client is being used.", $eLOG_WARN)
	EndIf
EndFunc   ;==>Log_Start
#EndRegion Public API

#Region Internal
Func Log_RingAdd($sLine, $iLevel)
	$g_aLogRing[$g_iLogRingHead][0] = $sLine
	$g_aLogRing[$g_iLogRingHead][1] = $iLevel

	$g_iLogRingHead = Mod($g_iLogRingHead + 1, $LOG_RING_SIZE)
	If $g_iLogRingCount < $LOG_RING_SIZE Then $g_iLogRingCount += 1
EndFunc   ;==>Log_RingAdd

;~ Description: Appends to the log file, reopening every time so the file
;~              survives a crash of the script.
Func Log_WriteToFile($sLine)
	Local $hFile = FileOpen($VQ_LOG_FILE, $FO_APPEND)
	If $hFile = -1 Then Return False

	FileWriteLine($hFile, $sLine)
	FileClose($hFile)
	Return True
EndFunc   ;==>Log_WriteToFile
#EndRegion Internal
