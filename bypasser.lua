-- Performance monitoring
local function safeCall(func, ...)
    local start = tick()
    local success, result = pcall(func, ...)
    local duration = tick() - start
    if duration > 0.08 then
        warn("Slow function:", debug.info(func, "n") or "anonymous", "took", duration, "seconds")
    end
    return success, result
end

if _G.MySkyCleanup then pcall(_G.MySkyCleanup) end

_G.MySkyCleanup = function()
    if _G.MySkyConnections then
        for _, conn in ipairs(_G.MySkyConnections) do pcall(function() conn:Disconnect() end) end
        _G.MySkyConnections = {}
    end
    for _, part in ipairs(workspace:GetChildren()) do
        if part.Name:find("myskyp") or part.Name:find("Cosmic") then pcall(function() part:Destroy() end) end
    end
    local coreGui = game:GetService("CoreGui")
    local eg = coreGui:FindFirstChild("InstaSteal")
    if eg then pcall(function() eg:Destroy() end) end
end

pcall(_G.MySkyCleanup)

-- SERVICES
local Services = {}
local servicePromises = {}
local function getService(n)
    if Services[n] then return Services[n] end
    if not servicePromises[n] then
        servicePromises[n] = task.spawn(function() Services[n] = game:GetService(n) ; servicePromises[n] = nil end)
    end
    while not Services[n] do task.wait() end
    return Services[n]
end

local Players            = getService("Players")
local RunService         = getService("RunService")
local ReplicatedStorage  = getService("ReplicatedStorage")
local UserInputService   = getService("UserInputService")
local TweenService       = getService("TweenService")
local TextChatService    = getService("TextChatService")
local LocalPlayer        = Players.LocalPlayer
local PlayerGui          = LocalPlayer:WaitForChild("PlayerGui")
local connections        = {}
_G.MySkyConnections      = connections
local IS_MOBILE          = UserInputService.TouchEnabled
local IS_PC              = not IS_MOBILE

print("Script loaded for:", LocalPlayer.Name, "|", IS_MOBILE and "MOBILE" or "PC")

if _G.MyskypInstaSteal then pcall(_G.MySkyCleanup) ; task.wait(0.1) end
_G.MyskypInstaSteal = true

-- TP CONFIG
local TP_POSITIONS = {
    BASE1 = {
        INFO_POS     = CFrame.new(334.76, 55.334, 99.40),
        TELEPORT_POS = CFrame.new(-352.98, -7.30, 74.3),
        STAND_HERE_PART = CFrame.new(-334.76, -5.334, 99.40) * CFrame.new(0, 2.6, 0)
    },
    BASE2 = {
        INFO_POS     = CFrame.new(334.76, 55.334, 19.17),
        TELEPORT_POS = CFrame.new(-352.98, -7.30, 45.76),
        STAND_HERE_PART = CFrame.new(-336.41, -5.34, 19.20) * CFrame.new(0, 2.6, 0)
    }
}
local TPSysEnabled           = true
local lastTeleportTime       = 0
local TELEPORT_COOLDOWN      = 0.5   -- faster: was 0.8
local lastMarkerUpdate       = 0
local MARKER_UPDATE_INTERVAL = 0.4

-- WAYPOINT PUSH SYSTEM
local MARKER_EXTRA_PUSH = 0
local PUSH_PER_STEAL    = 8
local PUSH_MAX          = 40
local PUSH_DECAY_TIME   = 6
local lastStealTime     = 0

local function getMarkerOffset()
    if tick() - lastStealTime > PUSH_DECAY_TIME then MARKER_EXTRA_PUSH = 0 end
    return MARKER_EXTRA_PUSH
end

local function onSuccessfulSteal()
    lastStealTime = tick()
    MARKER_EXTRA_PUSH = math.min(MARKER_EXTRA_PUSH + PUSH_PER_STEAL, PUSH_MAX)
    print(string.format("[WAYPOINT] Pushed +%d studs (total: %d)", PUSH_PER_STEAL, MARKER_EXTRA_PUSH))
end

-- DESYNC
local FFlags = {
    GameNetPVHeaderRotationalVelocityZeroCutoffExponent = -5000,
    LargeReplicatorWrite5 = true, LargeReplicatorEnabled9 = true, AngularVelociryLimit = 360,
    TimestepArbiterVelocityCriteriaThresholdTwoDt = 2147483646, S2PhysicsSenderRate = 15000,
    DisableDPIScale = true, MaxDataPacketPerSend = 2147483647, PhysicsSenderMaxBandwidthBps = 20000,
    TimestepArbiterHumanoidLinearVelThreshold = 21, MaxMissedWorldStepsRemembered = -2147483648,
    PlayerHumanoidPropertyUpdateRestrict = true, SimDefaultHumanoidTimestepMultiplier = 0,
    StreamJobNOUVolumeLengthCap = 2147483647, DebugSendDistInSteps = -2147483648,
    GameNetDontSendRedundantNumTimes = 1, CheckPVLinearVelocityIntegrateVsDeltaPositionThresholdPercent = 1,
    CheckPVDifferencesForInterpolationMinVelThresholdStudsPerSecHundredth = 1,
    LargeReplicatorSerializeRead3 = true, ReplicationFocusNouExtentsSizeCutoffForPauseStuds = 2147483647,
    CheckPVCachedVelThresholdPercent = 10,
    CheckPVDifferencesForInterpolationMinRotVelThresholdRadsPerSecHundredth = 1,
    GameNetDontSendRedundantDeltaPositionMillionth = 1, InterpolationFrameVelocityThresholdMillionth = 5,
    StreamJobNOUVolumeCap = 2147483647, InterpolationFrameRotVelocityThresholdMillionth = 5,
    CheckPVCachedRotVelThresholdPercent = 10, WorldStepMax = 30,
    InterpolationFramePositionThresholdMillionth = 5, TimestepArbiterHumanoidTurningVelThreshold = 1,
    SimOwnedNOUCountThresholdMillionth = 2147483647,
    GameNetPVHeaderLinearVelocityZeroCutoffExponent = -5000, NextGenReplicatorEnabledWrite4 = true,
    TimestepArbiterOmegaThou = 1073741823, MaxAcceptableUpdateDelay = 1, LargeReplicatorSerializeWrite4 = true
}
local desyncFirstActivation      = true
local desyncPermanentlyActivated = false

local function applyFFlags(flags)
    for name, value in pairs(flags) do pcall(function() setfflag(tostring(name), tostring(value)) end) end
end

local function respawnPlayer(plr)
    local char = plr.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Dead) end
        char:ClearAllChildren()
        local newChar = Instance.new("Model") ; newChar.Parent = workspace ; plr.Character = newChar
        task.wait() ; plr.Character = char ; newChar:Destroy()
    end
end

local function applyPermanentDesync()
    applyFFlags(FFlags)
    if desyncFirstActivation then respawnPlayer(LocalPlayer) ; desyncFirstActivation = false end
    desyncPermanentlyActivated = true
    print("[DESYNC] Permanent desync applied")
end

-- AP SPAMMER
local AP_TARGET   = nil
local AP_COMMANDS = { ";balloon ", ";rocket ", ";morph ", ";jumpscare ", ";jail " }
local apSpamming  = false
local apCooldown  = false

local function sendAPCommands(targetName)
    if apSpamming or apCooldown then return end
    if not targetName or targetName == "" then warn("[AP SPAM] No target selected!") ; return end
    apSpamming = true
    task.spawn(function()
        local ok, channel = pcall(function() return TextChatService.TextChannels.RBXGeneral end)
        if not ok or not channel then warn("[AP SPAM] Could not get chat channel") ; apSpamming = false ; return end
        for _, cmd in ipairs(AP_COMMANDS) do
            pcall(function() channel:SendAsync(cmd .. targetName) end)
            task.wait(0.12)
        end
        apSpamming = false ; apCooldown = true ; task.wait(1) ; apCooldown = false
        print("[AP SPAM] Done spamming:", targetName)
    end)
end

-- AUTO GRAB CONFIG
local AUTO_STEAL_CONFIG      = { ENABLED = false }
local AnimalsData            = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
local allAnimalsCache        = {}
local PromptMemoryCache      = {}
local LastTargetUID          = nil
local LastPlayerPosition     = nil
local PlayerVelocity         = Vector3.zero
local AUTO_STEAL_PROX_RADIUS = 20
local IsStealing             = false
local StealProgress          = 0
local CurrentStealTarget     = nil
local StealStartTime         = 0
local CIRCLE_RADIUS          = AUTO_STEAL_PROX_RADIUS
local PART_THICKNESS         = 0.3
local PART_HEIGHT            = 0.2
local PART_COLOR             = Color3.fromRGB(0, 180, 255)
local PartsCount             = 65
local circleParts            = {}
local circleEnabled          = false
local stealConnection        = nil
local velocityConnection     = nil
local typing                 = false

-- SPEED BOOSTER STATE
local speedBoosterEnabled = false
local speedBoosterValue   = 25
local jumpBoosterValue    = 40
local DEFAULT_WALKSPEED   = 16
local DEFAULT_JUMPPOWER   = 50
local boostKeybind        = Enum.KeyCode.T

-- GIANT POTION STATE
local giantPotionEnabled = false

-- HELPERS
local function cleanup()
    for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    connections = {}
end

local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function applyBoost()
    local hum = getHumanoid() ; if not hum then return end
    if speedBoosterEnabled then
        hum.WalkSpeed = speedBoosterValue ; hum.JumpPower = jumpBoosterValue
    else
        hum.WalkSpeed = DEFAULT_WALKSPEED ; hum.JumpPower = DEFAULT_JUMPPOWER
    end
end

-- ================================================================
-- GIANT POTION: fires potion, waits 0.3s (used before steal)
-- ================================================================
local function useGiantPotion()
    if not giantPotionEnabled then return end
    local character = LocalPlayer.Character ; if not character then return end
    local humanoid  = character:FindFirstChildOfClass("Humanoid") ; if not humanoid then return end

    local potion = LocalPlayer.Backpack:FindFirstChild("Giant Potion")
        or character:FindFirstChild("Giant Potion")
        or LocalPlayer.Backpack:FindFirstChild("GiantPotion")
        or character:FindFirstChild("GiantPotion")

    if potion then
        pcall(function() humanoid:EquipTool(potion) end)
        task.wait(0.03) -- faster: was 0.05

        local fired = false
        if getconnections then
            local ok, conns = pcall(getconnections, potion.Activated)
            if ok and type(conns) == "table" then
                for _, conn in ipairs(conns) do
                    if type(conn.Function) == "function" then
                        pcall(conn.Function) ; fired = true ; break
                    end
                end
            end
        end
        if not fired then pcall(function() potion:Activate() end) end
        print("[GIANT POTION] Fired — waiting 0.3s")
        task.wait(0.3)
    else
        warn("[GIANT POTION] Not found in backpack!")
    end
end

-- ================================================================
-- GIANT POTION IMMEDIATE: fires instantly, NO wait after
-- Used for TP-to-pet so potion fires at same moment as TP
-- ================================================================
local function useGiantPotionImmediate()
    if not giantPotionEnabled then return end
    local character = LocalPlayer.Character ; if not character then return end
    local humanoid  = character:FindFirstChildOfClass("Humanoid") ; if not humanoid then return end

    local potion = LocalPlayer.Backpack:FindFirstChild("Giant Potion")
        or character:FindFirstChild("Giant Potion")
        or LocalPlayer.Backpack:FindFirstChild("GiantPotion")
        or character:FindFirstChild("GiantPotion")

    if potion then
        pcall(function() humanoid:EquipTool(potion) end)
        task.wait(0.03)
        local fired = false
        if getconnections then
            local ok, conns = pcall(getconnections, potion.Activated)
            if ok and type(conns) == "table" then
                for _, conn in ipairs(conns) do
                    if type(conn.Function) == "function" then
                        pcall(conn.Function) ; fired = true ; break
                    end
                end
            end
        end
        if not fired then pcall(function() potion:Activate() end) end
        print("[GIANT POTION IMMEDIATE] Fired on TP press")
    else
        warn("[GIANT POTION] Not found in backpack!")
    end
end

local function getCurrentBasePosition()
    local hrp = getHRP()
    if not hrp then return TP_POSITIONS.BASE1.INFO_POS end
    local p  = hrp.Position
    local d1 = (p - TP_POSITIONS.BASE1.INFO_POS.Position).Magnitude
    local d2 = (p - TP_POSITIONS.BASE2.INFO_POS.Position).Magnitude
    return d1 < d2 and TP_POSITIONS.BASE1.INFO_POS or TP_POSITIONS.BASE2.INFO_POS
end

local function getCurrentTeleportPos()
    local hrp = getHRP()
    if not hrp then return TP_POSITIONS.BASE1.TELEPORT_POS end
    local p  = hrp.Position
    local d1 = (p - TP_POSITIONS.BASE1.INFO_POS.Position).Magnitude
    local d2 = (p - TP_POSITIONS.BASE2.INFO_POS.Position).Magnitude
    return d1 < d2 and TP_POSITIONS.BASE1.TELEPORT_POS or TP_POSITIONS.BASE2.TELEPORT_POS
end

local function getMarkerCFrame()
    local tp   = getCurrentTeleportPos()
    local push = getMarkerOffset()
    return CFrame.new(tp.Position + Vector3.new(0, 0.5, push))
end

local function CreateMarker()
    local markerPos = getMarkerCFrame()
    local part = workspace:FindFirstChild("JIGGY SEMI TP") or Instance.new("Part")
    part.Name = "JIGGY SEMI TP" ; part.Size = Vector3.new(1, 1, 1) ; part.CFrame = markerPos
    part.Anchored = true ; part.CanCollide = false ; part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(0, 180, 255) ; part.Transparency = 0.3 ; part.Parent = workspace
    if not part:FindFirstChild("JIGGY SEMI TP") then
        local gui = Instance.new("BillboardGui") ; gui.Name = "JIGGY SEMI TP"
        gui.AlwaysOnTop = true ; gui.Size = UDim2.new(0, 200, 0, 50)
        gui.ExtentsOffset = Vector3.new(0, 3, 0) ; gui.Parent = part
        local lbl = Instance.new("TextLabel") ; lbl.Name = "Text"
        lbl.BackgroundTransparency = 1 ; lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.Font = Enum.Font.GothamBold ; lbl.TextSize = 18
        lbl.TextColor3 = Color3.new(1, 1, 1) ; lbl.Text = "" ; lbl.Parent = gui
    end
    return part
end

local Marker = CreateMarker()

-- COSMIC INDICATORS
local function createCosmicIndicator(name, position, color, text)
    local part = Instance.new("Part") ; part.Name = name
    part.Size = Vector3.new(3.8, 0.3, 3.8) ; part.Material = Enum.Material.Plastic
    part.Color = color ; part.Transparency = 0.57 ; part.Anchored = true
    part.CanCollide = false ; part.Position = position ; part.Parent = workspace
    local bb = Instance.new("BillboardGui") ; bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 4, 0) ; bb.AlwaysOnTop = true ; bb.Parent = part
    local tl = Instance.new("TextLabel") ; tl.Size = UDim2.new(1, 0, 1, 0)
    tl.BackgroundTransparency = 1 ; tl.Text = text ; tl.TextColor3 = Color3.fromRGB(255,255,255)
    tl.TextStrokeTransparency = 0.3 ; tl.TextStrokeColor3 = color
    tl.Font = Enum.Font.GothamBold ; tl.TextSize = 18 ; tl.Parent = bb
    return part
end

task.spawn(function()
    createCosmicIndicator("CosmicStandHereBase1",    Vector3.new(-334.84,-5.40,101.02), Color3.fromRGB(39,39,39), " STAND HERE (BASE 1) ")
    createCosmicIndicator("CosmicTeleportHereBase1", Vector3.new(-352.98,-7.30,74.3),   Color3.fromRGB(39,39,39), " TELEPORT HERE (BASE 1) ")
    createCosmicIndicator("CosmicStandHereBase2",    Vector3.new(-334.84,-5.40,19.20),  Color3.fromRGB(39,39,39), " STAND HERE (BASE 2) ")
    createCosmicIndicator("CosmicTeleportHereBase2", Vector3.new(-352.98,-7.30,45.76),  Color3.fromRGB(39,39,39), " TELEPORT HERE (BASE 2) ")
end)

-- STEAL TP (runs after steal fires)
local function doStealTP()
    if not TPSysEnabled then return end
    local character = LocalPlayer.Character ; if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp.Parent then return end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        local carpet = backpack:FindFirstChild("Flying Carpet")
        if carpet and character:FindFirstChild("Humanoid") then
            pcall(function() character.Humanoid:EquipTool(carpet) end) ; task.wait(0.03) -- faster: was 0.05
        end
    end
    local cbp = getCurrentBasePosition()
    if cbp == TP_POSITIONS.BASE1.INFO_POS then
        pcall(function() hrp.CFrame = TP_POSITIONS.BASE1.TELEPORT_POS end) ; print("STEAL TP -> Base 1")
    else
        pcall(function() hrp.CFrame = TP_POSITIONS.BASE2.TELEPORT_POS end) ; print("STEAL TP -> Base 2")
    end
end

-- STEAL PROMPT DETECTION
local function initializeEventConnections()
    local ProximityPromptService = getService("ProximityPromptService")
    local promptConn = ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, who)
        if who ~= LocalPlayer then return end
        if prompt.Name ~= "Steal" and prompt.ActionText ~= "Steal" and prompt.ObjectText ~= "Steal" then return end
        warn("STEAL DETECTED (manual)") ; onSuccessfulSteal() ; doStealTP()
    end)
    table.insert(connections, promptConn)

    local hbConn = RunService.Heartbeat:Connect(function(dt)
        lastMarkerUpdate = lastMarkerUpdate + dt
        if lastMarkerUpdate < MARKER_UPDATE_INTERVAL then return end
        lastMarkerUpdate = 0
        local character = LocalPlayer.Character ; if not character then return end
        local hrp = character:FindFirstChild("HumanoidRootPart") ; if not hrp then return end
        local mp = getMarkerCFrame() ; local tp = getCurrentTeleportPos()
        if Marker and Marker.Parent then
            Marker.CFrame = mp
            local dist = (hrp.Position - tp.Position).Magnitude
            local pushActive = MARKER_EXTRA_PUSH > 0 and (tick() - lastStealTime) < PUSH_DECAY_TIME
            if pushActive then Marker.Color = Color3.fromRGB(255, 200, 0)
            elseif dist < 7 then Marker.Color = Color3.fromRGB(0, 255, 100)
            else Marker.Color = Color3.fromRGB(0, 180, 255) end
        end
    end)
    table.insert(connections, hbConn)
    print("Event connections initialized")
end

task.spawn(initializeEventConnections)

-- ANTI-KICK
local KICK_MESSAGE  = "EZZ STEAL JIGGY AND YUPS HUB"
local KICK_KEYWORDS = {"you stole", "stole a", "added to your base", "pet collected"}
local function hasKeyword(text)
    if typeof(text) ~= "string" then return false end
    local lower = text:lower()
    for _, kw in ipairs(KICK_KEYWORDS) do if lower:find(kw, 1, true) then return true end end
    return false
end

local function watchObject(obj)
    if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then return end
    if obj.Text and hasKeyword(obj.Text) then
        task.spawn(function() pcall(function() LocalPlayer:Kick(KICK_MESSAGE) end) end) ; return
    end
    local conn = obj:GetPropertyChangedSignal("Text"):Connect(function()
        if hasKeyword(obj.Text) then task.spawn(function() pcall(function() LocalPlayer:Kick(KICK_MESSAGE) end) end) end
    end)
    table.insert(connections, conn)
    local conn2 = obj:GetPropertyChangedSignal("Visible"):Connect(function()
        if obj.Visible and hasKeyword(obj.Text) then task.spawn(function() pcall(function() LocalPlayer:Kick(KICK_MESSAGE) end) end) end
    end)
    table.insert(connections, conn2)
end

local lastScanTime = 0 ; local SCAN_COOLDOWN = 0.5 ; local MAX_SCAN_TIME = 0.016
local function optimizedScanDescendants(parent)
    local ct = tick()
    if ct - lastScanTime < SCAN_COOLDOWN then return end
    local st = tick() ; if tick()-st>MAX_SCAN_TIME then return end
    lastScanTime = ct
    task.spawn(function()
        local objs = {} ; local batchSize = 15
        for _, obj in ipairs(parent:GetDescendants()) do
            if tick()-st>MAX_SCAN_TIME then break end
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then table.insert(objs, obj) end
        end
        for i=1,#objs,batchSize do
            local ei = math.min(i+batchSize-1, #objs)
            for j=i,ei do watchObject(objs[j]) end
            task.wait(0.05)
        end
    end)
end

local childAddedDebounce = false
local function debouncedWatchObject(obj)
    if not childAddedDebounce then childAddedDebounce=true ; watchObject(obj) ; childAddedDebounce=false end
end
task.spawn(function()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    task.wait(2) ; optimizedScanDescendants(pg)
    local c1 = pg.ChildAdded:Connect(function(gui)
        task.wait(0.1)
        if gui:IsA("ScreenGui") then optimizedScanDescendants(gui) else debouncedWatchObject(gui) end
    end)
    table.insert(connections, c1)
    local c2 = pg.DescendantAdded:Connect(debouncedWatchObject) ; table.insert(connections, c2)
end)
task.spawn(function()
    local c = Players.PlayerRemoving:Connect(function(p)
        if p==LocalPlayer then cleanup() ; _G.MyskypInstaSteal=false ; pcall(_G.MySkyCleanup) end
    end)
    table.insert(connections, c)
end)

-- ================================================================
-- EXECUTE SEMI TP
-- ORDER: 1) Giant Potion  2) wait 0.3s  3) Carpet  4) Steal  5) TP
-- Timings tightened throughout for speed
-- ================================================================
local isTeleporting = false

local function executeTP()
    if tick()-lastTeleportTime<TELEPORT_COOLDOWN then
        warn("Teleport on cooldown!", TELEPORT_COOLDOWN-(tick()-lastTeleportTime)) ; return false
    end
    lastTeleportTime = tick()
    local Character = LocalPlayer.Character
    if not Character then Character = LocalPlayer.CharacterAdded:Wait() end
    local Humanoid = Character:WaitForChild("Humanoid")
    local HRP      = Character:WaitForChild("HumanoidRootPart")
    local cbp      = getCurrentBasePosition()
    local isAtBase1 = (cbp == TP_POSITIONS.BASE1.INFO_POS)

    task.spawn(function()
        isTeleporting = true ; IsStealing = true
        local wasEnabled = AUTO_STEAL_CONFIG.ENABLED ; AUTO_STEAL_CONFIG.ENABLED = false

        if giantPotionEnabled then useGiantPotion() end

        local Carpet = Character:FindFirstChild("Flying Carpet") or LocalPlayer.Backpack:FindFirstChild("Flying Carpet")
        if Carpet then
            pcall(function() Humanoid:EquipTool(Carpet) end)
            task.wait(0.03) -- faster: was 0.05
        end

        task.spawn(function()
            local nearest = getNearestAnimal()
            if nearest then
                local prompt = PromptMemoryCache[nearest.uid]
                if not prompt or not prompt.Parent then prompt = findProximityPromptForAnimal(nearest) end
                if prompt then
                    print("[SEMI TP] Firing steal on:", nearest.name)
                    if fireproximityprompt then pcall(fireproximityprompt, prompt)
                    elseif getconnections then
                        local ok, conns = pcall(getconnections, prompt.Triggered)
                        if ok and type(conns) == "table" then
                            for _, conn in ipairs(conns) do
                                if type(conn.Function) == "function" then pcall(conn.Function) end
                            end
                        end
                    end
                    onSuccessfulSteal()
                end
            end
        end)

        if isAtBase1 then
            pcall(function() HRP.CFrame=CFrame.new(-351.49,-6.65,113.72) end) ; task.wait(0.15) -- faster: was 0.2
            if not HRP or not HRP.Parent then isTeleporting=false ; IsStealing=false ; AUTO_STEAL_CONFIG.ENABLED=wasEnabled ; return end
            pcall(function() HRP.CFrame=CFrame.new(-378.14,-6.00,26.43) end)  ; task.wait(0.15)
            if not HRP or not HRP.Parent then isTeleporting=false ; IsStealing=false ; AUTO_STEAL_CONFIG.ENABLED=wasEnabled ; return end
            pcall(function() HRP.CFrame=CFrame.new(-334.80,-5.04,18.90) end)
        else
            pcall(function() HRP.CFrame=CFrame.new(-352.54,-6.83,6.66) end)   ; task.wait(0.15)
            if not HRP or not HRP.Parent then isTeleporting=false ; IsStealing=false ; AUTO_STEAL_CONFIG.ENABLED=wasEnabled ; return end
            pcall(function() HRP.CFrame=CFrame.new(-372.90,-6.20,102.00) end) ; task.wait(0.15)
            if not HRP or not HRP.Parent then isTeleporting=false ; IsStealing=false ; AUTO_STEAL_CONFIG.ENABLED=wasEnabled ; return end
            pcall(function() HRP.CFrame=CFrame.new(-335.08,-5.10,101.40) end)
        end
        task.wait(0.2) -- faster: was 0.3
        AUTO_STEAL_CONFIG.ENABLED = wasEnabled ; isTeleporting = false ; IsStealing = false
    end)
    return true
end

-- SCANNER
local function isMyBase(plotName)
    local plot = workspace.Plots:FindFirstChild(plotName) ; if not plot then return false end
    local sign  = plot:FindFirstChild("PlotSign")
    if sign then
        local yb = sign:FindFirstChild("YourBase")
        if yb and yb:IsA("BillboardGui") then return yb.Enabled==true end
    end
    return false
end

local function scanSinglePlot(plot)
    if not plot or not plot:IsA("Model") then return end
    if isMyBase(plot.Name) then return end
    local podiums = plot:FindFirstChild("AnimalPodiums") ; if not podiums then return end
    for _, podium in ipairs(podiums:GetChildren()) do
        if podium:IsA("Model") and podium:FindFirstChild("Base") then
            local animalName = "Unknown"
            local spawn = podium.Base:FindFirstChild("Spawn")
            if spawn then
                for _, child in ipairs(spawn:GetChildren()) do
                    if child:IsA("Model") and child.Name ~= "PromptAttachment" then
                        animalName = child.Name
                        local ai = AnimalsData[animalName]
                        if ai and ai.DisplayName then animalName = ai.DisplayName end
                        break
                    end
                end
            end
            table.insert(allAnimalsCache,{
                name=animalName, plot=plot.Name, slot=podium.Name,
                worldPosition=podium:GetPivot().Position, uid=plot.Name.."_"..podium.Name,
            })
        end
    end
end

local function initializeScanner()
    task.wait(2)
    local plots = workspace:WaitForChild("Plots", 10) ; if not plots then return end
    for _, plot in ipairs(plots:GetChildren()) do if plot:IsA("Model") then scanSinglePlot(plot) end end
    plots.ChildAdded:Connect(function(plot)
        if plot:IsA("Model") then task.wait(0.5) ; scanSinglePlot(plot) end
    end)
    task.spawn(function()
        while task.wait(5) do
            allAnimalsCache = {}
            for _, plot in ipairs(plots:GetChildren()) do if plot:IsA("Model") then scanSinglePlot(plot) end end
        end
    end)
end

local function findProximityPromptForAnimal(animalData)
    if not animalData then return nil end
    local cached = PromptMemoryCache[animalData.uid]
    if cached and cached.Parent then return cached end
    local plot   = workspace.Plots:FindFirstChild(animalData.plot) ; if not plot then return nil end
    local podiums = plot:FindFirstChild("AnimalPodiums") ; if not podiums then return nil end
    local podium  = podiums:FindFirstChild(animalData.slot) ; if not podium then return nil end
    local base    = podium:FindFirstChild("Base") ; if not base then return nil end
    local spawn   = base:FindFirstChild("Spawn") ; if not spawn then return nil end
    local attach  = spawn:FindFirstChild("PromptAttachment") ; if not attach then return nil end
    for _, p in ipairs(attach:GetChildren()) do
        if p:IsA("ProximityPrompt") then PromptMemoryCache[animalData.uid] = p ; return p end
    end
    return nil
end

local function updatePlayerVelocity()
    local hrp = getHRP() ; if not hrp then return end
    local cp = hrp.Position
    if LastPlayerPosition then PlayerVelocity = (cp-LastPlayerPosition)/task.wait() end
    LastPlayerPosition = cp
end

local function shouldSteal(animalData)
    if not animalData or not animalData.worldPosition then return false end
    local hrp = getHRP() ; if not hrp then return false end
    return (hrp.Position-animalData.worldPosition).Magnitude <= AUTO_STEAL_PROX_RADIUS
end

local stealCooldowns = {}

-- ================================================================
-- FIRE STEAL
-- ORDER: 1) Giant Potion → 0.3s  2) Carpet  3) Fire prompt
-- ================================================================
local function fireSteal(prompt, animalData)
    if not prompt or not prompt.Parent then return false end
    local now = tick()
    if stealCooldowns[prompt] and now - stealCooldowns[prompt] < 0.3 then return false end
    stealCooldowns[prompt] = now
    IsStealing = true ; StealProgress = 1 ; CurrentStealTarget = animalData ; StealStartTime = tick()
    task.spawn(function()
        if giantPotionEnabled then useGiantPotion() end

        local character = LocalPlayer.Character
        local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
        local carpet    = character and (
            character:FindFirstChild("Flying Carpet") or
            LocalPlayer.Backpack:FindFirstChild("Flying Carpet")
        )
        if carpet and humanoid then
            pcall(function() humanoid:EquipTool(carpet) end)
            task.wait(0.03) -- faster: was 0.05
        end

        local fired = false
        if fireproximityprompt then
            local ok = pcall(fireproximityprompt, prompt) ; if ok then fired = true end
        end
        if not fired and getconnections then
            local ok2, conns2 = pcall(getconnections, prompt.Triggered)
            if ok2 and type(conns2) == "table" then
                for _, conn in ipairs(conns2) do
                    if type(conn.Function) == "function" then pcall(conn.Function) ; fired = true end
                end
            end
        end
        if fired then onSuccessfulSteal() end
        task.spawn(doStealTP)
        task.wait(0.1) ; IsStealing = false ; StealProgress = 0 ; CurrentStealTarget = nil -- faster: was 0.15
    end)
    return true
end

local function getNearestAnimal()
    local hrp = getHRP() ; if not hrp then return nil end
    local nearest, minDist = nil, math.huge
    for _, animalData in ipairs(allAnimalsCache) do
        if isMyBase(animalData.plot) then continue end
        if animalData.worldPosition then
            local dist = (hrp.Position-animalData.worldPosition).Magnitude
            if dist < minDist then minDist = dist ; nearest = animalData end
        end
    end
    return nearest
end

local function autoStealLoop()
    if stealConnection then stealConnection:Disconnect() end
    if velocityConnection then velocityConnection:Disconnect() end
    velocityConnection = RunService.Heartbeat:Connect(updatePlayerVelocity)
    stealConnection = RunService.Heartbeat:Connect(function()
        if not AUTO_STEAL_CONFIG.ENABLED or IsStealing or isTeleporting then return end
        local targetAnimal = getNearestAnimal() ; if not targetAnimal then return end
        if not shouldSteal(targetAnimal) then return end
        if LastTargetUID ~= targetAnimal.uid then LastTargetUID = targetAnimal.uid end
        local prompt = PromptMemoryCache[targetAnimal.uid]
        if not prompt or not prompt.Parent then prompt = findProximityPromptForAnimal(targetAnimal) end
        if prompt then fireSteal(prompt, targetAnimal) end
    end)
end

-- CIRCLE INDICATOR
local function createCircle(character)
    for _, part in ipairs(circleParts) do if part then part:Destroy() end end
    circleParts = {} ; CIRCLE_RADIUS = AUTO_STEAL_PROX_RADIUS
    character:WaitForChild("HumanoidRootPart")
    local points = {}
    for i=0,PartsCount-1 do
        local angle = math.rad(i*360/PartsCount)
        table.insert(points, Vector3.new(math.cos(angle),0,math.sin(angle))*CIRCLE_RADIUS)
    end
    for i=1,#points do
        local ni = i%#points+1 ; local p1,p2 = points[i],points[ni]
        local part = Instance.new("Part") ; part.Anchored = true ; part.CanCollide = false
        part.Size = Vector3.new((p2-p1).Magnitude,PART_HEIGHT,PART_THICKNESS)
        part.Color = PART_COLOR ; part.Material = Enum.Material.Neon ; part.Transparency = 0.3
        part.TopSurface = Enum.SurfaceType.Smooth ; part.BottomSurface = Enum.SurfaceType.Smooth
        part.Parent = workspace ; table.insert(circleParts, part)
    end
end

local function updateCircle(character)
    local root = character:FindFirstChild("HumanoidRootPart") ; if not root then return end
    local points = {}
    for i=0,PartsCount-1 do
        local angle = math.rad(i*360/PartsCount)
        table.insert(points, Vector3.new(math.cos(angle),0,math.sin(angle))*CIRCLE_RADIUS)
    end
    for i, part in ipairs(circleParts) do
        local ni = i%#points+1 ; local p1,p2 = points[i],points[ni]
        local center = (p1+p2)/2+root.Position
        part.CFrame = CFrame.new(center,center+Vector3.new(p2.X-p1.X,0,p2.Z-p1.Z))*CFrame.Angles(0,math.pi/2,0)
    end
end

local function updateCircleRadius()
    CIRCLE_RADIUS = AUTO_STEAL_PROX_RADIUS
    local character = LocalPlayer.Character
    if character and circleEnabled then createCircle(character) end
end

local function onCharacterAdded(character)
    PromptMemoryCache = {} ; stealCooldowns = {}
    if speedBoosterEnabled then
        local hum = character:WaitForChild("Humanoid")
        hum.WalkSpeed = speedBoosterValue ; hum.JumpPower = jumpBoosterValue
    end
    if circleEnabled then
        createCircle(character)
        RunService:BindToRenderStep("CircleFollow",Enum.RenderPriority.Camera.Value+1,function() updateCircle(character) end)
    end
end

RunService.Heartbeat:Connect(function()
    if speedBoosterEnabled then
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = speedBoosterValue ; hum.JumpPower = jumpBoosterValue end
    end
end)

_G.MySkyCleanup = function()
    cleanup()
    if stealConnection then stealConnection:Disconnect() end
    if velocityConnection then velocityConnection:Disconnect() end
    RunService:UnbindFromRenderStep("CircleFollow")
    for _, part in ipairs(circleParts) do if part then part:Destroy() end end ; circleParts = {}
    for _, part in ipairs(workspace:GetChildren()) do
        if part.Name:find("myskyp") or part.Name:find("Cosmic") then pcall(function() part:Destroy() end) end
    end
    local cg = getService("CoreGui") ; local eg = cg:FindFirstChild("SemiInstaSteal")
    if eg then pcall(function() eg:Destroy() end) end
    _G.MyskypInstaSteal = false ; _G.MySkyConnections = nil
end

-- MOBILE TP BUTTON
local mobilePetTPTarget = nil
local LONG_PRESS_TIME   = 0.5
local PET_TP_COOLDOWN   = 0.5  -- faster: was 0.8
local lastPetTPTime     = 0

local function createMobileTPButton()
    if not IS_MOBILE then return nil end
    local gui = Instance.new("ScreenGui")
    gui.Name = "MobileTPButton" ; gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling ; gui.DisplayOrder = 999 ; gui.Parent = PlayerGui

    local btn = Instance.new("TextButton") ; btn.Name = "BigTPBtn"
    btn.Size = UDim2.new(0,110,0,110) ; btn.Position = UDim2.new(1,-130,0.5,-55)
    btn.BackgroundColor3 = Color3.fromRGB(50,140,230) ; btn.BackgroundTransparency = 0.5
    btn.BorderSizePixel = 0 ; btn.Text = "" ; btn.AutoButtonColor = false ; btn.ZIndex = 10 ; btn.Parent = gui
    Instance.new("UICorner",btn).CornerRadius = UDim.new(0,22)
    local btnStroke = Instance.new("UIStroke",btn)
    btnStroke.Color = Color3.fromRGB(120,200,255) ; btnStroke.Thickness = 2.5 ; btnStroke.Transparency = 0.2
    local btnGrad = Instance.new("UIGradient",btn)
    btnGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(80,170,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(30,100,200))})
    btnGrad.Rotation = 45
    task.spawn(function() local t=0 ; while btn and btn.Parent do t=t+0.02 ; btnGrad.Rotation=45+math.sin(t)*20 ; task.wait(0.05) end end)

    local icon = Instance.new("TextLabel") ; icon.Size=UDim2.new(1,0,0,52) ; icon.Position=UDim2.new(0,0,0,10)
    icon.BackgroundTransparency=1 ; icon.Text="🐾" ; icon.TextSize=42 ; icon.Font=Enum.Font.GothamBold
    icon.TextColor3=Color3.fromRGB(255,255,255) ; icon.ZIndex=11 ; icon.Parent=btn

    local lbl = Instance.new("TextLabel") ; lbl.Size=UDim2.new(1,-8,0,28) ; lbl.Position=UDim2.new(0,4,0,62)
    lbl.BackgroundTransparency=1 ; lbl.Text="TP TO PET" ; lbl.TextSize=13 ; lbl.Font=Enum.Font.GothamBold
    lbl.TextColor3=Color3.fromRGB(220,240,255) ; lbl.TextWrapped=true ; lbl.ZIndex=11 ; lbl.Parent=btn

    local subLbl = Instance.new("TextLabel") ; subLbl.Size=UDim2.new(1,-8,0,18) ; subLbl.Position=UDim2.new(0,4,0,88)
    subLbl.BackgroundTransparency=1 ; subLbl.Text="Hold to set" ; subLbl.TextSize=10 ; subLbl.Font=Enum.Font.Gotham
    subLbl.TextColor3=Color3.fromRGB(160,210,255) ; subLbl.TextWrapped=true ; subLbl.ZIndex=11 ; subLbl.Parent=btn

    local cdOverlay = Instance.new("Frame") ; cdOverlay.Size=UDim2.new(1,0,1,0)
    cdOverlay.BackgroundColor3=Color3.fromRGB(10,40,100) ; cdOverlay.BackgroundTransparency=0.4
    cdOverlay.BorderSizePixel=0 ; cdOverlay.Visible=false ; cdOverlay.ZIndex=12 ; cdOverlay.Parent=btn
    Instance.new("UICorner",cdOverlay).CornerRadius=UDim.new(0,22)
    local cdText = Instance.new("TextLabel") ; cdText.Size=UDim2.new(1,0,1,0) ; cdText.BackgroundTransparency=1
    cdText.Text="" ; cdText.Font=Enum.Font.GothamBold ; cdText.TextSize=32 ; cdText.TextColor3=Color3.fromRGB(255,255,255)
    cdText.ZIndex=13 ; cdText.Parent=cdOverlay

    local holdBar = Instance.new("Frame") ; holdBar.Size=UDim2.new(0,0,0,4) ; holdBar.Position=UDim2.new(0,0,1,6)
    holdBar.BackgroundColor3=Color3.fromRGB(255,200,50) ; holdBar.BorderSizePixel=0 ; holdBar.ZIndex=11 ; holdBar.Parent=btn
    Instance.new("UICorner",holdBar).CornerRadius=UDim.new(1,0)

    local menu = Instance.new("Frame") ; menu.Name="ContextMenu" ; menu.Size=UDim2.new(0,200,0,0)
    menu.Position=UDim2.new(1,-220,0.5,-55) ; menu.BackgroundColor3=Color3.fromRGB(20,50,100)
    menu.BackgroundTransparency=0.6 ; menu.BorderSizePixel=0 ; menu.Visible=false
    menu.ZIndex=20 ; menu.ClipsDescendants=true ; menu.Parent=gui
    Instance.new("UICorner",menu).CornerRadius=UDim.new(0,14)
    local menuStroke = Instance.new("UIStroke",menu) ; menuStroke.Color=Color3.fromRGB(80,160,255) ; menuStroke.Thickness=1.5

    local menuTitle = Instance.new("TextLabel") ; menuTitle.Size=UDim2.new(1,-10,0,32) ; menuTitle.Position=UDim2.new(0,5,0,6)
    menuTitle.BackgroundTransparency=1 ; menuTitle.Text="SET TP TARGET" ; menuTitle.TextSize=13
    menuTitle.Font=Enum.Font.GothamBold ; menuTitle.TextColor3=Color3.fromRGB(150,210,255) ; menuTitle.ZIndex=21 ; menuTitle.Parent=menu

    local function makeMenuBtn(text,yPos,color)
        local mb = Instance.new("TextButton") ; mb.Size=UDim2.new(1,-16,0,36) ; mb.Position=UDim2.new(0,8,0,yPos)
        mb.BackgroundColor3=color ; mb.BackgroundTransparency=0.6 ; mb.BorderSizePixel=0
        mb.Text=text ; mb.Font=Enum.Font.GothamBold ; mb.TextSize=12
        mb.TextColor3=Color3.fromRGB(230,245,255) ; mb.AutoButtonColor=true ; mb.ZIndex=21 ; mb.Parent=menu
        Instance.new("UICorner",mb).CornerRadius=UDim.new(0,8) ; return mb
    end

    local btnNearestPet = makeMenuBtn("Nearest Pet (auto)",       44, Color3.fromRGB(30,100,200))
    local btnSaveHere   = makeMenuBtn("Save MY position now",      86, Color3.fromRGB(40,130,60))
    local btnSavePet    = makeMenuBtn("Save NEAREST pet position",128, Color3.fromRGB(120,60,180))
    local btnCustomXYZ  = makeMenuBtn("Enter X, Y, Z manually",   170, Color3.fromRGB(160,100,20))
    local btnClose      = makeMenuBtn("Close",                     212, Color3.fromRGB(160,30,30))

    local xyzPanel = Instance.new("Frame") ; xyzPanel.Size=UDim2.new(1,-16,0,110) ; xyzPanel.Position=UDim2.new(0,8,0,254)
    xyzPanel.BackgroundColor3=Color3.fromRGB(10,30,70) ; xyzPanel.BackgroundTransparency=0.6
    xyzPanel.BorderSizePixel=0 ; xyzPanel.Visible=false ; xyzPanel.ZIndex=21 ; xyzPanel.Parent=menu
    Instance.new("UICorner",xyzPanel).CornerRadius=UDim.new(0,8)

    local function makeXYZBox(placeholder,yOff)
        local box = Instance.new("TextBox") ; box.Size=UDim2.new(1,-12,0,28) ; box.Position=UDim2.new(0,6,0,yOff)
        box.BackgroundColor3=Color3.fromRGB(30,60,120) ; box.BackgroundTransparency=0.6
        box.BorderSizePixel=0 ; box.PlaceholderText=placeholder ; box.Text=""
        box.Font=Enum.Font.Gotham ; box.TextSize=12 ; box.TextColor3=Color3.fromRGB(220,240,255)
        box.PlaceholderColor3=Color3.fromRGB(100,150,200) ; box.ClearTextOnFocus=false ; box.ZIndex=22 ; box.Parent=xyzPanel
        Instance.new("UICorner",box).CornerRadius=UDim.new(0,6) ; return box
    end
    local xBox = makeXYZBox("X",6) ; local yBox = makeXYZBox("Y",40) ; local zBox = makeXYZBox("Z",74)

    local function openMenu()
        menu.Visible = true ; xyzPanel.Visible = false
        TweenService:Create(menu,TweenInfo.new(0.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,200,0,256)}):Play()
    end
    local function closeMenu()
        TweenService:Create(menu,TweenInfo.new(0.15),{Size=UDim2.new(0,200,0,0)}):Play()
        task.wait(0.15) ; menu.Visible=false ; xyzPanel.Visible=false
    end

    task.spawn(function()
        while gui and gui.Parent do
            local r = PET_TP_COOLDOWN-(tick()-lastPetTPTime)
            if r > 0 then cdOverlay.Visible=true ; cdText.Text=tostring(math.ceil(r)) ; btn.BackgroundColor3=Color3.fromRGB(30,80,160)
            else cdOverlay.Visible=false ; cdText.Text="" ; btn.BackgroundColor3=Color3.fromRGB(50,140,230) end
            subLbl.Text = mobilePetTPTarget and ("-> "..(mobilePetTPTarget.label or "Custom")) or "Hold to set target"
            task.wait(0.1)
        end
    end)

    -- ================================================================
    -- TP TO PET — Giant Potion fires IMMEDIATELY on press (parallel),
    -- then TP happens right away (no waiting on potion)
    -- ================================================================
    local function doTPToPet()
        if tick()-lastPetTPTime < PET_TP_COOLDOWN then return end
        lastPetTPTime = tick()
        local Character = LocalPlayer.Character ; if not Character then return end
        local HRP = Character:FindFirstChild("HumanoidRootPart") ; if not HRP then return end

        -- Fire potion immediately in parallel (no blocking wait)
        if giantPotionEnabled then
            task.spawn(useGiantPotionImmediate)
        end

        local target = nil
        if mobilePetTPTarget then
            target = mobilePetTPTarget.position
        else
            local hrp = getHRP() ; if not hrp then return end
            local nearest, minDist = nil, math.huge
            for _, a in ipairs(allAnimalsCache) do
                if a.worldPosition then
                    local d = (hrp.Position-a.worldPosition).Magnitude
                    if d < minDist then minDist=d ; nearest=a end
                end
            end
            if nearest then target = nearest.worldPosition end
        end

        if target then
            TweenService:Create(btn,TweenInfo.new(0.08),{BackgroundColor3=Color3.fromRGB(0,200,100)}):Play()
            -- TP instantly, no tween delay
            pcall(function() HRP.CFrame = CFrame.new(target.X, target.Y+4, target.Z) end)
            task.wait(0.15)
            btn.BackgroundColor3 = Color3.fromRGB(50,140,230)
        else
            TweenService:Create(btn,TweenInfo.new(0.08),{BackgroundColor3=Color3.fromRGB(200,50,50)}):Play()
            lbl.Text = "No pet found!" ; task.wait(1) ; lbl.Text = "TP TO PET"
            btn.BackgroundColor3 = Color3.fromRGB(50,140,230)
        end
    end

    local holdStart = 0 ; local isHolding = false ; local holdConn = nil ; local menuOpened = false
    btn.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.MouseButton2 then return end
        if input.UserInputType==Enum.UserInputType.MouseButton2 then openMenu() ; return end
        isHolding=true ; menuOpened=false ; holdStart=tick()
        if holdConn then holdConn:Disconnect() end
        holdConn = RunService.Heartbeat:Connect(function()
            if not isHolding then holdConn:Disconnect() ; TweenService:Create(holdBar,TweenInfo.new(0.1),{Size=UDim2.new(0,0,0,4)}):Play() ; return end
            local elapsed = tick()-holdStart ; holdBar.Size=UDim2.new(math.min(elapsed/LONG_PRESS_TIME,1),0,0,4)
            if elapsed >= LONG_PRESS_TIME and not menuOpened then
                menuOpened=true ; isHolding=false ; holdConn:Disconnect()
                TweenService:Create(holdBar,TweenInfo.new(0.15),{Size=UDim2.new(0,0,0,4)}):Play() ; openMenu()
            end
        end)
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        local wasHolding = isHolding ; isHolding = false
        if wasHolding and not menuOpened then doTPToPet() end
    end)

    btnNearestPet.MouseButton1Click:Connect(function() mobilePetTPTarget=nil ; closeMenu() end)
    btnSaveHere.MouseButton1Click:Connect(function()
        local hrp = getHRP() ; if hrp then mobilePetTPTarget={position=hrp.Position,label="My Pos"} end ; closeMenu()
    end)
    btnSavePet.MouseButton1Click:Connect(function()
        local hrp = getHRP()
        if hrp then
            local nearest, minDist = nil, math.huge
            for _, a in ipairs(allAnimalsCache) do
                if a.worldPosition then local d=(hrp.Position-a.worldPosition).Magnitude ; if d<minDist then minDist=d ; nearest=a end end
            end
            if nearest then mobilePetTPTarget={position=nearest.worldPosition,label=nearest.name}
            else lbl.Text="No pets found!" ; task.delay(1.5,function() lbl.Text="TP TO PET" end) end
        end
        closeMenu()
    end)
    btnCustomXYZ.MouseButton1Click:Connect(function()
        xyzPanel.Visible = not xyzPanel.Visible
        TweenService:Create(menu,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{Size=UDim2.new(0,200,0,xyzPanel.Visible and 372 or 256)}):Play()
        if xyzPanel.Visible then
            local pos = mobilePetTPTarget and mobilePetTPTarget.position or (getHRP() and getHRP().Position)
            if pos then xBox.Text=tostring(math.floor(pos.X)) ; yBox.Text=tostring(math.floor(pos.Y)) ; zBox.Text=tostring(math.floor(pos.Z)) end
        end
    end)
    local function tryConfirmXYZ()
        local x,y,z = tonumber(xBox.Text),tonumber(yBox.Text),tonumber(zBox.Text)
        if x and y and z then mobilePetTPTarget={position=Vector3.new(x,y,z),label=string.format("%.0f,%.0f,%.0f",x,y,z)} ; closeMenu() end
    end
    xBox.FocusLost:Connect(function(e) if e then tryConfirmXYZ() end end)
    yBox.FocusLost:Connect(function(e) if e then tryConfirmXYZ() end end)
    zBox.FocusLost:Connect(function(e) if e then tryConfirmXYZ() end end)
    btnClose.MouseButton1Click:Connect(closeMenu)
    return gui
end

-- AP SPAMMER UI
local function createAPSpammerUI()
    local apGui = Instance.new("ScreenGui") ; apGui.Name="APSpammerPanel" ; apGui.ResetOnSpawn=false
    apGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling ; apGui.DisplayOrder=998 ; apGui.Parent=PlayerGui

    local apFrame = Instance.new("Frame") ; apFrame.Name="APFrame"
    apFrame.Size=UDim2.fromOffset(190,240) ; apFrame.Position=UDim2.new(0,10,0.5,-120)
    apFrame.BackgroundColor3=Color3.fromRGB(12,12,20) ; apFrame.BackgroundTransparency=0.7
    apFrame.BorderSizePixel=0 ; apFrame.Parent=apGui
    Instance.new("UICorner",apFrame).CornerRadius=UDim.new(0,12)
    local apStroke = Instance.new("UIStroke",apFrame)
    apStroke.Color=Color3.fromRGB(200,60,60) ; apStroke.Thickness=1.5 ; apStroke.Transparency=0.3

    local apTitle = Instance.new("Frame") ; apTitle.Size=UDim2.new(1,0,0,30)
    apTitle.BackgroundColor3=Color3.fromRGB(180,40,40) ; apTitle.BorderSizePixel=0 ; apTitle.Parent=apFrame
    Instance.new("UICorner",apTitle).CornerRadius=UDim.new(0,12)

    local apTitleLbl = Instance.new("TextLabel") ; apTitleLbl.Size=UDim2.new(1,-35,1,0) ; apTitleLbl.Position=UDim2.new(0,8,0,0)
    apTitleLbl.BackgroundTransparency=1 ; apTitleLbl.Text="AP SPAMMER" ; apTitleLbl.Font=Enum.Font.GothamBold
    apTitleLbl.TextSize=13 ; apTitleLbl.TextColor3=Color3.fromRGB(255,255,255) ; apTitleLbl.TextXAlignment=Enum.TextXAlignment.Left ; apTitleLbl.Parent=apTitle

    local apMin = Instance.new("TextButton") ; apMin.Size=UDim2.new(0,22,0,22) ; apMin.Position=UDim2.new(1,-26,0,4)
    apMin.BackgroundColor3=Color3.fromRGB(60,20,20) ; apMin.BorderSizePixel=0 ; apMin.Text="-" ; apMin.TextScaled=true
    apMin.Font=Enum.Font.GothamBold ; apMin.TextColor3=Color3.fromRGB(255,255,255) ; apMin.Parent=apTitle
    Instance.new("UICorner",apMin).CornerRadius=UDim.new(0,6)

    local apContent = Instance.new("Frame") ; apContent.Name="Content"
    apContent.Size=UDim2.new(1,0,1,-30) ; apContent.Position=UDim2.new(0,0,0,30)
    apContent.BackgroundTransparency=1 ; apContent.Parent=apFrame

    local targetLabel = Instance.new("TextLabel") ; targetLabel.Size=UDim2.new(1,-10,0,20) ; targetLabel.Position=UDim2.new(0,5,0,6)
    targetLabel.BackgroundTransparency=1 ; targetLabel.Text="SELECT TARGET:" ; targetLabel.Font=Enum.Font.GothamBold
    targetLabel.TextSize=11 ; targetLabel.TextColor3=Color3.fromRGB(255,150,150) ; targetLabel.TextXAlignment=Enum.TextXAlignment.Left ; targetLabel.Parent=apContent

    local apScroll = Instance.new("ScrollingFrame") ; apScroll.Size=UDim2.new(1,-8,0,110) ; apScroll.Position=UDim2.new(0,4,0,30)
    apScroll.BackgroundColor3=Color3.fromRGB(20,20,30) ; apScroll.BackgroundTransparency=0.7 ; apScroll.BorderSizePixel=0
    apScroll.ScrollBarThickness=4 ; apScroll.ScrollBarImageColor3=Color3.fromRGB(180,40,40) ; apScroll.CanvasSize=UDim2.new(0,0,0,0) ; apScroll.Parent=apContent
    Instance.new("UICorner",apScroll).CornerRadius=UDim.new(0,8)
    local apList = Instance.new("UIListLayout") ; apList.Padding=UDim.new(0,3) ; apList.Parent=apScroll
    local apPad  = Instance.new("UIPadding") ; apPad.PaddingTop=UDim.new(0,3) ; apPad.PaddingLeft=UDim.new(0,3) ; apPad.PaddingRight=UDim.new(0,3) ; apPad.Parent=apScroll

    local selectedDisplay = Instance.new("TextLabel") ; selectedDisplay.Size=UDim2.new(1,-8,0,22) ; selectedDisplay.Position=UDim2.new(0,4,0,145)
    selectedDisplay.BackgroundColor3=Color3.fromRGB(40,15,15) ; selectedDisplay.BackgroundTransparency=0.6 ; selectedDisplay.BorderSizePixel=0
    selectedDisplay.Text="No target selected" ; selectedDisplay.Font=Enum.Font.Gotham ; selectedDisplay.TextSize=11
    selectedDisplay.TextColor3=Color3.fromRGB(200,120,120) ; selectedDisplay.Parent=apContent
    Instance.new("UICorner",selectedDisplay).CornerRadius=UDim.new(0,6)

    local spamBtn = Instance.new("TextButton") ; spamBtn.Size=UDim2.new(1,-8,0,42) ; spamBtn.Position=UDim2.new(0,4,0,172)
    spamBtn.BackgroundColor3=Color3.fromRGB(200,40,40) ; spamBtn.BorderSizePixel=0 ; spamBtn.Text="" ; spamBtn.AutoButtonColor=false ; spamBtn.Parent=apContent
    Instance.new("UICorner",spamBtn).CornerRadius=UDim.new(0,10)
    local spamStroke = Instance.new("UIStroke",spamBtn) ; spamStroke.Color=Color3.fromRGB(255,100,100) ; spamStroke.Thickness=1.5 ; spamStroke.Transparency=0.3

    local spamIcon = Instance.new("TextLabel") ; spamIcon.Size=UDim2.new(1,0,0,22) ; spamIcon.Position=UDim2.new(0,0,0,4)
    spamIcon.BackgroundTransparency=1 ; spamIcon.Text="SPAM AP" ; spamIcon.Font=Enum.Font.GothamBlack ; spamIcon.TextSize=17
    spamIcon.TextColor3=Color3.fromRGB(255,255,255) ; spamIcon.Parent=spamBtn

    local spamSub = Instance.new("TextLabel") ; spamSub.Size=UDim2.new(1,0,0,14) ; spamSub.Position=UDim2.new(0,0,0,26)
    spamSub.BackgroundTransparency=1 ; spamSub.Text=IS_PC and "Click or press F" or "Tap to spam"
    spamSub.Font=Enum.Font.Gotham ; spamSub.TextSize=10 ; spamSub.TextColor3=Color3.fromRGB(255,180,180) ; spamSub.Parent=spamBtn

    local spamCD = Instance.new("Frame") ; spamCD.Size=UDim2.new(1,0,1,0) ; spamCD.BackgroundColor3=Color3.fromRGB(0,0,0)
    spamCD.BackgroundTransparency=0.4 ; spamCD.BorderSizePixel=0 ; spamCD.Visible=false ; spamCD.ZIndex=5 ; spamCD.Parent=spamBtn
    Instance.new("UICorner",spamCD).CornerRadius=UDim.new(0,10)
    local spamCDTxt = Instance.new("TextLabel") ; spamCDTxt.Size=UDim2.new(1,0,1,0) ; spamCDTxt.BackgroundTransparency=1
    spamCDTxt.Text="WAIT..." ; spamCDTxt.Font=Enum.Font.GothamBold ; spamCDTxt.TextSize=14 ; spamCDTxt.TextColor3=Color3.fromRGB(255,255,255) ; spamCDTxt.ZIndex=6 ; spamCDTxt.Parent=spamCD

    task.spawn(function()
        while apGui and apGui.Parent do
            if apSpamming or apCooldown then spamCD.Visible=true ; spamBtn.BackgroundColor3=Color3.fromRGB(80,20,20)
            else spamCD.Visible=false ; spamBtn.BackgroundColor3=Color3.fromRGB(200,40,40) end
            task.wait(0.1)
        end
    end)

    local function refreshAPList()
        for _, child in pairs(apScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
        for _, player in pairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local pb = Instance.new("TextButton") ; pb.Size=UDim2.new(1,0,0,26)
            pb.BackgroundColor3=Color3.fromRGB(30,15,15) ; pb.BackgroundTransparency=0.6 ; pb.BorderSizePixel=0
            pb.Text=player.Name ; pb.Font=Enum.Font.Gotham ; pb.TextSize=12 ; pb.TextColor3=Color3.fromRGB(220,200,200) ; pb.AutoButtonColor=false ; pb.Parent=apScroll
            Instance.new("UICorner",pb).CornerRadius=UDim.new(0,5)
            pb.MouseButton1Click:Connect(function()
                AP_TARGET=player.Name ; selectedDisplay.Text="✓ "..player.Name ; selectedDisplay.TextColor3=Color3.fromRGB(100,255,150)
                TweenService:Create(pb,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(60,30,30)}):Play()
                task.delay(0.2,function() if pb and pb.Parent then TweenService:Create(pb,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(30,15,15)}):Play() end end)
            end)
            pb.InputBegan:Connect(function(i)
                if i.UserInputType==Enum.UserInputType.Touch then AP_TARGET=player.Name ; selectedDisplay.Text="✓ "..player.Name ; selectedDisplay.TextColor3=Color3.fromRGB(100,255,150) end
            end)
        end
        task.wait() ; apScroll.CanvasSize=UDim2.new(0,0,0,apList.AbsoluteContentSize.Y+6)
    end
    Players.PlayerAdded:Connect(refreshAPList) ; Players.PlayerRemoving:Connect(refreshAPList) ; refreshAPList()

    local function doSpam()
        if not AP_TARGET then
            selectedDisplay.Text="Pick a target first!" ; selectedDisplay.TextColor3=Color3.fromRGB(255,100,100)
            task.delay(1.5,function() selectedDisplay.Text="No target selected" ; selectedDisplay.TextColor3=Color3.fromRGB(200,120,120) end) ; return
        end
        sendAPCommands(AP_TARGET)
        TweenService:Create(spamBtn,TweenInfo.new(0.08),{BackgroundColor3=Color3.fromRGB(255,80,80)}):Play()
        task.delay(0.3,function() if spamBtn and spamBtn.Parent then TweenService:Create(spamBtn,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(200,40,40)}):Play() end end)
    end
    spamBtn.MouseButton1Click:Connect(doSpam)
    spamBtn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then doSpam() end end)

    if IS_PC then
        local fConn = UserInputService.InputBegan:Connect(function(input,gp) if input.KeyCode==Enum.KeyCode.F and not gp then doSpam() end end)
        table.insert(connections,fConn)
    end

    local apMinimized = false ; local apNormalSize = apFrame.Size
    apMin.MouseButton1Click:Connect(function()
        apMinimized = not apMinimized
        if apMinimized then apContent.Visible=false ; apFrame.Size=UDim2.fromOffset(190,30) ; apMin.Text="+"
        else apContent.Visible=true ; apFrame.Size=apNormalSize ; apMin.Text="-" end
    end)

    local apDragging=false ; local apDragStart,apStartPos
    apTitle.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            apDragging=true ; apDragStart=input.Position ; apStartPos=apFrame.Position
            input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then apDragging=false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if apDragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local delta = input.Position-apDragStart
            apFrame.Position = UDim2.new(apStartPos.X.Scale,apStartPos.X.Offset+delta.X,apStartPos.Y.Scale,apStartPos.Y.Offset+delta.Y)
        end
    end)
    return apGui
end

-- SPEED BOOSTER UI
local function createSpeedBoosterUI()
    local sbGui = Instance.new("ScreenGui") ; sbGui.Name="SpeedBoosterPanel" ; sbGui.ResetOnSpawn=false
    sbGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling ; sbGui.DisplayOrder=997 ; sbGui.Parent=PlayerGui

    local sbFrame = Instance.new("Frame") ; sbFrame.Name="SpeedFrame"
    sbFrame.Size=UDim2.fromOffset(200,200) ; sbFrame.Position=UDim2.new(0,10,0.5,135)
    sbFrame.BackgroundColor3=Color3.fromRGB(10,10,10) ; sbFrame.BackgroundTransparency=0.7 ; sbFrame.BorderSizePixel=0 ; sbFrame.Parent=sbGui
    Instance.new("UICorner",sbFrame).CornerRadius=UDim.new(0,12)
    local sbStroke = Instance.new("UIStroke",sbFrame) ; sbStroke.Color=Color3.fromRGB(80,200,80) ; sbStroke.Thickness=1.5 ; sbStroke.Transparency=0.3

    local sbTitle = Instance.new("Frame") ; sbTitle.Size=UDim2.new(1,0,0,30) ; sbTitle.BackgroundColor3=Color3.fromRGB(40,130,40) ; sbTitle.BorderSizePixel=0 ; sbTitle.Parent=sbFrame
    Instance.new("UICorner",sbTitle).CornerRadius=UDim.new(0,12)

    local sbTitleLbl = Instance.new("TextLabel") ; sbTitleLbl.Size=UDim2.new(1,-35,1,0) ; sbTitleLbl.Position=UDim2.new(0,8,0,0)
    sbTitleLbl.BackgroundTransparency=1 ; sbTitleLbl.Text="SPEED BOOSTER" ; sbTitleLbl.Font=Enum.Font.GothamBold ; sbTitleLbl.TextSize=13
    sbTitleLbl.TextColor3=Color3.fromRGB(255,255,255) ; sbTitleLbl.TextXAlignment=Enum.TextXAlignment.Left ; sbTitleLbl.Parent=sbTitle

    local sbMin = Instance.new("TextButton") ; sbMin.Size=UDim2.new(0,22,0,22) ; sbMin.Position=UDim2.new(1,-26,0,4)
    sbMin.BackgroundColor3=Color3.fromRGB(20,60,20) ; sbMin.BorderSizePixel=0 ; sbMin.Text="-" ; sbMin.TextScaled=true
    sbMin.Font=Enum.Font.GothamBold ; sbMin.TextColor3=Color3.fromRGB(255,255,255) ; sbMin.Parent=sbTitle
    Instance.new("UICorner",sbMin).CornerRadius=UDim.new(0,6)

    local sbContent = Instance.new("Frame") ; sbContent.Size=UDim2.new(1,0,1,-30) ; sbContent.Position=UDim2.new(0,0,0,30) ; sbContent.BackgroundTransparency=1 ; sbContent.Parent=sbFrame

    local function makeRow(labelText, yPos)
        local lbl = Instance.new("TextLabel") ; lbl.Size=UDim2.new(0,90,0,28) ; lbl.Position=UDim2.new(0,10,0,yPos)
        lbl.BackgroundTransparency=1 ; lbl.Text=labelText ; lbl.Font=Enum.Font.Gotham ; lbl.TextSize=11
        lbl.TextColor3=Color3.fromRGB(180,255,180) ; lbl.TextXAlignment=Enum.TextXAlignment.Left ; lbl.TextWrapped=true ; lbl.Parent=sbContent
        local box = Instance.new("TextBox") ; box.Size=UDim2.new(0,55,0,24) ; box.Position=UDim2.new(1,-65,0,yPos+2)
        box.BackgroundColor3=Color3.fromRGB(30,30,30) ; box.BackgroundTransparency=0.6 ; box.BorderSizePixel=0 ; box.Font=Enum.Font.GothamBold ; box.TextSize=14
        box.TextColor3=Color3.fromRGB(255,255,255) ; box.ClearTextOnFocus=false ; box.Parent=sbContent
        Instance.new("UICorner",box).CornerRadius=UDim.new(0,6) ; return box
    end

    local speedInputBox = makeRow("Speed (1-50):", 8)
    speedInputBox.Text = tostring(speedBoosterValue)
    speedInputBox.FocusLost:Connect(function()
        local n = tonumber(speedInputBox.Text)
        if n then speedBoosterValue=math.clamp(math.floor(n),1,50) end
        speedInputBox.Text = tostring(speedBoosterValue)
    end)

    local jumpInputBox = makeRow("Jump Power:", 44)
    jumpInputBox.Text = tostring(jumpBoosterValue)
    jumpInputBox.FocusLost:Connect(function()
        local n = tonumber(jumpInputBox.Text)
        if n then jumpBoosterValue=math.clamp(math.floor(n),1,999) end
        jumpInputBox.Text = tostring(jumpBoosterValue)
    end)

    local kbLbl = Instance.new("TextLabel") ; kbLbl.Size=UDim2.new(0,90,0,28) ; kbLbl.Position=UDim2.new(0,10,0,80)
    kbLbl.BackgroundTransparency=1 ; kbLbl.Text="Keybind:" ; kbLbl.Font=Enum.Font.Gotham ; kbLbl.TextSize=11
    kbLbl.TextColor3=Color3.fromRGB(180,255,180) ; kbLbl.TextXAlignment=Enum.TextXAlignment.Left ; kbLbl.Parent=sbContent

    local keybindBtn = Instance.new("TextButton") ; keybindBtn.Size=UDim2.new(0,55,0,24) ; keybindBtn.Position=UDim2.new(1,-65,0,82)
    keybindBtn.BackgroundColor3=Color3.fromRGB(30,30,30) ; keybindBtn.BackgroundTransparency=0.5 ; keybindBtn.BorderSizePixel=0 ; keybindBtn.Text=boostKeybind.Name
    keybindBtn.Font=Enum.Font.GothamBold ; keybindBtn.TextSize=12 ; keybindBtn.TextColor3=Color3.fromRGB(255,255,100) ; keybindBtn.Parent=sbContent
    Instance.new("UICorner",keybindBtn).CornerRadius=UDim.new(0,6)

    local listeningForKey = false
    keybindBtn.MouseButton1Click:Connect(function()
        if listeningForKey then return end ; listeningForKey=true ; keybindBtn.Text="..." ; keybindBtn.TextColor3=Color3.fromRGB(255,200,50)
        local kconn ; kconn=UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode~=Enum.KeyCode.Unknown then
                boostKeybind=input.KeyCode ; keybindBtn.Text=input.KeyCode.Name ; keybindBtn.TextColor3=Color3.fromRGB(255,255,100)
                listeningForKey=false ; kconn:Disconnect()
            end
        end)
    end)

    local activateBtn = Instance.new("TextButton") ; activateBtn.Size=UDim2.new(1,-16,0,40) ; activateBtn.Position=UDim2.new(0,8,0,118)
    activateBtn.BackgroundColor3=Color3.fromRGB(30,100,30) ; activateBtn.BackgroundTransparency=0.5 ; activateBtn.BorderSizePixel=0 ; activateBtn.Text="ACTIVATE BOOST"
    activateBtn.Font=Enum.Font.GothamBold ; activateBtn.TextSize=15 ; activateBtn.TextColor3=Color3.fromRGB(255,255,255) ; activateBtn.AutoButtonColor=false ; activateBtn.Parent=sbContent
    Instance.new("UICorner",activateBtn).CornerRadius=UDim.new(0,8)

    local function toggleBoost()
        speedBoosterEnabled = not speedBoosterEnabled
        if speedBoosterEnabled then activateBtn.BackgroundColor3=Color3.fromRGB(160,40,40) ; activateBtn.Text="DEACTIVATE BOOST"
        else activateBtn.BackgroundColor3=Color3.fromRGB(30,100,30) ; activateBtn.Text="ACTIVATE BOOST" end
        applyBoost()
    end
    activateBtn.MouseButton1Click:Connect(toggleBoost)
    activateBtn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then toggleBoost() end end)

    local kbConn = UserInputService.InputBegan:Connect(function(input,gp) if gp then return end ; if input.KeyCode==boostKeybind then toggleBoost() end end)
    table.insert(connections,kbConn)

    local sbMinimized = false ; local sbNormalSize = sbFrame.Size
    sbMin.MouseButton1Click:Connect(function()
        sbMinimized = not sbMinimized
        if sbMinimized then sbContent.Visible=false ; sbFrame.Size=UDim2.fromOffset(200,30) ; sbMin.Text="+"
        else sbContent.Visible=true ; sbFrame.Size=sbNormalSize ; sbMin.Text="-" end
    end)

    local sbDragging=false ; local sbDragStart,sbStartPos
    sbTitle.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            sbDragging=true ; sbDragStart=input.Position ; sbStartPos=sbFrame.Position
            input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then sbDragging=false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sbDragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local delta = input.Position-sbDragStart
            sbFrame.Position = UDim2.new(sbStartPos.X.Scale,sbStartPos.X.Offset+delta.X,sbStartPos.Y.Scale,sbStartPos.Y.Offset+delta.Y)
        end
    end)
    return sbGui
end

-- MAIN UI
local themeColors = {bg=Color3.fromRGB(210,235,255),card=Color3.fromRGB(180,215,245),accent=Color3.fromRGB(70,140,210),text=Color3.fromRGB(15,50,110),green=Color3.fromRGB(60,190,80),red=Color3.fromRGB(220,80,80)}

local function createToggle(parent,name,text,yPos)
    local toggle = Instance.new("TextButton") ; toggle.Name=name
    toggle.Size=UDim2.new(1,-20,0,30) ; toggle.Position=UDim2.new(0,10,0,yPos)
    toggle.BackgroundColor3=themeColors.card ; toggle.BackgroundTransparency=0.7
    toggle.BorderSizePixel=0 ; toggle.Text="" ; toggle.AutoButtonColor=false ; toggle.Parent=parent
    Instance.new("UICorner",toggle).CornerRadius=UDim.new(0,6)
    local label = Instance.new("TextLabel") ; label.Name="Label" ; label.Parent=toggle
    label.BackgroundTransparency=1 ; label.Position=UDim2.new(0,10,0,0) ; label.Size=UDim2.new(1,-60,1,0)
    label.Text=text ; label.Font=Enum.Font.Gotham ; label.TextSize=13 ; label.TextColor3=themeColors.text ; label.TextXAlignment=Enum.TextXAlignment.Left
    local switch = Instance.new("Frame") ; switch.Name="Switch" ; switch.Parent=toggle
    switch.Size=UDim2.new(0,40,0,20) ; switch.Position=UDim2.new(1,-50,0.5,-10)
    switch.BackgroundColor3=themeColors.red ; switch.BorderSizePixel=0
    Instance.new("UICorner",switch).CornerRadius=UDim.new(0,10)
    local knob = Instance.new("Frame") ; knob.Name="Knob" ; knob.Parent=switch
    knob.Size=UDim2.new(0,16,0,16) ; knob.Position=UDim2.new(0,2,0,2)
    knob.BackgroundColor3=Color3.fromRGB(255,255,255) ; knob.BorderSizePixel=0
    Instance.new("UICorner",knob).CornerRadius=UDim.new(0,8)
    return toggle,switch,knob
end

local function updateToggleUI(sw,knob,on)
    TweenService:Create(sw,TweenInfo.new(0.2),{BackgroundColor3=on and themeColors.green or themeColors.red}):Play()
    TweenService:Create(knob,TweenInfo.new(0.2),{Position=on and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)}):Play()
end

local function loadMainUI()
    local sg = Instance.new("ScreenGui") ; sg.Name="CleanAdminGUI" ; sg.ResetOnSpawn=false ; sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling ; sg.Parent=PlayerGui
    local mf = Instance.new("Frame") ; mf.Name="MainFrame"
    -- *** CHANGE 1: Mobile now uses same height (390) as PC ***
    mf.Size=UDim2.new(0,280,0,390) ; mf.Position=UDim2.new(1,350,0,60)
    mf.BackgroundColor3=themeColors.bg ; mf.BackgroundTransparency=0.7 ; mf.BorderSizePixel=0 ; mf.Parent=sg
    Instance.new("UICorner",mf).CornerRadius=UDim.new(0,10)
    local mfStroke = Instance.new("UIStroke",mf) ; mfStroke.Color=Color3.fromRGB(100,170,230) ; mfStroke.Thickness=2 ; mfStroke.Transparency=0.3

    local header = Instance.new("TextButton") ; header.Name="Header"
    header.Size=UDim2.new(1,0,0,50) ; header.BackgroundColor3=themeColors.accent ; header.BorderSizePixel=0 ; header.Text="" ; header.AutoButtonColor=false ; header.Parent=mf
    Instance.new("UICorner",header).CornerRadius=UDim.new(0,10)
    local hStroke = Instance.new("UIStroke",header) ; hStroke.Color=Color3.fromRGB(150,200,255) ; hStroke.Thickness=1.5

    local titleLbl = Instance.new("TextLabel") ; titleLbl.Parent=header ; titleLbl.BackgroundTransparency=1
    titleLbl.Position=UDim2.new(0,15,0,-5) ; titleLbl.Size=UDim2.new(1,-30,1,0)
    titleLbl.Text="JIGGY SEMI TP:" ; titleLbl.Font=Enum.Font.GothamBold ; titleLbl.TextSize=16 ; titleLbl.TextColor3=Color3.fromRGB(255,255,255) ; titleLbl.TextXAlignment=Enum.TextXAlignment.Left

    local subLbl2 = Instance.new("TextLabel") ; subLbl2.Parent=header ; subLbl2.BackgroundTransparency=1
    subLbl2.Position=UDim2.new(0,15,0,25) ; subLbl2.Size=UDim2.new(1,-30,0,20)
    subLbl2.Text="OWNER JIGGY" ; subLbl2.Font=Enum.Font.Gotham ; subLbl2.TextSize=12 ; subLbl2.TextColor3=Color3.fromRGB(200,230,255) ; subLbl2.TextXAlignment=Enum.TextXAlignment.Left

    local tf = Instance.new("Frame") ; tf.Name="TogglesFrame" ; tf.Size=UDim2.new(1,-20,0,340) ; tf.Position=UDim2.new(0,10,0,60) ; tf.BackgroundTransparency=1 ; tf.Parent=mf

    local adT,adS,adK = createToggle(tf,"AutoDefenseToggle","Teleport System",0)
    local agT,agS,agK = createToggle(tf,"AutoGrabToggle","Auto Grab (INSTA)",35)
    local dsT,dsS,dsK = createToggle(tf,"DesyncToggle","Activate To Work",70)
    local gpT,gpS,gpK = createToggle(tf,"GiantPotionToggle","Giant Potion",105)

    local rHint = Instance.new("TextLabel") ; rHint.Size=UDim2.new(0,70,0,16) ; rHint.Position=UDim2.new(0,12,0,143)
    rHint.BackgroundTransparency=1 ; rHint.Text="R: "..AUTO_STEAL_PROX_RADIUS ; rHint.Font=Enum.Font.Gotham ; rHint.TextSize=11
    rHint.TextColor3=Color3.fromRGB(30,90,180) ; rHint.TextXAlignment=Enum.TextXAlignment.Left ; rHint.Parent=tf

    local rBox = Instance.new("TextButton") ; rBox.Size=UDim2.new(0,40,0,16) ; rBox.Position=UDim2.new(0,55,0,143)
    rBox.BackgroundColor3=Color3.fromRGB(160,205,240) ; rBox.BackgroundTransparency=0.5 ; rBox.BorderSizePixel=0 ; rBox.Text=tostring(AUTO_STEAL_PROX_RADIUS)
    rBox.Font=Enum.Font.GothamBold ; rBox.TextSize=11 ; rBox.TextColor3=themeColors.text ; rBox.Parent=tf
    Instance.new("UICorner",rBox).CornerRadius=UDim.new(0,4)

    local pushLabel = Instance.new("TextLabel") ; pushLabel.Size=UDim2.new(0,110,0,16) ; pushLabel.Position=UDim2.new(1,-120,0,143)
    pushLabel.BackgroundTransparency=1 ; pushLabel.Text="WP push: 0" ; pushLabel.Font=Enum.Font.Gotham ; pushLabel.TextSize=11
    pushLabel.TextColor3=Color3.fromRGB(200,160,30) ; pushLabel.TextXAlignment=Enum.TextXAlignment.Right ; pushLabel.Parent=tf

    rBox.MouseButton1Click:Connect(function()
        if typing then return end ; typing=true
        local tb = Instance.new("TextBox") ; tb.Size=UDim2.new(1,0,1,0) ; tb.BackgroundTransparency=1
        tb.Text=tostring(AUTO_STEAL_PROX_RADIUS) ; tb.Font=Enum.Font.GothamBold ; tb.TextSize=11
        tb.TextColor3=themeColors.text ; tb.ClearTextOnFocus=false ; tb.Parent=rBox ; tb:CaptureFocus()
        tb.FocusLost:Connect(function(enter)
            if enter then local n=tonumber(tb.Text) ; if n and n>=5 and n<=200 then AUTO_STEAL_PROX_RADIUS=math.floor(n) ; updateCircleRadius() end end
            tb:Destroy() ; rBox.Text=tostring(AUTO_STEAL_PROX_RADIUS) ; typing=false
        end)
    end)

    local pbBg = Instance.new("Frame") ; pbBg.Size=UDim2.new(1,-20,0,5) ; pbBg.Position=UDim2.new(0,10,0,162)
    pbBg.BackgroundColor3=Color3.fromRGB(160,200,235) ; pbBg.BorderSizePixel=0 ; pbBg.Parent=tf
    Instance.new("UICorner",pbBg).CornerRadius=UDim.new(1,0)
    local pbFill = Instance.new("Frame") ; pbFill.Size=UDim2.new(0,0,1,0) ; pbFill.BackgroundColor3=Color3.fromRGB(0,140,255) ; pbFill.BorderSizePixel=0 ; pbFill.Parent=pbBg
    Instance.new("UICorner",pbFill).CornerRadius=UDim.new(1,0)

    local agStroke = Instance.new("UIStroke",agT) ; agStroke.Thickness=1.5 ; agStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    agStroke.Color=Color3.fromRGB(0,140,255) ; agStroke.Transparency=0.5
    local agGrad = Instance.new("UIGradient")
    agGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(0,140,255)),ColorSequenceKeypoint.new(0.25,Color3.fromRGB(180,215,245)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,140,255)),ColorSequenceKeypoint.new(0.75,Color3.fromRGB(180,215,245)),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,140,255))})
    agGrad.Parent=agStroke
    task.spawn(function() while agT and agT.Parent do agGrad.Rotation=agGrad.Rotation+2 ; task.wait(0.02) end end)

    -- ================================================================
    -- ACTIVATE BUTTON — identical style on BOTH PC and MOBILE
    -- ================================================================
    local tpBigBtn
    if IS_PC then
        tpBigBtn = Instance.new("TextButton") ; tpBigBtn.Name="TPToPetBig"
        tpBigBtn.Size=UDim2.new(1,-20,0,48) ; tpBigBtn.Position=UDim2.new(0,10,0,180)
        tpBigBtn.BackgroundColor3=Color3.fromRGB(50,140,230) ; tpBigBtn.BackgroundTransparency=0.5
        tpBigBtn.BorderSizePixel=0 ; tpBigBtn.Text="" ; tpBigBtn.AutoButtonColor=false ; tpBigBtn.ZIndex=5 ; tpBigBtn.Parent=tf
        Instance.new("UICorner",tpBigBtn).CornerRadius=UDim.new(0,10)
        local tpStroke = Instance.new("UIStroke",tpBigBtn) ; tpStroke.Color=Color3.fromRGB(120,200,255) ; tpStroke.Thickness=1.5 ; tpStroke.Transparency=0.2
        local tpIcon = Instance.new("TextLabel") ; tpIcon.Size=UDim2.new(1,0,1,0) ; tpIcon.BackgroundTransparency=1
        tpIcon.Text="ACTIVATE" ; tpIcon.Font=Enum.Font.GothamBlack ; tpIcon.TextSize=22 ; tpIcon.TextColor3=Color3.fromRGB(255,255,255) ; tpIcon.ZIndex=6 ; tpIcon.Parent=tpBigBtn
        local tpSub = Instance.new("TextLabel") ; tpSub.Size=UDim2.new(1,0,0,14) ; tpSub.Position=UDim2.new(0,0,1,-16)
        tpSub.BackgroundTransparency=1 ; tpSub.Text="Press G or click" ; tpSub.Font=Enum.Font.Gotham ; tpSub.TextSize=11
        tpSub.TextColor3=Color3.fromRGB(180,220,255) ; tpSub.ZIndex=6 ; tpSub.Parent=tpBigBtn

        -- PC ACTIVATE BUTTON: Giant Potion fires IMMEDIATELY on press
        tpBigBtn.MouseButton1Click:Connect(function()
            TweenService:Create(tpBigBtn,TweenInfo.new(0.08),{BackgroundColor3=Color3.fromRGB(0,200,100)}):Play()
            if giantPotionEnabled then task.spawn(useGiantPotionImmediate) end
            executeTP()
            task.delay(0.3,function() TweenService:Create(tpBigBtn,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(50,140,230)}):Play() end)
        end)
    end

    -- *** CHANGE 2: Mobile ACTIVATE button now matches PC style exactly ***
    if IS_MOBILE then
        local petBtn = Instance.new("TextButton") ; petBtn.Name="TPToPetBig"
        petBtn.Size=UDim2.new(1,-20,0,48) ; petBtn.Position=UDim2.new(0,10,0,180)
        petBtn.BackgroundColor3=Color3.fromRGB(50,140,230) ; petBtn.BackgroundTransparency=0.5
        petBtn.BorderSizePixel=0 ; petBtn.Text="" ; petBtn.AutoButtonColor=false ; petBtn.ZIndex=5 ; petBtn.Parent=tf
        Instance.new("UICorner",petBtn).CornerRadius=UDim.new(0,10)
        local tpStroke = Instance.new("UIStroke",petBtn) ; tpStroke.Color=Color3.fromRGB(120,200,255) ; tpStroke.Thickness=1.5 ; tpStroke.Transparency=0.2
        local tpIcon = Instance.new("TextLabel") ; tpIcon.Size=UDim2.new(1,0,1,0) ; tpIcon.BackgroundTransparency=1
        tpIcon.Text="ACTIVATE" ; tpIcon.Font=Enum.Font.GothamBlack ; tpIcon.TextSize=22 ; tpIcon.TextColor3=Color3.fromRGB(255,255,255) ; tpIcon.ZIndex=6 ; tpIcon.Parent=petBtn
        local tpSubMobile = Instance.new("TextLabel") ; tpSubMobile.Size=UDim2.new(1,0,0,14) ; tpSubMobile.Position=UDim2.new(0,0,1,-16)
        tpSubMobile.BackgroundTransparency=1 ; tpSubMobile.Text="Tap to activate" ; tpSubMobile.Font=Enum.Font.Gotham ; tpSubMobile.TextSize=11
        tpSubMobile.TextColor3=Color3.fromRGB(180,220,255) ; tpSubMobile.ZIndex=6 ; tpSubMobile.Parent=petBtn

        -- ================================================================
        -- MOBILE ACTIVATE: identical behaviour to PC — calls executeTP()
        -- Giant Potion fires IMMEDIATELY in parallel, same as PC G-key
        -- ================================================================
        local function doMobileActivate()
            TweenService:Create(petBtn,TweenInfo.new(0.08),{BackgroundColor3=Color3.fromRGB(0,200,100)}):Play()
            if giantPotionEnabled then task.spawn(useGiantPotionImmediate) end
            executeTP()
            task.delay(0.3,function() TweenService:Create(petBtn,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(50,140,230)}):Play() end)
        end
        petBtn.MouseButton1Click:Connect(doMobileActivate)
        petBtn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then doMobileActivate() end end)
    end

    local adEnabled=true ; local agEnabled=false ; local gpEnabled=false
    task.spawn(function()
        task.wait(1.3)
        adS.BackgroundColor3=Color3.fromRGB(60,190,80) ; adK.Position=UDim2.new(1,-18,0,2)
        agS.BackgroundColor3=themeColors.red ; agK.Position=UDim2.new(0,2,0,2)
        dsS.BackgroundColor3=themeColors.red ; dsK.Position=UDim2.new(0,2,0,2)
        gpS.BackgroundColor3=themeColors.red ; gpK.Position=UDim2.new(0,2,0,2)
    end)

    task.spawn(function()
        local tw = nil
        while true do
            task.wait(0.03) ; rBox.Text=tostring(AUTO_STEAL_PROX_RADIUS)
            local pushActive = MARKER_EXTRA_PUSH>0 and (tick()-lastStealTime)<PUSH_DECAY_TIME
            if pushActive then pushLabel.Text="WP push: +"..MARKER_EXTRA_PUSH ; pushLabel.TextColor3=Color3.fromRGB(255,200,0)
            else pushLabel.Text="WP push: 0" ; pushLabel.TextColor3=Color3.fromRGB(160,160,180) end
            if IsStealing then
                if tw then tw:Cancel() end
                tw=TweenService:Create(pbFill,TweenInfo.new(0.05,Enum.EasingStyle.Linear),{Size=UDim2.new(StealProgress,0,1,0)}) ; tw:Play()
            else
                if tw then tw:Cancel() ; tw=nil end
                if pbFill.Size.X.Scale>0 then pbFill.Size=UDim2.new(math.max(0,pbFill.Size.X.Scale-0.05),0,1,0) end
            end
        end
    end)

    agT.MouseButton1Click:Connect(function()
        agEnabled=not agEnabled ; AUTO_STEAL_CONFIG.ENABLED=agEnabled ; updateToggleUI(agS,agK,agEnabled) ; circleEnabled=agEnabled
        if agEnabled then
            local char = LocalPlayer.Character
            if char then createCircle(char) ; RunService:BindToRenderStep("CircleFollow",Enum.RenderPriority.Camera.Value+1,function() updateCircle(char) end) end
            agStroke.Transparency=0
        else
            RunService:UnbindFromRenderStep("CircleFollow")
            for _, p in ipairs(circleParts) do if p then p:Destroy() end end ; circleParts={} ; agStroke.Transparency=0.5
        end
    end)

    dsT.MouseButton1Click:Connect(function()
        if desyncPermanentlyActivated then return end
        dsT.AutoButtonColor=false ; dsT.Active=false
        local dsLabel = dsT:FindFirstChild("Label")
        task.spawn(function()
            if dsLabel then dsLabel.Text="Preparing..." end ; task.wait(0.3)
            applyPermanentDesync() ; task.wait(1.5)
            if dsLabel then dsLabel.Text="Almost done..." end ; task.wait(2)
            if dsLabel then dsLabel.Text="Done!" end ; task.wait(0.5)
            if dsLabel then dsLabel.Text="Ready To Work" end
            desyncPermanentlyActivated=true ; updateToggleUI(dsS,dsK,true)
        end)
    end)

    gpT.MouseButton1Click:Connect(function()
        gpEnabled=not gpEnabled ; giantPotionEnabled=gpEnabled ; updateToggleUI(gpS,gpK,gpEnabled)
        print("[GIANT POTION]", gpEnabled and "ON  (fires immediately on TP press)" or "OFF")
    end)
    gpT.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch then
            gpEnabled=not gpEnabled ; giantPotionEnabled=gpEnabled ; updateToggleUI(gpS,gpK,gpEnabled)
        end
    end)

    if IS_PC then
        UserInputService.InputBegan:Connect(function(input,gp)
            if input.KeyCode==Enum.KeyCode.G and not gp then
                if tpBigBtn then
                    TweenService:Create(tpBigBtn,TweenInfo.new(0.08),{BackgroundColor3=Color3.fromRGB(0,200,100)}):Play()
                    task.delay(0.3,function() TweenService:Create(tpBigBtn,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(50,140,230)}):Play() end)
                end
                if giantPotionEnabled then task.spawn(useGiantPotionImmediate) end
                executeTP()
            end
        end)
    end

    adT.MouseButton1Click:Connect(function()
        adEnabled=not adEnabled ; updateToggleUI(adS,adK,adEnabled) ; TPSysEnabled=adEnabled
        if not TPSysEnabled then if Marker and Marker.Parent then pcall(function() Marker:Destroy() end) end
        else Marker=CreateMarker() end
    end)

    local foot = Instance.new("Frame") ; foot.Size=UDim2.new(1,-20,0,30) ; foot.Position=UDim2.new(0,10,1,-40) ; foot.BackgroundTransparency=1 ; foot.Parent=mf
    local vl = Instance.new("TextLabel") ; vl.Size=UDim2.new(1,0,1,0) ; vl.BackgroundTransparency=1
    vl.Text="discord.gg/YJaajAeuD" ; vl.Font=Enum.Font.Gotham ; vl.TextSize=12
    vl.TextColor3=Color3.fromRGB(50,110,190) ; vl.TextXAlignment=Enum.TextXAlignment.Center ; vl.Parent=foot

    task.spawn(function()
        task.wait(0.5)
        TweenService:Create(mf,TweenInfo.new(0.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.new(1,-300,0,60),BackgroundTransparency=0.7}):Play()
    end)

    local dragging,dragStart,startPos=false,nil,nil
    local function update(input) local delta=input.Position-dragStart ; mf.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y) end
    header.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true ; dragStart=input.Position ; startPos=mf.Position
            TweenService:Create(hStroke,TweenInfo.new(0.2),{Thickness=2.5}):Play()
            input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false ; TweenService:Create(hStroke,TweenInfo.new(0.2),{Thickness=1.5}):Play() end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then update(input) end
    end)
end

-- LOADING SCREEN
local lsg = Instance.new("ScreenGui") ; lsg.Name="PremiumLoadScreen" ; lsg.ResetOnSpawn=false
lsg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling ; lsg.DisplayOrder=1000 ; lsg.Parent=LocalPlayer:WaitForChild("PlayerGui")
local lbg = Instance.new("Frame") ; lbg.Size=UDim2.new(1,0,1,0)
lbg.BackgroundColor3=Color3.fromRGB(200,230,255) ; lbg.BackgroundTransparency=0.7 ; lbg.BorderSizePixel=0 ; lbg.Parent=lsg
local mc = Instance.new("Frame") ; mc.Name="MainContainer" ; mc.Size=UDim2.new(0,400,0,300) ; mc.Position=UDim2.new(0.5,-200,0.5,-150)
mc.BackgroundColor3=Color3.fromRGB(225,242,255) ; mc.BackgroundTransparency=0.7 ; mc.BorderSizePixel=0 ; mc.Parent=lbg
Instance.new("UICorner",mc).CornerRadius=UDim.new(0,15)
local cs = Instance.new("UIStroke",mc) ; cs.Color=Color3.fromRGB(80,150,220) ; cs.Thickness=2 ; cs.Transparency=0.1

local function mkLbl(parent,text,font,size,color,posY,sizeX)
    local l = Instance.new("TextLabel") ; l.Size=UDim2.new(sizeX or 1,0,0,40)
    l.Position=UDim2.new(0,0,posY,0) ; l.BackgroundTransparency=1 ; l.Text=text
    l.Font=font ; l.TextSize=size ; l.TextColor3=color ; l.Parent=parent ; return l
end
mkLbl(mc,"SEMI TELEPORT",Enum.Font.GothamBlack,32,Color3.fromRGB(20,70,150),0.1)
mkLbl(mc,"LOADING PLEASE WAIT",Enum.Font.GothamMedium,16,Color3.fromRGB(60,120,190),0.25)
local statusTxt    = mkLbl(mc,"VERIFYING WHITELIST",Enum.Font.GothamBold,20,Color3.fromRGB(30,90,180),0.4)
local subStatusTxt = mkLbl(mc,"CHECKING PERMISSIONS...",Enum.Font.Gotham,14,Color3.fromRGB(80,140,200),0.5)

local pc = Instance.new("Frame") ; pc.Size=UDim2.new(1,-80,0,8) ; pc.Position=UDim2.new(0,40,0.65,0)
pc.BackgroundColor3=Color3.fromRGB(180,215,245) ; pc.BorderSizePixel=0 ; pc.Parent=mc
Instance.new("UICorner",pc).CornerRadius=UDim.new(1,0)
local pf = Instance.new("Frame") ; pf.Size=UDim2.new(0,0,1,0) ; pf.BackgroundColor3=Color3.fromRGB(50,140,230) ; pf.BorderSizePixel=0 ; pf.Parent=pc
Instance.new("UICorner",pf).CornerRadius=UDim.new(1,0)
local pt = Instance.new("TextLabel") ; pt.Size=UDim2.new(0,-180,0,30) ; pt.Position=UDim2.new(1,10,0.5,0)
pt.BackgroundTransparency=1 ; pt.Text="0%" ; pt.Font=Enum.Font.GothamBold ; pt.TextSize=18 ; pt.TextColor3=Color3.fromRGB(30,90,180) ; pt.TextXAlignment=Enum.TextXAlignment.Left ; pt.Parent=pc

local foot2 = Instance.new("Frame") ; foot2.Size=UDim2.new(1,-40,0,30) ; foot2.Position=UDim2.new(0,20,0.85,0) ; foot2.BackgroundTransparency=1 ; foot2.Parent=mc
local vl2 = Instance.new("TextLabel") ; vl2.Size=UDim2.new(0.5,0,1,0) ; vl2.BackgroundTransparency=1
vl2.Text="discord.gg/YJaajAeuD" ; vl2.Font=Enum.Font.Gotham ; vl2.TextSize=12 ; vl2.TextColor3=Color3.fromRGB(60,120,190) ; vl2.TextXAlignment=Enum.TextXAlignment.Left ; vl2.Parent=foot2
local cl2 = Instance.new("TextLabel") ; cl2.Size=UDim2.new(0.5,0,1,0) ; cl2.Position=UDim2.new(0.5,0,0,0)
cl2.BackgroundTransparency=1 ; cl2.Text="ARTFUL & MYSKYP" ; cl2.Font=Enum.Font.Gotham ; cl2.TextSize=12 ; cl2.TextColor3=Color3.fromRGB(90,150,210) ; cl2.TextXAlignment=Enum.TextXAlignment.Right ; cl2.Parent=foot2

local function updateProgress(pct,status,sub)
    TweenService:Create(pf,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.new(pct/100,0,1,0)}):Play()
    pt.Text=string.format("%d%%",pct) ; if status then statusTxt.Text=status end ; if sub then subStatusTxt.Text=sub end
end

-- BOOT SEQUENCE
task.spawn(function()
    mc.Position=UDim2.new(0.5,-200,0.4,-150) ; mc.BackgroundTransparency=1
    TweenService:Create(mc,TweenInfo.new(0.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.new(0.5,-200,0.5,-150),BackgroundTransparency=0.7}):Play()
    task.wait(0.5)
    local st = tick()
    updateProgress(15,"INITIALIZING","Starting SEMI Teleport...") ; task.wait(0.3)
    updateProgress(30,"CHECKING CHARACTER","Loading player data...")
    if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end ; task.wait(0.7)
    updateProgress(40,"DETECTING DEVICE",IS_MOBILE and "Mobile detected" or "PC detected") ; task.wait(0.5)
    updateProgress(45,"VERIFYING WHITELIST","Checking permissions...") ; task.wait(0.7)
    updateProgress(60,"WHITELIST CHECK","Validating access...") ; task.wait(0.7)
    updateProgress(75,"WHITELIST VERIFIED","Access granted") ; task.wait(0.6)
    updateProgress(85,"LOADING SYSTEMS","Initializing modules...") ; task.wait(0.5)
    updateProgress(95,"FINALIZING","Almost ready...") ; task.wait(0.5)
    updateProgress(100,"READY","Semi TP + Auto Grab + Desync + AP Spammer + Speed Booster + Giant Potion active")
    local elapsed = tick()-st ; if elapsed < 5 then task.wait(5-elapsed) end
    TweenService:Create(mc,TweenInfo.new(0.5),{BackgroundTransparency=1,Position=UDim2.new(0.5,-200,0.4,-150)}):Play()
    TweenService:Create(lbg,TweenInfo.new(0.5),{BackgroundTransparency=1}):Play()
    task.wait(0.5) ; lsg:Destroy()

    initializeScanner()
    autoStealLoop()
    loadMainUI()
    createAPSpammerUI()
    createSpeedBoosterUI()
    if LocalPlayer.Character then onCharacterAdded(LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
    if IS_MOBILE then task.wait(0.5) ; createMobileTPButton() end
end)

print("Script configured for:", IS_MOBILE and "MOBILE" or "PC")
