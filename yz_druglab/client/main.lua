local labUIOpen = false
local currentLabId = nil
local savedWorldCoords = nil
local currentLabIdWhenInShell = nil
local keypadOpen = false
local entranceShellObj = nil
local labShellObj = nil
local labTerminalPropObj = nil
local transformSpotCoords = nil
local transformSpotTextUIShown = false
local transformLoopActive = false
local transformSpotLastPrompt = nil
local terminalCoords = nil
local terminalTextUIShown = false
local terminalLastPrompt = nil
local cachedClientLabs = {}

local function toVec3(t)
    if not t then return vector3(0, 0, 0) end
    if type(t) == 'vector3' then return t end
    return vector3(t.x or t[1] or 0, t.y or t[2] or 0, t.z or t[3] or 0)
end

local function debugLog(fmt, ...)
    if Config and Config.Debug then
        print(('[yz_druglab DEBUG] ' .. fmt):format(...))
    end
end

local function closeUI()
    if not labUIOpen then return end
    labUIOpen = false
    currentLabId = nil
    SendNUIMessage({ action = 'close' })
    CreateThread(function()
        Wait(400)
        SetNuiFocus(false, false)
    end)
end

local function sendLabDataToNUI(data)
    SendNUIMessage({ action = 'update', data = data })
end

local function openLabUI(labId)
    if labUIOpen then return end
    local id = labId or currentLabIdWhenInShell or 'lab1'
    currentLabId = id
    labUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = nil })
    lib.callback('yz_druglab:getLabData', false, function(data)
        if not labUIOpen then return end
        SendNUIMessage({ action = 'open', data = data or {} })
    end, id)
end

local function closeKeypad()
    if not keypadOpen then return end
    keypadOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeKeypad' })
end

RegisterNetEvent('yz_druglab:entranceDenied', function(reason)
    savedWorldCoords = nil
    currentLabIdWhenInShell = nil
    DoScreenFadeIn(500)
    lib.notify({ description = reason or 'Adgang nægtet', type = 'error' })
end)

local function spawnEntranceShellAndTeleport(entranceCoords, labId)
    local lab = cachedClientLabs[labId]
    local baseZ = Config.ShellBaseZEntrance or 2000.0
    if lab and lab.entranceShell and lab.entranceShell.model then
        local es = lab.entranceShell
        local modelHash = type(es.model) == 'number' and es.model or GetHashKey(tostring(es.model))
        local ok = pcall(function()
            lib.requestModel(modelHash, 10000)
        end)
        if not ok then
            lib.notify({ description = 'Kunne ikke loade indgangsshell (' .. tostring(es.model) .. '). Tjek at housingshells er startet og model-navnet matcher din pack.', type = 'error' })
        elseif IsModelValid(modelHash) then
            if entranceShellObj and DoesEntityExist(entranceShellObj) then
                DeleteEntity(entranceShellObj)
                entranceShellObj = nil
            end
            local pos = vector3(0.0, 0.0, baseZ) + toVec3(es.pos)
            entranceShellObj = CreateObjectNoOffset(modelHash, pos.x, pos.y, pos.z, false, false, false)
            if entranceShellObj and entranceShellObj ~= 0 then
                SetEntityHeading(entranceShellObj, 0.0)
                FreezeEntityPosition(entranceShellObj, true)
                while not DoesEntityExist(entranceShellObj) do Wait(10) end
                Wait(200)
            end
            SetModelAsNoLongerNeeded(modelHash)
        else
            lib.notify({ description = 'Ugyldig shell-model: ' .. tostring(es.model) .. '. Ret model i config efter din housingshells-pack.', type = 'error' })
        end
    end
    local c = entranceCoords
    local x, y, z, w = c.x or c[1], c.y or c[2], c.z or c[3], c.w or c[4] or 0.0
    RequestCollisionAtCoord(x, y, z)
    local timeout = 0
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and timeout < 100 do Wait(10) timeout = timeout + 1 end
    SetEntityCoords(PlayerPedId(), x, y, z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), w)
    DoScreenFadeIn(800)
end

RegisterNetEvent('yz_druglab:entranceCoords', function(entranceCoords, labId)
    if not entranceCoords then return end
    spawnEntranceShellAndTeleport(entranceCoords, labId or currentLabIdWhenInShell)
end)

local function enterLabInterior(labId, lab, labCoords)
    if not lab or not labCoords then return end
    local baseZLab = Config.ShellBaseZLab or 2100.0
    if lab.labShell and lab.labShell.model then
        local ls = lab.labShell
        local modelHash = type(ls.model) == 'number' and ls.model or GetHashKey(tostring(ls.model))
        local ok = pcall(function()
            lib.requestModel(modelHash, 10000)
        end)
        if not ok then
            lib.notify({ description = 'Kunne ikke loade lab-shell (' .. tostring(ls.model) .. '). Tjek model-navn i config.', type = 'error' })
        elseif IsModelValid(modelHash) then
            if labShellObj and DoesEntityExist(labShellObj) then
                DeleteEntity(labShellObj)
                labShellObj = nil
            end
            local pos = vector3(0.0, 0.0, baseZLab) + toVec3(ls.pos)
            labShellObj = CreateObjectNoOffset(modelHash, pos.x, pos.y, pos.z, false, false, false)
            if labShellObj and labShellObj ~= 0 then
                SetEntityHeading(labShellObj, 0.0)
                FreezeEntityPosition(labShellObj, true)
                while not DoesEntityExist(labShellObj) do Wait(10) end
                Wait(200)
            end
            SetModelAsNoLongerNeeded(modelHash)
            if labTerminalPropObj and DoesEntityExist(labTerminalPropObj) then
                DeleteEntity(labTerminalPropObj)
                labTerminalPropObj = nil
            end
            local tp = ls.terminalProp
            local tpo = ls.terminalPropOffset
            if tp and tpo then
                local tx = (tpo.x or tpo[1] or 0) + (pos.x or 0)
                local ty = (tpo.y or tpo[2] or 0) + (pos.y or 0)
                local tz = (tpo.z or tpo[3] or 0) + (pos.z or 0)
                local tw = tpo.w or tpo[4] or 0.0
                local th = type(tp) == 'number' and tp or GetHashKey(tostring(tp))
                pcall(function()
                    lib.requestModel(th, 5000)
                    if IsModelValid(th) then
                        labTerminalPropObj = CreateObjectNoOffset(th, tx, ty, tz, false, false, false)
                        if labTerminalPropObj and labTerminalPropObj ~= 0 then
                            SetEntityHeading(labTerminalPropObj, tw)
                            FreezeEntityPosition(labTerminalPropObj, true)
                            SetModelAsNoLongerNeeded(th)
                        end
                    end
                end)
            end
        end
    end
    local c = labCoords
    local x, y, z, w = c.x or c[1], c.y or c[2], c.z or c[3], c.w or c[4] or 0.0
    RequestCollisionAtCoord(x, y, z)
    local timeout = 0
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and timeout < 100 do Wait(10) timeout = timeout + 1 end
    SetEntityCoords(PlayerPedId(), x, y, z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), w)
    Wait(100)
    pcall(function() exports.ox_target:removeZone('yz_druglab_terminal_zone_current') end)
    if lab.labShell then
        local ls = lab.labShell
        local tpo = ls.terminalPropOffset or (Config.TerminalDefaultOffset)
        local sp = toVec3(ls.pos)
        local tx = (tpo.x or tpo[1] or 0) + (sp.x or 0)
        local ty = (tpo.y or tpo[2] or 0) + (sp.y or 0)
        local tz = baseZLab + (tpo.z or tpo[3] or 0) + (sp.z or 0)
        terminalCoords = vector3(tx, ty, tz)
    else
        terminalCoords = nil
    end
    if lab.labShell then
        local ls = lab.labShell
        local model = (ls.model and tostring(ls.model)) or nil
        local off = nil
        if model and Config.TransformSpotByShell and Config.TransformSpotByShell[model] then
            off = Config.TransformSpotByShell[model]
        end
        off = off or ls.transformSpotOffset or Config.TransformSpotOffset
        if off then
            local sp = toVec3(ls.pos)
            transformSpotCoords = vector3(
                (sp.x or 0) + (off.x or off[1] or 0),
                (sp.y or 0) + (off.y or off[2] or 0),
                baseZLab + (sp.z or 0) + (off.z or off[3] or 0)
            )
        else
            transformSpotCoords = nil
        end
    else
        transformSpotCoords = nil
    end
    pcall(function() exports.ox_target:removeZone('yz_druglab_exit_zone_current') end)
    if lab.labShell and labId then
        local ls = lab.labShell
        local eo = ls.entryOffset or ls.playerOffset or ls.coords
        local ex = (eo and (eo.x or eo[1])) or 0.0
        local ey = (eo and (eo.y or eo[2])) or 0.0
        local ez = baseZLab + (eo and (eo.z or eo[3]) or 0)
        local labIdExit = currentLabIdWhenInShell or labId
        pcall(function()
            exports.ox_target:addBoxZone({
                name = 'yz_druglab_exit_zone_current',
                coords = vector3(ex, ey, ez),
                size = vector3(1.2, 1.2, 1.5),
                rotation = (eo and (eo.w or eo[4])) or 0,
                options = {
                    {
                        name = 'yz_druglab_exit',
                        icon = 'fa-solid fa-door-open',
                        label = 'Forlad lab',
                        onSelect = function()
                            if currentLabIdWhenInShell == labIdExit then
                                TriggerServerEvent('yz_druglab:exitLab', labIdExit)
                            end
                        end,
                    },
                },
            })
        end)
    end
end

RegisterNetEvent('yz_druglab:codeResult', function(success, labCoords, labId)
    closeKeypad()
    if not success then
        lib.notify({ description = 'Forkert kode', type = 'error' })
        return
    end
    debugLog('codeResult: success=%s labId=%s currentLabIdWhenInShell=%s', tostring(success), tostring(labId), tostring(currentLabIdWhenInShell))
    if not labCoords or not currentLabIdWhenInShell then return end
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    if entranceShellObj and DoesEntityExist(entranceShellObj) then
        DeleteEntity(entranceShellObj)
        entranceShellObj = nil
    end
    local lab = cachedClientLabs[labId or currentLabIdWhenInShell]
    enterLabInterior(labId or currentLabIdWhenInShell, lab, labCoords)
    DoScreenFadeIn(800)
    local pos = GetEntityCoords(PlayerPedId())
    local px, py, pz = pos.x or pos[1], pos.y or pos[2], pos.z or pos[3]
    print(('[yz_druglab CLIENT] Du er nu i lab %s. Coords: %.2f, %.2f, %.2f – gå hen til laptoppen og brug ox_target (øje-ikon).'):format(tostring(currentLabIdWhenInShell), px, py, pz))
end)

RegisterNetEvent('yz_druglab:restoreInLab', function(labId, labCoords, labPayload)
    if not labId or not labCoords then return end
    currentLabIdWhenInShell = labId
    if labPayload then
        cachedClientLabs[labId] = labPayload
    end
    local lab = cachedClientLabs[labId]
    if not lab then return end
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(10) end
    enterLabInterior(labId, lab, labCoords)
    Wait(200)
    DoScreenFadeIn(600)
    print(('[yz_druglab CLIENT] Genoprettet i lab %s efter genstart.'):format(tostring(labId)))
end)

RegisterNetEvent('yz_druglab:exitConfirm', function()
    if not savedWorldCoords then return end
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    pcall(function() exports.ox_target:removeZone('yz_druglab_terminal_zone_current') end)
    pcall(function() exports.ox_target:removeZone('yz_druglab_exit_zone_current') end)
    if labShellObj and DoesEntityExist(labShellObj) then
        DeleteEntity(labShellObj)
        labShellObj = nil
    end
    if labTerminalPropObj and DoesEntityExist(labTerminalPropObj) then
        DeleteEntity(labTerminalPropObj)
        labTerminalPropObj = nil
    end
    local c = savedWorldCoords
    SetEntityCoords(PlayerPedId(), c.x, c.y, c.z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), c.w or 0.0)
    savedWorldCoords = nil
    currentLabIdWhenInShell = nil
    transformSpotCoords = nil
    terminalCoords = nil
    if transformSpotTextUIShown or terminalTextUIShown then
        transformSpotTextUIShown = false
        terminalTextUIShown = false
        terminalLastPrompt = nil
        lib.hideTextUI()
    end
    Wait(100)
    DoScreenFadeIn(800)
end)

local transformSpotMarkerCache = nil
local terminalMarkerCache = nil

CreateThread(function()
    while true do
        local waitMs = 500
        if not ((transformSpotCoords or terminalCoords) and currentLabIdWhenInShell) then
            transformSpotMarkerCache = nil
            terminalMarkerCache = nil
        end
        if (transformSpotCoords or terminalCoords) and currentLabIdWhenInShell then
            waitMs = 120
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local px = pos.x or pos[1]
            local py = pos.y or pos[2]
            local pz = pos.z or pos[3]

            local inTransformZone = false
            local transformRadius = (Config.TransformSpotRadius or 1.5)
            if transformSpotCoords then
                if not transformSpotMarkerCache then
                    local cfg = Config.TransformSpotMarker or {}
                    transformSpotMarkerCache = {
                        draw = cfg.draw ~= false,
                        mType = cfg.type or 27,
                        sx = (cfg.scale and (cfg.scale.x or cfg.scale[1])) or 0.8,
                        sy = (cfg.scale and (cfg.scale.y or cfg.scale[2])) or 0.8,
                        sz = (cfg.scale and (cfg.scale.z or cfg.scale[3])) or 0.5,
                        r = (cfg.color and (cfg.color.r or cfg.color[1])) or 100,
                        g = (cfg.color and (cfg.color.g or cfg.color[2])) or 200,
                        b = (cfg.color and (cfg.color.b or cfg.color[3])) or 100,
                        a = (cfg.color and (cfg.color.a or cfg.color[4])) or 150,
                    }
                end
                if transformSpotMarkerCache.draw then
                    local m = transformSpotMarkerCache
                    DrawMarker(m.mType, transformSpotCoords.x, transformSpotCoords.y, (transformSpotCoords.z or transformSpotCoords[3]) - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, m.sx, m.sy, m.sz, m.r, m.g, m.b, m.a, false, false, 2, false, nil, nil, false)
                end
                local tx = transformSpotCoords.x or transformSpotCoords[1]
                local ty = transformSpotCoords.y or transformSpotCoords[2]
                local tz = transformSpotCoords.z or transformSpotCoords[3]
                local dist = #(vector3(px, py, pz) - vector3(tx, ty, tz))
                inTransformZone = (dist < transformRadius)
                if not inTransformZone then transformLoopActive = false end
            end

            if inTransformZone then
                waitMs = 0
                local prompt = transformLoopActive and (Config.TransformSpotStopPrompt or '[E] Stop omdannelse') or (Config.TransformSpotPrompt or '[E] For at omdanne')
                if prompt ~= transformSpotLastPrompt then
                    transformSpotLastPrompt = prompt
                    lib.showTextUI(prompt, { position = 'left-center' })
                end
                transformSpotTextUIShown = true
                if terminalTextUIShown then terminalTextUIShown = false; terminalLastPrompt = nil end
                if IsControlJustPressed(0, 38) then
                    if transformLoopActive then
                        transformLoopActive = false
                    elseif not lib.progressActive() then
                        local canPack, amountRequired = lib.callback.await('yz_druglab:canPack', false, currentLabIdWhenInShell)
                        if not canPack then
                            local lab = cachedClientLabs[currentLabIdWhenInShell]
                            local cfg = lab and Config.PackingByDrugType and Config.PackingByDrugType[lab.drug_type]
                            local stofLabel = (cfg and cfg.label) or 'stof'
                            lib.notify({ description = ('Du mangler %dx %s for at pakke.'):format(amountRequired or 20, stofLabel), type = 'error' })
                        else
                            transformLoopActive = true
                            local txc, tyc, tzc = transformSpotCoords.x or transformSpotCoords[1], transformSpotCoords.y or transformSpotCoords[2], transformSpotCoords.z or transformSpotCoords[3]
                            CreateThread(function()
                                local duration = Config.PackDurationMs or 10000
                                local anim = Config.PackProgressAnim or { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 }
                                local p = PlayerPedId()
                                while transformLoopActive and transformSpotCoords and currentLabIdWhenInShell do
                                    local pos2 = GetEntityCoords(p)
                                    local d = #(vector3(pos2.x or pos2[1], pos2.y or pos2[2], pos2.z or pos2[3]) - vector3(txc, tyc, tzc))
                                    if d >= transformRadius then break end
                                    local canPackNow = lib.callback.await('yz_druglab:canPack', false, currentLabIdWhenInShell)
                                    if not canPackNow then break end
                                    local success = lib.progressCircle({
                                        duration = duration,
                                        label = 'Pakker stof...',
                                        position = 'bottom',
                                        useWhileDead = false,
                                        canCancel = true,
                                        disable = { move = true, car = true },
                                        anim = anim,
                                    })
                                    if not success then break end
                                    TriggerServerEvent('yz_druglab:packDrugs', currentLabIdWhenInShell)
                                    Wait(200)
                                end
                                ClearPedTasks(p)
                            end)
                        end
                    end
                end
            elseif terminalCoords then
                if transformSpotTextUIShown then transformSpotTextUIShown = false; transformSpotLastPrompt = nil; lib.hideTextUI() end
                local termRadius = (Config.TerminalSpotRadius or 2.0)
                if not terminalMarkerCache then
                    local cfg = Config.TerminalMarker or {}
                    terminalMarkerCache = {
                        draw = cfg.draw == true,
                        mType = cfg.type or 27,
                        sx = (cfg.scale and (cfg.scale.x or cfg.scale[1])) or 0.6,
                        sy = (cfg.scale and (cfg.scale.y or cfg.scale[2])) or 0.6,
                        sz = (cfg.scale and (cfg.scale.z or cfg.scale[3])) or 0.3,
                        r = (cfg.color and (cfg.color.r or cfg.color[1])) or 111,
                        g = (cfg.color and (cfg.color.g or cfg.color[2])) or 73,
                        b = (cfg.color and (cfg.color.b or cfg.color[3])) or 121,
                        a = (cfg.color and (cfg.color.a or cfg.color[4])) or 150,
                    }
                end
                if terminalMarkerCache.draw then
                    local m = terminalMarkerCache
                    DrawMarker(m.mType, terminalCoords.x, terminalCoords.y, (terminalCoords.z or terminalCoords[3]) - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, m.sx, m.sy, m.sz, m.r, m.g, m.b, m.a, false, false, 2, false, nil, nil, false)
                end
                local distTerm = #(vector3(px, py, pz) - vector3(terminalCoords.x, terminalCoords.y, terminalCoords.z or terminalCoords[3]))
                local inTerminalZone = (distTerm < termRadius)
                if inTerminalZone then
                    waitMs = 0
                    local prompt = Config.TerminalSpotPrompt or '[E] Åbn lab terminal'
                    if prompt ~= terminalLastPrompt then
                        terminalLastPrompt = prompt
                        lib.showTextUI(prompt, { position = 'left-center' })
                    end
                    terminalTextUIShown = true
                    if transformSpotTextUIShown then transformSpotTextUIShown = false; transformSpotLastPrompt = nil end
                    if IsControlJustPressed(0, 38) and not labUIOpen then
                        openLabUI(currentLabIdWhenInShell)
                    end
                else
                    if terminalTextUIShown then
                        terminalTextUIShown = false
                        terminalLastPrompt = nil
                        lib.hideTextUI()
                    end
                end
            else
                if transformSpotTextUIShown or terminalTextUIShown then
                    transformSpotTextUIShown = false
                    terminalTextUIShown = false
                    transformSpotLastPrompt = nil
                    terminalLastPrompt = nil
                    lib.hideTextUI()
                end
            end
        end
        Wait(waitMs)
    end
end)

RegisterNetEvent('yz_druglab:labUpdated', function(labId, data)
    if not labUIOpen or currentLabId ~= labId then return end
    sendLabDataToNUI(data)
end)

CreateThread(function()
    while true do
        if labUIOpen and currentLabId then
            Wait(2000)
            if not labUIOpen then break end
            lib.callback('yz_druglab:getLabData', false, function(data)
                if labUIOpen then sendLabDataToNUI(data) end
            end, currentLabId)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(4000)
        if not Config.Debug or not currentLabIdWhenInShell then goto continue end
        local lab = cachedClientLabs[currentLabIdWhenInShell]
        if not lab or not lab.labShell or not lab.labShell.terminalPropOffset then goto continue end
        local ls = lab.labShell
        local baseZLab = Config.ShellBaseZLab or 2100.0
        local sp = toVec3(ls.pos)
        local tpo = ls.terminalPropOffset
        local tx = (tpo.x or tpo[1] or 0) + (sp.x or 0)
        local ty = (tpo.y or tpo[2] or 0) + (sp.y or 0)
        local tz = baseZLab + (tpo.z or tpo[3] or 0) + (sp.z or 0)
        local ped = PlayerPedId()
        local px, py, pz = GetEntityCoords(ped)
        local dist = #(vector3(px, py, pz) - vector3(tx, ty, tz))
        print(('[yz_druglab DEBUG] I lab: %s | Din pos: %.2f, %.2f, %.2f | Terminal-zone center: %.2f, %.2f, %.2f | Afstand: %.2f (skal være < ~0.8 for at zone trigge)'):format(tostring(currentLabIdWhenInShell), px, py, pz, tx, ty, tz, dist))
        ::continue::
    end
end)

RegisterNUICallback('startProduction', function(_, cb)
    if currentLabId then TriggerServerEvent('yz_druglab:startProduction', currentLabId) end
    cb('ok')
end)
RegisterNUICallback('pauseProduction', function(_, cb)
    if currentLabId then TriggerServerEvent('yz_druglab:pauseProduction', currentLabId) end
    cb('ok')
end)
RegisterNUICallback('stopProduction', function(_, cb)
    if currentLabId then TriggerServerEvent('yz_druglab:stopProduction', currentLabId) end
    cb('ok')
end)
RegisterNUICallback('closeUI', function(_, cb)
    closeUI()
    cb('ok')
end)
RegisterNUICallback('openLabStash', function(_, cb)
    local id = currentLabId or currentLabIdWhenInShell
    if id then
        pcall(function()
            exports.ox_inventory:openInventory('stash', { id = 'yz_druglab_lab', owner = id })
        end)
    end
    cb('ok')
end)
RegisterNUICallback('addLabMember', function(data, cb)
    if not currentLabId then cb('ok') return end
    local ident = type(data) == 'table' and (data.identifier or data.id) or tostring(data or '')
    local name = type(data) == 'table' and data.playerName or ''
    TriggerServerEvent('yz_druglab:addLabMember', currentLabId, ident, name)
    cb('ok')
end)
RegisterNUICallback('removeLabMember', function(data, cb)
    if not currentLabId then cb('ok') return end
    local ident = type(data) == 'table' and (data.identifier or data.id) or tostring(data or '')
    TriggerServerEvent('yz_druglab:removeLabMember', currentLabId, ident)
    cb('ok')
end)
RegisterNUICallback('changeLabCode', function(data, cb)
    local id = currentLabId or currentLabIdWhenInShell
    if not id then cb('ok') return end
    local code = type(data) == 'table' and (data.code or data.password) or tostring(data or '')
    TriggerServerEvent('yz_druglab:setLabCode', id, code)
    cb('ok')
end)

RegisterNUICallback('submitCode', function(data, cb)
    local code = type(data) == 'table' and (data.code or data.password) or tostring(data or '')
    if currentLabIdWhenInShell then
        TriggerServerEvent('yz_druglab:checkCode', currentLabIdWhenInShell, code)
    end
    cb('ok')
end)
RegisterNUICallback('closeKeypad', function(_, cb)
    currentLabIdWhenInShell = nil
    closeKeypad()
    cb('ok')
end)

local addedLabIds = {}
local labBlips = {}

local function removeLabZones()
    for _, labId in ipairs(addedLabIds) do
        pcall(function()
            exports.ox_target:removeZone('yz_druglab_world_' .. labId)
            exports.ox_target:removeZone('yz_druglab_keypad_' .. labId)
        end)
    end
    addedLabIds = {}
    pcall(function() exports.ox_target:removeZone('yz_druglab_terminal_zone_current') end)
    for labId, blip in pairs(labBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    labBlips = {}
end

local function openBuyLabAtEntrance(lab)
    if not lab or not lab.id then return end
    local drugLabel = lab.drug_type
    for _, d in ipairs(Config.DrugTypes or {}) do
        if d.id == lab.drug_type then drugLabel = d.label break end
    end
    local price = tonumber(lab.price) or 0
    local content = string.format([[
- **Lab type:** %s
- **Pris:** %s kr

Bekræft for at gennemføre købet.
]], drugLabel, price)
    local confirm = lib.alertDialog({
        header = 'Køb druglab',
        content = content,
        centered = true,
        cancel = true,
    })
    if confirm == 'confirm' then
        TriggerServerEvent('yz_druglab:buyLabAtEntrance', lab.id)
        CreateThread(function()
            Wait(800)
            TriggerServerEvent('yz_druglab:requestLabEntrances')
        end)
    end
end

local function buildLabZones(labs, myIdentifier)
    removeLabZones()
    cachedClientLabs = {}
    local count = labs and #labs or 0
    print(('[yz_druglab CLIENT] buildLabZones: modtaget %s lab(s)'):format(count))
    if count == 0 then
        print('[yz_druglab CLIENT] Ingen labs – ingen ox_target zoner oprettet. Opret et lab med /opretdruglab først.')
        return
    end
    for _, lab in ipairs(labs or {}) do
        cachedClientLabs[lab.id or 'lab1'] = lab
    end
    local sizeWorld = Config.WorldEntranceZoneSize or vector3(1.5, 1.5, 2.0)
    local sizeKeypad = Config.EntranceKeypadZoneSize or vector3(1.0, 1.0, 2.0)
    local sizeLab = Config.LabZoneSize or vector3(2.0, 2.0, 2.0)
    local blipCfg = Config.LabBlip or {}
    for idx, lab in ipairs(labs or {}) do
        local labId = lab.id or 'lab1'
        addedLabIds[#addedLabIds + 1] = labId
        local isOwner = not not (myIdentifier and lab.owner_identifier and lab.owner_identifier == myIdentifier)

        local we = lab.worldEntrance
        if type(we) == 'table' then we = vector4(we.x or 0, we.y or 0, we.z or 0, we.w or 0) end
        if we then
            print(('[yz_druglab CLIENT] Tilføjer world-zone for lab %s ved %.1f, %.1f, %.1f (ejer=%s)'):format(labId, we.x, we.y, we.z, tostring(isOwner)))
            local options = {
                {
                    name = 'yz_druglab_enter',
                    icon = 'fa-solid fa-door-open',
                    label = 'Gå ind',
                    onSelect = function()
                        if currentLabIdWhenInShell or keypadOpen then return end
                        local ped = PlayerPedId()
                        savedWorldCoords = vector4(GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z, GetEntityHeading(ped))
                        currentLabIdWhenInShell = labId
                        keypadOpen = true
                        SetNuiFocus(true, true)
                        SendNUIMessage({ action = 'openKeypad', labId = labId })
                    end,
                },
            }
            if not isOwner then
                options[#options + 1] = {
                    name = 'yz_druglab_buy_at_entrance',
                    icon = 'fa-solid fa-sack-dollar',
                    label = 'Køb',
                    onSelect = function()
                        openBuyLabAtEntrance(lab)
                    end,
                }
            end
            local ok, err = pcall(function()
                exports.ox_target:addBoxZone({
                    name = 'yz_druglab_world_' .. labId,
                    coords = vector3(we.x, we.y, we.z),
                    size = sizeWorld,
                    rotation = we.w or 0,
                    options = options,
                })
            end)
            if not ok then
                print(('[yz_druglab CLIENT FEJL] addBoxZone world for %s: %s'):format(labId, tostring(err)))
            end
            if isOwner then
                local blip = AddBlipForCoord(we.x, we.y, we.z)
                if blip and blip ~= 0 then
                    SetBlipSprite(blip, blipCfg.sprite or 514)
                    SetBlipColour(blip, blipCfg.color or 2)
                    SetBlipScale(blip, blipCfg.scale or 0.9)
                    SetBlipAsShortRange(blip, true)
                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentString(blipCfg.label or 'Mit druglab')
                    EndTextCommandSetBlipName(blip)
                    labBlips[labId] = blip
                end
            end
        else
            print(('[yz_druglab CLIENT] Lab %s har ingen worldEntrance – springer world-zone over'):format(labId))
        end

        local es = lab.entranceShell
        if es then
            local baseZ = Config.ShellBaseZEntrance or 2000.0
            local po = es.playerOffset or es.coords
            local kx = (po and (po.x or po[1])) or 0.0
            local ky = (po and (po.y or po[2])) or 0.0
            local kz = baseZ + (po and (po.z or po[3]) or 0)
            exports.ox_target:addBoxZone({
                name = 'yz_druglab_keypad_' .. labId,
                coords = vector3(kx, ky, kz),
                size = sizeKeypad,
                rotation = (po and (po.w or po[4])) or 0,
                options = {
                    {
                        name = 'yz_druglab_keypad',
                        icon = 'fa-solid fa-keyboard',
                        label = 'Indtast kode',
                        onSelect = function()
                            if keypadOpen then return end
                            keypadOpen = true
                            SetNuiFocus(true, true)
                            SendNUIMessage({ action = 'openKeypad', labId = labId })
                        end,
                    },
                },
            })
        end

    end
end

local refreshLabsReceived = false

RegisterNetEvent('yz_druglab:refreshLabs', function(labs)
    refreshLabsReceived = true
    local n = labs and #labs or 0
    CreateThread(function()
        local myId = nil
        pcall(function() myId = lib.callback.await('yz_druglab:getMyIdentifier') end)
        pcall(buildLabZones, labs, myId)
    end)
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('yz_druglab:requestLabEntrances')
    Wait(2500)
    if not currentLabIdWhenInShell then
        TriggerServerEvent('yz_druglab:requestRestoreIfInLab')
    end
    Wait(3000)
    if not refreshLabsReceived and Config.Debug then
        print('[yz_druglab CLIENT] Ingen refreshLabs modtaget efter 5 sek.')
    end
end)

local function openBuyLabMenu()
    local price = lib.callback.await('yz_druglab:getLabPrice')
    if price and price > 0 then
        local confirm = lib.alertDialog({
            header = 'Køb druglab',
            content = ('Det koster **%s kr**. Fortsæt?'):format(price),
            centered = true,
            cancel = true,
        })
        if confirm ~= 'confirm' then return end
    end
    local drugTypes = lib.callback.await('yz_druglab:getDrugTypes')
    local gangJobs = lib.callback.await('yz_druglab:getGangJobs')
    if #drugTypes == 0 or #gangJobs == 0 then
        lib.notify({ description = 'Ingen stoftyper eller bander konfigureret.', type = 'error' })
        return
    end
    local drugOptions = {}
    for _, d in ipairs(drugTypes) do
        drugOptions[#drugOptions + 1] = { value = d.id, label = d.label }
    end
    local gangOptions = {}
    for _, g in ipairs(gangJobs) do
        gangOptions[#gangOptions + 1] = { value = g.name, label = g.label or g.name }
    end
    local title = (price and price > 0) and ('Køb druglab (%s kr)'):format(price) or 'Køb druglab'
    local input = lib.inputDialog(title, {
        { type = 'select', label = 'Stof (yz-drug)', options = drugOptions, required = true },
        { type = 'select', label = 'Bande (job)', options = gangOptions, required = true },
    })
    if not input or not input[1] or not input[2] then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    TriggerServerEvent('yz_druglab:buyLab', input[1], input[2], { x = coords.x, y = coords.y, z = coords.z, w = heading })
    CreateThread(function()
        Wait(800)
        TriggerServerEvent('yz_druglab:requestLabEntrances')
    end)
end

if Config.LabSellerZone and Config.LabSellerZone.coords then
    local sz = Config.LabSellerZone
    local c = sz.coords
    local size = sz.size or vector3(2.0, 2.0, 2.0)
    local rot = sz.rotation or 0
    exports.ox_target:addBoxZone({
        name = 'yz_druglab_seller',
        coords = c,
        size = size,
        rotation = rot,
        options = {
            {
                name = 'yz_druglab_buy',
                icon = 'fa-solid fa-sack-dollar',
                label = 'Køb druglab',
                onSelect = function()
                    CreateThread(openBuyLabMenu)
                end,
            },
        },
    })
end

local function dbg(fmt, ...)
    if Config.Debug then
        print(('[yz_druglab CLIENT] ' .. fmt):format(...))
    end
end

local function openCreateLabMenu()
    SetNuiFocus(false, false)
    Wait(0)
    local ok, data = pcall(lib.callback.await, 'yz_druglab:getCreateLabFormData')
    if not ok then
        if Config.Debug then print('^1[yz_druglab]^7 Callback fejlede: ' .. tostring(data)) end
        lib.notify({ description = 'Fejl ved hentning: ' .. tostring(data), type = 'error' })
        return
    end
    if not data or not data.canCreate then
        lib.notify({ description = 'Du har ikke rettigheder til at oprette druglabs.', type = 'error' })
        return
    end
    local drugTypes = data.drugTypes or {}
    local gangJobs = data.gangJobs or {}
    if #drugTypes == 0 or #gangJobs == 0 then
        lib.notify({ description = 'Ingen stoftyper eller bander konfigureret.', type = 'error' })
        return
    end
    local drugOptions, gangOptions = {}, {}
    for i = 1, #drugTypes do
        local d = drugTypes[i]
        drugOptions[i] = { value = d.id, label = d.label }
    end
    for i = 1, #gangJobs do
        local g = gangJobs[i]
        gangOptions[i] = { value = g.name, label = g.label or g.name }
    end
    local defaultPrice = (data and data.defaultPrice) or (Config.LabPrice or 0)
    local input = lib.inputDialog('Opret druglab', {
        { type = 'select', label = 'Stof', options = drugOptions, required = true },
        { type = 'select', label = 'Bande', options = gangOptions, required = true },
        { type = 'number', label = 'Pris', default = defaultPrice, min = 0, required = true },
    })
    if not input or not input[1] or not input[2] then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local amount = (input[3] ~= nil and input[3] >= 0) and math.floor(tonumber(input[3]) or 0) or 0
    TriggerServerEvent('yz_druglab:createLab', input[1], input[2], { x = coords.x, y = coords.y, z = coords.z, w = heading }, amount)
    CreateThread(function()
        Wait(800)
        TriggerServerEvent('yz_druglab:requestLabEntrances')
    end)
end

local function openLabsList()
    SetNuiFocus(false, false)
    Wait(0)
    local labs = lib.callback.await('yz_druglab:getLabsList')
    if not labs or #labs == 0 then
        lib.notify({ description = 'Der er ingen druglabs.', type = 'inform' })
        return
    end
    local canDelete = lib.callback.await('yz_druglab:canCreateLab')
    local drugLabels = {}
    for _, d in ipairs(Config.DrugTypes or {}) do drugLabels[d.id] = d.label end
    local options = {}
    for _, lab in ipairs(labs) do
        local drugLabel = drugLabels[lab.drug_type] or lab.drug_type
        local desc = ('Pos: %.0f, %.0f, %.0f | Kode: %s | Pris: %s kr'):format(lab.x or 0, lab.y or 0, lab.z or 0, lab.code or '1234', lab.price and tostring(lab.price) or '0')
        options[#options + 1] = {
            title = ('Lab #%s – %s / %s'):format(lab.id, drugLabel, lab.job_name),
            description = desc,
            icon = 'flask',
            onSelect = function()
                if canDelete then
                    local confirm = lib.alertDialog({
                        header = 'Slet druglab',
                        content = ('Er du sikker på at du vil slette **Lab #%s** (%s / %s)?'):format(lab.id, drugLabel, lab.job_name),
                        centered = true,
                        cancel = true,
                    })
                    if confirm == 'confirm' then
                        TriggerServerEvent('yz_druglab:deleteLab', lab.id)
                    end
                else
                    lib.notify({ description = desc, type = 'inform' })
                end
            end,
        }
    end
    lib.registerContext({
        id = 'yz_druglab_list',
        title = 'Druglabs (' .. #labs .. ')',
        options = options,
    })
    lib.showContext('yz_druglab_list')
end

exports('openCreateLabMenu', function()
    CreateThread(function()
        local ok, err = pcall(openCreateLabMenu)
        if not ok and Config.Debug then print('^1[yz_druglab]^7 openCreateLabMenu: ' .. tostring(err)) end
        if not ok then lib.notify({ description = 'Fejl: ' .. tostring(err), type = 'error' }) end
    end)
end)
exports('openLabsList', function()
    CreateThread(openLabsList)
end)

RegisterNetEvent('yz_druglab:openCreateLabMenu', function()
    exports.yz_druglab:openCreateLabMenu()
end)
RegisterNetEvent('yz_druglab:openLabsList', function()
    exports.yz_druglab:openLabsList()
end)

RegisterCommand('opretdruglab', function()
    CreateThread(openCreateLabMenu)
end, false)
RegisterCommand('druglabs', function()
    CreateThread(openLabsList)
end, false)

CreateThread(function()
    while true do
        if labUIOpen then
            if IsControlJustReleased(0, 322) then
                closeUI()
            end
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            Wait(0)
        elseif keypadOpen then
            if IsControlJustReleased(0, 322) then
                closeKeypad()
            end
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            Wait(0)
        else
            Wait(300)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if labUIOpen or keypadOpen then
        SetNuiFocus(false, false)
    end
end)
