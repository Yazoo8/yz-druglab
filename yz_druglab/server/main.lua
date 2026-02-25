local ESX = nil
local labState = {}
local playerInLab = {}
local cachedLabEntrances = {}

CreateThread(function()
    while not ESX do
        local ok, err = pcall(function()
            ESX = exports['es_extended']:getSharedObject()
        end)
        if not ok or not ESX then Wait(500) else break end
    end
end)

local function d(fmt, ...)
    if not Config.Debug then return end
    print(('[yz_druglab] ' .. fmt):format(...))
end

local function sendDiscordWebhookSafe(url, payload)
    if not url or type(url) ~= 'string' or url:gsub('%s', '') == '' then return end
    CreateThread(function()
        pcall(function()
            local body = type(payload) == 'table' and json.encode(payload) or tostring(payload)
            if not body or body == '' then return end
            PerformHttpRequest(url, function() end, 'POST', body, { ['Content-Type'] = 'application/json' })
        end)
    end)
end

local function getPlayerInfoForLog(src)
    local name = GetPlayerName(src)
    if not name then name = 'Ukendt' end
    local ident = nil
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then ident = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier end
    end
    return name, ident or '–'
end

local function logDiscordCreateLab(src, labId, drugType, jobName, coords, price)
    local url = Config.DiscordWebhookCreateLab or Config.DiscordWebhookCreate or ''
    if url == '' then return end
    local name, ident = getPlayerInfoForLog(src)
    local cx = coords and (coords.x or coords[1]) or '–'
    local cy = coords and (coords.y or coords[2]) or '–'
    local cz = coords and (coords.z or coords[3]) or '–'
    sendDiscordWebhookSafe(url, {
        embeds = { {
            title = 'Druglab oprettet',
            color = 3066993,
            fields = {
                { name = 'Oprettet af', value = name .. '\n`' .. tostring(ident) .. '`', inline = true },
                { name = 'Lab ID', value = '`' .. tostring(labId) .. '`', inline = true },
                { name = 'Stof', value = tostring(drugType or '–'), inline = true },
                { name = 'Bande/job', value = tostring(jobName or '–'), inline = true },
                { name = 'Pris', value = tostring(price or 0) .. ' kr', inline = true },
                { name = 'Position', value = string.format('%.1f, %.1f, %.1f', cx, cy, cz), inline = false },
            },
        } },
    })
end

local function logDiscordBuyLab(src, labId, drugType, jobName, coords, price, atEntrance)
    local url = Config.DiscordWebhookBuyLab or Config.DiscordWebhookBuy or ''
    if url == '' then return end
    local name, ident = getPlayerInfoForLog(src)
    local title = atEntrance and 'Druglab købt (ved indgang)' or 'Druglab købt (nytt lab)'
    local fields = {
        { name = 'Køber', value = name .. '\n`' .. tostring(ident) .. '`', inline = true },
        { name = 'Lab ID', value = '`' .. tostring(labId) .. '`', inline = true },
        { name = 'Pris', value = tostring(price or 0) .. ' kr', inline = true },
    }
    if not atEntrance and drugType then
        fields[#fields + 1] = { name = 'Stof', value = tostring(drugType), inline = true }
        fields[#fields + 1] = { name = 'Bande/job', value = tostring(jobName or '–'), inline = true }
        if coords then
            local cx, cy, cz = coords.x or coords[1], coords.y or coords[2], coords.z or coords[3]
            fields[#fields + 1] = { name = 'Position', value = string.format('%.1f, %.1f, %.1f', cx or 0, cy or 0, cz or 0), inline = false }
        end
    end
    sendDiscordWebhookSafe(url, {
        embeds = { { title = title, color = 15844367, fields = fields } },
    })
end

local function isValidSource(src)
    if type(src) ~= 'number' or src < 1 then return false end
    return GetPlayerName(src) and true or false
end

local function normalizeLabId(labId)
    if labId == nil then return nil end
    local s = tostring(labId):gsub('%s', ''):sub(1, 64)
    return s ~= '' and s or nil
end

local function ensureTable()
    if not MySQL or not MySQL.query.await then return end
    pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS yz_druglab_labs (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            drug_type VARCHAR(50) NOT NULL,
            job_name VARCHAR(50) NOT NULL,
            world_x FLOAT NOT NULL,
            world_y FLOAT NOT NULL,
            world_z FLOAT NOT NULL,
            world_w FLOAT NOT NULL DEFAULT 0,
            code VARCHAR(20) NOT NULL DEFAULT '1234',
            price INT UNSIGNED NOT NULL DEFAULT 0,
            entrance_shell_model VARCHAR(80) NULL DEFAULT NULL,
            lab_shell_model VARCHAR(80) NULL DEFAULT NULL,
            created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    pcall(MySQL.query.await, 'ALTER TABLE yz_druglab_labs ADD COLUMN price INT UNSIGNED NOT NULL DEFAULT 0')
    pcall(MySQL.query.await, 'ALTER TABLE yz_druglab_labs ADD COLUMN owner_identifier VARCHAR(64) NULL DEFAULT NULL')
    pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS yz_druglab_lab_members (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            lab_id INT UNSIGNED NOT NULL,
            identifier VARCHAR(64) NOT NULL,
            player_name VARCHAR(64) NULL DEFAULT NULL,
            added_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_lab_identifier (lab_id, identifier),
            FOREIGN KEY (lab_id) REFERENCES yz_druglab_labs(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS yz_druglab_access_log (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT,
            lab_id INT UNSIGNED NOT NULL,
            identifier VARCHAR(64) NOT NULL,
            player_name VARCHAR(64) NULL DEFAULT NULL,
            action VARCHAR(20) NOT NULL DEFAULT 'entered',
            created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_lab_created (lab_id, created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS yz_druglab_player_in_lab (
            identifier VARCHAR(64) NOT NULL PRIMARY KEY,
            lab_id VARCHAR(64) NOT NULL,
            updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end

local function setPlayerInLabDb(identifier, labId)
    if not identifier or not labId or not MySQL then return end
    pcall(MySQL.query.await, 'INSERT INTO yz_druglab_player_in_lab (identifier, lab_id) VALUES (?, ?) ON DUPLICATE KEY UPDATE lab_id = VALUES(lab_id)', { identifier, labId })
end

local function clearPlayerInLabDb(identifier)
    if not identifier or not MySQL or not MySQL.update then return end
    pcall(function() MySQL.update.await('DELETE FROM yz_druglab_player_in_lab WHERE identifier = ?', { identifier }) end)
end

local function buildCachedLabEntrances()
    cachedLabEntrances = {}
    for _, lab in ipairs(Config.LabEntrances or {}) do
        cachedLabEntrances[#cachedLabEntrances + 1] = lab
    end
    if not MySQL or not MySQL.query.await then return end
    ensureTable()
    local rows = MySQL.query.await('SELECT id, drug_type, job_name, world_x, world_y, world_z, world_w, code, price, owner_identifier, entrance_shell_model, lab_shell_model FROM yz_druglab_labs ORDER BY id') or {}
    for _, row in ipairs(rows) do
        local labId = 'lab_db_' .. tostring(row.id)
        local drugShells = Config.ShellsByDrugType and Config.ShellsByDrugType[row.drug_type]
        local defEnt = Config.DefaultEntranceShell
        local defLab = Config.DefaultLabShell
        local esBase = (drugShells and drugShells.entranceShell) or defEnt
        local lsBase = (drugShells and drugShells.labShell) or defLab
        local es = esBase and {
            model = row.entrance_shell_model or esBase.model or (defEnt and defEnt.model) or 'shell_store1',
            pos = esBase.pos or (defEnt and defEnt.pos) or vector3(0,0,0),
            playerOffset = esBase.playerOffset or (defEnt and defEnt.playerOffset) or vector4(0,0,1,0),
        } or nil
        local ls = lsBase and {
            model = row.lab_shell_model or lsBase.model or (defLab and defLab.model) or 'shell_ranch',
            pos = lsBase.pos or (defLab and defLab.pos) or vector3(0,0,0),
            playerOffset = lsBase.playerOffset or (defLab and defLab.playerOffset) or vector4(0,0,1,0),
            entryOffset = lsBase.entryOffset or (defLab and defLab.entryOffset),
            terminalRadius = lsBase.terminalRadius or 1.5,
            exitRadius = lsBase.exitRadius or 1.5,
            terminalProp = lsBase.terminalProp or (defLab and defLab.terminalProp),
            terminalPropOffset = lsBase.terminalPropOffset or (defLab and defLab.terminalPropOffset),
            packingSpotOffset = lsBase.packingSpotOffset or (defLab and defLab.packingSpotOffset),
        } or nil
        if es then es.model = es.model or 'shell_store1' end
        if ls then ls.model = ls.model or 'shell_ranch' end
        cachedLabEntrances[#cachedLabEntrances + 1] = {
            id = labId,
            code = row.code or '1234',
            drug_type = row.drug_type,
            job_name = row.job_name,
            price = tonumber(row.price) or 0,
            owner_identifier = row.owner_identifier,
            worldEntrance = vector4(row.world_x, row.world_y, row.world_z, row.world_w or 0),
            entranceShell = es,
            labShell = ls,
        }
    end
end

local function getLabEntranceConfig(labId)
    for _, lab in ipairs(cachedLabEntrances) do
        if lab.id == labId then return lab end
    end
    return nil
end

local function getLabDbId(labId)
    return tonumber((tostring(labId or ''):gsub('lab_db_', '')))
end

local function isLabOwner(src, labId)
    if not ESX or not src then return false end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local ident = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
    local lab = getLabEntranceConfig(labId)
    return lab and lab.owner_identifier and ident and (lab.owner_identifier == ident)
end

local function hasLabAccess(src, labId, lab)
    if not ESX or not src then return false end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local ident = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
    if not ident then return false end
    lab = lab or getLabEntranceConfig(labId)
    if not lab then return false end
    if lab.owner_identifier == ident then return true end
    local dbId = getLabDbId(labId)
    if not dbId or not MySQL or not MySQL.query.await then return false end
    local row = MySQL.query.await('SELECT 1 FROM yz_druglab_lab_members WHERE lab_id = ? AND identifier = ? LIMIT 1', { dbId, ident })
    return row and #row > 0
end

local function getLabMembers(labId)
    local dbId = getLabDbId(labId)
    if not dbId or not MySQL or not MySQL.query.await then return {} end
    local rows = MySQL.query.await('SELECT identifier, player_name, added_at FROM yz_druglab_lab_members WHERE lab_id = ? ORDER BY added_at DESC', { dbId }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { identifier = r.identifier, player_name = r.player_name or r.identifier, added_at = r.added_at }
    end
    return out
end

local function getLabAccessLog(labId, limit)
    local dbId = getLabDbId(labId)
    if not dbId or not MySQL or not MySQL.query.await then return {} end
    local n = tonumber(limit) or 30
    local rows = MySQL.query.await('SELECT identifier, player_name, action, created_at FROM yz_druglab_access_log WHERE lab_id = ? ORDER BY created_at DESC LIMIT ?', { dbId, n }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { identifier = r.identifier, player_name = r.player_name or r.identifier, action = r.action or 'entered', created_at = r.created_at }
    end
    return out
end

local function logLabAccess(labId, src, action)
    local dbId = getLabDbId(labId)
    if not dbId or not MySQL or not MySQL.insert then return end
    local name = nil
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then name = xPlayer.getName and xPlayer.getName() or xPlayer.get and xPlayer.get('name') end
        if not name and xPlayer then name = GetPlayerName(src) end
    end
    local ident = nil
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then ident = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier end
    end
    if not ident then ident = 'unknown' end
    if not name then name = GetPlayerName(src) or ident end
    MySQL.insert.await('INSERT INTO yz_druglab_access_log (lab_id, identifier, player_name, action) VALUES (?, ?, ?, ?)', { dbId, ident, name, action or 'entered' })
end

local function getLabCode(labId)
    local lab = getLabEntranceConfig(labId)
    if not lab then return nil end
    if lab.code and lab.code ~= '' then return lab.code end
    return GetConvar and GetConvar('yz_druglab_code_' .. labId, '1234') or '1234'
end

local function getOrCreateLab(labId)
    if not labState[labId] then
        labState[labId] = {
            inventory = {
                cocaine_base = 245,
                pure_cocaine = 89,
                chemical_x = 567,
                catalyst = 234,
                premium_extract = 12,
                processing_waste = 423,
            },
            stock = {
                raw_material = 78,
                processing_cap = 45,
                storage_available = 34,
                equipment_health = 92,
                temperature = 87,
            },
            production = {
                active = false,
                paused = false,
                currentStage = 1,
                stageProgress = { 100, 0, 0 },
            },
            log = {},
            lastTick = 0,
        }
    end
    return labState[labId]
end

local function addLog(labId, message, logType)
    local lab = getOrCreateLab(labId)
    local time = os.date('%H:%M:%S')
    lab.log[#lab.log + 1] = { time = time, message = message, type = logType or '' }
    while #lab.log > 20 do
        table.remove(lab.log, 1)
    end
end

local function buildLabData(labId)
    local lab = getOrCreateLab(labId)
    local invList = {}
    for _, item in ipairs(Config.InventoryItems or {}) do
        invList[#invList + 1] = {
            name = item.label,
            quantity = lab.inventory[item.key] or 0,
            unit = item.unit,
            rarity = item.rarity or '',
        }
    end
    local stockList = {}
    for _, s in ipairs(Config.StockLevels or {}) do
        local val = lab.stock[s.key] or 0
        local display = s.unit == '°C' and (tostring(val) .. '°C') or (tostring(val) .. '%')
        stockList[#stockList + 1] = {
            name = s.label,
            value = val,
            display = display,
            max = s.max or 100,
        }
    end
    return {
        inventory = invList,
        stockLevels = stockList,
        production = {
            active = lab.production.active,
            paused = lab.production.paused,
            currentStage = lab.production.currentStage,
            stageProgress = lab.production.stageProgress and { lab.production.stageProgress[1], lab.production.stageProgress[2], lab.production.stageProgress[3] } or { 0, 0, 0 },
        },
        log = lab.log,
        alert = lab.stock.temperature and lab.stock.temperature > 90 and 'Temperature rising - Check cooling system' or nil,
    }
end

CreateThread(function()
    buildCachedLabEntrances()
    for _ = 1, 25 do
        Wait(400)
        pcall(ensureTable)
        local ok = pcall(buildCachedLabEntrances)
        if ok and MySQL and MySQL.query.await then
            d('Loaded %d lab entrances', #cachedLabEntrances)
            break
        end
    end
end)

local function buildRefreshPayload()
    local payload = {}
    for _, lab in ipairs(cachedLabEntrances) do
        local L = { id = lab.id, code = lab.code, drug_type = lab.drug_type, job_name = lab.job_name, price = lab.price, owner_identifier = lab.owner_identifier, entranceShell = lab.entranceShell, labShell = lab.labShell }
        if lab.worldEntrance then L.worldEntrance = { x = lab.worldEntrance.x, y = lab.worldEntrance.y, z = lab.worldEntrance.z, w = lab.worldEntrance.w or 0 } end
        payload[#payload + 1] = L
    end
    return payload
end

lib.callback.register('yz_druglab:getLabEntrances', function(source)
    if #cachedLabEntrances == 0 then buildCachedLabEntrances() end
    return cachedLabEntrances
end)

RegisterNetEvent('yz_druglab:requestLabEntrances', function()
    local src = source
    if not isValidSource(src) then return end
    if #cachedLabEntrances > 0 then
        TriggerClientEvent('yz_druglab:refreshLabs', src, buildRefreshPayload())
        return
    end
    TriggerClientEvent('yz_druglab:refreshLabs', src, {})
    CreateThread(function()
        if not pcall(buildCachedLabEntrances) or #cachedLabEntrances == 0 then return end
        TriggerClientEvent('yz_druglab:refreshLabs', src, buildRefreshPayload())
    end)
end)

lib.callback.register('yz_druglab:getLabsList', function(source)
    local rows = MySQL and MySQL.query.await and MySQL.query.await('SELECT id, drug_type, job_name, world_x, world_y, world_z, code, price FROM yz_druglab_labs ORDER BY id') or {}
    local list = {}
    for _, row in ipairs(rows) do
        list[#list + 1] = {
            id = row.id,
            drug_type = row.drug_type,
            job_name = row.job_name,
            x = row.world_x, y = row.world_y, z = row.world_z,
            code = row.code or '1234',
            price = tonumber(row.price) or 0,
        }
    end
    return list
end)

lib.callback.register('yz_druglab:getCreateLabFormData', function(source)
    local canCreate = false
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            local job = xPlayer.getJob()
            if job then
                local rank = Config.CreateLabRank or {}
                local ok = (not rank.job or job.name == rank.job)
                if ok and rank.grade then
                    local g = type(job.grade) == 'number' and job.grade or (job.grade and job.grade.grade)
                    ok = g and g >= rank.grade
                end
                canCreate = ok
            end
        end
    end
    local drugTypes = Config.DrugTypes or {}
    local rawGang = type(Config.GangJobs) == 'table' and Config.GangJobs or {}
    local gangJobs = {}
    for _, v in ipairs(rawGang) do
        if type(v) == 'table' and v.name then
            gangJobs[#gangJobs + 1] = { name = v.name, label = v.label or v.name }
        elseif type(v) == 'string' then
            gangJobs[#gangJobs + 1] = { name = v, label = v }
        end
    end
    local defaultPrice = tonumber(Config.LabPrice) or 0
    return { canCreate = canCreate, drugTypes = drugTypes, gangJobs = gangJobs, defaultPrice = defaultPrice }
end)

lib.callback.register('yz_druglab:getDrugTypes', function(source)
    return Config.DrugTypes or {}
end)

lib.callback.register('yz_druglab:getGangJobs', function(source)
    local list = Config.GangJobs or {}
    if #list == 0 then
        local rows = MySQL and MySQL.query.await and MySQL.query.await('SELECT name, label FROM jobs ORDER BY name') or {}
        for _, r in ipairs(rows) do
            list[#list + 1] = { name = r.name, label = r.label or r.name }
        end
        return list
    end
    local out = {}
    for _, name in ipairs(list) do
        local row = MySQL and MySQL.single.await and MySQL.single.await('SELECT name, label FROM jobs WHERE name = ?', { name }) or nil
        if row then out[#out + 1] = { name = row.name, label = row.label or row.name } end
    end
    return out
end)

lib.callback.register('yz_druglab:getLabPrice', function(source)
    return Config.LabPrice or 0
end)

lib.callback.register('yz_druglab:getMyIdentifier', function(source)
    if not ESX then return nil end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end
    return xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
end)

lib.callback.register('yz_druglab:canCreateLab', function(source)
    if not ESX then return false end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    local job = xPlayer.getJob()
    if not job then return false end
    local rank = Config.CreateLabRank or {}
    if (rank.job and job.name ~= rank.job) then return false end
    if rank.grade and (type(job.grade) == 'number' and job.grade < rank.grade) then return false end
    if type(job.grade) == 'table' and job.grade.grade and job.grade.grade < (rank.grade or 0) then return false end
    return true
end)

local function doCreateLab(src, drugType, jobName, coords, price)
    if not isValidSource(src) then return false, 'Ugyldig spiller' end
    if not ESX then return false, 'ESX ikke tilgængelig' end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false, 'Spiller ikke fundet' end
    local job = xPlayer.getJob()
    if not job then return false, 'Du har ikke rettigheder til at oprette druglabs.' end
    local rank = Config.CreateLabRank or {}
    if rank.job and job.name ~= rank.job then
        return false, 'Du har ikke rettigheder til at oprette druglabs.'
    end
    local gradeNum = type(job.grade) == 'number' and job.grade or (job.grade and job.grade.grade)
    if rank.grade and (not gradeNum or gradeNum < rank.grade) then
        return false, 'Du har ikke det krævede rank til at oprette druglabs.'
    end
    drugType = type(drugType) == 'string' and drugType:gsub('%s', ''):sub(1, 50) or nil
    jobName = type(jobName) == 'string' and jobName:gsub('%s', ''):sub(1, 50) or nil
    if not drugType or drugType == '' or not jobName or jobName == '' then
        return false, 'Ugyldige data (stof, bande eller position).'
    end
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' and type(coords) ~= 'vector4' then
        return false, 'Ugyldige data (stof, bande eller position).'
    end
    local cx = coords.x or coords[1]
    local cy = coords.y or coords[2]
    local cz = coords.z or coords[3]
    local cw = coords.w or coords[4] or 0
    if not cx or not cy or not cz then
        return false, 'Ugyldige data (stof, bande eller position).'
    end
    if not MySQL or not MySQL.insert.await then
        return false, 'Database ikke tilgængelig.'
    end
    local amount = tonumber(price)
    if amount == nil or amount < 0 then amount = tonumber(Config.LabPrice) or 0 end
    local id = MySQL.insert.await('INSERT INTO yz_druglab_labs (drug_type, job_name, world_x, world_y, world_z, world_w, code, price) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        drugType,
        jobName,
        cx, cy, cz, cw,
        '1234',
        amount,
    })
    if not id then
        return false, 'Kunne ikke oprette lab.'
    end
    buildCachedLabEntrances()
    local payload = buildRefreshPayload()
    TriggerClientEvent('yz_druglab:refreshLabs', -1, payload)
    if isValidSource(src) then TriggerClientEvent('yz_druglab:refreshLabs', src, payload) end
    logDiscordCreateLab(src, 'lab_db_' .. tostring(id), drugType, jobName, { x = cx, y = cy, z = cz }, amount)
    d('createLab src=%s id=%s drug=%s job=%s', src, id, drugType, jobName)
    return true, id
end

exports('createLab', function(src, drugType, jobName, coords, price)
    local ok, result = doCreateLab(src, drugType, jobName, coords, price)
    if ok and result then
        if isValidSource(src) then
            TriggerClientEvent('ox_lib:notify', src, { description = 'Druglab oprettet (lab_db_' .. result .. '). Kode: 1234', type = 'success' })
        end
        return true
    end
    if not ok and isValidSource(src) and result then
        TriggerClientEvent('ox_lib:notify', src, { description = result, type = 'error' })
    end
    return false
end)

RegisterNetEvent('yz_druglab:createLab', function(drugType, jobName, coords, price)
    local src = source
    local ok, result = doCreateLab(src, drugType, jobName, coords, price)
    if not ok then
        if result and isValidSource(src) then
            TriggerClientEvent('ox_lib:notify', src, { description = result, type = 'error' })
        end
        return
    end
    if isValidSource(src) then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Druglab oprettet (lab_db_' .. result .. '). Kode: 1234', type = 'success' })
        TriggerClientEvent('yz_druglab:refreshLabs', src, buildRefreshPayload())
    end
end)

RegisterNetEvent('yz_druglab:buyLab', function(drugType, jobName, coords)
    local src = source
    if not isValidSource(src) or not ESX then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if type(coords) ~= 'table' or not coords.x or not coords.y or not coords.z then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Ugyldige data (stof, bande eller position).', type = 'error' })
        return
    end
    drugType = type(drugType) == 'string' and drugType:gsub('%s', ''):sub(1, 50) or nil
    jobName = type(jobName) == 'string' and jobName:gsub('%s', ''):sub(1, 50) or nil
    if not drugType or not jobName then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Ugyldige data (stof, bande eller position).', type = 'error' })
        return
    end
    local price = tonumber(Config.LabPrice) or 0
    if price > 0 then
        local account = xPlayer.getAccount('money')
        if not account or (account.money or 0) < price then
            TriggerClientEvent('ox_lib:notify', src, { description = ('Du har ikke nok kontanter (%s kr).'):format(price), type = 'error' })
            return
        end
        xPlayer.removeAccountMoney('money', price)
    end
    if not MySQL or not MySQL.insert.await then
        if price > 0 then xPlayer.addAccountMoney('money', price) end
        TriggerClientEvent('ox_lib:notify', src, { description = 'Database ikke tilgængelig.', type = 'error' })
        return
    end
    local identifier = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
    local id = MySQL.insert.await('INSERT INTO yz_druglab_labs (drug_type, job_name, world_x, world_y, world_z, world_w, code, price, owner_identifier) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        drugType,
        jobName,
        coords.x, coords.y, coords.z, coords.w or 0,
        '1234',
        price,
        identifier or nil,
    })
    if not id then
        if price > 0 then xPlayer.addAccountMoney('money', price) end
        TriggerClientEvent('ox_lib:notify', src, { description = 'Kunne ikke oprette lab.', type = 'error' })
        return
    end
    buildCachedLabEntrances()
    local payload = buildRefreshPayload()
    TriggerClientEvent('yz_druglab:refreshLabs', -1, payload)
    TriggerClientEvent('yz_druglab:refreshLabs', src, payload)
    logDiscordBuyLab(src, 'lab_db_' .. tostring(id), drugType, jobName, coords, price, false)
    local msg = price > 0 and ('Druglab købt og oprettet (kode 1234). %s kr trukket.'):format(price) or 'Druglab oprettet (kode 1234).'
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = 'success' })
    d('buyLab src=%s id=%s drug=%s job=%s price=%s', src, id, drugType, jobName, price)
end)

RegisterNetEvent('yz_druglab:buyLabAtEntrance', function(labId)
    local src = source
    if not isValidSource(src) then return end
    local id = normalizeLabId(labId)
    if not id then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Ugyldigt lab.', type = 'error' })
        return
    end
    if not ESX then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local lab = getLabEntranceConfig(id)
    if not lab then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Lab findes ikke.', type = 'error' })
        return
    end
    local price = tonumber(lab.price) or 0
    if price > 0 then
        local account = xPlayer.getAccount('money')
        if not account or (account.money or 0) < price then
            TriggerClientEvent('ox_lib:notify', src, { description = ('Du har ikke nok kontanter (%s kr).'):format(price), type = 'error' })
            return
        end
        xPlayer.removeAccountMoney('money', price)
    end
    local dbId = getLabDbId(id)
    if dbId and MySQL and MySQL.update then
        local identifier = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
        if identifier then
            MySQL.update.await('UPDATE yz_druglab_labs SET owner_identifier = ? WHERE id = ?', { identifier, dbId })
        end
    end
    buildCachedLabEntrances()
    local payload = buildRefreshPayload()
    TriggerClientEvent('yz_druglab:refreshLabs', -1, payload)
    TriggerClientEvent('yz_druglab:refreshLabs', src, payload)
    logDiscordBuyLab(src, id, lab.drug_type, lab.job_name, nil, price, true)
    local code = getLabCode(id) or '1234'
    TriggerClientEvent('ox_lib:notify', src, { description = ('Lab købt. Kode: %s'):format(code), type = 'success' })
    d('buyLabAtEntrance src=%s labId=%s price=%s', src, id, price)
end)

RegisterNetEvent('yz_druglab:deleteLab', function(dbId)
    local src = source
    if not isValidSource(src) or not ESX then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local job = xPlayer.getJob()
    if not job then return end
    local rank = Config.CreateLabRank or {}
    if (rank.job and job.name ~= rank.job) then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Du har ikke rettigheder til at slette labs.', type = 'error' })
        return
    end
    local gradeNum = type(job.grade) == 'number' and job.grade or (job.grade and job.grade.grade)
    if rank.grade and (not gradeNum or gradeNum < rank.grade) then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Du har ikke rettigheder til at slette labs.', type = 'error' })
        return
    end
    dbId = tonumber(dbId)
    if not dbId then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Ugyldigt lab-id.', type = 'error' })
        return
    end
    if not MySQL or not MySQL.update.await then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Database ikke tilgængelig.', type = 'error' })
        return
    end
    local affected = MySQL.update.await('DELETE FROM yz_druglab_labs WHERE id = ?', { dbId })
    if not affected or affected == 0 then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Lab findes ikke eller kunne ikke slettes.', type = 'error' })
        return
    end
    if labState['lab_db_' .. dbId] then labState['lab_db_' .. dbId] = nil end
    buildCachedLabEntrances()
    TriggerClientEvent('yz_druglab:refreshLabs', -1, buildRefreshPayload())
    TriggerClientEvent('ox_lib:notify', src, { description = ('Lab #%s slettet.'):format(dbId), type = 'success' })
    d('deleteLab src=%s id=%s', src, dbId)
end)

local function registerLabStash()
    if not exports.ox_inventory then return end
    pcall(function()
        exports.ox_inventory:RegisterStash('yz_druglab_lab', 'Lab lager', 50, 100000, true, nil, nil)
    end)
end
registerLabStash()

local function getStashInventoryList(labId)
    local list = {}
    if not labId or not exports.ox_inventory or not exports.ox_inventory.GetInventoryItems then return list end
    local ok, items = pcall(function() return exports.ox_inventory:GetInventoryItems('yz_druglab_lab', labId) end)
    if not ok or not items or type(items) ~= 'table' then return list end
    local aggregated = {}
    for _, item in pairs(items) do
        if item and item.name and (item.count or 0) > 0 then
            local key = item.name
            if not aggregated[key] then
                aggregated[key] = { name = item.label or item.name, quantity = 0 }
            end
            aggregated[key].quantity = aggregated[key].quantity + (item.count or 0)
        end
    end
    for _, v in pairs(aggregated) do
        list[#list + 1] = { name = v.name, quantity = v.quantity, unit = 'stk' }
    end
    return list
end

local function buildFullLabData(labId, src)
    local id = labId or 'lab1'
    local data = buildLabData(id)
    data.members = getLabMembers(id)
    data.accessLog = getLabAccessLog(id, 30)
    data.isOwner = src and isLabOwner(src, id) or false
    data.labId = id
    data.stashInventory = getStashInventoryList(id)
    local labCfg = getLabEntranceConfig(id)
    data.drug_type = labCfg and labCfg.drug_type or nil
    data.drug_type_label = nil
    if data.drug_type and Config.DrugTypes then
        for _, dt in ipairs(Config.DrugTypes) do
            if dt.id == data.drug_type then data.drug_type_label = dt.label break end
        end
    end
    if data.isOwner then
        data.code = getLabCode(id) or '1234'
    end
    return data
end

lib.callback.register('yz_druglab:getLabData', function(source, labId)
    return buildFullLabData(labId or 'lab1', source)
end)

local function doStartProduction(labId, src)
    local id = normalizeLabId(labId) or 'lab1'
    local lab = getOrCreateLab(id)
    if lab.production.active and not lab.production.paused then
        return false
    end
    lab.production.active = true
    lab.production.paused = false
    addLog(id, 'Production initiated - All systems online', 'success')
    if src and isValidSource(src) then
        TriggerClientEvent('yz_druglab:labUpdated', src, id, buildFullLabData(id, src))
    end
    d('startProduction lab=%s', id)
    return true
end

exports('startProduction', function(labId, src)
    return doStartProduction(labId, src) == true
end)

RegisterNetEvent('yz_druglab:startProduction', function(labId)
    local src = source
    doStartProduction(labId, src)
end)

RegisterNetEvent('yz_druglab:pauseProduction', function(labId)
    local src = source
    local id = normalizeLabId(labId) or 'lab1'
    local lab = getOrCreateLab(id)
    lab.production.paused = true
    addLog(id, 'Production paused by operator', 'warning')
    TriggerClientEvent('yz_druglab:labUpdated', src, id, buildFullLabData(id, src))
    d('pauseProduction lab=%s', id)
end)

RegisterNetEvent('yz_druglab:stopProduction', function(labId)
    local src = source
    local id = normalizeLabId(labId) or 'lab1'
    local lab = getOrCreateLab(id)
    lab.production.active = false
    lab.production.paused = false
    lab.production.currentStage = 1
    lab.production.stageProgress = { 0, 0, 0 }
    addLog(id, 'Production stopped - Standby mode engaged', 'error')
    TriggerClientEvent('yz_druglab:labUpdated', src, id, buildFullLabData(id, src))
    d('stopProduction lab=%s', id)
end)

local tickInterval = Config.ProductionTickInterval or 1000
CreateThread(function()
    while true do
        Wait(tickInterval)
        for labId, lab in pairs(labState) do
            if lab.production.active and not lab.production.paused then
                local p = lab.production
                p.stageProgress = p.stageProgress or { 0, 0, 0 }
                local advance = (100 / (Config.ProductionStageDuration or 60000)) * tickInterval
                if p.currentStage == 1 then
                    p.stageProgress[1] = math.min(100, (p.stageProgress[1] or 0) + advance)
                    if p.stageProgress[1] >= 100 then
                        p.currentStage = 2
                        addLog(labId, 'Extraction complete', '')
                    end
                elseif p.currentStage == 2 then
                    p.stageProgress[2] = math.min(100, (p.stageProgress[2] or 0) + advance)
                    if p.stageProgress[2] >= 100 then
                        p.currentStage = 3
                        addLog(labId, 'Purification complete', '')
                    end
                else
                    p.stageProgress[3] = math.min(100, (p.stageProgress[3] or 0) + advance)
                    if p.stageProgress[3] >= 100 then
                        addLog(labId, 'Packaging complete - Batch ready', 'success')
                        p.currentStage = 1
                        p.stageProgress = { 0, 0, 0 }
                        lab.inventory.pure_cocaine = (lab.inventory.pure_cocaine or 0) + math.random(1, 3)
                        lab.inventory.processing_waste = math.max(0, (lab.inventory.processing_waste or 0) - math.random(5, 15))
                    end
                end
                lab.stock.temperature = math.max(70, math.min(99, (lab.stock.temperature or 80) + (math.random() - 0.5) * 2))
                lab.stock.equipment_health = math.max(50, math.min(100, (lab.stock.equipment_health or 92) - (math.random() * 0.1)))
            end
        end
    end
end)

local function getEntrancePlayerCoords(lab)
    local es = lab and lab.entranceShell
    if not es then return nil end
    if es.coords then return es.coords end
    local po = es.playerOffset
    if not po then return nil end
    local baseZ = Config.ShellBaseZEntrance or 2000.0
    return vector4(po.x or 0, po.y or 0, baseZ + (po.z or 0), po.w or 0)
end

local function getLabPlayerCoords(lab)
    local ls = lab and lab.labShell
    if not ls then return nil end
    if ls.coords then return ls.coords end
    local po = ls.entryOffset or ls.playerOffset
    if not po then return nil end
    local baseZ = Config.ShellBaseZLab or 2100.0
    return vector4(po.x or 0, po.y or 0, baseZ + (po.z or 0), po.w or 0)
end

local function doSendEntranceCoords(playerId, coords, labId)
    if not isValidSource(playerId) then return false end
    local id = normalizeLabId(labId)
    if not id then return false end
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' and type(coords) ~= 'vector4' then return false end
    local cx, cy, cz = coords.x or coords[1], coords.y or coords[2], coords.z or coords[3]
    if not cx or not cy or not cz then return false end
    local cw = coords.w or coords[4] or 0
    playerInLab[playerId] = id
    SetPlayerRoutingBucket(playerId, playerId)
    TriggerClientEvent('yz_druglab:entranceCoords', playerId, vector4(cx, cy, cz, cw), id)
    d('sendEntranceCoords playerId=%s labId=%s', playerId, id)
    return true
end

local function doGiveEntranceToPlayer(playerId, labId)
    if not isValidSource(playerId) then return false end
    local id = normalizeLabId(labId)
    if not id then
        TriggerClientEvent('yz_druglab:entranceDenied', playerId, 'Ugyldig lab.')
        return false
    end
    if playerInLab[playerId] then
        TriggerClientEvent('yz_druglab:entranceDenied', playerId, 'Du er allerede i et lab.')
        return false
    end
    local lab = getLabEntranceConfig(id)
    local coords = lab and getEntrancePlayerCoords(lab)
    if not lab or not coords then
        TriggerClientEvent('yz_druglab:entranceDenied', playerId, 'Ugyldig lab.')
        return false
    end
    return doSendEntranceCoords(playerId, coords, id)
end

exports('sendEntranceCoords', function(playerId, entranceCoords, labId)
    return doSendEntranceCoords(playerId, entranceCoords, labId) == true
end)

exports('giveEntranceToPlayer', function(playerId, labId)
    return doGiveEntranceToPlayer(playerId, labId) == true
end)

RegisterNetEvent('yz_druglab:requestEnterEntrance', function(labId)
    local src = source
    doGiveEntranceToPlayer(src, labId)
end)

local function doCheckCode(src, labId, code)
    if not isValidSource(src) then return false end
    local id = normalizeLabId(labId)
    if not id then return false end
    if not hasLabAccess(src, id) then
        TriggerClientEvent('yz_druglab:codeResult', src, false)
        TriggerClientEvent('ox_lib:notify', src, { description = 'Du har ikke adgang til dette lab.', type = 'error' })
        return false
    end
    local lab = getLabEntranceConfig(id)
    local coords = lab and getLabPlayerCoords(lab)
    if not lab or not coords then
        TriggerClientEvent('yz_druglab:codeResult', src, false)
        return false
    end
    local expected = getLabCode(id)
    local codeStr = tostring(code or ''):gsub('%s', '')
    local correct = (codeStr == tostring(expected))
    if correct then
        playerInLab[src] = id
        SetPlayerRoutingBucket(src, src)
        Player(src).state:set('yz_druglab_labId', id, false)
        local ident = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
        if ident then setPlayerInLabDb(ident, id) end
        logLabAccess(id, src, 'entered')
        TriggerClientEvent('yz_druglab:codeResult', src, true, coords, id)
        d('checkCode src=%s labId=%s OK', src, id)
        return true, coords, id
    end
    TriggerClientEvent('yz_druglab:codeResult', src, false)
    d('checkCode src=%s labId=%s WRONG', src, id)
    return false
end

exports('checkCode', function(src, labId, code)
    return doCheckCode(src, labId, code)
end)

exports('sendCodeResult', function(playerId, success, labCoords, labId)
    if not isValidSource(playerId) then return end
    TriggerClientEvent('yz_druglab:codeResult', playerId, success == true, labCoords or nil, labId or nil)
end)

RegisterNetEvent('yz_druglab:checkCode', function(labId, code)
    doCheckCode(source, labId, code)
end)

RegisterNetEvent('yz_druglab:setLabCode', function(labId, newCode)
    local src = source
    if not isValidSource(src) then return end
    local id = normalizeLabId(labId)
    if not id then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Ugyldigt lab.', type = 'error' })
        return
    end
    if not isLabOwner(src, id) then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Kun ejeren kan ændre koden.', type = 'error' })
        return
    end
    local codeStr = tostring(newCode or ''):gsub('%s', '')
    if #codeStr ~= 4 or not codeStr:match('^%d%d%d%d$') then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Koden skal være 4 cifre.', type = 'error' })
        return
    end
    local dbId = getLabDbId(id)
    if not dbId or not MySQL or not MySQL.update then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Kunne ikke opdatere kode.', type = 'error' })
        return
    end
    MySQL.update.await('UPDATE yz_druglab_labs SET code = ? WHERE id = ?', { codeStr, dbId })
    buildCachedLabEntrances()
    TriggerClientEvent('ox_lib:notify', src, { description = ('Kode ændret til %s.'):format(codeStr), type = 'success' })
    TriggerClientEvent('yz_druglab:labUpdated', src, id, buildFullLabData(id, src))
    d('setLabCode src=%s labId=%s', src, id)
end)

RegisterNetEvent('yz_druglab:addLabMember', function(labId, targetIdentifier, targetName)
    local src = source
    if not isValidSource(src) then return end
    local id = normalizeLabId(labId)
    if not id or not isLabOwner(src, id) then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Kun ejeren kan tilføje adgang.', type = 'error' })
        return
    end
    targetIdentifier = tostring(targetIdentifier or ''):gsub('%s', ''):sub(1, 64)
    if targetIdentifier == '' then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Ugyldig identifier.', type = 'error' })
        return
    end
    local dbId = getLabDbId(id)
    if not dbId or not MySQL then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Kunne ikke tilføje.', type = 'error' })
        return
    end
    local name = tostring(targetName or targetIdentifier):sub(1, 64)
    local ok = pcall(function()
        MySQL.query.await('INSERT INTO yz_druglab_lab_members (lab_id, identifier, player_name) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE player_name = VALUES(player_name)', { dbId, targetIdentifier, name })
    end)
    if ok then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Adgang tilføjet.', type = 'success' })
        TriggerClientEvent('yz_druglab:labUpdated', src, id, buildFullLabData(id, src))
    else
        TriggerClientEvent('ox_lib:notify', src, { description = 'Kunne ikke tilføje adgang.', type = 'error' })
    end
end)

RegisterNetEvent('yz_druglab:removeLabMember', function(labId, identifier)
    local src = source
    if not isValidSource(src) then return end
    local id = normalizeLabId(labId)
    if not id or not isLabOwner(src, id) then
        TriggerClientEvent('ox_lib:notify', src, { description = 'Kun ejeren kan fjerne adgang.', type = 'error' })
        return
    end
    identifier = tostring(identifier or ''):gsub('%s', ''):sub(1, 64)
    if identifier == '' then return end
    local dbId = getLabDbId(id)
    if not dbId or not MySQL then return end
    MySQL.update.await('DELETE FROM yz_druglab_lab_members WHERE lab_id = ? AND identifier = ?', { dbId, identifier })
    TriggerClientEvent('ox_lib:notify', src, { description = 'Adgang fjernet.', type = 'success' })
    TriggerClientEvent('yz_druglab:labUpdated', src, id, buildFullLabData(id, src))
end)

lib.callback.register('yz_druglab:canPack', function(source, labId)
    if not isValidSource(source) then return false, 0 end
    local id = normalizeLabId(labId)
    if not id or playerInLab[source] ~= id then return false, 0 end
    local lab = getLabEntranceConfig(id)
    if not lab or not lab.drug_type then return false, 0 end
    if not hasLabAccess(source, id, lab) then return false, 0 end
    local cfg = Config.PackingByDrugType and Config.PackingByDrugType[lab.drug_type]
    if not cfg or not cfg.transformedItem then return false, 0 end
    local amount = (cfg.amountRequired or Config.PackAmountRequired or 20)
    amount = math.max(1, math.floor(amount))
    local ox = exports.ox_inventory
    if not ox or not ox.GetItemCount then return false, amount end
    local count = ox:GetItemCount(source, cfg.transformedItem)
    return (count and count >= amount), amount
end)

local function doPackDrugs(src, labId)
    if not isValidSource(src) then return false, 'Ugyldig spiller' end
    local id = normalizeLabId(labId)
    if not id or playerInLab[src] ~= id then
        return false, 'Du skal være inde i labbet for at pakke.'
    end
    local lab = getLabEntranceConfig(id)
    if not lab or not lab.drug_type then
        return false, 'Ugyldigt lab.'
    end
    if not hasLabAccess(src, id, lab) then
        return false, 'Du har ikke adgang til dette lab.'
    end
    local cfg = Config.PackingByDrugType and Config.PackingByDrugType[lab.drug_type]
    if not cfg or not cfg.transformedItem or not cfg.packedItem then
        return false, 'Pakning er ikke konfigureret for dette lab.'
    end
    local amount = (cfg.amountRequired or Config.PackAmountRequired or 20)
    amount = math.max(1, math.floor(amount))
    local ox = exports.ox_inventory
    if not ox or not ox.GetItemCount then
        return false, 'Inventory kunne ikke bruges.'
    end
    local count = ox:GetItemCount(src, cfg.transformedItem)
    if not count or count < amount then
        return false, ('Du mangler %dx %s for at pakke.'):format(amount, cfg.label or cfg.transformedItemLabel or 'stof')
    end
    if not ox:RemoveItem(src, cfg.transformedItem, amount) then
        return false, 'Kunne ikke fjerne stof.'
    end
    local ok = ox:AddItem(src, cfg.packedItem, 1)
    if not ok then
        ox:AddItem(src, cfg.transformedItem, amount)
        return false, 'Kunne ikke give pakket stof.'
    end
    d('packDrugs src=%s labId=%s %dx %s -> 1x %s', src, id, amount, cfg.transformedItem, cfg.packedItem)
    return true, amount, cfg
end

exports('packDrugs', function(src, labId)
    local ok, a, cfg = doPackDrugs(src, labId)
    if ok and isValidSource(src) then
        TriggerClientEvent('ox_lib:notify', src, { description = ('Omdannet succesfuldt. %dx %s -> 1x %s'):format(a, cfg and cfg.label or 'stof', cfg and cfg.label or 'stof'), type = 'success' })
        return true
    end
    if not ok and isValidSource(src) and a then
        TriggerClientEvent('ox_lib:notify', src, { description = a, type = 'error' })
    end
    return false
end)

RegisterNetEvent('yz_druglab:packDrugs', function(labId)
    local src = source
    local ok, amountOrErr, cfg = doPackDrugs(src, labId)
    if not ok then
        if amountOrErr and isValidSource(src) then
            TriggerClientEvent('ox_lib:notify', src, { description = amountOrErr, type = 'error' })
        end
        return
    end
    if isValidSource(src) and amountOrErr and cfg then
        TriggerClientEvent('ox_lib:notify', src, { description = ('Omdannet succesfuldt. %dx %s -> 1x %s'):format(amountOrErr, cfg.label or 'stof', cfg.label or 'stof'), type = 'success' })
    end
end)

RegisterNetEvent('yz_druglab:exitLab', function(labId)
    local src = source
    if not isValidSource(src) then return end
    local id = normalizeLabId(labId)
    if id then logLabAccess(id, src, 'exited') end
    if playerInLab[src] then
        playerInLab[src] = nil
    end
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local ident = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
            if ident then clearPlayerInLabDb(ident) end
        end
    end
    Player(src).state:set('yz_druglab_labId', nil, false)
    SetPlayerRoutingBucket(src, 0)
    TriggerClientEvent('yz_druglab:exitConfirm', src)
    d('exitLab src=%s labId=%s', src, id or labId)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    if playerInLab[src] and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local ident = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
            if ident then clearPlayerInLabDb(ident) end
        end
        playerInLab[src] = nil
    end
    SetPlayerRoutingBucket(src, 0)
end)

local function sendRestoreInLab(src, labId, lab, coords)
    if not lab or not coords then return end
    playerInLab[src] = labId
    Player(src).state:set('yz_druglab_labId', labId, false)
    SetPlayerRoutingBucket(src, src)
    local payload = {
        id = lab.id,
        entranceShell = lab.entranceShell,
        labShell = lab.labShell,
        worldEntrance = lab.worldEntrance and { x = lab.worldEntrance.x, y = lab.worldEntrance.y, z = lab.worldEntrance.z, w = lab.worldEntrance.w or 0 } or nil,
    }
    TriggerClientEvent('yz_druglab:restoreInLab', src, labId, { x = coords.x, y = coords.y, z = coords.z, w = coords.w or 0 }, payload)
    d('Restored player %s in lab %s', src, labId)
end

CreateThread(function()
    for _ = 1, 20 do
        Wait(500)
        if #cachedLabEntrances > 0 then break end
        pcall(buildCachedLabEntrances)
    end
    Wait(3500)
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        if not src then goto continue end
        local labId = Player(src).state.yz_druglab_labId
        if (not labId or labId == '') and ESX and MySQL and MySQL.query.await then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                local ident = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
                if ident then
                    local row = MySQL.query.await('SELECT lab_id FROM yz_druglab_player_in_lab WHERE identifier = ? LIMIT 1', { ident })
                    if row and row[1] then labId = row[1].lab_id end
                end
            end
        end
        if labId and type(labId) == 'string' and labId ~= '' then
            local lab = getLabEntranceConfig(labId)
            local coords = lab and getLabPlayerCoords(lab)
            if lab and coords then
                sendRestoreInLab(src, labId, lab, coords)
            else
                Player(src).state:set('yz_druglab_labId', nil, false)
                if ESX then
                    local xPlayer = ESX.GetPlayerFromId(src)
                    if xPlayer then
                        local ident = xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier
                        if ident then clearPlayerInLabDb(ident) end
                    end
                end
            end
        end
        ::continue::
    end
end)

RegisterNetEvent('yz_druglab:requestRestoreIfInLab', function()
    local src = source
    if not isValidSource(src) then return end
    local labId = normalizeLabId(Player(src).state.yz_druglab_labId)
    if not labId then return end
    if #cachedLabEntrances == 0 then pcall(buildCachedLabEntrances) end
    local lab = getLabEntranceConfig(labId)
    local coords = lab and getLabPlayerCoords(lab)
    if lab and coords then
        sendRestoreInLab(src, labId, lab, coords)
    end
end)

