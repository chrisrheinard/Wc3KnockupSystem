library KnockupSystem /* version 1.1
*************************************************************************************
*
*   ------------
*   Description:
*   ------------
*   A simple knock-up system inspired by Mobile Legends & League of Legends.
*   By yours truly, Rheiko.
*
*   ---------
*   Features:
*   ---------
*   - Allows you to apply knockup effect on a unit
*   - Allows you to remove knockup effect from a unit
*   - Allows you to check if a unit is being knocked up
*   - Allows you to give knockup immunity to a unit
*   - Allows you to remove knockup immunity from a unit
*   - Allows you to check if a unit is immune to knockup effect
*   - Allows you to check the remaining time of knockup effect on a unit
*
*   ----
*   API:
*   ----
*   function ApplyKnockup(unit whichUnit, real height, real duration)
*     - Apply knockup effect on a unit
*     - If the unit is already airborne from a previous knockup, the current effect will be **overridden**.
*     - The new knockup will **blend smoothly** with the remaining height/time from the previous one, instead of resetting abruptly.
*     - You can also configure this behavior from global configuration. (No override/Always override/Only stronger effect override)
*
*   function RemoveKnockup(unit whichUnit) -> Returns a boolean value
*     - Remove knockup effect from a unit
*
*   function IsUnitKnockup(unit whichUnit) -> Returns a boolean value
*     - Check if the unit is being knocked up
*
*   function SetKnockupImmune(unit whichUnit, boolean flag) -> Returns a boolean value
*     - Grants a unit immunity against knockup effect
*
*   function IsKnockupImmune(unit whichUnit) -> Returns a boolean value
*     - Check if the unit is immune to knockup
*
*   function GetKnockupRemaining(unit whichUnit) -> Returns a real value
*     - Check the remaining time of knockup effect on a unit
*     - It will always return 0.0 if the unit is not airborne
*
*   --------------
*   */ requires /*
*   --------------
*   Knockup System has no requirement whatsoever.
*
*   --------------------------
*   */ optional PauseUnitEx /*
*   --------------------------
*   This snippet helps preventing the target from being unpaused early.
*   Very useful if you use BlzPauseUnitEx for many things in your map
*   and not just for this system.
*
*   I highly recommend to use KnockupSystem along PauseUnitEx for the best outcomes.
*
*   Credits to MyPad
*   Link: https://www.hiveworkshop.com/threads/pauseunitex.326422/
*
*   -------------------
*   Import instruction:
*   -------------------
*   Simply copy and paste the Knockup System folder into your map. Easy Peasy Lemon Squeezy.
*   If you want to use the optional library, then simply import it as well.
*   But if you don't, you can simply delete it.
*
*   ---------------------
*   Global configuration:
*   ---------------------
*/
    globals      
        /* 
            Default duration value for knockup, used when the parameter value <= 0
        */
        private constant real DEFAULT_KNOCKUP_DURATION = 1.0

        /*
            Default height value for knockup, used when the parameter value <= 0
        */
        private constant real DEFAULT_KNOCKUP_HEIGHT = 150.0

        /* 
            Max height value for knockup
        */
        private constant real MAX_KNOCKUP_HEIGHT = 500.0

        /* 
            Effect attached on the target during "airborne" state
        */
        private constant string ATTACHMENT_EFFECT = "Abilities\\Spells\\Orc\\StasisTrap\\StasisTotemTarget.mdl"

        /*
            Unit attachment point (head, origin, overhead, etc)
        */
        private constant string ATTACHMENT_POINT = "overhead"

        /* 
            Effect on the location of the target when they get launched
        */
        private constant string LAUNCH_EFFECT = ""
    
        /* 
            Effect on the location of the target when they land
        */
        private constant string LANDING_EFFECT = ""

        /* 
            -1 = no override (wait until land), 0 = always override, 1 = only stronger duration override
        */
        private constant integer OVERRIDE_MODE = 1

        /* 
            Timer interval used to update target unit fly height
        */
        private constant real TIMEOUT = .03125
        
        /* -------------
            END OF CONFIG
            -------------
    */endglobals

    globals
        // Initialize hashtable
        private hashtable TABLE = InitHashtable()

        // Initialize timer
        private timer TIMER = CreateTimer()
    endglobals

    native UnitAlive takes unit id returns boolean

    function ApplyKnockup takes unit u, real height, real duration returns nothing
        if height <= 0. then
            set height = DEFAULT_KNOCKUP_HEIGHT
        endif

        if height > MAX_KNOCKUP_HEIGHT then
            set height = MAX_KNOCKUP_HEIGHT
        endif

        if duration <= 0. then
            set duration = DEFAULT_KNOCKUP_DURATION
        endif

        call KnockupInstance.create(u, height, duration)
    endfunction

    function RemoveKnockup takes unit u returns boolean
        return KnockupInstance.Remove(u) 
    endfunction

    function IsUnitKnockup takes unit u returns boolean
        return KnockupInstance.IsKnockup(u)
    endfunction 

    function SetKnockupImmune takes unit u, boolean flag returns boolean
        return KnockupInstance.SetImmune(u, flag)
    endfunction

    function IsKnockupImmune takes unit u returns boolean
        return KnockupInstance.IsImmune(u)
    endfunction

    function GetKnockupRemaining takes unit u returns real
        return KnockupInstance.GetRemaining(u)
    endfunction

    private module LinkedList
        thistype next
        thistype prev
        
        static method insert takes thistype this returns nothing
            set this.next = 0
            set this.prev = thistype(0).prev
            set thistype(0).prev.next = this
            set thistype(0).prev = this
        endmethod

        static method pop takes thistype this returns nothing
            set this.next.prev = this.prev
            set this.prev.next = this.next
        endmethod

    endmodule

    struct KnockupInstance   
        implement LinkedList

        boolean isAirborne
        real height
        real duration
        real deltaHeight
        real initialHeight
        real baseHeight
        real counter
        unit target
        effect sfx

        static method IsKnockup takes unit u returns boolean
            local integer key = GetHandleId(u)
            local integer index = LoadInteger(TABLE, 0, key)

            if index != 0 then
                return KnockupInstance(index).isAirborne
            endif

            return false        
        endmethod

        static method GetRemaining takes unit u returns real
            local integer index = LoadInteger(TABLE, 0, GetHandleId(u))
            
            if not (index == 0) then
                if not thistype(index).isAirborne then
                    return 0.0
                endif

                return thistype(index).duration - thistype(index).counter
            endif

            return 0.0
        endmethod

        static method SetImmune takes unit u, boolean flag returns boolean
            call SaveBoolean(TABLE, 1, GetHandleId(u), flag)
            return true
        endmethod

        static method IsImmune takes unit u returns boolean
            return LoadBoolean(TABLE, 1, GetHandleId(u))
        endmethod

        private static method CalculateApex takes real init, real peak, real base returns real
            return (init + peak) * 2.0 - 0.5 * (init + base)
        endmethod

        static method Remove takes unit u returns boolean
            local thistype this
            local integer unitId = GetHandleId(u)
            local integer index = LoadInteger(TABLE, 0, unitId)
            local real x
            local real y

            if not (index == 0) then
                set this = index
                
                if this.isAirborne then
                    set this.isAirborne = false
                    call SetUnitFlyHeight(this.target, this.baseHeight, 0)
                    call RemoveSavedInteger(TABLE, 0, unitId)

                    static if LIBRARY_PauseUnitEx then
                        call PauseUnitEx(this.target, false)
                    else
                        call BlzPauseUnitEx(this.target, false)
                    endif

                    if UnitAlive(this.target) then
                        // Allows user to catch the event
                        set udg_KnockupEventTarget = this.target
                        set udg_KnockupCancelledEvent = 1.00
                        set udg_KnockupCancelledEvent = 0.00
                        set udg_KnockupEventTarget = null
                    endif

                    call DestroyEffect(this.sfx)
                    set this.sfx = null

                    call this.pop(this)
                    call this.destroy()
            
                    if thistype(0).next == 0 then
                        call PauseTimer(TIMER)
                    endif

                    return true
                endif
            endif

            return false
        endmethod

        private static method Loop takes nothing returns nothing
            local thistype this = thistype(0).next
            local real t
            local real a
            local real b
            local real x
            local real y

            loop
                exitwhen this == 0

                if IsImmune(this.target) or not UnitAlive(this.target) then
                    call KnockupInstance.Remove(this.target)
                else
                
                    set this.counter = this.counter + TIMEOUT
                    set t = this.counter / this.duration

                    if t >= 1.0 then
                        call SetUnitFlyHeight(this.target, this.baseHeight, 0)
                        set this.isAirborne = false
                        call RemoveSavedInteger(TABLE, 0, GetHandleId(this.target))

                        set x = GetUnitX(this.target)
                        set y = GetUnitY(this.target)
                    
                        static if LIBRARY_PauseUnitEx then
                            call PauseUnitEx(this.target, false)
                        else
                            call BlzPauseUnitEx(this.target, false)
                        endif

                        // Allows user to catch the event
                        set udg_KnockupEventTarget = this.target
                        set udg_KnockupLandingEvent = 1.00
                        set udg_KnockupLandingEvent = 0.00
                        set udg_KnockupEventTarget = null
    
                        call DestroyEffect(this.sfx)
                        set this.sfx = null

                        if LANDING_EFFECT != "" then
                            call DestroyEffect(AddSpecialEffect(LANDING_EFFECT, x, y))
                        endif

                        call this.pop(this)
                        call this.destroy()

                        if thistype(0).next == 0 then
                            call PauseTimer(TIMER)
                        endif

                        set this = this.next
                    else
                        set a = (1.0 - t)
                        set b = t
                        set this.deltaHeight = a * a * this.initialHeight + 2.0 * a * b * this.height + b * b * this.baseHeight
                        call SetUnitFlyHeight(this.target, this.deltaHeight, 0)
                    endif

                    // debug call BJDebugMsg("Current Fly Height of " + GetUnitName(this.target) + ":" + R2S(GetUnitFlyHeight(this.target)) )
                
                endif

                set this = this.next
            endloop
        endmethod

        static method create takes unit target, real height, real duration returns thistype
            local integer key = GetHandleId(target)
            local thistype existing = LoadInteger(TABLE, 0, key)
            local thistype this
            local real x
            local real y
            local boolean shouldOverride           

            if target == null or IsImmune(target) then
                return 0
            endif

            if not (existing == 0) then
                if OVERRIDE_MODE == 0 then 
                    debug call BJDebugMsg("DEBUG | Override always")
                    set shouldOverride = true               
                elseif OVERRIDE_MODE == 1 and duration > existing.duration - existing.counter then
                    debug call BJDebugMsg("DEBUG | Override only if stronger. Remaining duration: " + R2S(existing.duration - existing.counter) + " vs new: " + R2S(duration))
                    set shouldOverride = true
                elseif OVERRIDE_MODE == -1 then
                    debug call BJDebugMsg("DEBUG | No Override")
                    return existing
                endif

                if shouldOverride then
                    set existing.duration = duration
                    set existing.counter = 0.0
                    set existing.initialHeight = GetUnitFlyHeight(existing.target)
                    set existing.height = CalculateApex(existing.initialHeight, height, existing.baseHeight)  
                    if existing.height > MAX_KNOCKUP_HEIGHT then
                        set existing.height = MAX_KNOCKUP_HEIGHT
                    endif
                endif

                return existing
            endif

            set this = allocate()

            call this.insert(this)

            set this.target = target
            set this.duration = duration
            set this.isAirborne = true
            set this.counter = 0.0
            set this.initialHeight = GetUnitFlyHeight(this.target)
            set this.baseHeight = GetUnitDefaultFlyHeight(this.target)

            set this.height = CalculateApex(this.initialHeight, height, this.baseHeight)

            if this.height > MAX_KNOCKUP_HEIGHT then
                set this.height = MAX_KNOCKUP_HEIGHT
            endif

            call UnitAddAbility(this.target, 'Amrf')
            call UnitRemoveAbility(this.target, 'Amrf')

            set x = GetUnitX(this.target)
            set y = GetUnitY(this.target)

            static if LIBRARY_PauseUnitEx then
                call PauseUnitEx(this.target, true)
            else
                call BlzPauseUnitEx(this.target, true)
            endif

            // Allows user to catch the event
            set udg_KnockupEventTarget = this.target
            set udg_KnockupTakeoffEvent = 1.00
            set udg_KnockupTakeoffEvent = 0.00
            set udg_KnockupEventTarget = null

            set this.sfx = AddSpecialEffectTarget(ATTACHMENT_EFFECT, this.target, ATTACHMENT_POINT)
            
            if LAUNCH_EFFECT != "" then
                call DestroyEffect(AddSpecialEffect(LAUNCH_EFFECT, x, y))
            endif

            call SaveInteger(TABLE, 0, key, this)

            // debug call BJDebugMsg("Current Fly Height of " + GetUnitName(this.target) + ":" + R2S(GetUnitFlyHeight(this.target)) )
            
            if thistype(0).next == this then
                call TimerStart(TIMER, TIMEOUT, true, function thistype.Loop)
            endif

            return this
        endmethod

        static method onInit takes nothing returns nothing
            set thistype(0).next = thistype(0)
            set thistype(0).prev = thistype(0)
        endmethod
    endstruct
endlibrary
