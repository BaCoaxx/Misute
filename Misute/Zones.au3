#include-once

Global Enum _
    $ZONE_REGISTRY_KEY = 0, _
    $ZONE_REGISTRY_DISPLAY_NAME, _
    $ZONE_REGISTRY_TAB_NAME, _
    $ZONE_REGISTRY_START_MAP, _
    $ZONE_REGISTRY_AREA_MAP, _
    $ZONE_REGISTRY_PATH_ARRAY

Global Enum _
    $ZONE_SCAN_AVAILABLE = 0, _
    $ZONE_SCAN_UNAVAILABLE, _
    $ZONE_SCAN_VANQUISHED

Global $aSparkflySwamp[7][3] = [ _
    [1450, 3020, ""], _
    [1675, 2890, ""], _
    [1820, 2715, ""], _
    [2010, 2540, ""], _
    [2235, 2385, ""], _
    [2410, 2210, ""], _
    [2595, 2050, ""] _
]

Global $aRivenEarth[7][3] = [ _
    [-3735, 14170, ""], _
    [-3410, 13825, ""], _
    [-3080, 13460, ""], _
    [-2750, 13110, ""], _
    [-2430, 12780, ""], _
    [-2105, 12445, ""], _
    [-1780, 12115, ""] _
]

Global $g_aZoneRegistry[2][6] = [ _
    ["aSparkflySwamp", "Sparkfly Swamp", "Maguuma Jungle", "GC_I_MAP_ID_RATA_SUM", "GC_I_MAP_ID_SPARKFLY_SWAMP", "aSparkflySwamp"], _
    ["aRivenEarth", "Riven Earth", "Crystal Desert", "GC_I_MAP_ID_DESTINYS_GORGE", "GC_I_MAP_ID_RIVEN_EARTH", "aRivenEarth"] _
]

Global $g_aZoneScanState[UBound($g_aZoneRegistry)]
For $i = 0 To UBound($g_aZoneScanState) - 1
    $g_aZoneScanState[$i] = $ZONE_SCAN_AVAILABLE
Next

Func NormalizeZoneKey($sZoneName)
    $sZoneName = StringStripWS($sZoneName, 3)
    If $sZoneName = "" Then Return ""
    Return "a" & StringRegExpReplace($sZoneName, "\s+", "")
EndFunc

Func ZoneRegistry_Count()
    Return UBound($g_aZoneRegistry)
EndFunc

Func ZoneRegistry_GetValue($iZoneIndex, $iValueIndex)
    If $iZoneIndex < 0 Or $iZoneIndex >= UBound($g_aZoneRegistry) Then Return ""
    Return $g_aZoneRegistry[$iZoneIndex][$iValueIndex]
EndFunc

Func ZoneRegistry_FindIndexByKey($sZoneKey)
    For $i = 0 To UBound($g_aZoneRegistry) - 1
        If $g_aZoneRegistry[$i][$ZONE_REGISTRY_KEY] = $sZoneKey Then Return $i
    Next
    Return -1
EndFunc

Func ZoneRegistry_SetScanState($iZoneIndex, $iScanState)
    If $iZoneIndex < 0 Or $iZoneIndex >= UBound($g_aZoneScanState) Then Return
    $g_aZoneScanState[$iZoneIndex] = $iScanState
EndFunc

Func ZoneRegistry_GetScanState($iZoneIndex)
    If $iZoneIndex < 0 Or $iZoneIndex >= UBound($g_aZoneScanState) Then Return $ZONE_SCAN_UNAVAILABLE
    Return $g_aZoneScanState[$iZoneIndex]
EndFunc

Func ZoneRegistry_IsSelectable($iZoneIndex)
    Return ZoneRegistry_GetScanState($iZoneIndex) = $ZONE_SCAN_AVAILABLE
EndFunc

Func ZoneRegistry_ResolveMapId($sMapConstantName)
    If $sMapConstantName = "" Then Return 0
    If Not IsDeclared($sMapConstantName) Then Return 0

    Local $vMapId = Eval($sMapConstantName)
    If Not IsNumber($vMapId) Then Return 0

    Return Number($vMapId)
EndFunc

Func ZoneRegistry_CopyPathArray($iZoneIndex, ByRef $aPathing)
    Local $sArrayName = ZoneRegistry_GetValue($iZoneIndex, $ZONE_REGISTRY_PATH_ARRAY)
    If $sArrayName = "" Then Return False

    Local $aZonePath = Eval($sArrayName)
    If Not IsArray($aZonePath) Then Return False

    $aPathing = $aZonePath
    Return True
EndFunc

Func ZoneRegistry_DetectScanState($iZoneIndex, ByRef $sReason)
    $sReason = "ready"

    Local $iStartMapId = ZoneRegistry_ResolveMapId(ZoneRegistry_GetValue($iZoneIndex, $ZONE_REGISTRY_START_MAP))
    If $iStartMapId > 0 And IsFunc("Map_IsMapUnlocked") Then
        If Not Map_IsMapUnlocked($iStartMapId) Then
            $sReason = "starting outpost locked or unavailable"
            Return $ZONE_SCAN_UNAVAILABLE
        EndIf
    ElseIf ZoneRegistry_GetValue($iZoneIndex, $ZONE_REGISTRY_START_MAP) <> "" And $iStartMapId = 0 Then
        $sReason = "starting outpost constant unresolved"
        Return $ZONE_SCAN_UNAVAILABLE
    EndIf

    Local $iAreaMapId = ZoneRegistry_ResolveMapId(ZoneRegistry_GetValue($iZoneIndex, $ZONE_REGISTRY_AREA_MAP))
    If $iAreaMapId > 0 Then
        If IsFunc("Map_IsMapVanquished") Then
            If Call("Map_IsMapVanquished", $iAreaMapId) Then
                $sReason = "already vanquished"
                Return $ZONE_SCAN_VANQUISHED
            EndIf
        ElseIf IsFunc("Map_IsAreaVanquished") Then
            If Call("Map_IsAreaVanquished", $iAreaMapId) Then
                $sReason = "already vanquished"
                Return $ZONE_SCAN_VANQUISHED
            EndIf
        EndIf
    EndIf

    Return $ZONE_SCAN_AVAILABLE
EndFunc
