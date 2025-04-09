if Debug then Debug.beginFile 'CustomShockwave' end
do
    local caster = {} ---@type unit
    local curDist = {} ---@type number
    local x1 = {} ---@type number
    local y1 = {} ---@type number
    local x2 = {} ---@type number
    local y2 = {} ---@type number
    local a = {} ---@type number
    local missile = {} ---@type effect
    local group = {} ---@type group
    local index = 0 ---@type number

    local timer = CreateTimer() ---@type timer

    local function OnCast()
        if (GetSpellAbilityId() == FourCC('A000')) then
            index = index + 1
            caster[index] = GetTriggerUnit()
            x1[index] = GetUnitX(caster[index])
            y1[index] = GetUnitY(caster[index])

            x2[index] = GetSpellTargetX()
            y2[index] = GetSpellTargetY()

            a[index] = Atan2(y2[index]-y1[index], x2[index]-x1[index]) * bj_RADTODEG

            curDist[index] = 0.0
            
            if group[index] == nil then
                group[index] = CreateGroup()
            end

            missile[index] = AddSpecialEffect("Abilities\\Spells\\Orc\\Shockwave\\ShockwaveMissile.mdl", x1[index], y1[index])
            BlzSetSpecialEffectHeight( missile[index], 50.0 )
            BlzSetSpecialEffectOrientation( missile[index], a[index] * bj_DEGTORAD, 0.0, 0.0 )

            if index == 1 then
                TimerStart(timer, 0.03125, true, function ()
                    local i = 1

                    while (i <= index) do
                        x1[i] = x1[i] + (1050 * 0.03125) * Cos(a[i] * bj_DEGTORAD)
                        y1[i] = y1[i] + (1050 * 0.03125) * Sin(a[i] * bj_DEGTORAD)

                        BlzSetSpecialEffectX( missile[i], x1[i] )
                        BlzSetSpecialEffectY( missile[i], y1[i] )

                        curDist[i] = curDist[i] + (1050 * 0.03125)

                        local g = CreateGroup() ---@type group
                        GroupEnumUnitsInRange(g, x1[i], y1[i], 125.0, nil)

                        local u = FirstOfGroup(g)
                        while (u ~= nil) do
                            u = FirstOfGroup(g)

                            if UnitAlive(u) and IsUnitEnemy(u, GetOwningPlayer(caster[i])) and not IsUnitType(u, UNIT_TYPE_STRUCTURE) and not IsUnitInGroup(u, group[i]) then
                                UnitDamageTarget(caster[i], u, (25 + (50 * GetUnitAbilityLevel(caster[i], FourCC('A000')))), true, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                                ApplyKnockup(u, 150, 0.7)
                                GroupAddUnit(group[i], u)     
                            end

                            GroupRemoveUnit(g, u)
                        end

                        if curDist[i] >= 800.0 then
                            DestroyEffect(missile[i])

                            caster[i] = caster[index]
                            caster[index] = nil

                            curDist[i] = curDist[index]
                            curDist[index] = nil

                            x1[i] = x1[index]
                            x1[index] = nil

                            y1[i] = y1[index]
                            y1[index] = nil

                            x2[i] = x2[index]
                            x2[index] = nil

                            y2[i] = y2[index]
                            y2[index] = nil

                            a[i] = a[index]
                            a[index] = nil

                            group[i] = group[index]
                            DestroyGroup(group[index])
                            group[index] = nil

                            missile[i] = missile[index]
                            missile[index] = nil

                            i = i - 1
                            index = index - 1
                            if index == 0 then
                                PauseTimer(timer)
                            end
                        end

                        DestroyGroup(g) 
                        g = nil ---@type group
                        
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