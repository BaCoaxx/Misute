Func FollowLeader($desiredDistance)
    Local $Leader = GetMemberAgentID(1)
    Local $me = Agent_GetMyID()
    Local $currentDistance, $leaderX, $leaderY
    Local $myX, $myY, $angle, $newX, $newY

    Local $tolerance = 120
    Local $adjustFactor = 0.6

    If $Leader = 0 Or $Leader = $me Then Return

    While True
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

            Map_Move($newX, $newY)
        EndIf

        If Not GetIsDead($Leader) And Agent_GetAgentInfo($Leader, "IsAttacking") Then
            UAI_Fight($leaderX, $leaderY)
        EndIf

        If GetIsDead($Leader) Then TryRes()

        If GetIsDead($me) Then WaitForRes()

        Other_RndSleep(250)
    WEnd
EndFunc

Func GetMemberAgentID($aPartyMember)
    If $aPartyMember < 1 Then Return 0

    Local $meLogin = Agent_GetAgentInfo(-2, "LoginNumber")
    Local $playerCount = Party_GetMyPartyInfo("ArrayPlayerPartyMemberSize")
    If $playerCount < 1 Then Return 0

    Local $pos = 0

    For $i = 1 To $playerCount
        $pos += 1
        If $pos <> $aPartyMember Then ContinueLoop

        Local $login = Party_GetMyPartyPlayerMemberInfo($i, "LoginNumber")
        If $login = 0 Then Return 0

        If $login = $meLogin Then Return Agent_GetMyID()

        Local $agents = Agent_GetAgentArray(0xDB)
        If Not IsArray($agents) Or $agents[0] = 0 Then Return 0

        For $j = 1 To $agents[0]
            If Agent_GetAgentInfo($agents[$j], "LoginNumber") = $login Then
                Return Agent_GetAgentInfo($agents[$j], "ID")
            EndIf
        Next

        Return 0
    Next

    Return 0
EndFunc   ;==>GetMemberAgentID