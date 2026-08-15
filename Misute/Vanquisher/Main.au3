#RequireAdmin

#cs ----------------------------------------------------------------------------

    Main.au3 - entry point for the Misute vanquisher.

    Run this file. It wires the pieces together and then does nothing but turn
    the handle:

        GUI            GUI.au3            what the user sees
         |
        Controller     BotController.au3  the state machine, queue and retries
         |
        Adapters       Pathfinder.au3 / GuildWars.au3   the game

    The loop below is the whole scheduler: one slice of bot work, one repaint,
    a short sleep. Because no step blocks, the window stays responsive and a
    stop request is picked up within a few milliseconds.

    Command line:
        Main.au3 -character "My Character" [-autostart]

#ce ----------------------------------------------------------------------------

Opt("GUIOnEventMode", 1)     ; button clicks are delivered to handler functions
Opt("GUICloseOnESC", False)  ; ESC must not kill a long unattended run

#include "Config.au3"
#include "Log.au3"
#include "BotState.au3"
#include "Maps.au3"
#include "GuildWars.au3"
#include "Pathfinder.au3"
#include "BotController.au3"
#include "GUI.au3"

Main()

Func Main()
	OnAutoItExitRegister("Main_OnExit")

	Main_ParseCommandLine()

	Log_Start()
	State_Init()
	Maps_Load()

	GUI_Create()

	; Lets a blocking adapter call keep the window alive; see State_Yield().
	State_SetPumpHandler("GUI_Pump")

	Log_Info($VQ_BOT_TITLE & " ready. Press Start to begin.")

	If $g_bAutoStart Then
		Log_Status("Auto-start requested on the command line.")
		StartBot($g_sTargetCharacter)
	EndIf

	Main_Loop()
EndFunc   ;==>Main

;~ Description: The application loop. Kept deliberately tiny - all behaviour
;~              lives in the controller, all presentation in the GUI.
Func Main_Loop()
	Local $hExitTimer = 0

	While True
		Bot_Tick()
		GUI_Update()

		If GUI_IsExitRequested() Then
			If $hExitTimer = 0 Then $hExitTimer = TimerInit()

			; Normally we wait for the workflow to stop safely. The grace period
			; stops a wedged adapter from keeping the window alive forever.
			If Not Bot_IsActive() Or TimerDiff($hExitTimer) > 15000 Then ExitLoop
		EndIf

		Sleep($TICK_SLEEP_MS)
	WEnd

	Exit
EndFunc   ;==>Main_Loop

;~ Description: -character "Name" selects the client, -autostart begins at once.
Func Main_ParseCommandLine()
	For $i = 1 To $CmdLine[0]
		Switch $CmdLine[$i]
			Case "-character"
				If $i < $CmdLine[0] Then $g_sTargetCharacter = $CmdLine[$i + 1]
			Case "-autostart"
				$g_bAutoStart = True
		EndSwitch
	Next

	; Passing a character on its own implies "just get on with it", which is how
	; the original script behaved.
	If $g_sTargetCharacter <> "" And $CmdLine[0] = 2 Then $g_bAutoStart = True
EndFunc   ;==>Main_ParseCommandLine

;~ Description: Runs on every exit, including a crash, so the log always says
;~              how the session ended.
Func Main_OnExit()
	Bot_Shutdown()
	Log_Info("Script terminated. ExitCode=" & @exitCode)
	GUI_Shutdown()
EndFunc   ;==>Main_OnExit
