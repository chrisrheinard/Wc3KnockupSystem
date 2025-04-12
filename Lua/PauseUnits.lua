---@diagnostic disable: undefined-global
if Debug then Debug.beginFile 'PauseUnits' end --[[
        PauseUnits v1.1
    Lua version by Wrda
    https://www.hiveworkshop.com/threads/pauseunits.340457/


    Requires:
        - Global Init: https://www.hiveworkshop.com/threads/global-initialization.317099/ 
 
    ---------------------------------------------------------------
    -   Mimics BlzPauseUnitEx while providing an actual counter   -
    -   which is able to be manipulated.                          -
    -                                                             -
    -   Known issue from this native that fixed with this script: -
    -       - Pausing after reviving or any other form to come    -
    -   back to life wouldn't work while the unit was paused      -
    -   before the start of reviving and during it.               -
    -                                                             -
    -   Note: While pausing buildings work, buildings that are    -
    -    currently training a queue of units/researches aren't    -
    -    stopped in any shape or form. However, attempting to     -
    -    train/researc further things after a pause doesn't work, -
    -    as expected.                                             -
    ---------------------------------------------------------------
    API
        PauseUnits.pauseUnit(u:unit, flag:boolean)
            - Self-explanatory. Pausing the unit more than one time will result the counter rise up.
            - Unpausing does the reverse.
        PauseUnits.getUnitPauseCounter(u:unit)
            - Returns the pause counter of the unit.
        PauseUnits.setUnitPauseCounter(u:unit, new:integer)
            - Sets the unit pause counter to the new desired value while calling BlzPauseUnitEx internally.
            - O(n)
        PauseUnits.isUnitPaused(u)
            - Checks if the unit is paused.
]]
do
    PauseUnits = {}
    local paused = setmetatable({}, {__mode = "k",
        __index = function(_, k) return 0 end}) -- default counter as 0 while first time accessing by user or the system.
    local CUSTOM_DEFEND = FourCC('A000') -- Your custom defend ability

    ---Pauses the unit, with an internal counter. Calls BlzPauseUnitEx internally.
    ---@param u unit
    ---@param flag boolean
    function PauseUnits.pauseUnit(u, flag)
        if flag then
            paused[u] = paused[u] + 1
        else
            paused[u] = paused[u] - 1
        end
        BlzPauseUnitEx(u, flag)
    end
    ---Gets the pause counter of the unit.
    ---@param u unit
    ---@return integer
    function PauseUnits.getUnitPauseCounter(u)
        return paused[u]
    end
    ---Sets the pause counter of the unit to the new desired value. Calls BlzPauseUnitEx internally.
    ---O(n)
    ---@param u unit
    ---@param new integer
    function PauseUnits.setUnitPauseCounter(u, new)
        local sign = 0
        local flag = false
        local counter = paused[u]
        if new > counter then
            sign = 1
            flag = true
        elseif new < counter then
            sign = -1
            flag = false
        end
        while new ~= counter do
            counter = counter + sign
            BlzPauseUnitEx(u, flag)
        end
        paused[u] = counter
    end
    ---Checks if the unit is paused.
    ---O(n)
    ---@param u unit
    ---@return boolean
    function PauseUnits.isUnitPaused(u)
        return paused[u] > 0
    end

    --actions for events.
    local enterMapActions = function(u)
        local unit = u or GetTriggerUnit()
        UnitAddAbility(unit, CUSTOM_DEFEND)
        UnitMakeAbilityPermanent(unit, true, CUSTOM_DEFEND)
    end
    local deathActions = function()
        PauseUnits.setUnitPauseCounter(GetTriggerUnit(), 0)
    end
    --If unit has become alive again through reicarn, ressurect, animate dead
    local wasUnitRevived = Condition(function() return (GetIssuedOrderId() == 852056) and UnitAlive(GetTriggerUnit()) end)
    local unitRevivedActions = function()
        PauseUnits.setUnitPauseCounter(GetTriggerUnit(), 0)
    end
    OnTrigInit(function()
        for i = 0, GetBJMaxPlayers() - 1 do
            SetPlayerAbilityAvailable(Player(i), CUSTOM_DEFEND, false)
        end
        local area = CreateRegion()
        RegionAddRect(area, bj_mapInitialPlayableArea)
        local g = CreateGroup()
        GroupEnumUnitsInRect(g, bj_mapInitialPlayableArea, nil)
        ForGroup(g, function() enterMapActions(GetEnumUnit()) end)
        DestroyGroup(g)
        local enterMap = CreateTrigger() --register on map enter
        TriggerRegisterEnterRegion(enterMap, area, nil)
        TriggerAddAction(enterMap, enterMapActions)
        local death = CreateTrigger() --actual death
        TriggerRegisterAnyUnitEventBJ(death, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddAction(death, deathActions)
        local other = CreateTrigger() --finished reicarn, ressurect, started animate dead
        TriggerRegisterAnyUnitEventBJ(other, EVENT_PLAYER_UNIT_ISSUED_ORDER)
        TriggerAddCondition(other, wasUnitRevived)
        TriggerAddAction(other, unitRevivedActions)
    end)
end

if Debug then Debug.endFile() end