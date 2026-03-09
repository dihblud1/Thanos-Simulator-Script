-- ============================================================
--  Infinity Gauntlet | Thanos Simulator — Auto Farm v14
--  Features: Godmode • Auto Gauntlet • Kill Aura • Auto-Walk
--            Cooldown Break • Rapid Fire • Auto Abilities
--            Auto-Upgrade Detector • 6-Tab GUI • Notifications
--  Loader: loadstring(game:HttpGet("YOUR_RAW_GITHUB_URL"))()
-- ============================================================

local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer        = Players.LocalPlayer

-- ──────────────────────────────────────────────────────────
--  CONFIG
-- ──────────────────────────────────────────────────────────

local WEAPON_PRIORITY = {
    "Blitz", "The Secret Weapon", "Secret Weapon", "Secret",
    "Techno Blade", "Technoblade Sword", "Mjolnir", "Infinity Gauntlet",
    "Stormbreaker", "Upgraded Stormbreaker", "Hadron Enforcer",
    "Casket of Ancient Winters", "Time Stick", "Cosmi-Rod",
    "Universal Weapon", "Gungnir", "TemPad",
}

local CATACOMBS_NAMES = {
    "catacomb", "skeleton", "undead", "crypt", "bones", "revenant",
    "wraith", "ghoul", "lich", "grave", "tomb", "cursed", "spirit",
    "phantom", "specter", "level 1 servant",
}

local SERVANT_NAMES = {
    "level 1 servant of the celestial", "servant of the celestial",
    "servants of the celestial", "servant", "celestial",
}

local TP_LOCATIONS = {
    { name = "Spawn",           cframe = CFrame.new(0,    5,   0)  },
    { name = "Catacombs",       cframe = CFrame.new(200,  5,  300) },
    { name = "Arena",           cframe = CFrame.new(-300, 5,  100) },
    { name = "Boss Room",       cframe = CFrame.new(500,  5, -200) },
    { name = "Celestial Forge", cframe = CFrame.new(210,  5,  315) },
}

local ABILITIES = {
    { key = Enum.KeyCode.E, cd = 8,  label = "Disintegrate" },
    { key = Enum.KeyCode.V, cd = 12, label = "Decimate"     },
    { key = Enum.KeyCode.T, cd = 15, label = "Timestop"     },
    { key = Enum.KeyCode.Q, cd = 6,  label = "Charge"       },
    { key = Enum.KeyCode.C, cd = 10, label = "Shield"       },
    { key = Enum.KeyCode.R, cd = 5,  label = "Focus/Heal"   },
}

local DEBOUNCE_KEYS = {
    "debounce", "Debounce", "cooldown", "Cooldown",
    "attacking", "Attacking", "swinging", "Swinging",
    "canAttack", "CanAttack", "canSwing", "CanSwing",
    "onCooldown", "OnCooldown", "active", "Active", "busy", "Busy",
}

local BLOCKED_CONTAINS     = { "jimmy", "templar", "shopkeeper" }
local BLOCKED_PARENT_NAMES = { "shop", "stand", "stall", "vendor", "market", "store" }
local STREAK_MILESTONES    = { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 }

local CATACOMBS_POS      = Vector3.new(200, 5, 300)
local CELESTIAL_FORGE_CF = CFrame.new(210, 5, 315)
local UPGRADE_THRESHOLD  = 200000

local GODMODE_INTERVAL   = 0.033
local SWING_WAIT_BASE    = 0.065
local PRE_SWING_WAIT     = 0.12
local SWING_COUNT_MIN    = 40
local SWING_COUNT_MAX    = 60
local TP_OFFSET          = 2.5
local LINGER_TIME_MIN    = 1.5
local LINGER_TIME_MAX    = 2.5
local LINGER_CHECK_RATE  = 0.2
local CYCLE_WAIT_MIN     = 0.4
local CYCLE_WAIT_MAX     = 0.6
local DEATH_CHECK_INT    = 3
local RESPAWN_WAIT       = 2.5
local BASE_WIN_W         = 280
local BASE_WIN_H         = 330

-- ──────────────────────────────────────────────────────────
--  STATE
-- ──────────────────────────────────────────────────────────

local isAlive             = false
local isRespawning        = false
local isWalking           = false
local farmEnabled         = false
local godmodeEnabled      = true
local autoGauntlet        = true
local killAuraEnabled     = false
local cooldownBreak       = false
local rapidFireEnabled    = false
local autoWalkEnabled     = false
local abilityEnabled      = false
local whitelistEnabled    = false
local godmodeConnections  = {}
local cachedAttackRemotes = {}
local whitelistNames      = {}
local killCount           = 0
local currentWeapon       = "None"
local currentTarget       = "None"
local statusText          = "Idle"
local farmSpeedMult       = 1
local rapidFireCount      = 3
local killAuraRadius      = 20
local sessionStart        = os.clock()
local killsThisMinute     = {}
local nextStreakIdx        = 1
local upgradeNotified     = false
local upgradeComplete     = false
local abilityLastFired    = {}
for i = 1, #ABILITIES do abilityLastFired[i] = 0 end

-- ──────────────────────────────────────────────────────────
--  HELPERS
-- ──────────────────────────────────────────────────────────

local function randomFloat(a, b)
    return a + math.random() * (b - a)
end

local function getLocalParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return nil, nil, nil end
    return char, hum, root
end

local function isDead(hum)
    if not hum or not hum.Parent then return true end
    if hum.Health <= 0 then return true end
    if hum:GetState() == Enum.HumanoidStateType.Dead then return true end
    return false
end

local function hasWeapon()
    local bp   = LocalPlayer:FindFirstChildOfClass("Backpack")
    local char = LocalPlayer.Character
    for _, wn in ipairs(WEAPON_PRIORITY) do
        if bp   and bp:FindFirstChild(wn)   then return true end
        if char and char:FindFirstChild(wn) then return true end
    end
    return false
end

local function isBlocked(name)
    local low = name:lower()
    for _, p in ipairs(BLOCKED_CONTAINS) do
        if low:find(p) then return true end
    end
    return false
end

local function passesWhitelist(name)
    if not whitelistEnabled or #whitelistNames == 0 then return true end
    local low = name:lower()
    for _, w in ipairs(whitelistNames) do
        if low:find(w) then return true end
    end
    return false
end

local function getTargetTier(name)
    local low = name:lower()
    for _, k in ipairs(CATACOMBS_NAMES) do if low:find(k) then return 1 end end
    for _, k in ipairs(SERVANT_NAMES)   do if low:find(k) then return 2 end end
    return 3
end

local function getKillsPerHour()
    local now, fresh = os.clock(), {}
    for _, t in ipairs(killsThisMinute) do
        if t >= now - 60 then table.insert(fresh, t) end
    end
    killsThisMinute = fresh
    return math.floor(#fresh * 60)
end

local function getSessionTime()
    local e = os.clock() - sessionStart
    local h = math.floor(e / 3600)
    local m = math.floor((e % 3600) / 60)
    local s = math.floor(e % 60)
    return h > 0
        and string.format("%dh %02dm %02ds", h, m, s)
        or  string.format("%dm %02ds", m, s)
end

-- ──────────────────────────────────────────────────────────
--  NOTIFICATIONS
-- ──────────────────────────────────────────────────────────

local notifQueue  = {}
local notifActive = false

local function pushNotif(icon, title, body, color)
    table.insert(notifQueue, {
        icon  = icon,
        title = title,
        body  = body,
        color = color or Color3.fromRGB(90, 0, 180),
    })
end

local notifGui = Instance.new("ScreenGui")
notifGui.Name           = "ThanosNotifs"
notifGui.ResetOnSpawn   = false
notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
notifGui.Parent         = LocalPlayer:WaitForChild("PlayerGui")

local function showNextNotif()
    if notifActive or #notifQueue == 0 then return end
    notifActive = true
    local n = table.remove(notifQueue, 1)

    local card = Instance.new("Frame", notifGui)
    card.Size             = UDim2.new(0, 220, 0, 54)
    card.Position         = UDim2.new(1, 10, 0, 12)
    card.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
    card.BorderSizePixel  = 0
    card.ZIndex           = 20
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", card)
    stroke.Color     = n.color
    stroke.Thickness = 1

    local accent = Instance.new("Frame", card)
    accent.Size             = UDim2.new(0, 4, 1, 0)
    accent.BackgroundColor3 = n.color
    accent.BorderSizePixel  = 0
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 4)

    local ico = Instance.new("TextLabel", card)
    ico.Size                   = UDim2.new(0, 32, 1, 0)
    ico.Position               = UDim2.new(0, 8, 0, 0)
    ico.BackgroundTransparency = 1
    ico.Text                   = n.icon
    ico.TextSize               = 22
    ico.Font                   = Enum.Font.GothamBold
    ico.TextXAlignment         = Enum.TextXAlignment.Center
    ico.ZIndex                 = 21

    local ttl = Instance.new("TextLabel", card)
    ttl.Size                   = UDim2.new(1, -52, 0, 24)
    ttl.Position               = UDim2.new(0, 44, 0, 5)
    ttl.BackgroundTransparency = 1
    ttl.Text                   = n.title
    ttl.TextColor3             = Color3.fromRGB(210, 160, 255)
    ttl.TextSize               = 11
    ttl.Font                   = Enum.Font.GothamBold
    ttl.TextXAlignment         = Enum.TextXAlignment.Left
    ttl.ZIndex                 = 21

    local bod = Instance.new("TextLabel", card)
    bod.Size                   = UDim2.new(1, -52, 0, 20)
    bod.Position               = UDim2.new(0, 44, 0, 28)
    bod.BackgroundTransparency = 1
    bod.Text                   = n.body
    bod.TextColor3             = Color3.fromRGB(160, 160, 180)
    bod.TextSize               = 10
    bod.Font                   = Enum.Font.Gotham
    bod.TextXAlignment         = Enum.TextXAlignment.Left
    bod.ZIndex                 = 21

    TweenService:Create(card,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(1, -230, 0, 12) }
    ):Play()

    task.delay(3, function()
        local t = TweenService:Create(card,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(1, 10, 0, 12) }
        )
        t:Play()
        t.Completed:Once(function()
            card:Destroy()
            notifActive = false
            task.wait(0.15)
            showNextNotif()
        end)
    end)
end

task.spawn(function()
    while true do
        showNextNotif()
        task.wait(0.1)
    end
end)

local function checkStreak()
    if nextStreakIdx > #STREAK_MILESTONES then return end
    if killCount >= STREAK_MILESTONES[nextStreakIdx] then
        pushNotif("🔥", "KILL STREAK!", STREAK_MILESTONES[nextStreakIdx] .. " kills!", Color3.fromRGB(200, 80, 0))
        nextStreakIdx = nextStreakIdx + 1
    end
end

-- ──────────────────────────────────────────────────────────
--  VIRTUAL INPUT MANAGER
-- ──────────────────────────────────────────────────────────

local VIM
pcall(function()
    VIM = cloneref and cloneref(game:GetService("VirtualInputManager"))
                    or game:GetService("VirtualInputManager")
end)

local function fireKey(keyCode)
    if not VIM then return end
    pcall(function()
        VIM:SendKeyEvent(true,  keyCode, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, keyCode, false, game)
    end)
end

-- ──────────────────────────────────────────────────────────
--  AUTO-ABILITY SPAM
-- ──────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        if abilityEnabled and farmEnabled and isAlive then
            local now = os.clock()
            for i, ab in ipairs(ABILITIES) do
                if now - abilityLastFired[i] >= ab.cd then
                    pcall(function() fireKey(ab.key) end)
                    abilityLastFired[i] = now
                    task.wait(0.15)
                end
            end
        end
        task.wait(0.5)
    end
end)

-- ──────────────────────────────────────────────────────────
--  AUTO-UPGRADE DETECTOR
-- ──────────────────────────────────────────────────────────

local function findForgeButton()
    local kws = { "upgrade", "ascend", "forge", "celestial", "evolve", "transcend" }
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("ProximityPrompt") then
            local txt = (obj.Text or obj.ActionText or obj.Name or ""):lower()
            for _, kw in ipairs(kws) do
                if txt:find(kw) then return obj end
            end
        end
    end
    return nil
end

local function tryForgeUpgrade()
    local btn = findForgeButton()
    if not btn then
        local _, _, root = getLocalParts()
        if root then
            root.CFrame = CELESTIAL_FORGE_CF
            task.wait(1)
            btn = findForgeButton()
        end
    end
    if btn then
        pcall(function() firebutton(btn) end)
        pcall(function() btn.MouseButton1Click:Fire() end)
        pcall(function() btn.Activated:Fire() end)
        if btn:IsA("ProximityPrompt") then
            pcall(function()
                firetouchinterest(btn.Parent, LocalPlayer.Character.HumanoidRootPart, 0)
            end)
        end
        task.wait(0.5)
        pushNotif("⚡", "Upgrade Attempted!", "Check if gauntlet ascended", Color3.fromRGB(255, 180, 0))
        upgradeComplete = true
    else
        pushNotif("⚠️", "Forge Not Found", "TP to Forge — press upgrade manually", Color3.fromRGB(180, 80, 0))
    end
end

task.spawn(function()
    while true do
        if not upgradeComplete and killCount >= UPGRADE_THRESHOLD then
            if not upgradeNotified then
                upgradeNotified = true
                pushNotif("🔱", "200K KILLS!", "Heading to Celestial Forge...", Color3.fromRGB(255, 200, 0))
                task.wait(2)
                pcall(tryForgeUpgrade)
            end
        end
        if killCount < UPGRADE_THRESHOLD then
            upgradeNotified = false
        end
        task.wait(2)
    end
end)

-- ──────────────────────────────────────────────────────────
--  COOLDOWN BREAK
-- ──────────────────────────────────────────────────────────

local function breakToolCooldowns()
    if not cooldownBreak then return end
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then return end
        for _, s in ipairs(tool:GetDescendants()) do
            if s:IsA("LocalScript") or s:IsA("ModuleScript") then
                for _, fn in ipairs({ getfenv, getrenv }) do
                    pcall(function()
                        local env = fn and fn(s)
                        if not env then return end
                        for _, key in ipairs(DEBOUNCE_KEYS) do
                            if env[key] == true then env[key] = false end
                            if type(env[key]) == "number" and env[key] > 0 then env[key] = 0 end
                        end
                    end)
                end
            end
        end
    end)
end

-- ──────────────────────────────────────────────────────────
--  TOOL ACTIVATION
-- ──────────────────────────────────────────────────────────

local function refreshAttackRemotes()
    cachedAttackRemotes = {}
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then return end
        local kws = { "swing", "attack", "hit", "damage", "activate", "slash", "strike", "smash" }
        for _, v in ipairs(tool:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local low = v.Name:lower()
                for _, kw in ipairs(kws) do
                    if low:find(kw) then
                        table.insert(cachedAttackRemotes, v)
                        break
                    end
                end
            end
        end
    end)
end

local function fireAttackRemotes(times)
    for _, r in ipairs(cachedAttackRemotes) do
        for _ = 1, (times or 1) do
            pcall(function() r:FireServer() end)
        end
    end
end

local function doSwing()
    if cooldownBreak then breakToolCooldowns() end
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then return end

        pcall(function() tool:Activate() end)
        if VIM then pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, true,  game, 0) end) end
        task.wait(0.04)
        if VIM then pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0) end) end

        local handle = tool:FindFirstChild("Handle")
        if handle then
            pcall(function() firetouchinterest(handle, char.HumanoidRootPart, 0) end)
            pcall(function() firetouchinterest(handle, char.HumanoidRootPart, 1) end)
            local cd = handle:FindFirstChildOfClass("ClickDetector")
            if cd then pcall(function() fireclickdetector(cd) end) end
        end

        fireAttackRemotes(rapidFireEnabled and rapidFireCount or 1)
    end)
end

-- ──────────────────────────────────────────────────────────
--  WEAPON EQUIP
-- ──────────────────────────────────────────────────────────

local function getBestWeapon()
    local bp   = LocalPlayer:FindFirstChildOfClass("Backpack")
    local char = LocalPlayer.Character
    for _, wn in ipairs(WEAPON_PRIORITY) do
        if bp   then local t = bp:FindFirstChild(wn)   if t and t:IsA("Tool") then return t, wn end end
        if char then local t = char:FindFirstChild(wn) if t and t:IsA("Tool") then return t, wn end end
    end
    return nil, nil
end

local function equipBestWeapon()
    local tool, name = getBestWeapon()
    if not tool then return nil, nil end
    local _, hum = getLocalParts()
    if not hum then return nil, nil end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp and bp:FindFirstChild(name) then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.1)
        if currentWeapon ~= name then
            currentWeapon = name
            refreshAttackRemotes()
            pushNotif("⚔️", "Weapon Equipped", name, Color3.fromRGB(60, 0, 160))
        end
    end
    return tool, name
end

-- ──────────────────────────────────────────────────────────
--  ENEMY SCANNER
-- ──────────────────────────────────────────────────────────

local function isRealEnemy(model, hum)
    if model.Parent then
        local pn = model.Parent.Name:lower()
        for _, kw in ipairs(BLOCKED_PARENT_NAMES) do
            if pn:find(kw) then return false end
        end
    end
    if hum.MaxHealth == math.huge or hum.MaxHealth >= 1e15 then return false end
    for _, v in ipairs(model:GetDescendants()) do
        if v:IsA("ProximityPrompt") then return false end
        if v:IsA("BillboardGui")    then return false end
        if v:IsA("SurfaceGui")      then return false end
    end
    return true
end

local function scanEnemies()
    local catacombs, servants, other = {}, {}, {}
    local myChar = LocalPlayer.Character
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Health > 0 then
            local model = obj.Parent
            if model and model ~= myChar then
                local root = model:FindFirstChild("HumanoidRootPart")
                if root and not isBlocked(model.Name) and passesWhitelist(model.Name) then
                    local isPlayer = false
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Character == model then isPlayer = true break end
                    end
                    if not isPlayer and isRealEnemy(model, obj) then
                        local entry = { model = model, hum = obj, root = root }
                        local tier  = getTargetTier(model.Name)
                        if     tier == 1 then table.insert(catacombs, entry)
                        elseif tier == 2 then table.insert(servants,  entry)
                        else                  table.insert(other,     entry)
                        end
                    end
                end
            end
        end
    end
    return catacombs, servants, other
end

local function getNearbyEnemies(radius)
    local _, _, myRoot = getLocalParts()
    if not myRoot then return {} end
    local cats, servs, other = scanEnemies()
    local all, nearby = {}, {}
    for _, e in ipairs(cats)  do table.insert(all, e) end
    for _, e in ipairs(servs) do table.insert(all, e) end
    for _, e in ipairs(other) do table.insert(all, e) end
    for _, e in ipairs(all) do
        if (e.root.Position - myRoot.Position).Magnitude <= radius and not isDead(e.hum) then
            table.insert(nearby, e)
        end
    end
    return nearby
end

-- ──────────────────────────────────────────────────────────
--  AUTO-WALK
-- ──────────────────────────────────────────────────────────

local function walkToCatacombs()
    if not autoWalkEnabled or isWalking then return end
    local _, hum, root = getLocalParts()
    if not hum or not root then return end
    if (root.Position - CATACOMBS_POS).Magnitude < 30 then return end

    isWalking  = true
    statusText = "Walking to Catacombs..."
    pushNotif("🚶", "Auto-Walk", "No enemies — heading to Catacombs", Color3.fromRGB(0, 100, 180))

    task.spawn(function()
        pcall(function()
            local path = PathfindingService:CreatePath({
                AgentHeight  = 5,
                AgentRadius  = 2,
                AgentCanJump = true,
            })
            path:ComputeAsync(root.Position, CATACOMBS_POS)
            if path.Status == Enum.PathStatus.Success then
                for _, wp in ipairs(path:GetWaypoints()) do
                    if not farmEnabled or not autoWalkEnabled then break end
                    if #(scanEnemies()) > 0 then break end
                    hum:MoveTo(wp.Position)
                    if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
                    hum.MoveToFinished:Wait()
                end
            else
                hum:MoveTo(CATACOMBS_POS)
                hum.MoveToFinished:Wait()
            end
        end)
        isWalking  = false
        statusText = farmEnabled and "Arrived — scanning..." or "Idle"
    end)
end

-- ──────────────────────────────────────────────────────────
--  SWING BURST
-- ──────────────────────────────────────────────────────────

local function swingBurst(weaponName, targetHum)
    if not weaponName then return true end
    local count     = math.random(SWING_COUNT_MIN, SWING_COUNT_MAX)
    local swingWait = math.max(0.01, SWING_WAIT_BASE / farmSpeedMult)
    if cooldownBreak then swingWait = swingWait * 0.2 end
    for i = 1, count do
        if not farmEnabled then return true end
        if i % DEATH_CHECK_INT == 0 and isDead(targetHum) then return true end
        doSwing()
        task.wait(swingWait)
    end
    return isDead(targetHum)
end

-- ──────────────────────────────────────────────────────────
--  KILL AURA
-- ──────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        if killAuraEnabled and farmEnabled and isAlive then
            pcall(function()
                local _, weaponName = equipBestWeapon()
                if not weaponName then return end
                local nearby = getNearbyEnemies(killAuraRadius)
                if #nearby == 0 then return end
                local _, _, myRoot = getLocalParts()
                if not myRoot then return end
                local sw = math.max(0.01, SWING_WAIT_BASE / farmSpeedMult)
                if cooldownBreak then sw = sw * 0.2 end
                local killed = 0
                for _, e in ipairs(nearby) do
                    if not farmEnabled then break end
                    if not isDead(e.hum) then
                        pcall(function()
                            myRoot.CFrame = e.root.CFrame
                                + Vector3.new(randomFloat(-1.5, 1.5), 0, randomFloat(-1.5, 1.5))
                        end)
                        task.wait(0.03)
                        doSwing()
                        task.wait(sw)
                        if isDead(e.hum) then
                            killed    = killed + 1
                            killCount = killCount + 1
                            table.insert(killsThisMinute, os.clock())
                            checkStreak()
                        end
                    end
                end
                if killed > 0 then
                    currentTarget = "Kill Aura +" .. killed
                    statusText    = "Kill Aura " .. farmSpeedMult .. "x"
                end
            end)
        end
        task.wait(math.max(0.05, 0.3 / farmSpeedMult))
    end
end)

-- ──────────────────────────────────────────────────────────
--  LINGER
-- ──────────────────────────────────────────────────────────

local function lingerAndSwing()
    local elapsed = 0
    local t       = randomFloat(LINGER_TIME_MIN, LINGER_TIME_MAX)
    currentTarget = "Lingering..."
    while elapsed < t do
        if not farmEnabled then break end
        if #(scanEnemies()) > 0 then break end
        doSwing()
        task.wait(LINGER_CHECK_RATE)
        elapsed = elapsed + LINGER_CHECK_RATE
    end
end

-- ──────────────────────────────────────────────────────────
--  GODMODE
-- ──────────────────────────────────────────────────────────

local function clearConnections()
    for _, c in ipairs(godmodeConnections) do
        pcall(function() c:Disconnect() end)
    end
    godmodeConnections = {}
end

local function setupGodmode(char, hum)
    clearConnections()
    table.insert(godmodeConnections, hum.HealthChanged:Connect(function(hp)
        if not godmodeEnabled then return end
        if hp < hum.MaxHealth then
            pcall(function()
                hum.MaxHealth = math.huge
                hum.Health    = math.huge
            end)
        end
    end))
    table.insert(godmodeConnections, hum.StateChanged:Connect(function(_, new)
        if not godmodeEnabled then return end
        if new == Enum.HumanoidStateType.Dead then
            pcall(function()
                hum.MaxHealth = math.huge
                hum.Health    = math.huge
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
    end))
    pcall(function()
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("Motor6D") or v:IsA("Weld") then v.Enabled = true end
        end
    end)
end

task.spawn(function()
    while true do
        if godmodeEnabled then
            pcall(function()
                local char, hum = getLocalParts()
                if char and hum then
                    if not char:FindFirstChildOfClass("ForceField") then
                        local ff = Instance.new("ForceField", char)
                        ff.Visible = false
                    end
                    hum.MaxHealth = math.huge
                    hum.Health    = math.huge
                end
            end)
        end
        task.wait(GODMODE_INTERVAL)
    end
end)

-- ──────────────────────────────────────────────────────────
--  AUTO GAUNTLET
-- ──────────────────────────────────────────────────────────

local function findGauntletButton()
    local function check(obj)
        local txt = (obj.Text or ""):lower()
        return txt:find("fine") or txt:find("myself") or txt:find("thanos")
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and check(obj) then return obj end
    end
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, obj in ipairs(pg:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and check(obj) then return obj end
        end
    end
    return nil
end

local function findGauntletRemote()
    local kws = { "gauntlet", "weapon", "give", "grant", "equip", "stone", "infinity" }
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local low = obj.Name:lower()
            for _, kw in ipairs(kws) do if low:find(kw) then return obj end end
        end
    end
    return nil
end

local function tryAcquireGauntlet()
    if not autoGauntlet or hasWeapon() then return hasWeapon() end
    statusText = "Acquiring gauntlet..."
    local btn  = findGauntletButton()
    if btn then
        pcall(function() firebutton(btn) end)
        pcall(function() btn.MouseButton1Click:Fire() end)
        pcall(function() btn.Activated:Fire() end)
        pcall(function()
            btn.MouseButton1Down:Fire(0, 0)
            task.wait(0.05)
            btn.MouseButton1Up:Fire(0, 0)
        end)
        task.wait(0.5)
        if hasWeapon() then return true end
    end
    local remote = findGauntletRemote()
    if remote then
        pcall(function()
            if remote:IsA("RemoteEvent") then remote:FireServer() else remote:InvokeServer() end
        end)
        task.wait(0.5)
        if hasWeapon() then return true end
    end
    if btn then
        pcall(function()
            local p = btn.Parent
            while p and not p:IsA("BasePart") do p = p.Parent end
            if p then
                local _, _, root = getLocalParts()
                if root then root.CFrame = p.CFrame + Vector3.new(0, 4, 0) end
            end
        end)
        task.wait(0.5)
    end
    return hasWeapon()
end

local function acquireGauntletLoop()
    task.spawn(function()
        for _ = 1, 40 do
            if hasWeapon() then
                pushNotif("✊", "Gauntlet Ready!", currentWeapon, Color3.fromRGB(130, 0, 255))
                statusText = farmEnabled and "Farming..." or "Ready"
                return
            end
            tryAcquireGauntlet()
            task.wait(0.5)
        end
    end)
end

-- ──────────────────────────────────────────────────────────
--  CHARACTER SETUP
-- ──────────────────────────────────────────────────────────

local function onCharacterAdded(char)
    isAlive       = true
    isRespawning  = false
    isWalking     = false
    currentTarget = "None"
    statusText    = "Spawned"

    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end

    setupGodmode(char, hum)

    local ff = Instance.new("ForceField", char)
    ff.Visible    = false
    hum.MaxHealth = math.huge
    hum.Health    = math.huge

    task.delay(1.5, acquireGauntletLoop)

    hum.Died:Once(function()
        if isRespawning then return end
        isRespawning  = true
        isAlive       = false
        isWalking     = false
        currentTarget = "None"
        statusText    = "Respawning..."
        pushNotif("💀", "Respawning", "Back in " .. RESPAWN_WAIT .. "s", Color3.fromRGB(150, 0, 0))
        task.delay(RESPAWN_WAIT, function()
            pcall(function() LocalPlayer:LoadCharacter() end)
        end)
    end)
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then
    task.spawn(function() onCharacterAdded(LocalPlayer.Character) end)
end

-- ──────────────────────────────────────────────────────────
--  MAIN FARM LOOP
-- ──────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        if not farmEnabled then
            statusText    = "Idle"
            currentTarget = "None"
            task.wait(0.25)
            continue
        end

        if not isAlive then
            statusText = "Waiting to respawn..."
            task.wait(0.5)
            continue
        end

        pcall(function()
            if not farmEnabled then return end

            local _, _, myRoot = getLocalParts()
            if not myRoot then return end

            local _, weaponName = equipBestWeapon()
            if not weaponName then
                statusText = "Finding gauntlet..."
                tryAcquireGauntlet()
                task.wait(1)
                return
            end

            if killAuraEnabled then
                statusText = "Kill Aura " .. farmSpeedMult .. "x"
                task.wait(0.3)
                return
            end

            local cats, servs, other = scanEnemies()
            local pool, tierName

            if     #cats  > 0 then pool = cats   tierName = "Catacombs"
            elseif #servs > 0 then pool = servs  tierName = "Servant"
            elseif #other > 0 then pool = other  tierName = "Other"
            else
                if autoWalkEnabled and not isWalking then
                    walkToCatacombs()
                else
                    statusText    = whitelistEnabled and "No whitelisted enemies" or "No enemies"
                    currentTarget = "None"
                end
                return
            end

            local target  = pool[math.random(1, #pool)]
            currentTarget = target.model.Name .. " [" .. tierName .. "]"
            statusText    = "Farming " .. tierName .. " " .. farmSpeedMult .. "x"

            if not farmEnabled then return end
            local _, _, root = getLocalParts()
            if not root then return end

            root.CFrame = target.root.CFrame
                + Vector3.new(randomFloat(-TP_OFFSET, TP_OFFSET), 0, randomFloat(-TP_OFFSET, TP_OFFSET))
            task.wait(PRE_SWING_WAIT)

            local died = false
            repeat
                if not farmEnabled then break end
                if isDead(target.hum) then died = true break end
                died = swingBurst(weaponName, target.hum)
            until died

            if died and farmEnabled then
                killCount = killCount + 1
                table.insert(killsThisMinute, os.clock())
                checkStreak()
                lingerAndSwing()
            end
        end)

        task.wait(math.max(0.05, randomFloat(CYCLE_WAIT_MIN, CYCLE_WAIT_MAX) / farmSpeedMult))
    end
end)

-- ══════════════════════════════════════════════════════════
--  GUI — 6 Tabs | iPhone 13 Pro Landscape | 280 x 330
-- ══════════════════════════════════════════════════════════

local sg = Instance.new("ScreenGui")
sg.Name           = "ThanosHub"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent         = LocalPlayer:WaitForChild("PlayerGui")

local win = Instance.new("Frame", sg)
win.Name             = "Win"
win.Size             = UDim2.new(0, BASE_WIN_W, 0, BASE_WIN_H)
win.Position         = UDim2.new(0, 12, 0.5, -(BASE_WIN_H / 2))
win.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
win.BorderSizePixel  = 0
win.Active           = true
win.Draggable        = false
win.ClipsDescendants = true
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 10)
local winStroke = Instance.new("UIStroke", win)
winStroke.Color     = Color3.fromRGB(100, 0, 200)
winStroke.Thickness = 1.5

-- Title bar (ONLY draggable element)
local titleBar = Instance.new("Frame", win)
titleBar.Name             = "TitleBar"
titleBar.Size             = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = Color3.fromRGB(18, 0, 42)
titleBar.BorderSizePixel  = 0
titleBar.ZIndex           = 5
titleBar.Active           = true
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleCap = Instance.new("Frame", titleBar)
titleCap.Size             = UDim2.new(1, 0, 0.5, 0)
titleCap.Position         = UDim2.new(0, 0, 0.5, 0)
titleCap.BackgroundColor3 = Color3.fromRGB(18, 0, 42)
titleCap.BorderSizePixel  = 0

local titleLabel = Instance.new("TextLabel", titleBar)
titleLabel.Size                   = UDim2.new(1, -60, 1, 0)
titleLabel.Position               = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                   = "⚡ THANOS FARM v14"
titleLabel.TextColor3             = Color3.fromRGB(190, 130, 255)
titleLabel.TextSize               = 13
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.ZIndex                 = 6

local minBtn = Instance.new("TextButton", titleBar)
minBtn.Size             = UDim2.new(0, 24, 0, 24)
minBtn.Position         = UDim2.new(1, -28, 0.5, -12)
minBtn.BackgroundColor3 = Color3.fromRGB(60, 0, 130)
minBtn.Text             = "−"
minBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
minBtn.TextSize         = 14
minBtn.Font             = Enum.Font.GothamBold
minBtn.BorderSizePixel  = 0
minBtn.ZIndex           = 7
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)

-- Tab bar
local TAB_DEFS = {
    { icon = "🗡",  label = "FARM"   },
    { icon = "💥",  label = "COMBAT" },
    { icon = "✨",  label = "ABILTY" },
    { icon = "📊",  label = "STATS"  },
    { icon = "📍",  label = "TP"     },
    { icon = "⚙️",  label = "MORE"   },
}

local tabBar = Instance.new("Frame", win)
tabBar.Size             = UDim2.new(1, 0, 0, 36)
tabBar.Position         = UDim2.new(0, 0, 0, 32)
tabBar.BackgroundColor3 = Color3.fromRGB(14, 0, 30)
tabBar.BorderSizePixel  = 0
tabBar.ZIndex           = 5
tabBar.Active           = true
local tabLayout = Instance.new("UIListLayout", tabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder     = Enum.SortOrder.LayoutOrder
tabLayout.Padding       = UDim.new(0, 0)

local pageContainer = Instance.new("Frame", win)
pageContainer.Size                   = UDim2.new(1, -8, 1, -76)
pageContainer.Position               = UDim2.new(0, 4, 0, 72)
pageContainer.BackgroundTransparency = 1
pageContainer.ClipsDescendants       = true

local resizeHandle = Instance.new("TextButton", win)
resizeHandle.Size             = UDim2.new(0, 14, 0, 14)
resizeHandle.Position         = UDim2.new(1, -14, 1, -14)
resizeHandle.BackgroundColor3 = Color3.fromRGB(100, 0, 200)
resizeHandle.Text             = ""
resizeHandle.BorderSizePixel  = 0
resizeHandle.ZIndex           = 10
Instance.new("UICorner", resizeHandle).CornerRadius = UDim.new(0, 3)

-- Drag / resize logic
local draggingWin = false
local dragStart   = Vector2.new()
local winStart    = Vector2.new()
local resizing    = false
local resizeStart = Vector2.new()
local sizeStart   = Vector2.new()
local savedSize   = Vector2.new(BASE_WIN_W, BASE_WIN_H)
local minimized   = false

titleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        draggingWin = true
        dragStart   = Vector2.new(inp.Position.X, inp.Position.Y)
        winStart    = Vector2.new(win.AbsolutePosition.X, win.AbsolutePosition.Y)
    end
end)

resizeHandle.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        resizing    = true
        resizeStart = Vector2.new(inp.Position.X, inp.Position.Y)
        sizeStart   = Vector2.new(win.AbsoluteSize.X, win.AbsoluteSize.Y)
    end
end)

UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        draggingWin = false
        resizing    = false
    end
end)

UserInputService.InputChanged:Connect(function(inp)
    if inp.UserInputType ~= Enum.UserInputType.MouseMovement
    and inp.UserInputType ~= Enum.UserInputType.Touch then return end

    if draggingWin then
        local delta  = Vector2.new(inp.Position.X, inp.Position.Y) - dragStart
        local inset  = game:GetService("GuiService"):GetGuiInset()
        win.Position = UDim2.new(0, winStart.X + delta.X, 0, winStart.Y + delta.Y - inset.Y)
    end

    if resizing and not minimized then
        local delta = Vector2.new(inp.Position.X, inp.Position.Y) - resizeStart
        local newW  = math.clamp(sizeStart.X + delta.X, 200, 500)
        local newH  = math.clamp(sizeStart.Y + delta.Y, 80,  500)
        win.Size    = UDim2.new(0, newW, 0, newH)
        savedSize   = Vector2.new(newW, newH)
    end
end)

minBtn.MouseButton1Click:Connect(function()
    minimized             = not minimized
    tabBar.Visible        = not minimized
    pageContainer.Visible = not minimized
    resizeHandle.Visible  = not minimized
    win.Size = minimized
        and UDim2.new(0, win.AbsoluteSize.X, 0, 32)
        or  UDim2.new(0, savedSize.X, 0, savedSize.Y)
    minBtn.Text = minimized and "+" or "−"
end)

-- ──────────────────────────────────────────────────────────
--  TAB SYSTEM
-- ──────────────────────────────────────────────────────────

local pages   = {}
local tabBtns = {}

local function makeScroll(parent)
    local s = Instance.new("ScrollingFrame", parent)
    s.Size                = UDim2.new(1, 0, 1, 0)
    s.BackgroundTransparency = 1
    s.ScrollBarThickness  = 2
    s.ScrollBarImageColor3= Color3.fromRGB(100, 0, 200)
    s.CanvasSize          = UDim2.new(0, 0, 0, 0)
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.BorderSizePixel     = 0
    local l = Instance.new("UIListLayout", s)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding   = UDim.new(0, 4)
    return s
end

local function switchTab(idx)
    for i, page in ipairs(pages) do page.Visible = (i == idx) end
    for i, btn  in ipairs(tabBtns) do
        btn.BackgroundColor3 = (i == idx) and Color3.fromRGB(80, 0, 160) or Color3.fromRGB(14, 0, 30)
        btn.TextColor3       = (i == idx) and Color3.fromRGB(255, 220, 255) or Color3.fromRGB(130, 100, 180)
    end
end

for i, td in ipairs(TAB_DEFS) do
    local btn = Instance.new("TextButton", tabBar)
    btn.LayoutOrder      = i
    btn.Size             = UDim2.new(1 / #TAB_DEFS, 0, 1, 0)
    btn.BackgroundColor3 = i == 1 and Color3.fromRGB(80, 0, 160) or Color3.fromRGB(14, 0, 30)
    btn.Text             = td.icon .. "\n" .. td.label
    btn.TextColor3       = i == 1 and Color3.fromRGB(255, 220, 255) or Color3.fromRGB(130, 100, 180)
    btn.TextSize         = 8
    btn.Font             = Enum.Font.GothamBold
    btn.BorderSizePixel  = 0
    btn.ZIndex           = 6
    btn.MouseButton1Click:Connect(function() switchTab(i) end)
    tabBtns[i] = btn

    local page = Instance.new("Frame", pageContainer)
    page.Size                   = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible                = (i == 1)
    pages[i] = page
end

-- ──────────────────────────────────────────────────────────
--  WIDGET BUILDERS
-- ──────────────────────────────────────────────────────────

local layoutOrder = 0
local function nextOrder()
    layoutOrder = layoutOrder + 1
    return layoutOrder
end

local function makeSectionLabel(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.LayoutOrder               = nextOrder()
    lbl.Size                      = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency    = 1
    lbl.Text                      = text
    lbl.TextColor3                = Color3.fromRGB(90, 60, 130)
    lbl.TextSize                  = 9
    lbl.Font                      = Enum.Font.GothamBold
    lbl.TextXAlignment            = Enum.TextXAlignment.Left
end

local function makeToggle(parent, label, default, callback)
    local row = Instance.new("Frame", parent)
    row.LayoutOrder      = nextOrder()
    row.Size             = UDim2.new(1, 0, 0, 30)
    row.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    row.BorderSizePixel  = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size                   = UDim2.new(1, -54, 1, 0)
    lbl.Position               = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = label
    lbl.TextColor3             = Color3.fromRGB(210, 210, 210)
    lbl.TextSize               = 11
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left

    local bg = Instance.new("Frame", row)
    bg.Size             = UDim2.new(0, 38, 0, 19)
    bg.Position         = UDim2.new(1, -44, 0.5, -9)
    bg.BackgroundColor3 = default and Color3.fromRGB(90, 0, 180) or Color3.fromRGB(45, 45, 55)
    bg.BorderSizePixel  = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", bg)
    knob.Size             = UDim2.new(0, 13, 0, 13)
    knob.Position         = default and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel  = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = default
    local hit   = Instance.new("TextButton", row)
    hit.Size                   = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text                   = ""
    hit.MouseButton1Click:Connect(function()
        state = not state
        local ti = TweenInfo.new(0.12)
        TweenService:Create(bg,   ti, { BackgroundColor3 = state and Color3.fromRGB(90, 0, 180) or Color3.fromRGB(45, 45, 55) }):Play()
        TweenService:Create(knob, ti, { Position = state and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 3, 0.5, -6) }):Play()
        callback(state)
    end)
end

local function makeInfo(parent, labelText)
    local row = Instance.new("Frame", parent)
    row.LayoutOrder      = nextOrder()
    row.Size             = UDim2.new(1, 0, 0, 22)
    row.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    row.BorderSizePixel  = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

    local key = Instance.new("TextLabel", row)
    key.Size                   = UDim2.new(0.48, 0, 1, 0)
    key.Position               = UDim2.new(0, 6, 0, 0)
    key.BackgroundTransparency = 1
    key.Text                   = labelText
    key.TextColor3             = Color3.fromRGB(120, 120, 150)
    key.TextSize               = 10
    key.Font                   = Enum.Font.Gotham
    key.TextXAlignment         = Enum.TextXAlignment.Left

    local val = Instance.new("TextLabel", row)
    val.Size                   = UDim2.new(0.52, -6, 1, 0)
    val.Position               = UDim2.new(0.48, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Text                   = "—"
    val.TextColor3             = Color3.fromRGB(180, 120, 255)
    val.TextSize               = 10
    val.Font                   = Enum.Font.GothamBold
    val.TextXAlignment         = Enum.TextXAlignment.Right
    val.TextTruncate           = Enum.TextTruncate.AtEnd
    return val
end

local function makeSlider(parent, label, minV, maxV, default, callback)
    local row = Instance.new("Frame", parent)
    row.LayoutOrder      = nextOrder()
    row.Size             = UDim2.new(1, 0, 0, 42)
    row.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    row.BorderSizePixel  = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size                   = UDim2.new(0.65, 0, 0, 18)
    lbl.Position               = UDim2.new(0, 8, 0, 3)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = label
    lbl.TextColor3             = Color3.fromRGB(210, 210, 210)
    lbl.TextSize               = 10
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", row)
    valLbl.Size                   = UDim2.new(0.35, -8, 0, 18)
    valLbl.Position               = UDim2.new(0.65, 0, 0, 3)
    valLbl.BackgroundTransparency = 1
    valLbl.Text                   = tostring(default)
    valLbl.TextColor3             = Color3.fromRGB(180, 120, 255)
    valLbl.TextSize               = 10
    valLbl.Font                   = Enum.Font.GothamBold
    valLbl.TextXAlignment         = Enum.TextXAlignment.Right

    local track = Instance.new("Frame", row)
    track.Size             = UDim2.new(1, -16, 0, 4)
    track.Position         = UDim2.new(0, 8, 0, 28)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
    track.BorderSizePixel  = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local initP = (default - minV) / (maxV - minV)

    local fill = Instance.new("Frame", track)
    fill.Size             = UDim2.new(initP, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(90, 0, 180)
    fill.BorderSizePixel  = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", track)
    knob.Size             = UDim2.new(0, 12, 0, 12)
    knob.Position         = UDim2.new(initP, -6, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 3
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local hit = Instance.new("TextButton", track)
    hit.Size                   = UDim2.new(1, 0, 0, 28)
    hit.Position               = UDim2.new(0, 0, 0.5, -14)
    hit.BackgroundTransparency = 1
    hit.Text                   = ""
    hit.ZIndex                 = 4

    local sliding = false
    local function updateSlider(x)
        local pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = math.floor(minV + (maxV - minV) * pct + 0.5)
        fill.Size     = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, -6, 0.5, -6)
        valLbl.Text   = tostring(val)
        callback(val)
    end

    hit.MouseButton1Down:Connect(function(x) sliding = true updateSlider(x) end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not sliding then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            updateSlider(inp.Position.X)
        end
    end)
end

local function makeTpButton(parent, loc)
    local btn = Instance.new("TextButton", parent)
    btn.LayoutOrder      = nextOrder()
    btn.Size             = UDim2.new(1, 0, 0, 26)
    btn.BackgroundColor3 = Color3.fromRGB(22, 0, 52)
    btn.Text             = "📍 " .. loc.name
    btn.TextColor3       = Color3.fromRGB(200, 160, 255)
    btn.TextSize         = 11
    btn.Font             = Enum.Font.GothamBold
    btn.BorderSizePixel  = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        pcall(function()
            local _, _, root = getLocalParts()
            if root then
                root.CFrame = loc.cframe
                statusText  = "TP'd → " .. loc.name
                pushNotif("📍", "Teleported", loc.name, Color3.fromRGB(0, 80, 160))
            end
        end)
    end)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(50, 0, 110) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(22, 0, 52) }):Play()
    end)
end

local function makeTextInput(parent, placeholder, callback)
    local box = Instance.new("TextBox", parent)
    box.LayoutOrder       = nextOrder()
    box.Size              = UDim2.new(1, 0, 0, 26)
    box.BackgroundColor3  = Color3.fromRGB(20, 20, 32)
    box.Text              = ""
    box.PlaceholderText   = placeholder
    box.TextColor3        = Color3.fromRGB(220, 220, 220)
    box.PlaceholderColor3 = Color3.fromRGB(80, 80, 100)
    box.TextSize          = 10
    box.Font              = Enum.Font.Gotham
    box.BorderSizePixel   = 0
    box.ClearTextOnFocus  = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    Instance.new("UIPadding", box).PaddingLeft = UDim.new(0, 7)
    box.FocusLost:Connect(function() callback(box.Text) end)
end

local function makeActionButton(parent, label, color, callback)
    local btn = Instance.new("TextButton", parent)
    btn.LayoutOrder      = nextOrder()
    btn.Size             = UDim2.new(1, 0, 0, 26)
    btn.BackgroundColor3 = color
    btn.Text             = label
    btn.TextColor3       = Color3.fromRGB(255, 240, 200)
    btn.TextSize         = 11
    btn.Font             = Enum.Font.GothamBold
    btn.BorderSizePixel  = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(
                math.min(255, color.R * 255 + 30),
                math.min(255, color.G * 255 + 30),
                math.min(255, color.B * 255 + 30)
            )
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = color }):Play()
    end)
end

-- ──────────────────────────────────────────────────────────
--  PAGE 1 — FARM
-- ──────────────────────────────────────────────────────────

local farmScroll = makeScroll(pages[1])

makeSectionLabel(farmScroll, "  CORE")
makeToggle(farmScroll, "🗡  Auto Farm", false, function(s)
    farmEnabled = s
    statusText  = s and "Farming..." or "Idle"
end)
makeToggle(farmScroll, "🛡  Godmode", true, function(s)
    godmodeEnabled = s
end)
makeToggle(farmScroll, "✊  Auto Gauntlet", true, function(s)
    autoGauntlet = s
end)

makeSectionLabel(farmScroll, "  MOVEMENT")
makeToggle(farmScroll, "💥  Kill Aura", false, function(s)
    killAuraEnabled = s
    if s then statusText = "Kill Aura active" end
end)
makeToggle(farmScroll, "🚶  Auto-Walk to Catacombs", false, function(s)
    autoWalkEnabled = s
    if s then pushNotif("🚶", "Auto-Walk ON", "Walks to Catacombs when idle", Color3.fromRGB(0, 100, 180)) end
end)

makeSectionLabel(farmScroll, "  SPEED")
makeSlider(farmScroll, "⚡ Farm Speed", 1, 5, 1, function(v)
    farmSpeedMult = v
end)
makeSlider(farmScroll, "💥 Aura Radius", 5, 60, 20, function(v)
    killAuraRadius = v
end)

-- ──────────────────────────────────────────────────────────
--  PAGE 2 — COMBAT
-- ──────────────────────────────────────────────────────────

local combatScroll = makeScroll(pages[2])

makeSectionLabel(combatScroll, "  SWING MECHANICS")
makeToggle(combatScroll, "⚡  Cooldown Break", false, function(s)
    cooldownBreak = s
    if s then pushNotif("⚡", "Cooldown Break ON", "Swing debounces zeroed", Color3.fromRGB(200, 100, 0)) end
end)
makeToggle(combatScroll, "🔥  Rapid Fire", false, function(s)
    rapidFireEnabled = s
end)
makeSlider(combatScroll, "🔥 Hits per Swing", 1, 10, 3, function(v)
    rapidFireCount = v
end)

-- ──────────────────────────────────────────────────────────
--  PAGE 3 — ABILITY
-- ──────────────────────────────────────────────────────────

local abilityScroll = makeScroll(pages[3])

makeSectionLabel(abilityScroll, "  AUTO ABILITIES")
makeToggle(abilityScroll, "✨  Auto Abilities", false, function(s)
    abilityEnabled = s
    if s then
        for i = 1, #ABILITIES do abilityLastFired[i] = 0 end
        pushNotif("✨", "Abilities ON", "E V T Q C R cycling", Color3.fromRGB(160, 80, 255))
    end
end)

makeSectionLabel(abilityScroll, "  LIVE STATUS")
local abilityStatusVal = makeInfo(abilityScroll, "Next Ready:")
local forgeProgressVal = makeInfo(abilityScroll, "Forge Progress:")

makeSectionLabel(abilityScroll, "  COOLDOWNS")
local abCdVals = {}
for i, ab in ipairs(ABILITIES) do
    abCdVals[i] = makeInfo(abilityScroll, ab.label .. ":")
end

makeSectionLabel(abilityScroll, "  FORGE")
makeActionButton(abilityScroll, "🔱 TP to Celestial Forge", Color3.fromRGB(60, 30, 0), function()
    pcall(function()
        local _, _, root = getLocalParts()
        if root then
            root.CFrame = CELESTIAL_FORGE_CF
            statusText  = "At Celestial Forge"
            pushNotif("🔱", "Forge", "Teleported to Celestial Forge", Color3.fromRGB(255, 180, 0))
        end
    end)
end)
makeActionButton(abilityScroll, "⚡ Force Try Upgrade", Color3.fromRGB(80, 40, 0), function()
    upgradeComplete = false
    task.spawn(tryForgeUpgrade)
end)

-- ──────────────────────────────────────────────────────────
--  PAGE 4 — STATS
-- ──────────────────────────────────────────────────────────

local statsScroll = makeScroll(pages[4])

makeSectionLabel(statsScroll, "  EQUIPMENT")
local wVal = makeInfo(statsScroll, "Weapon:")

makeSectionLabel(statsScroll, "  TARGETING")
local tVal = makeInfo(statsScroll, "Target:")

makeSectionLabel(statsScroll, "  KILLS")
local kVal   = makeInfo(statsScroll, "Total Kills:")
local khrVal = makeInfo(statsScroll, "Kills / hr:")
local sesVal = makeInfo(statsScroll, "Session:")

makeSectionLabel(statsScroll, "  SYSTEM")
local sVal = makeInfo(statsScroll, "Status:")
local gVal = makeInfo(statsScroll, "Godmode:")

-- ──────────────────────────────────────────────────────────
--  PAGE 5 — TELEPORT
-- ──────────────────────────────────────────────────────────

local tpScroll = makeScroll(pages[5])
makeSectionLabel(tpScroll, "  LOCATIONS")
for _, loc in ipairs(TP_LOCATIONS) do
    makeTpButton(tpScroll, loc)
end

-- ──────────────────────────────────────────────────────────
--  PAGE 6 — MORE
-- ──────────────────────────────────────────────────────────

local moreScroll = makeScroll(pages[6])

makeSectionLabel(moreScroll, "  WHITELIST")
makeToggle(moreScroll, "🎯  Whitelist Only Mode", false, function(s)
    whitelistEnabled = s
    pushNotif("🎯", "Whitelist " .. (s and "ON" or "OFF"),
        s and "Only listed enemies targeted" or "All enemies targeted",
        Color3.fromRGB(0, 120, 60))
end)
makeTextInput(moreScroll, "enemy1, enemy2, enemy3...", function(txt)
    whitelistNames = {}
    for name in txt:gmatch("[^,]+") do
        local trimmed = name:match("^%s*(.-)%s*$"):lower()
        if trimmed ~= "" then table.insert(whitelistNames, trimmed) end
    end
    local msg = #whitelistNames > 0 and table.concat(whitelistNames, ", ") or "cleared"
    pushNotif("🎯", "Whitelist Updated", msg, Color3.fromRGB(0, 120, 60))
end)

makeSectionLabel(moreScroll, "  RESET")
makeActionButton(moreScroll, "🔄 Reset Kill Count & Session", Color3.fromRGB(40, 0, 80), function()
    killCount       = 0
    nextStreakIdx   = 1
    killsThisMinute = {}
    sessionStart    = os.clock()
    pushNotif("🔄", "Stats Reset", "Kill count and session timer reset", Color3.fromRGB(60, 0, 130))
end)

-- ──────────────────────────────────────────────────────────
--  STATS + ABILITY UPDATER  (0.25s tick)
-- ──────────────────────────────────────────────────────────

task.spawn(function()
    while true do
        pcall(function()
            -- Page 4 stats
            wVal.Text   = currentWeapon
            tVal.Text   = currentTarget
            kVal.Text   = tostring(killCount)
            khrVal.Text = tostring(getKillsPerHour()) .. "/hr"
            sesVal.Text = getSessionTime()
            sVal.Text   = statusText
            gVal.Text   = godmodeEnabled and "✅ ON" or "❌ OFF"

            -- Page 3 ability cooldowns
            local now          = os.clock()
            local soonestTime  = math.huge
            local soonestLabel = "—"

            for i, ab in ipairs(ABILITIES) do
                local remaining = ab.cd - (now - abilityLastFired[i])
                if abCdVals[i] then
                    abCdVals[i].Text = remaining <= 0 and "✅ READY" or (math.ceil(remaining) .. "s")
                end
                if remaining <= 0 and soonestTime > 0 then
                    soonestTime  = 0
                    soonestLabel = ab.label .. " ✅"
                elseif remaining < soonestTime then
                    soonestTime  = remaining
                    soonestLabel = ab.label .. " " .. math.ceil(remaining) .. "s"
                end
            end

            abilityStatusVal.Text = abilityEnabled and soonestLabel or "OFF"

            local pct = math.min(100, math.floor(killCount / UPGRADE_THRESHOLD * 100))
            forgeProgressVal.Text = killCount .. " / 200k (" .. pct .. "%)"
        end)
        task.wait(0.25)
    end
end)

-- ──────────────────────────────────────────────────────────
print("✅  THANOS FARM v14 — LOADED")
print("📋  Loader: loadstring(game:HttpGet('YOUR_GITHUB_RAW_URL'))()")
-- ──────────────────────────────────────────────────────────
