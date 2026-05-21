; [ADDED] Zone-settling flag
Global $g_zoneReady = False

; [ADDED] Register async zone watcher — fires every 100ms independent of loop position
AdlibRegister("ZoneWatcher", 100)

; [ADDED] Catches zone transitions even mid-block, cancels movement immediately
Func ZoneWatcher()
    If Map_GetInstanceInfo("IsLoading") Then
        $g_zoneReady = False
        Map_Move(Agent_GetAgentInfo(-2, "X"), Agent_GetAgentInfo(-2, "Y"), 0)
    EndIf
EndFunc

Func FollowLeader($desiredDistance)
    Local $Leader = GetMemberAgentID(1)
    Local $me = Agent_GetMyID()
    Local $currentDistance, $leaderX, $leaderY
    Local $myX, $myY, $angle, $newX, $newY

    Local $tolerance = 120
    Local $adjustFactor = 0.6

    If $Leader = 0 Or $Leader = $me Then Return

    While True
        ; [ADDED] If ZoneWatcher flagged a load, wait here until fully settled
        If Not $g_zoneReady Then
            If Map_GetInstanceInfo("IsExplorable") Then
                Map_WaitMapLoading()
                $g_zoneReady = True
            EndIf
            Other_RndSleep(250)
            ContinueLoop
        EndIf

        $leaderX = Agent_GetAgentInfo($Leader, "X")
        $leaderY = Agent_GetAgentInfo($Leader, "Y")

        $currentDistance = GetDistance($Leader, $me)

        If Abs($currentDistance - $desiredDistance) > $tolerance Then
            $myX = Agent_GetAgentInfo($me, "X")
            $myY = Agent_GetAgentInfo($me, "Y")

            $angle = ATan2($leaderY - $myY, $leaderX - $myX)

            $newX = $leaderX - ($desiredDistance * Cos($angle))
            $newY = $leaderY - ($desiredDistance * Sin($angle))

            $newX = $myX + ($newX - $myX) * $adjustFactor
            $newY = $myY + ($newY - $myY) * $adjustFactor

            If $g_zoneReady Then Map_Move($newX, $newY)
        EndIf

        ; [CHANGED] Self-alive guard only, leader death removed, fresh leader coords
        If $g_zoneReady And Not GetIsDead($me) And Agent_GetAgentInfo($Leader, "IsAttacking") Then
            UAI_Fight(Agent_GetAgentInfo($Leader, "X"), Agent_GetAgentInfo($Leader, "Y"))
        EndIf

        If GetIsDead($me) Then WaitForRes()

        Other_RndSleep(250)
    WEnd
EndFunc