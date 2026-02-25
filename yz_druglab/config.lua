Config = {}

Config.Debug = false

Config.CreateLabRank = {
    job = 'dynasty8',
    grade = 1,
}

Config.GangJobs = {
    'bande1',
    'bande2',
    'bande3',
    'bande4',
    'bande5',
    'bande6',
    'bande7',
    'bande8',
    -- osv osv osv. Du forstår
}

Config.LabPrice = 50000

Config.LabSellerZone = {}

Config.DrugTypes = {
    { id = 'cocaine',  label = 'Kokain' },
    { id = 'mushrooms', label = 'Svampe' },
    { id = 'heroin',   label = 'Heroin' },
    { id = 'weed',     label = 'Cannabis' },
    { id = 'meth',     label = 'Amfetamin' },
}

Config.ShellsByDrugType = {
    cocaine = {
        entranceShell = { model = 'shell_coke2', pos = vector3(0.0, 0.0, 2099.0400), playerOffset = vector4(0.0, 0.0, 1.0, 178.5905) },
        labShell = { model = 'shell_coke2', pos = vector3(0.0, 0.0, 0.0), playerOffset = vector4(0.0, 0.0, 1.0, 0.0), entryOffset = vector4(-6.2538, 8.6609, -0.9595, 179.98), terminalRadius = 1.5, exitRadius = 1.5, terminalProp = 'bkr_ware05_laptop2', terminalPropOffset = vector4(-8.3052, -0.9162, -0.1077, 105.1729), packingSpotOffset = vector4(-4.0, 2.5, -0.7, 0.0) },
    },
    meth = {
        entranceShell = { model = 'shell_meth', pos = vector3(0.0, 0.0, 2099.0400), playerOffset = vector4(0.0, 0.0, 1.0, 0.0) },
        labShell = { model = 'shell_meth', pos = vector3(0.0, 0.0, 0.0), playerOffset = vector4(0.0, 0.0, 1.0, 0.0), entryOffset = vector4(-6.4570, 8.6472, -0.9541, 181.3558), terminalRadius = 1.5, exitRadius = 1.5, terminalProp = 'bkr_ware05_laptop2', terminalPropOffset = vector4(-8.7715, 1.5569, -0.26, 93.9876) },
    },
    weed = {
        entranceShell = { model = 'shell_weed2', pos = vector3(0.0, 0.0, 2098.0), playerOffset = vector4(0.0, 0.0, 1.0, 0.0) },
        labShell = { model = 'shell_weed2', pos = vector3(0.0, 0.0, 0.0), playerOffset = vector4(0.0, 0.0, 1.0, 0.0), entryOffset = vector4(17.8835, 11.7248, -2.0964, 90.3775), terminalRadius = 1.5, exitRadius = 1.5, terminalProp = 'bkr_ware05_laptop2', terminalPropOffset = vector4(-3.5668, -3.8168, -0.135, 282.7194) },
    },
    heroin = {
        entranceShell = { model = 'shell_meth', pos = vector3(0.0, 0.0, 2099.0400), playerOffset = vector4(0.0, 0.0, 1.0, 0.0) },
        labShell = { model = 'shell_meth', pos = vector3(0.0, 0.0, 0.0), playerOffset = vector4(0.0, 0.0, 1.0, 0.0), entryOffset = vector4(-6.4570, 8.6472, -0.9541, 181.3558), terminalRadius = 1.5, exitRadius = 1.5, terminalProp = 'bkr_ware05_laptop2', terminalPropOffset = vector4(-8.7715, 1.5569, -0.26, 93.9876) },
    },
    mushrooms = {
        entranceShell = { model = 'shell_meth', pos = vector3(0.0, 0.0, 2099.0400), playerOffset = vector4(0.0, 0.0, 1.0, 0.0) },
        labShell = { model = 'shell_meth', pos = vector3(0.0, 0.0, 0.0), playerOffset = vector4(0.0, 0.0, 1.0, 0.0), entryOffset = vector4(-6.4570, 8.6472, -0.9541, 181.3558), terminalRadius = 1.5, exitRadius = 1.5, terminalProp = 'bkr_ware05_laptop2', terminalPropOffset = vector4(-8.7715, 1.5569, -0.26, 93.9876) },
    },
}

Config.DefaultEntranceShell = {
    model = 'shell_store1',
    pos = vector3(0.0, 0.0, 0.0),
    playerOffset = vector4(0.0, 0.0, 1.0, 0.0),
}
Config.DefaultLabShell = {
    model = 'shell_ranch',
    pos = vector3(0.0, 0.0, 0.0),
    playerOffset = vector4(0.0, 0.0, 1.0, 0.0),
    entryOffset = vector4(0.0, 3.0, 0.0, 180.0),
    terminalRadius = 1.5,
    exitRadius = 1.5,
    terminalProp = 'bkr_ware05_laptop2',
    terminalPropOffset = vector4(-8.7715, 1.5569, -0.26, 93.9876),
}

Config.PackAmountRequired = 20
Config.PackDurationMs = 10000
Config.PackProgressAnim = {
    dict = 'mini@repair',
    clip = 'fixing_a_ped',
    flag = 49,
}
Config.PackingByDrugType = {
    cocaine  = { transformedItem = 'drug_cocaine_bag',  packedItem = 'drug_cocaine_packed',  label = 'Kokain', amountRequired = 20, transformedItemLabel = 'poser' },
    mushrooms = { transformedItem = 'drug_mushroom_bag', packedItem = 'drug_mushroom_packed', label = 'Svampe', amountRequired = 20, transformedItemLabel = 'poser' },
    heroin   = { transformedItem = 'drug_heroin_bag',   packedItem = 'drug_heroin_packed',   label = 'Heroin', amountRequired = 20, transformedItemLabel = 'poser' },
    weed     = { transformedItem = 'drug_weed_bag',    packedItem = 'drug_weed_packed',     label = 'Cannabis', amountRequired = 20, transformedItemLabel = 'poser' },
    meth     = { transformedItem = 'drug_meth_bag',     packedItem = 'drug_meth_packed',     label = 'Amfetamin', amountRequired = 20, transformedItemLabel = 'poser' },
}

Config.TransformSpotOffset = vector4(-15.2754, -9.9446, -1.116, 354.3911)
Config.TransformSpotByShell = {
    shell_coke2  = vector4(-2.0316, 0.5753, -0.19, 188.4254),
    shell_meth   = vector4(-2.2293, -1.5240, -0.47, 184.9003),
    shell_weed2  = vector4(-15.2754, -9.9446, -1.116, 354.3911),
    shell_ranch  = vector4(0.0, 3.0, 0.0, 180.0),
}
Config.TransformSpotRadius = 3.0
Config.TransformSpotMarker = {
    draw = false,
    type = 25,
    scale = vector3(0.8, 0.8, 0.3),
    color = { r = 100, g = 200, b = 100, a = 150 },
}
Config.TransformSpotPrompt = '[E] For at omdanne'
Config.TransformSpotStopPrompt = '[E] Stop omdannelse'

Config.TerminalDefaultOffset = vector4(-8.7715, 1.5569, -0.26, 93.9876)
Config.TerminalSpotRadius = 2.0
Config.TerminalSpotPrompt = '[E] Åbn lab terminal'
Config.TerminalMarker = {
    draw = false,
    type = 27,
    scale = vector3(0.6, 0.6, 0.3),
    color = { r = 111, g = 73, b = 121, a = 150 },
}

Config.WorldEntranceZoneSize = vector3(1.5, 1.5, 2.0)
Config.EntranceKeypadZoneSize = vector3(1.5, 1.5, 2.0)
Config.LabZoneSize = vector3(2.0, 2.0, 2.0)
Config.LabBlip = {
    sprite = 514,
    color = 2,
    scale = 0.9,
    label = 'Mit druglab',
}

Config.DiscordWebhookCreateLab = 'webhook-her'
Config.DiscordWebhookBuyLab = 'webhook-her'

Config.ShellBaseZEntrance = 2000.0
Config.ShellBaseZLab = 2100.0
Config.LabEntrances = {}

Config.InventoryItems = {}
Config.StockLevels = {}

Config.ProductionStageDuration = 60000
Config.ProductionTickInterval = 1000
