if Debug then Debug.beginFile 'CustomStomp' end
do
    local caster = {} ---@type unit
    local counter = {} ---@type number
    local counter2 = {} ---@type number
    local x = {} ---@type number
    local y = {} ---@type number
    local index = 0 ---@type number

    local timer = CreateTimer() ---@type timer

    ---@param c unit
    ---@param x number
    ---@param y number
    local function DamageUnitInArea(c, x, y)
        local g = CreateGroup()

        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Orc\\WarStomp\\WarStompCaster.mdl", x, y))
        GroupEnumUnitsInRange(g, x, y, (200 + (GetUnitAbilityLevel(c, FourCC('A001')) * 50)), nil)

        local u = FirstOfGroup(g)
        while (u ~= nil) do
            u = FirstOfGroup(g)

            if UnitAlive(u) and IsUnitEnemy(u, GetOwningPlayer(c)) and not IsUnitType(u, UNIT_TYPE_STRUCTURE) then
                UnitDamageTarget(c, u, (25 + (50 * GetUnitAbilityLevel(c, FourCC('A001')))), true, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                ApplyKnockup(u, 200, 0.9)
            end

            GroupRemoveUnit(g, u)
        end

        DestroyGroup(g)
        g = nil ---@type group
    end

    local function OnCast()
        if (GetSpellAbilityId() == FourCC('A001')) then
            index = index + 1
            caster[index] = GetTriggerUnit()
            x[index] = GetUnitX(caster[index])
            y[index] = GetUnitY(caster[index])

            counter[index] = 0.0
            counter2[index] = 0.0

            DamageUnitInArea(caster[index], x[index], y[index])

            if index == 1 then
                TimerStart(timer, 0.03125, true, function ()
                    local i = 1

                    while (i <= index) do
                        counter[i] = counter[i] + 0.03125
                        counter2[i] = counter2[i] + 0.03125

                        if counter2[i] >= 0.5 then
                            DamageUnitInArea(caster[i], x[i], y[i])
                            counter2[i] = .0
                        end

                        if counter[i] >= 1.0 then
                            caster[i] = caster[index]
                            caster[index] = nil

                            x[i] = x[index]
                            x[index] = nil

                            y[i] = y[index]
                            y[index] = nil

                            counter[i] = counter[index]
                            counter[index] = nil

                            counter2[i] = counter2[index]
                            counter2[index] = nil

                            i = i - 1
                            index = index - 1
                            if index == 0 then
                                PauseTimer(timer)
                            end
                        end
                        
                        i = i + 1
                    end
                end)
            end
        end
    end

    OnInit(function()
        local t = CreateTrigger() 
        TriggerAddCondition(t, Condition(OnCast))
        TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    end)

end

if Debug then Debug.endFile() end