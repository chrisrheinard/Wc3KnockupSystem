scope KnockupSystemGUI initializer Init /*
*************************************************************************************
*
*   ------------------
*   Knockup System GUI
*   ------------------
*   This is a library containing GUI Wrappers for Knockup System by Rheiko.
*   Intended for GUIers.
*
*   --------
*   Requires
*   -------------
*   KnockupSystem
*   -------------
*   
*   --------------
*   How to import:
*   --------------
*   1. You need to first import KnockupSystem library
*   2. Copy the GUI API folder to your map
*   3. You are done!
*
*   -----------
*   How to use:
*   -----------
*   - Fill the variables that have _param prefix
*     i.e: GKS_Param_Flag (boolean), GKS_Param_Height (real), GKS_Param_Target (unit), GKS_Param_Duration (real)
*
*   - Run the trigger you want
*     i.e:
*         - GKS_ApplyKnockup (requirements: GKS_Param_Target, GKS_Param_Height, GKS_Param_Duration)
*           Run this trigger to apply knockup effect on a unit
*
*         - GKS_RemoveKnockup (requirements: GKS_Param_Target)
*           Run this trigger to remove knockup effect from a unit
*
*         - GKS_CheckKnockup (requirements: GKS_Param_Target)
*           Run this trigger to check if a unit is being knocked up
*
*         - GKS_CheckKnockupImmunity (requirements: GKS_Param_Target)
*           Run this trigger to check if a unit is immune to knockup effects
*
*         - GKS_SetKnockupImmunity (requirements: GKS_Param_Target, GKS_Param_Flag)
*           Run this trigger to grant or remove knockup immunity from a unit
*
*         - GKS_GetRemainingTime (requirements: GKS_Param_Target)
*           Run this trigger to get the remaining time of knockup effect on a unit
*
*
*   - Some that has return value will be stored inside these variables
*     i.e:
*         - GKS_IsUnitKnockup (boolean)
*           Response to GKS_CheckKnockup trigger
*
*         - GKS_IsKnockupImmune (boolean)
*           Response to GKS_CheckKnockupImmunity trigger
*
*         - GKS_RemainingTime (real)
*           Response to GKS_GetRemainingTime trigger
*
*    Note: Please check the GUI examples to understand further!
*
*************************************************************************************
*/
    private function GUI_GetRemainingTime takes nothing returns nothing
        set udg_GKS_RemainingTime = GetKnockupRemaining(udg_GKS_Param_Target)
    endfunction

    private function GUI_SetKnockupImmunity takes nothing returns nothing
        call SetKnockupImmune(udg_GKS_Param_Target, udg_GKS_Param_Flag)
    endfunction

    private function GUI_CheckKnockupImmunity takes nothing returns nothing
        set udg_GKS_IsKnockupImmune = IsKnockupImmune(udg_GKS_Param_Target)
    endfunction

    private function GUI_CheckKnockup takes nothing returns nothing
        set udg_GKS_IsUnitKnockup = IsUnitKnockup(udg_GKS_Param_Target)
    endfunction

    private function GUI_RemoveKnockup takes nothing returns nothing
        call RemoveKnockup(udg_GKS_Param_Target)
    endfunction

    private function GUI_ApplyKnockup takes nothing returns nothing
        call ApplyKnockup(udg_GKS_Param_Target, udg_GKS_Param_Height, udg_GKS_Param_Duration)
    endfunction

    private function Init takes nothing returns nothing
        set udg_GKS_ApplyKnockup = CreateTrigger()
        set udg_GKS_RemoveKnockup = CreateTrigger()
        set udg_GKS_CheckKnockup = CreateTrigger()
        set udg_GKS_CheckKnockupImmunity = CreateTrigger()
        set udg_GKS_SetKnockupImmunity = CreateTrigger()
        set udg_GKS_GetRemainingTime = CreateTrigger()

        call TriggerAddAction(udg_GKS_ApplyKnockup, function GUI_ApplyKnockup)
        call TriggerAddAction(udg_GKS_RemoveKnockup, function GUI_RemoveKnockup)
        call TriggerAddAction(udg_GKS_CheckKnockup, function GUI_CheckKnockup)
        call TriggerAddAction(udg_GKS_CheckKnockupImmunity, function GUI_CheckKnockupImmunity)
        call TriggerAddAction(udg_GKS_SetKnockupImmunity, function GUI_SetKnockupImmunity)
        call TriggerAddAction(udg_GKS_GetRemainingTime, function GUI_GetRemainingTime)
    endfunction

endscope