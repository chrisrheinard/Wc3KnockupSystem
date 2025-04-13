---@diagnostic disable: undefined-global
if Debug then Debug.beginFile 'KnockupSystem' end --[[
*************************************************************************************
*   -----------
*   version 1.1
*   -----------
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
*   Requirements:
*   --------------
*   Knockup System has no requirement whatsoever.
*
*   ----------
*   Optionals:
*   ----------
*   Wrda's PauseUnits (Link: https://www.hiveworkshop.com/threads/pauseunits.340457/)
*       This snippet helps preventing the target from being unpaused early.
*       Very useful if you use BlzPauseUnitEx for many things in your map
*       and not just for this system.
*
*       I highly recommend to use KnockupSystem along PauseUnits -- as it is the equivalent
*       of PauseUnitEx (vJASS) by MyPad -- for the best outcomes.
*
*   Credits to Wrda
*
*   -------------------
*   Import instruction:
*   -------------------
*   Simply copy and paste the Knockup System folder into your map. Easy Peasy Lemon Squeezy.
*   If you want to use the optional library, then simply import it as well.
*   But if you don't, you can simply delete it.
*
**************************************************************************************]]
do
    --======================
    -- System Configuration
    --======================

    ---Default duration value for knockup, used when the parameter value <= 0
    local DEFAULT_KNOCKUP_DURATION = 1.0

    ---Default height value for knockup, used when the parameter value <= 0
    local DEFAULT_KNOCKUP_HEIGHT = 150.0

    ---Max height value for knockup
    local MAX_KNOCKUP_HEIGHT = 500.0

    ---Effect attached on the target during "airborne" state
    local ATTACHMENT_EFFECT = "Abilities\\Spells\\Orc\\StasisTrap\\StasisTotemTarget.mdl"

    ---Unit attachment point (head, origin, overhead, etc)
    local ATTACHMENT_POINT = "overhead"

    ---Effect on the location of the target when they get launched
    local LAUNCH_EFFECT = ""

    ---Effect on the location of the target when they land
    local LANDING_EFFECT = ""

    --- -1 = no override (wait until land), 0 = always override, 1 = only stronger duration override
    local OVERRIDE_MODE = 1

    ---Timer interval used to update target unit fly height
    local TIMEOUT = .03125

    --======================
    -- End of Config
    --======================

    local TIMER ---@type timer

    ---@class KnockupInstance 
    ---@field target unit
    ---@field duration number
    ---@field height number
    ---@field counter number
    ---@field isAirborne boolean
    ---@field initialHeight number
    ---@field baseHeight number
    ---@field deltaHeight number
    ---@field sfx effect
    local KnockupInstance = {}
    KnockupInstance.__index = KnockupInstance
    KnockupInstance.__name = 'KnockupInstance'

    ---@type table<unit, KnockupInstance>
    KnockupInstance._instances = {}

    ---@type KnockupInstance[]
    KnockupInstance._list = {}

    ---@type table<unit, integer>
    KnockupInstance._index = {}

    ---Creates a new instance or overrides the current one
    ---@param target unit
    ---@param height number
    ---@param duration number
    ---@return KnockupInstance|nil
    function KnockupInstance.create(target, height, duration)
        if target == nil or KnockupInstance.IsImmune(target) then
            return nil
        end

        ---@type KnockupInstance
        local existing = KnockupInstance._instances[target]
        local shouldOverride = false

        if existing then
            if OVERRIDE_MODE == 0 then
                shouldOverride = true
            elseif OVERRIDE_MODE == 1 and duration > (existing.duration - existing.counter) then
                shouldOverride = true
            elseif OVERRIDE_MODE == -1 then
                return existing
            end

            if shouldOverride then
                existing.duration = duration
                existing.counter = 0.0
                existing.initialHeight = GetUnitFlyHeight(target)
                existing.height = KnockupInstance.calculateApex(existing.initialHeight, height, existing.baseHeight)
                if existing.height > MAX_KNOCKUP_HEIGHT then
                    existing.height = MAX_KNOCKUP_HEIGHT
                end
            end

            return existing
        end

        ---@type KnockupInstance
        local new = setmetatable({}, KnockupInstance)
        new.target = target
        new.duration = duration
        new.isAirborne = true
        new.counter = 0.0
        new.initialHeight = GetUnitFlyHeight(target)
        new.baseHeight = GetUnitDefaultFlyHeight(target)

        new.height = KnockupInstance.calculateApex(new.initialHeight, height, new.baseHeight)

        if new.height > MAX_KNOCKUP_HEIGHT then
            new.height = MAX_KNOCKUP_HEIGHT
        end

        UnitAddAbility(target, FourCC('Amrf'))
        UnitRemoveAbility(target, FourCC('Amrf'))

        if PauseUnits ~= nil then
            PauseUnits.pauseUnit(target, true)
        else
            BlzPauseUnitEx(target, true)
        end

        ---Allows user to catch the event
        _G.udg_KnockupEventTarget = target     --Reminder to self: _G. to reference / set gui globals
        globals.udg_KnockupTakeoffEvent = 1.00 --Reminder to self: globals to make the real event works
        globals.udg_KnockupTakeoffEvent = 0.00
        _G.udg_KnockupEventTarget = target

        new.sfx = AddSpecialEffectTarget(ATTACHMENT_EFFECT, target, ATTACHMENT_POINT)
        if LAUNCH_EFFECT ~= "" then
            local x = GetUnitX(target)
            local y = GetUnitY(target)
            DestroyEffect(AddSpecialEffect(LAUNCH_EFFECT, x, y))
        end

        table.insert(KnockupInstance._list, new)
        KnockupInstance._index[target] = #KnockupInstance._list
        KnockupInstance._instances[target] = new

        if #KnockupInstance._list == 1 then
            TIMER = TIMER or CreateTimer()
            TimerStart(TIMER, TIMEOUT, true, KnockupInstance.loop)
        end

        return new
    end

    ---Loop with checks, immediately calls remove() when target dies or granted immunity
    function KnockupInstance.loop()
        local i = 1

        while i <= #KnockupInstance._list do
            local this = KnockupInstance._list[i]

            if not UnitAlive(this.target) or KnockupInstance.IsImmune(this.target) then
                KnockupInstance.remove(this.target)
            else
                this.counter = this.counter + TIMEOUT
                local t = this.counter / this.duration

                if t >= 1.0 then
                    SetUnitFlyHeight(this.target, this.baseHeight, 0)
                    this.isAirborne = false

                    if PauseUnits ~= nil then
                        PauseUnits.pauseUnit(this.target, false)
                    else
                        BlzPauseUnitEx(this.target, false)
                    end
                    

                    ---Allows user to catch the event
                    _G.udg_KnockupEventTarget = this.target
                    globals.udg_KnockupLandingEvent = 1.00
                    globals.udg_KnockupLandingEvent = 0.00
                    _G.udg_KnockupEventTarget = nil

                    DestroyEffect(this.sfx)
                    this.sfx = nil

                    if LANDING_EFFECT ~= "" then
                        local x = GetUnitX(this.target)
                        local y = GetUnitY(this.target)
                        DestroyEffect(AddSpecialEffect(LANDING_EFFECT, x, y))
                    end

                    KnockupInstance._instances[this.target] = nil
            
                    local index = KnockupInstance._index[this.target]
                    KnockupInstance._index[this.target] = nil

                    if index then
                        local lastIndex = #KnockupInstance._list
                        if index ~= lastIndex then
                            local lastInst = KnockupInstance._list[lastIndex]
                            KnockupInstance._list[index] = lastInst
                            KnockupInstance._index[lastInst.target] = index
                        end
                        KnockupInstance._list[lastIndex] = nil
                    end

                    -- Stop loop if no active knockups
                    if #KnockupInstance._list == 0 then
                        PauseTimer(TIMER)
                    end
                else
                    local a = (1.0 - t)
                    local b = t
                    this.deltaHeight = a * a * this.initialHeight + 2.0 * a * b * this.height + b * b * this.baseHeight
                    SetUnitFlyHeight(this.target, this.deltaHeight, 0)

                    i = i + 1
                end
            end
        end
    end

    ---Remove the instance
    function KnockupInstance.remove(target)
        local instance = KnockupInstance._instances[target]
        if instance then
            SetUnitFlyHeight(target, instance.baseHeight, 0)
            instance.isAirborne = false

            if PauseUnits ~= nil then
                PauseUnits.pauseUnit(target, false)
            else
                BlzPauseUnitEx(target, false)
            end

            if UnitAlive(target) then
                ---Allows user to catch the event
                _G.udg_KnockupEventTarget = target
                globals.udg_KnockupCancelledEvent = 1.00
                globals.udg_KnockupCancelledEvent = 0.00
                _G.udg_KnockupEventTarget = nil
            end

            DestroyEffect(instance.sfx)
            instance.sfx = nil

            if LANDING_EFFECT ~= "" then
                local x = GetUnitX(target)
                local y = GetUnitY(target)
                DestroyEffect(AddSpecialEffect(LANDING_EFFECT, x, y))
            end

            KnockupInstance._instances[target] = nil
            
            local index = KnockupInstance._index[target]
            KnockupInstance._index[target] = nil

            if index then
                local lastIndex = #KnockupInstance._list
                if index ~= lastIndex then
                    local lastInst = KnockupInstance._list[lastIndex]
                    KnockupInstance._list[index] = lastInst
                    KnockupInstance._index[lastInst.target] = index
                end
                KnockupInstance._list[lastIndex] = nil
            end

            -- Stop loop if no active knockups
            if #KnockupInstance._list == 0 then
                PauseTimer(TIMER)
            end

            return true
        end

        return false
    end

    ---@param init number
    ---@param peak number
    ---@param base number
    function KnockupInstance.calculateApex (init, peak, base)
        return (init + peak) * 2.0 - 0.5 * (init + base)
    end

    ---@type table<unit, boolean>
    KnockupInstance._immune = {}

    function KnockupInstance.SetImmune(unit, flag)
        if flag then
            KnockupInstance._immune[unit] = true
        else
            KnockupInstance._immune[unit] = nil
        end
    end

    function KnockupInstance.IsImmune(unit)
        return KnockupInstance._immune[unit] == true
    end

    function KnockupInstance.GetRemaining(unit)
        local inst = KnockupInstance._instances[unit]
        if inst then
            return inst.duration - inst.counter
        end
        return 0.0
    end

    --======================
    -- API
    --======================

    ---@param target unit
    ---@param height number
    ---@param duration number
    ---@return boolean -- true if applied successfully
    ApplyKnockup = function(target, height, duration)
        if height <= 0. then
            height = DEFAULT_KNOCKUP_HEIGHT
        end

        if height > MAX_KNOCKUP_HEIGHT then
            height = MAX_KNOCKUP_HEIGHT
        end

        if duration <= 0. then
            duration = DEFAULT_KNOCKUP_DURATION
        end

        return KnockupInstance.create(target, height, duration) ~= nil
    end

    ---@param target unit
    ---@return boolean -- true if applied successfully
    RemoveKnockup = function(target)
        return KnockupInstance.remove(target) ~= nil
    end

    ---@param target unit
    ---@return boolean
    IsUnitKnockup = function(target)
        local inst = KnockupInstance._instances[target]
        return inst and inst.isAirborne or false
    end

    ---@param target unit
    ---@param flag boolean
    SetKnockupImmune = function(target, flag)
        KnockupInstance.SetImmune(target, flag)
    end

    ---@param target unit
    ---@return boolean
    IsKnockupImmune = function(target)
        return KnockupInstance.IsImmune(target)
    end

    ---@param target unit
    ---@return number
    GetKnockupRemaining = function(target)
        return KnockupInstance.GetRemaining(target)
    end
end

if Debug then Debug.endFile() end