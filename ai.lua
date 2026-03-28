-- ⚡ CHIRON DUELS ⚡
-- Pink Edition - Vertical Single Column UI

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

-- ============================================================
-- SERVICES & SAFE CHARACTER WAIT
-- ============================================================
local function waitForCharacter()
    local char = Player.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") then
        return char
    end
    return Player.CharacterAdded:Wait()
end
task.spawn(waitForCharacter)

if not getgenv then getgenv = function() return _G end end

-- ============================================================
-- STATE
-- ============================================================
local Enabled = {
    SpeedBoost        = false,
    AntiRagdoll       = false,
    HitCircle         = false,
    Float             = false,
    SpeedWhileStealing= false,
    AutoSteal         = false,
    Unwalk            = false,
    OptimizerXRay     = false,
    SpamBat           = false,
    Helicopter        = false,
    Vibrance          = false,
    AutoRight         = false,
    AutoLeft          = false,
    GalaxyMode        = false,
    BatAimbot         = false,
}

local Values = {
    BoostSpeed           = 30,
    SpinSpeed            = 30,
    StealingSpeedValue   = 29,
    STEAL_RADIUS         = 20,
    STEAL_DURATION       = 1.3,
    DEFAULT_GRAVITY      = 196.2,
    GalaxyGravityPercent = 70,
    HOP_POWER            = 35,
    HOP_COOLDOWN         = 0.08,
    BatAimbotSpeed       = 55,
}

local KEYBINDS = {
    SPEED     = Enum.KeyCode.V,
    FLOAT     = Enum.KeyCode.F,
    AUTORIGHT = Enum.KeyCode.E,
    AUTOLEFT  = Enum.KeyCode.Q,
    BATAIMBOT = Enum.KeyCode.X,
}

local Connections   = {}
local isStealing    = false
local lastBatSwing  = 0
local BAT_SWING_COOLDOWN = 0.12

-- ============================================================
-- HELPERS
-- ============================================================
local function getMovementDirection()
    local c = Player.Character
    if not c then return Vector3.zero end
    local hum = c:FindFirstChildOfClass("Humanoid")
    return hum and hum.MoveDirection or Vector3.zero
end

local SlapList = {
    {1,"Bat"},{2,"Slap"},{3,"Iron Slap"},{4,"Gold Slap"},
    {5,"Diamond Slap"},{6,"Emerald Slap"},{7,"Ruby Slap"},
    {8,"Dark Matter Slap"},{9,"Flame Slap"},{10,"Nuclear Slap"},
    {11,"Galaxy Slap"},{12,"Glitched Slap"}
}

local function findBat()
    local c = Player.Character
    if not c then return nil end
    local bp = Player:FindFirstChildOfClass("Backpack")
    for _, ch in ipairs(c:GetChildren()) do
        if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end
    end
    if bp then
        for _, ch in ipairs(bp:GetChildren()) do
            if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end
        end
    end
    for _, i in ipairs(SlapList) do
        local t = c:FindFirstChild(i[2]) or (bp and bp:FindFirstChild(i[2]))
        if t then return t end
    end
    return nil
end

-- ============================================================
-- FEATURE LOGIC
-- ============================================================

-- Speed Boost
local function startSpeedBoost()
    if Connections.speed then return end
    Connections.speed = RunService.Heartbeat:Connect(function()
        if not Enabled.SpeedBoost then return end
        pcall(function()
            local c = Player.Character
            if not c then return end
            local h = c:FindFirstChild("HumanoidRootPart")
            if not h then return end
            local md = getMovementDirection()
            if md.Magnitude > 0.1 then
                h.AssemblyLinearVelocity = Vector3.new(md.X * Values.BoostSpeed, h.AssemblyLinearVelocity.Y, md.Z * Values.BoostSpeed)
            end
        end)
    end)
end
local function stopSpeedBoost()
    if Connections.speed then Connections.speed:Disconnect() Connections.speed = nil end
end

-- Speed While Stealing
local function startSpeedWhileStealing()
    if Connections.speedWhileStealing then return end
    Connections.speedWhileStealing = RunService.Heartbeat:Connect(function()
        if not Enabled.SpeedWhileStealing or not Player:GetAttribute("Stealing") then return end
        local c = Player.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        if not h then return end
        local md = getMovementDirection()
        if md.Magnitude > 0.1 then
            h.AssemblyLinearVelocity = Vector3.new(md.X * Values.StealingSpeedValue, h.AssemblyLinearVelocity.Y, md.Z * Values.StealingSpeedValue)
        end
    end)
end
local function stopSpeedWhileStealing()
    if Connections.speedWhileStealing then Connections.speedWhileStealing:Disconnect() Connections.speedWhileStealing = nil end
end

-- Anti Ragdoll (v2)
local antiRagdollMode = nil
local ragdollConnections = {}
local cachedCharData = {}
local isBoosting = false
local AR_BOOST_SPEED = 400
local AR_DEFAULT_SPEED = 16

local function arCacheCharacterData()
    local char = Player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    cachedCharData = { character = char, humanoid = hum, root = root }
    return true
end

local function arDisconnectAll()
    for _, conn in ipairs(ragdollConnections) do
        pcall(function() conn:Disconnect() end)
    end
    ragdollConnections = {}
end

local function arIsRagdolled()
    if not cachedCharData.humanoid then return false end
    local state = cachedCharData.humanoid:GetState()
    if state == Enum.HumanoidStateType.Physics or
       state == Enum.HumanoidStateType.Ragdoll or
       state == Enum.HumanoidStateType.FallingDown then return true end
    local endTime = Player:GetAttribute("RagdollEndTime")
    if endTime and (endTime - workspace:GetServerTimeNow()) > 0 then return true end
    return false
end

local function arForceExit()
    if not cachedCharData.humanoid or not cachedCharData.root then return end
    pcall(function()
        Player:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow())
    end)
    for _, d in ipairs(cachedCharData.character:GetDescendants()) do
        if d:IsA("BallSocketConstraint") or (d:IsA("Attachment") and d.Name:find("RagdollAttachment")) then
            d:Destroy()
        end
    end
    if not isBoosting then
        isBoosting = true
        cachedCharData.humanoid.WalkSpeed = AR_BOOST_SPEED
    end
    if cachedCharData.humanoid.Health > 0 then
        cachedCharData.humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end
    cachedCharData.root.Anchored = false
end

local function arHeartbeatLoop()
    while antiRagdollMode == "v1" do
        task.wait()
        if not Enabled.AntiRagdoll then break end
        local ragdolled = arIsRagdolled()
        if ragdolled then
            arForceExit()
        elseif isBoosting and not ragdolled then
            isBoosting = false
            if cachedCharData.humanoid then
                cachedCharData.humanoid.WalkSpeed = AR_DEFAULT_SPEED
            end
        end
    end
end

local function startAntiRagdoll()
    if antiRagdollMode == "v1" then return end
    if not arCacheCharacterData() then return end
    antiRagdollMode = "v1"
    local camConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if cam and cachedCharData.humanoid then
            cam.CameraSubject = cachedCharData.humanoid
        end
    end)
    table.insert(ragdollConnections, camConn)
    local respawnConn = Player.CharacterAdded:Connect(function()
        isBoosting = false
        task.wait(0.5)
        arCacheCharacterData()
    end)
    table.insert(ragdollConnections, respawnConn)
    task.spawn(arHeartbeatLoop)
end

local function stopAntiRagdoll()
    antiRagdollMode = nil
    if isBoosting and cachedCharData.humanoid then
        cachedCharData.humanoid.WalkSpeed = AR_DEFAULT_SPEED
    end
    isBoosting = false
    arDisconnectAll()
    cachedCharData = {}
end

-- Spam Bat
local function startSpamBat()
    if Connections.spamBat then return end
    Connections.spamBat = RunService.Heartbeat:Connect(function()
        if not Enabled.SpamBat then return end
        local c = Player.Character
        if not c then return end
        local bat = findBat()
        if not bat then return end
        if bat.Parent ~= c then bat.Parent = c end
        local now = tick()
        if now - lastBatSwing < BAT_SWING_COOLDOWN then return end
        lastBatSwing = now
        pcall(function() bat:Activate() end)
    end)
end
local function stopSpamBat()
    if Connections.spamBat then Connections.spamBat:Disconnect() Connections.spamBat = nil end
end

-- Helicopter
local helicopterBAV = nil
local function startHelicopter()
    local c = Player.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if helicopterBAV then helicopterBAV:Destroy() helicopterBAV = nil end
    helicopterBAV = Instance.new("BodyAngularVelocity")
    helicopterBAV.Name = "HelicopterBAV"
    helicopterBAV.MaxTorque = Vector3.new(0, math.huge, 0)
    helicopterBAV.AngularVelocity = Vector3.new(0, Values.SpinSpeed, 0)
    helicopterBAV.Parent = hrp
end
local function stopHelicopter()
    if helicopterBAV then helicopterBAV:Destroy() helicopterBAV = nil end
    local c = Player.Character
    if c then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, v in pairs(hrp:GetChildren()) do
                if v.Name == "HelicopterBAV" then v:Destroy() end
            end
        end
    end
end

-- Float
local floatConn = nil
local FLOAT_TARGET_HEIGHT = 10
local function startFloat()
    if floatConn then return end
    local c = Player.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local floatOriginY = hrp.Position.Y + FLOAT_TARGET_HEIGHT
    local floatStartTime = tick()
    local floatDescending = false
    floatConn = RunService.Heartbeat:Connect(function()
        if not Enabled.Float then return end
        local c2 = Player.Character
        if not c2 then return end
        local h = c2:FindFirstChild("HumanoidRootPart")
        if not h then return end
        local hum2 = c2:FindFirstChildOfClass("Humanoid")
        local moveDir = hum2 and hum2.MoveDirection or Vector3.zero
        if tick() - floatStartTime >= 4 then floatDescending = true end
        local currentY = h.Position.Y
        local vertVel
        if floatDescending then
            vertVel = -20
            if currentY <= floatOriginY - FLOAT_TARGET_HEIGHT + 0.5 then
                h.AssemblyLinearVelocity = Vector3.zero
                Enabled.Float = false
                if floatConn then floatConn:Disconnect() floatConn = nil end
                return
            end
        else
            local diff = floatOriginY - currentY
            if diff > 0.3 then vertVel = math.clamp(diff * 8, 5, 50)
            elseif diff < -0.3 then vertVel = math.clamp(diff * 8, -50, -5)
            else vertVel = 0 end
        end
        local horizX = moveDir.Magnitude > 0.1 and moveDir.X * Values.BoostSpeed or 0
        local horizZ = moveDir.Magnitude > 0.1 and moveDir.Z * Values.BoostSpeed or 0
        h.AssemblyLinearVelocity = Vector3.new(horizX, vertVel, horizZ)
    end)
end
local function stopFloat()
    if floatConn then floatConn:Disconnect() floatConn = nil end
    local c = Player.Character
    if c then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
    end
end

-- Unwalk
local savedAnimations = {}
local function startUnwalk()
    local c = Player.Character
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum then for _, t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop() end end
    local anim = c:FindFirstChild("Animate")
    if anim then savedAnimations.Animate = anim:Clone() anim:Destroy() end
end
local function stopUnwalk()
    local c = Player.Character
    if c and savedAnimations.Animate then
        savedAnimations.Animate:Clone().Parent = c
        savedAnimations.Animate = nil
    end
end

-- Hit Circle (Melee Aimbot)
local Cebo = { Conn = nil, Circle = nil, Align = nil, Attach = nil }
local function startHitCircle()
    if Cebo.Conn then return end
    local char = Player.Character or Player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    Cebo.Attach = Instance.new("Attachment", hrp)
    Cebo.Align = Instance.new("AlignOrientation", hrp)
    Cebo.Align.Attachment0 = Cebo.Attach
    Cebo.Align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    Cebo.Align.RigidityEnabled = true
    Cebo.Circle = Instance.new("Part")
    Cebo.Circle.Shape = Enum.PartType.Cylinder
    Cebo.Circle.Material = Enum.Material.Neon
    Cebo.Circle.Size = Vector3.new(0.05, 14.5, 14.5)
    Cebo.Circle.Color = Color3.fromRGB(255, 120, 0)
    Cebo.Circle.CanCollide = false
    Cebo.Circle.Massless = true
    Cebo.Circle.Parent = workspace
    local weld = Instance.new("Weld")
    weld.Part0 = hrp
    weld.Part1 = Cebo.Circle
    weld.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90))
    weld.Parent = Cebo.Circle
    Cebo.Conn = RunService.RenderStepped:Connect(function()
        if not Enabled.HitCircle then return end
        local target, dmin = nil, 7.25
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local d = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                if d <= dmin then target, dmin = p.Character.HumanoidRootPart, d end
            end
        end
        if target then
            char.Humanoid.AutoRotate = false
            Cebo.Align.Enabled = true
            Cebo.Align.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(target.Position.X, hrp.Position.Y, target.Position.Z))
            local t = char:FindFirstChild("Bat") or char:FindFirstChild("Medusa")
            if t then t:Activate() end
        else
            Cebo.Align.Enabled = false
            char.Humanoid.AutoRotate = true
        end
    end)
end
local function stopHitCircle()
    if Cebo.Conn   then Cebo.Conn:Disconnect()   Cebo.Conn   = nil end
    if Cebo.Circle then Cebo.Circle:Destroy()     Cebo.Circle = nil end
    if Cebo.Align  then Cebo.Align:Destroy()      Cebo.Align  = nil end
    if Cebo.Attach then Cebo.Attach:Destroy()     Cebo.Attach = nil end
    if Player.Character and Player.Character:FindFirstChild("Humanoid") then
        Player.Character.Humanoid.AutoRotate = true
    end
end

-- Bat Aimbot
local function findNearestEnemy(myHRP)
    local nearest, nearestDist, nearestTorso = nil, math.huge, nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local eh  = p.Character:FindFirstChild("HumanoidRootPart")
            local torso = p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if eh and hum and hum.Health > 0 then
                local d = (eh.Position - myHRP.Position).Magnitude
                if d < nearestDist then
                    nearestDist = d
                    nearest     = eh
                    nearestTorso = torso or eh
                end
            end
        end
    end
    return nearest, nearestDist, nearestTorso
end

local function startBatAimbot()
    if Connections.batAimbot then return end
    Connections.batAimbot = RunService.Heartbeat:Connect(function()
        if not Enabled.BatAimbot then return end
        local c = Player.Character
        if not c then return end
        local h   = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not h or not hum then return end
        local bat = findBat()
        if bat and bat.Parent ~= c then
            pcall(function() hum:EquipTool(bat) end)
        end
        local target, _, torso = findNearestEnemy(h)
        if target and torso then
            local dir     = torso.Position - h.Position
            local flatDir = Vector3.new(dir.X, 0, dir.Z)
            local flatDist = flatDir.Magnitude
            local spd = Values.BatAimbotSpeed
            if flatDist > 1.5 then
                local moveDir = flatDir.Unit
                h.AssemblyLinearVelocity = Vector3.new(moveDir.X * spd, h.AssemblyLinearVelocity.Y, moveDir.Z * spd)
            else
                local tv = target.AssemblyLinearVelocity
                h.AssemblyLinearVelocity = Vector3.new(tv.X, h.AssemblyLinearVelocity.Y, tv.Z)
            end
        end
    end)
end
local function stopBatAimbot()
    if Connections.batAimbot then
        Connections.batAimbot:Disconnect()
        Connections.batAimbot = nil
    end
end

-- Galaxy Mode
local galaxyModeEnabled = false
local galaxyHopsEnabled = false
local galaxyLastHopTime = 0
local galaxySpaceHeld   = false
local galaxyOriginalJump = 50
local galaxyVectorForce = nil
local galaxyAttachment  = nil

local function galaxyCaptureJumpPower()
    local c = Player.Character
    if c then
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum and hum.JumpPower > 0 then galaxyOriginalJump = hum.JumpPower end
    end
end
task.spawn(function() task.wait(1) galaxyCaptureJumpPower() end)
Player.CharacterAdded:Connect(function() task.wait(1) galaxyCaptureJumpPower() end)

local function galaxySetupForce()
    pcall(function()
        local c = Player.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        if not h then return end
        if galaxyVectorForce then galaxyVectorForce:Destroy() end
        if galaxyAttachment  then galaxyAttachment:Destroy()  end
        galaxyAttachment = Instance.new("Attachment")
        galaxyAttachment.Parent = h
        galaxyVectorForce = Instance.new("VectorForce")
        galaxyVectorForce.Attachment0 = galaxyAttachment
        galaxyVectorForce.ApplyAtCenterOfMass = true
        galaxyVectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
        galaxyVectorForce.Force = Vector3.zero
        galaxyVectorForce.Parent = h
    end)
end
local function galaxyUpdateForce()
    if not galaxyModeEnabled or not galaxyVectorForce then return end
    local c = Player.Character
    if not c then return end
    local mass = 0
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then mass += p:GetMass() end
    end
    local tg = Values.DEFAULT_GRAVITY * (Values.GalaxyGravityPercent / 100)
    galaxyVectorForce.Force = Vector3.new(0, mass * (Values.DEFAULT_GRAVITY - tg) * 0.95, 0)
end
local function galaxyAdjustJump()
    pcall(function()
        local c = Player.Character
        if not c then return end
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if not galaxyModeEnabled then hum.JumpPower = galaxyOriginalJump return end
        local ratio = math.sqrt((Values.DEFAULT_GRAVITY * (Values.GalaxyGravityPercent / 100)) / Values.DEFAULT_GRAVITY)
        hum.JumpPower = galaxyOriginalJump * ratio
    end)
end
local function galaxyDoMiniHop()
    if not galaxyHopsEnabled then return end
    pcall(function()
        local c = Player.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not h or not hum then return end
        if tick() - galaxyLastHopTime < Values.HOP_COOLDOWN then return end
        galaxyLastHopTime = tick()
        if hum.FloorMaterial == Enum.Material.Air then
            h.AssemblyLinearVelocity = Vector3.new(h.AssemblyLinearVelocity.X, Values.HOP_POWER, h.AssemblyLinearVelocity.Z)
        end
    end)
end
local function startGalaxyMode()
    galaxyModeEnabled = true
    galaxyHopsEnabled = true
    galaxySetupForce()
    galaxyAdjustJump()
end
local function stopGalaxyMode()
    galaxyModeEnabled = false
    galaxyHopsEnabled = false
    if galaxyVectorForce then galaxyVectorForce:Destroy() galaxyVectorForce = nil end
    if galaxyAttachment  then galaxyAttachment:Destroy()  galaxyAttachment  = nil end
    galaxyAdjustJump()
end

RunService.Heartbeat:Connect(function()
    if galaxyHopsEnabled and galaxySpaceHeld then galaxyDoMiniHop() end
    if galaxyModeEnabled then galaxyUpdateForce() end
end)
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Space then galaxySpaceHeld = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then galaxySpaceHeld = false end
end)
Player.CharacterAdded:Connect(function()
    task.wait(1)
    if galaxyModeEnabled then galaxySetupForce() galaxyAdjustJump() end
end)

-- Optimizer + XRay
local originalTransparency = {}
local function enableOptimizer()
    if getgenv and getgenv().OPTIMIZER_ACTIVE then return end
    if getgenv then getgenv().OPTIMIZER_ACTIVE = true end
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        Lighting.GlobalShadows = false
        Lighting.Brightness = 3
        Lighting.FogEnd = 9e9
    end)
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                    obj:Destroy()
                elseif obj:IsA("BasePart") then
                    obj.CastShadow = false
                    obj.Material = Enum.Material.Plastic
                end
            end)
        end
    end)
end
local function disableOptimizer()
    if getgenv then getgenv().OPTIMIZER_ACTIVE = false end
end
local function enableXRay()
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Anchored and
               (obj.Name:lower():find("base") or (obj.Parent and obj.Parent.Name:lower():find("base"))) then
                originalTransparency[obj] = obj.LocalTransparencyModifier
                obj.LocalTransparencyModifier = 0.85
            end
        end
    end)
end
local function disableXRay()
    for part, value in pairs(originalTransparency) do
        if part then part.LocalTransparencyModifier = value end
    end
    originalTransparency = {}
end

-- Pink Moon
local pinkMoonCC       = nil
local pinkMoonBloom    = nil
local pinkMoonConn     = nil
local pinkMoonSky      = nil
local pinkMoonFOV      = nil
local pinkMoonBall     = nil

local function enablePinkMoon()
    if pinkMoonCC then return end
    pinkMoonCC = Instance.new("ColorCorrectionEffect")
    pinkMoonCC.TintColor = Color3.fromRGB(255, 140, 30)
    pinkMoonCC.Saturation = 0.6
    pinkMoonCC.Contrast   = 0.15
    pinkMoonCC.Brightness = 0.05
    pinkMoonCC.Parent = Lighting

    pinkMoonBloom = Instance.new("BloomEffect")
    pinkMoonBloom.Intensity  = 1.2
    pinkMoonBloom.Size       = 20
    pinkMoonBloom.Threshold  = 0.7
    pinkMoonBloom.Parent = Lighting

    Lighting.ExposureCompensation = 0.2
    Lighting.Ambient = Color3.fromRGB(60, 25, 5)
    Lighting.OutdoorAmbient = Color3.fromRGB(80, 35, 8)

    pinkMoonBall = Instance.new("Part")
    pinkMoonBall.Name         = "PinkMoon"
    pinkMoonBall.Anchored     = true
    pinkMoonBall.CanCollide   = false
    pinkMoonBall.CastShadow   = false
    pinkMoonBall.Massless     = true
    pinkMoonBall.Material     = Enum.Material.Neon
    pinkMoonBall.Shape        = Enum.PartType.Ball
    pinkMoonBall.Color        = Color3.fromRGB(255, 100, 0)
    pinkMoonBall.Size         = Vector3.new(60, 60, 60)
    pinkMoonBall.Position     = Vector3.new(0, 800, -500)
    pinkMoonBall.Parent       = workspace

    pinkMoonFOV = Instance.new("ImageLabel")
    pinkMoonFOV.Name               = "PinkMoonFOV"
    pinkMoonFOV.Size               = UDim2.new(1, 0, 1, 0)
    pinkMoonFOV.Position           = UDim2.new(0, 0, 0, 0)
    pinkMoonFOV.BackgroundTransparency = 1
    pinkMoonFOV.Image              = "rbxassetid://6923796549"
    pinkMoonFOV.ImageColor3        = Color3.fromRGB(255, 120, 0)
    pinkMoonFOV.ImageTransparency  = 0.55
    pinkMoonFOV.ZIndex             = 1
    pinkMoonFOV.Parent             = ScreenGui

    pinkMoonConn = RunService.Heartbeat:Connect(function()
        if not Enabled.Vibrance then return end
        local t = tick()
        local pulse = math.sin(t * 0.9) * 0.08
        if pinkMoonCC then
            pinkMoonCC.Saturation = 0.55 + pulse
            pinkMoonCC.Brightness = 0.04 + pulse * 0.3
        end
        if pinkMoonBloom then
            pinkMoonBloom.Intensity = 1.1 + math.sin(t * 1.3) * 0.3
        end
        if pinkMoonFOV then
            pinkMoonFOV.ImageTransparency = 0.52 + math.sin(t * 0.7) * 0.06
        end
        if pinkMoonBall then
            pinkMoonBall.Color = Color3.fromRGB(
                255,
                math.floor(100 + math.sin(t * 0.5) * 40),
                math.floor(0 + math.sin(t * 0.8) * 15)
            )
        end
    end)
end

local function disablePinkMoon()
    if pinkMoonConn  then pinkMoonConn:Disconnect()    pinkMoonConn  = nil end
    if pinkMoonBloom then pinkMoonBloom:Destroy()       pinkMoonBloom = nil end
    if pinkMoonCC    then pinkMoonCC:Destroy()          pinkMoonCC    = nil end
    if pinkMoonBall  then pinkMoonBall:Destroy()        pinkMoonBall  = nil end
    if pinkMoonFOV   then pinkMoonFOV:Destroy()         pinkMoonFOV   = nil end
    Lighting.ExposureCompensation = 0
    Lighting.Ambient = Color3.fromRGB(70, 70, 70)
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
end

-- Auto Steal
local StealData = {}
local stealStartTime = nil
local progressConnection = nil
local ProgressBarFill = nil
local ProgressLabel = nil
local ProgressPercentLabel = nil

local function isMyPlotByName(pn)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return false end
    local plot = plots:FindFirstChild(pn)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yb = sign:FindFirstChild("YourBase")
        if yb and yb:IsA("BillboardGui") then return yb.Enabled == true end
    end
    return false
end

local function findNearestPrompt()
    local h = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not h then return nil end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local np, nd, nn = nil, math.huge, nil
    for _, plot in ipairs(plots:GetChildren()) do
        if isMyPlotByName(plot.Name) then continue end
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if not podiums then continue end
        for _, pod in ipairs(podiums:GetChildren()) do
            pcall(function()
                local base = pod:FindFirstChild("Base")
                local spawn = base and base:FindFirstChild("Spawn")
                if spawn then
                    local dist = (spawn.Position - h.Position).Magnitude
                    if dist < nd and dist <= Values.STEAL_RADIUS then
                        local att = spawn:FindFirstChild("PromptAttachment")
                        if att then
                            for _, ch in ipairs(att:GetChildren()) do
                                if ch:IsA("ProximityPrompt") then
                                    np, nd, nn = ch, dist, pod.Name
                                    break
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
    return np, nd, nn
end

local function ResetProgressBar()
    if ProgressLabel then ProgressLabel.Text = "READY" end
    if ProgressPercentLabel then ProgressPercentLabel.Text = "" end
    if ProgressBarFill then ProgressBarFill.Size = UDim2.new(0, 0, 1, 0) end
end

local CHIRON_TEXT = "Chiron Duels"
local function getChironProgress(percent)
    local total = #CHIRON_TEXT
    local adjusted = math.min(percent * 1.5, 100)
    local chars = math.floor((adjusted / 100) * total)
    return string.sub(CHIRON_TEXT, 1, chars)
end

local function executeSteal(prompt, name)
    if isStealing then return end
    if not StealData[prompt] then
        StealData[prompt] = {hold = {}, trigger = {}, ready = true}
        pcall(function()
            if getconnections then
                for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                    if c.Function then table.insert(StealData[prompt].hold, c.Function) end
                end
                for _, c in ipairs(getconnections(prompt.Triggered)) do
                    if c.Function then table.insert(StealData[prompt].trigger, c.Function) end
                end
            end
        end)
    end
    local data = StealData[prompt]
    if not data.ready then return end
    data.ready = false
    isStealing = true
    stealStartTime = tick()
    if ProgressLabel then ProgressLabel.Text = name or "STEALING..." end
    if progressConnection then progressConnection:Disconnect() end
    progressConnection = RunService.Heartbeat:Connect(function()
        if not isStealing then progressConnection:Disconnect() return end
        local prog = math.clamp((tick() - stealStartTime) / Values.STEAL_DURATION, 0, 1)
        if ProgressBarFill then ProgressBarFill.Size = UDim2.new(prog, 0, 1, 0) end
        if ProgressPercentLabel then
            local pct = math.floor(prog * 100)
            ProgressPercentLabel.Text = getChironProgress(pct)
        end
    end)
    task.spawn(function()
        for _, f in ipairs(data.hold) do task.spawn(f) end
        task.wait(Values.STEAL_DURATION)
        for _, f in ipairs(data.trigger) do task.spawn(f) end
        if progressConnection then progressConnection:Disconnect() end
        ResetProgressBar()
        data.ready = true
        isStealing = false
    end)
end

local function startAutoSteal()
    if Connections.autoSteal then return end
    Connections.autoSteal = RunService.Heartbeat:Connect(function()
        if not Enabled.AutoSteal or isStealing then return end
        local p, _, n = findNearestPrompt()
        if p then executeSteal(p, n) end
    end)
end
local function stopAutoSteal()
    if Connections.autoSteal then Connections.autoSteal:Disconnect() Connections.autoSteal = nil end
    isStealing = false
    ResetProgressBar()
end

-- Steal Paths
local stealPathActive = false
local stealLastFlatVel = Vector3.zero
local STEAL_PATH_VELOCITY_SPEED  = 59.2
local STEAL_PATH_SECOND_SPEED    = 29.6
local STEAL_PATH_BASE_STOP       = 1.35
local STEAL_PATH_MIN_STOP        = 0.65
local STEAL_PATH_NEXT_POINT_BIAS = 0.45
local STEAL_PATH_SMOOTH_FACTOR   = 0.12

local stealPath_Right = {
    {pos = Vector3.new(-470.6, -5.9, 34.4)},
    {pos = Vector3.new(-484.2, -3.9, 21.4)},
    {pos = Vector3.new(-475.6, -5.8, 29.3)},
    {pos = Vector3.new(-473.4, -5.9, 111)}
}
local stealPath_Left = {
    {pos = Vector3.new(-474.7, -5.9, 91.0)},
    {pos = Vector3.new(-483.4, -3.9, 97.3)},
    {pos = Vector3.new(-474.7, -5.9, 91.0)},
    {pos = Vector3.new(-476.1, -5.5, 25.4)}
}

local function stealMoveToPoint(hrp, current, nextPoint, speed)
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not stealPathActive then
            conn:Disconnect()
            hrp.AssemblyLinearVelocity = Vector3.zero
            return
        end
        local pos = hrp.Position
        local target = Vector3.new(current.X, pos.Y, current.Z)
        local dir = target - pos
        local dist = dir.Magnitude
        local stopDist = math.clamp(STEAL_PATH_BASE_STOP - dist * 0.04, STEAL_PATH_MIN_STOP, STEAL_PATH_BASE_STOP)
        if dist <= stopDist then conn:Disconnect() hrp.AssemblyLinearVelocity = Vector3.zero return end
        local moveDir = dir.Unit
        if nextPoint then
            local nextDir = (Vector3.new(nextPoint.X, pos.Y, nextPoint.Z) - pos).Unit
            moveDir = (moveDir + nextDir * STEAL_PATH_NEXT_POINT_BIAS).Unit
        end
        if stealLastFlatVel.Magnitude > 0.1 then
            moveDir = (moveDir * (1 - STEAL_PATH_SMOOTH_FACTOR) + stealLastFlatVel.Unit * STEAL_PATH_SMOOTH_FACTOR).Unit
        end
        local vel = Vector3.new(moveDir.X * speed, hrp.AssemblyLinearVelocity.Y, moveDir.Z * speed)
        hrp.AssemblyLinearVelocity = vel
        stealLastFlatVel = Vector3.new(vel.X, 0, vel.Z)
    end)
    while stealPathActive and
        (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(current.X, 0, current.Z)).Magnitude > STEAL_PATH_BASE_STOP do
        RunService.Heartbeat:Wait()
    end
end

local function stealRunPath(path)
    local hrp = (Player.Character or Player.CharacterAdded:Wait()):WaitForChild("HumanoidRootPart")
    for i, p in ipairs(path) do
        if not stealPathActive then return end
        local speed = i > 2 and STEAL_PATH_SECOND_SPEED or STEAL_PATH_VELOCITY_SPEED
        local nextP = path[i + 1] and path[i + 1].pos
        stealMoveToPoint(hrp, p.pos, nextP, speed)
        if i == 2 then task.wait(0.2) else task.wait(0.01) end
    end
end

local function startStealPath(path)
    stealPathActive = true
    task.spawn(function()
        while stealPathActive do
            stealRunPath(path)
            task.wait(0.1)
        end
    end)
end
local function stopStealPath()
    stealPathActive = false
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
end

-- ============================================================
-- UI CONSTRUCTION — SINGLE VERTICAL COLUMN
-- ============================================================
if CoreGui:FindFirstChild("ChironDuels") then
    CoreGui.ChironDuels:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChironDuels"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

-- Colors
local PINK       = Color3.fromRGB(255, 120, 0)
local PINK_LIGHT = Color3.fromRGB(255, 160, 40)
local PINK_DARK  = Color3.fromRGB(200, 80, 0)
local BG_DARK    = Color3.fromRGB(18, 8, 2)
local BG_MID     = Color3.fromRGB(25, 10, 3)
local SECTION_BG = Color3.fromRGB(14, 6, 1)

-- Size constants for single-column vertical layout
local PANEL_W      = 230   -- single column width
local BANNER_H     = 28
local TOGGLE_H     = 28
local SLIDER_H     = 40
local SECTION_H    = 20
local FONT_TITLE   = 14
local FONT_SECTION = 11
local FONT_TOGGLE  = 10
local FONT_SLIDER  = 9
local TOGGLE_W     = 32
local TOGGLE_H2    = 16
local DOT_S        = 11
local PBAR_W       = 310
local PBAR_H       = 38

local function Create(className, properties, children)
    local inst = Instance.new(className)
    for k, v in pairs(properties or {}) do inst[k] = v end
    for _, child in pairs(children or {}) do child.Parent = inst end
    return inst
end

-- ── MAIN CONTAINER ─────────────────────────────────────────
local MainContainer = Create("Frame", {
    Name = "MainContainer",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 16, 0.5, -240),
    Size = UDim2.new(0, PANEL_W, 0, 480),
    Parent = ScreenGui
})

-- ── SINGLE PANEL ───────────────────────────────────────────
local PanelFrame = Create("Frame", {
    Name = "PanelFrame",
    BackgroundColor3 = BG_DARK,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    ClipsDescendants = true,
    Parent = MainContainer
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
    Create("UIStroke", {Color = PINK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
})

-- Background gradient
Create("Frame", {
    BackgroundColor3 = BG_DARK,
    Size = UDim2.new(1, 0, 1, 0),
    BorderSizePixel = 0,
    ZIndex = 0,
    Parent = PanelFrame
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
    Create("UIGradient", {
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 10, 2)),
            ColorSequenceKeypoint.new(0.4, Color3.fromRGB(35, 13, 3)),
            ColorSequenceKeypoint.new(0.8, Color3.fromRGB(45, 18, 4)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 11, 2))
        },
        Rotation = 135
    })
})

-- Particles
local particleBg = Create("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), ZIndex=1, Parent=PanelFrame})
for i = 1, 18 do
    local sz = math.random(2, 5)
    local p = Create("Frame", {
        BackgroundColor3 = math.random(1,2)==1 and PINK or PINK_LIGHT,
        BorderSizePixel = 0,
        Size = UDim2.new(0, sz, 0, sz),
        Position = UDim2.new(math.random(0,100)/100, 0, math.random(0,100)/100, 0),
        BackgroundTransparency = math.random(40,75)/100,
        ZIndex = 1,
        Parent = particleBg
    }, {Create("UICorner", {CornerRadius=UDim.new(1,0)})})
    task.spawn(function()
        while p and p.Parent do
            TweenService:Create(p, TweenInfo.new(math.random(15,35)/10, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = math.random(20,80)/100,
                Size = UDim2.new(0, math.random(2,6), 0, math.random(2,6))
            }):Play()
            task.wait(math.random(15,35)/10)
        end
    end)
end

-- ── FLOATING CH CIRCLE LOGO (outside panel, click to toggle UI) ──
local chSize = 48
local chCircle = Instance.new("Frame")
chCircle.Name = "CH_Logo"
chCircle.Size = UDim2.new(0, chSize, 0, chSize)
chCircle.Position = UDim2.new(0, 16, 0.5, -(480/2) - chSize - 10)
chCircle.BackgroundColor3 = Color3.fromRGB(20, 8, 1)
chCircle.BorderSizePixel = 0
chCircle.ZIndex = 50
chCircle.Parent = ScreenGui

Instance.new("UICorner", chCircle).CornerRadius = UDim.new(1, 0)

local chStroke = Instance.new("UIStroke", chCircle)
chStroke.Thickness = 2.5
chStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local chGrad = Instance.new("UIGradient", chStroke)
chGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 140, 0)),
    ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(255, 70,  0)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 140, 0)),
})
task.spawn(function()
    local r = 0
    while chCircle.Parent do
        r = (r + 2) % 360
        chGrad.Rotation = r
        task.wait(0.02)
    end
end)

-- "CH" text
local chText = Instance.new("TextLabel", chCircle)
chText.BackgroundTransparency = 1
chText.Size = UDim2.new(1, 0, 1, 0)
chText.Font = Enum.Font.GothamBlack
chText.Text = "CH"
chText.TextColor3 = Color3.fromRGB(255, 255, 255)
chText.TextSize = 18
chText.TextXAlignment = Enum.TextXAlignment.Center
chText.TextYAlignment = Enum.TextYAlignment.Center
chText.ZIndex = 51

-- Click to toggle UI
local chBtn = Instance.new("TextButton", chCircle)
chBtn.Size = UDim2.new(1, 0, 1, 0)
chBtn.BackgroundTransparency = 1
chBtn.Text = ""
chBtn.ZIndex = 52

local uiVisible = true
chBtn.MouseButton1Click:Connect(function()
    if cMoved then cMoved = false return end
    uiVisible = not uiVisible
    MainContainer.Visible = uiVisible
    TweenService:Create(chCircle, TweenInfo.new(0.2), {
        BackgroundColor3 = uiVisible and Color3.fromRGB(20, 8, 1) or Color3.fromRGB(50, 20, 2)
    }):Play()
end)

-- Drag support for circle logo
local cDrag, cDragStart, cDragPos, cMoved = false, nil, nil, false
chBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        cDrag = true
        cMoved = false
        cDragStart = input.Position
        cDragPos = chCircle.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then cDrag = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if cDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - cDragStart
        if delta.Magnitude > 4 then
            cMoved = true
            chCircle.Position = UDim2.new(cDragPos.X.Scale, cDragPos.X.Offset + delta.X, cDragPos.Y.Scale, cDragPos.Y.Offset + delta.Y)
        end
    end
end)
-- (drag-cancel handled inline above)

-- ── TITLE BAR ──────────────────────────────────────────────
local TitleBar = Create("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, BANNER_H),
    ZIndex = 10,
    Parent = PanelFrame
})

-- Title text (no logo inside panel now)
Create("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -36, 1, 0),
    Position = UDim2.new(0, 10, 0, 0),
    Font = Enum.Font.GothamBold,
    Text = "Chiron Duels",
    TextColor3 = PINK,
    TextSize = FONT_TITLE,
    TextStrokeTransparency = 0.3,
    TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 11,
    Parent = TitleBar
})

local CloseBtn = Create("TextButton", {
    BackgroundColor3 = PINK_DARK,
    Position = UDim2.new(1, -28, 0.5, -9),
    Size = UDim2.new(0, 18, 0, 18),
    Font = Enum.Font.GothamBold,
    Text = "X",
    TextColor3 = Color3.new(1,1,1),
    TextSize = 10,
    AutoButtonColor = false,
    ZIndex = 12,
    Parent = TitleBar
}, {
    Create("UICorner", {CornerRadius=UDim.new(1,0)}),
    Create("UIStroke", {Color=PINK_LIGHT, Thickness=2})
})
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Separator under title
Create("Frame", {
    BackgroundColor3 = PINK,
    BackgroundTransparency = 0.6,
    Position = UDim2.new(0, 8, 0, BANNER_H - 2),
    Size = UDim2.new(1, -16, 0, 1),
    BorderSizePixel = 0,
    ZIndex = 10,
    Parent = PanelFrame
})

-- Drag logic on title bar
local dragging, dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainContainer.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainContainer.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ── SCROLL CONTAINER ───────────────────────────────────────
local ScrollFrame = Create("ScrollingFrame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 6, 0, BANNER_H + 4),
    Size = UDim2.new(1, -12, 1, -(BANNER_H + 10)),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = PINK,
    BorderSizePixel = 0,
    ZIndex = 5,
    Parent = PanelFrame
}, {
    Create("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center
    })
})

local ContentLayout = ScrollFrame:FindFirstChildOfClass("UIListLayout")
ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 12)
end)

-- ============================================================
-- SECTION HEADER BUILDER
-- ============================================================
local function CreateSection(parent, title, order)
    local sec = Create("Frame", {
        BackgroundColor3 = SECTION_BG,
        Size = UDim2.new(1, -4, 0, SECTION_H),
        LayoutOrder = order or 0,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = parent
    }, {
        Create("UICorner", {CornerRadius=UDim.new(0,6)}),
        Create("UIStroke", {Color=PINK_DARK, Thickness=1.5, Transparency=0.4})
    })
    Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,-8,1,0),
        Position = UDim2.new(0,8,0,0),
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = Color3.fromRGB(200,130,255),
        TextSize = FONT_SECTION,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = sec
    })
    -- decorative line
    Create("Frame", {
        BackgroundColor3 = PINK,
        BackgroundTransparency = 0.5,
        Position = UDim2.new(0, 4, 1, -1),
        Size = UDim2.new(1, -8, 0, 1),
        BorderSizePixel = 0,
        ZIndex = 7,
        Parent = sec
    })
    return sec
end

-- ============================================================
-- TOGGLE & SLIDER BUILDERS
-- ============================================================
local VisualSetters = {}

local function CreateToggle(parent, labelText, enabledKey, callback, order)
    local row = Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(22, 9, 2),
        Size = UDim2.new(1, -4, 0, TOGGLE_H),
        LayoutOrder = order or 0,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = parent
    }, {
        Create("UICorner", {CornerRadius=UDim.new(0,8)}),
        Create("UIStroke", {Color=PINK_DARK, Thickness=1.5})
    })

    Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.6, 0, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        Font = Enum.Font.GothamBold,
        Text = labelText,
        TextColor3 = Color3.fromRGB(255, 220, 180),
        TextSize = FONT_TOGGLE,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = row
    })

    local isOn = Enabled[enabledKey] or false

    local toggleBg = Create("Frame", {
        Size = UDim2.new(0, TOGGLE_W, 0, TOGGLE_H2),
        Position = UDim2.new(1, -(TOGGLE_W + 8), 0.5, -TOGGLE_H2/2),
        BackgroundColor3 = isOn and PINK or Color3.fromRGB(55, 22, 5),
        ZIndex = 7,
        Parent = row
    }, {Create("UICorner", {CornerRadius=UDim.new(1,0)})})

    local toggleDot = Create("Frame", {
        Size = UDim2.new(0, DOT_S, 0, DOT_S),
        Position = isOn and UDim2.new(1,-(DOT_S+3),0.5,-DOT_S/2) or UDim2.new(0,3,0.5,-DOT_S/2),
        BackgroundColor3 = Color3.new(1,1,1),
        ZIndex = 8,
        Parent = toggleBg
    }, {Create("UICorner", {CornerRadius=UDim.new(1,0)})})

    local btn = Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 9,
        Parent = row
    })

    local function setVisual(state, skipCb)
        isOn = state
        TweenService:Create(toggleBg, TweenInfo.new(0.25), {BackgroundColor3 = isOn and PINK or Color3.fromRGB(50,15,32)}):Play()
        TweenService:Create(toggleDot, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
            Position = isOn and UDim2.new(1,-(DOT_S+3),0.5,-DOT_S/2) or UDim2.new(0,3,0.5,-DOT_S/2)
        }):Play()
        if not skipCb then callback(isOn) end
    end
    VisualSetters[enabledKey] = setVisual

    btn.MouseButton1Click:Connect(function()
        isOn = not isOn
        Enabled[enabledKey] = isOn
        setVisual(isOn)
    end)

    return row
end

local function CreateSlider(parent, labelText, minVal, maxVal, valueKey, callback, order)
    local container = Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(22, 9, 2),
        Size = UDim2.new(1, -4, 0, SLIDER_H),
        LayoutOrder = order or 0,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = parent
    }, {
        Create("UICorner", {CornerRadius=UDim.new(0,8)}),
        Create("UIStroke", {Color=PINK_DARK, Thickness=1.5})
    })

    local labelFrame = Create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.85, 0, 0, 16),
        Position = UDim2.new(0, 8, 0, 4),
        Font = Enum.Font.GothamBold,
        Text = labelText .. ": " .. tostring(Values[valueKey]),
        TextColor3 = Color3.fromRGB(255, 200, 150),
        TextSize = FONT_SLIDER,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = container
    })

    local sliderBg = Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(22, 9, 2),
        Position = UDim2.new(0, 8, 0, 24),
        Size = UDim2.new(1, -16, 0, 10),
        ZIndex = 7,
        Parent = container
    }, {Create("UICorner", {CornerRadius=UDim.new(1,0)})})

    local pct = math.clamp((Values[valueKey] - minVal) / (maxVal - minVal), 0, 1)

    local fill = Create("Frame", {
        BackgroundColor3 = PINK,
        Size = UDim2.new(pct, 0, 1, 0),
        ZIndex = 8,
        Parent = sliderBg
    }, {Create("UICorner", {CornerRadius=UDim.new(1,0)})})

    local knob = Create("Frame", {
        BackgroundColor3 = Color3.new(1,1,1),
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(pct, -6, 0.5, -6),
        ZIndex = 9,
        Parent = sliderBg
    }, {
        Create("UICorner", {CornerRadius=UDim.new(1,0)}),
        Create("UIStroke", {Color=PINK, Thickness=2})
    })

    local sliderBtn = Create("TextButton", {
        Size = UDim2.new(1, 0, 3, 0),
        Position = UDim2.new(0, 0, -1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 10,
        Parent = sliderBg
    })

    local draggingSlider = false
    sliderBtn.MouseButton1Down:Connect(function() draggingSlider = true end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if draggingSlider and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((inp.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            knob.Position = UDim2.new(rel, -6, 0.5, -6)
            local val = math.floor(minVal + (maxVal - minVal) * rel)
            Values[valueKey] = val
            labelFrame.Text = labelText .. ": " .. tostring(val)
            callback(val)
        end
    end)

    return container
end

-- ============================================================
-- PROGRESS BAR (bottom of screen) — glowing rotating border style
-- ============================================================
local pbar = Instance.new("Frame")
pbar.Size = UDim2.new(0, PBAR_W, 0, 44)
pbar.Position = UDim2.new(0.5, -PBAR_W/2, 1, -110)  -- moved up from -60 to -110
pbar.BackgroundColor3 = Color3.fromRGB(8, 4, 1)
pbar.BorderSizePixel = 0
pbar.ClipsDescendants = false
pbar.ZIndex = 10
pbar.Parent = ScreenGui
Instance.new("UICorner", pbar).CornerRadius = UDim.new(0, 14)

-- Rotating gradient border stroke
local pStroke = Instance.new("UIStroke", pbar)
pStroke.Thickness = 2.5
pStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local pGrad = Instance.new("UIGradient", pStroke)
pGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 130, 0)),
    ColorSequenceKeypoint.new(0.25, Color3.fromRGB(80,  30,  0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 0)),
    ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60,  20,  0)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 130, 0)),
})
task.spawn(function()
    local r = 0
    while pbar.Parent do
        r = (r + 2) % 360
        pGrad.Rotation = r
        task.wait(0.02)
    end
end)

-- "READY" / steal name label — left, vertically centred
ProgressLabel = Instance.new("TextLabel", pbar)
ProgressLabel.Size = UDim2.new(0.55, 0, 1, 0)
ProgressLabel.Position = UDim2.new(0, 14, 0, 0)
ProgressLabel.BackgroundTransparency = 1
ProgressLabel.Text = "READY"
ProgressLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ProgressLabel.Font = Enum.Font.GothamBold
ProgressLabel.TextSize = 14
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Left
ProgressLabel.ZIndex = 12

-- Steal progress text (shows during steal, centre)
ProgressPercentLabel = Instance.new("TextLabel", pbar)
ProgressPercentLabel.Size = UDim2.new(0.4, 0, 1, 0)
ProgressPercentLabel.Position = UDim2.new(0.3, 0, 0, 0)
ProgressPercentLabel.BackgroundTransparency = 1
ProgressPercentLabel.Text = ""
ProgressPercentLabel.TextColor3 = Color3.fromRGB(255, 160, 40)
ProgressPercentLabel.Font = Enum.Font.GothamBlack
ProgressPercentLabel.TextSize = 13
ProgressPercentLabel.TextXAlignment = Enum.TextXAlignment.Center
ProgressPercentLabel.ZIndex = 12

-- Small stat on the right (steal radius)
local statRadius = Instance.new("TextLabel", pbar)
statRadius.Size = UDim2.new(0, 38, 1, 0)
statRadius.Position = UDim2.new(1, -44, 0, 0)
statRadius.BackgroundTransparency = 1
statRadius.Text = tostring(Values.STEAL_RADIUS)
statRadius.TextColor3 = Color3.fromRGB(255, 140, 40)
statRadius.Font = Enum.Font.GothamBold
statRadius.TextSize = 13
statRadius.TextXAlignment = Enum.TextXAlignment.Right
statRadius.ZIndex = 12

-- Bottom fill track
local pTrack = Instance.new("Frame", pbar)
pTrack.Size = UDim2.new(1, -16, 0, 4)
pTrack.Position = UDim2.new(0, 8, 1, -7)
pTrack.BackgroundColor3 = Color3.fromRGB(25, 12, 2)
pTrack.BorderSizePixel = 0
pTrack.ZIndex = 11
Instance.new("UICorner", pTrack).CornerRadius = UDim.new(1, 0)

ProgressBarFill = Instance.new("Frame", pTrack)
ProgressBarFill.Size = UDim2.new(0, 0, 1, 0)
ProgressBarFill.BackgroundColor3 = Color3.fromRGB(255, 120, 0)
ProgressBarFill.BorderSizePixel = 0
ProgressBarFill.ZIndex = 12
Instance.new("UICorner", ProgressBarFill).CornerRadius = UDim.new(1, 0)

-- Keep stat label live-updated
RunService.Heartbeat:Connect(function()
    statRadius.Text = tostring(Values.STEAL_RADIUS)
end)

-- ============================================================
-- POPULATE SINGLE COLUMN: MOVEMENT SECTION
-- ============================================================
local order = 1

CreateSection(ScrollFrame, "⚡  MOVEMENT", order) order += 1

CreateToggle(ScrollFrame, "Speed Boost [V]", "SpeedBoost", function(s)
    Enabled.SpeedBoost = s
    if s then startSpeedBoost() else stopSpeedBoost() end
end, order) order += 1

CreateSlider(ScrollFrame, "Boost Speed", 1, 70, "BoostSpeed", function(v)
    Values.BoostSpeed = v
end, order) order += 1

CreateToggle(ScrollFrame, "Float [F]", "Float", function(s)
    Enabled.Float = s
    if s then startFloat() else stopFloat() end
end, order) order += 1

CreateToggle(ScrollFrame, "Gravity Mode", "GalaxyMode", function(s)
    Enabled.GalaxyMode = s
    if s then startGalaxyMode() else stopGalaxyMode() end
end, order) order += 1

CreateSlider(ScrollFrame, "Gravity %", 25, 130, "GalaxyGravityPercent", function(v)
    Values.GalaxyGravityPercent = v
    if galaxyModeEnabled then galaxyAdjustJump() end
end, order) order += 1

-- ============================================================
-- STEALING SECTION
-- ============================================================
CreateSection(ScrollFrame, "🐾  STEALING", order) order += 1

CreateToggle(ScrollFrame, "Auto Grab", "AutoSteal", function(s)
    Enabled.AutoSteal = s
    if s then startAutoSteal() else stopAutoSteal() end
end, order) order += 1

CreateSlider(ScrollFrame, "Steal Radius", 5, 100, "STEAL_RADIUS", function(v)
    Values.STEAL_RADIUS = v
end, order) order += 1

CreateToggle(ScrollFrame, "Speed While Stealing", "SpeedWhileStealing", function(s)
    Enabled.SpeedWhileStealing = s
    if s then startSpeedWhileStealing() else stopSpeedWhileStealing() end
end, order) order += 1

CreateSlider(ScrollFrame, "Steal Speed", 10, 35, "StealingSpeedValue", function(v)
    Values.StealingSpeedValue = v
end, order) order += 1

CreateToggle(ScrollFrame, "Auto Right Steal [E]", "AutoRight", function(s)
    Enabled.AutoRight = s
    if s then
        Enabled.AutoLeft = false
        if VisualSetters.AutoLeft then VisualSetters.AutoLeft(false, true) end
        stopStealPath()
        startStealPath(stealPath_Right)
    else
        stopStealPath()
    end
end, order) order += 1

CreateToggle(ScrollFrame, "Auto Left Steal [Q]", "AutoLeft", function(s)
    Enabled.AutoLeft = s
    if s then
        Enabled.AutoRight = false
        if VisualSetters.AutoRight then VisualSetters.AutoRight(false, true) end
        stopStealPath()
        startStealPath(stealPath_Left)
    else
        stopStealPath()
    end
end, order) order += 1

-- ============================================================
-- COMBAT SECTION
-- ============================================================
CreateSection(ScrollFrame, "⚔️  COMBAT", order) order += 1

CreateToggle(ScrollFrame, "Hit Circle", "HitCircle", function(s)
    Enabled.HitCircle = s
    if s then startHitCircle() else stopHitCircle() end
end, order) order += 1

CreateToggle(ScrollFrame, "Anti Ragdoll", "AntiRagdoll", function(s)
    Enabled.AntiRagdoll = s
    if s then startAntiRagdoll() else stopAntiRagdoll() end
end, order) order += 1

CreateToggle(ScrollFrame, "Spam Bat", "SpamBat", function(s)
    Enabled.SpamBat = s
    if s then startSpamBat() else stopSpamBat() end
end, order) order += 1

CreateToggle(ScrollFrame, "🎯 Bat Aimbot [X]", "BatAimbot", function(s)
    Enabled.BatAimbot = s
    if s then startBatAimbot() else stopBatAimbot() end
end, order) order += 1

CreateSlider(ScrollFrame, "Aimbot Speed", 10, 120, "BatAimbotSpeed", function(v)
    Values.BatAimbotSpeed = v
end, order) order += 1

CreateToggle(ScrollFrame, "Spin Bot", "Helicopter", function(s)
    Enabled.Helicopter = s
    if s then startHelicopter() else stopHelicopter() end
end, order) order += 1

CreateSlider(ScrollFrame, "Spin Speed", 5, 80, "SpinSpeed", function(v)
    Values.SpinSpeed = v
    if helicopterBAV then helicopterBAV.AngularVelocity = Vector3.new(0, v, 0) end
end, order) order += 1

CreateToggle(ScrollFrame, "Unwalk", "Unwalk", function(s)
    Enabled.Unwalk = s
    if s then startUnwalk() else stopUnwalk() end
end, order) order += 1

-- ============================================================
-- VISUAL / MISC SECTION
-- ============================================================
CreateSection(ScrollFrame, "✨  VISUAL & MISC", order) order += 1

CreateToggle(ScrollFrame, "🌙 Orange Moon", "Vibrance", function(s)
    Enabled.Vibrance = s
    if s then enablePinkMoon() else disablePinkMoon() end
end, order) order += 1

CreateToggle(ScrollFrame, "Optimizer + XRay", "OptimizerXRay", function(s)
    Enabled.OptimizerXRay = s
    if s then enableOptimizer() enableXRay() else disableOptimizer() disableXRay() end
end, order) order += 1

-- ============================================================
-- FLOATING BUTTONS (outside main UI, draggable, right side)
-- ============================================================

local function CreateFloatingButton(labelText, icon, defaultPos, enabledKey, onToggle)
    local btnFrame = Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(18, 7, 2),
        Position = defaultPos,
        Size = UDim2.new(0, 130, 0, 36),
        BorderSizePixel = 0,
        ZIndex = 20,
        Parent = ScreenGui
    }, {
        Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
        Create("UIStroke", {Color = PINK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
        Create("UIGradient", {
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 13, 3)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 7, 1))
            },
            Rotation = 90
        })
    })

    local glowFrame = Create("Frame", {
        BackgroundColor3 = PINK,
        BackgroundTransparency = 0.85,
        Size = UDim2.new(1, 6, 1, 6),
        Position = UDim2.new(0, -3, 0, -3),
        BorderSizePixel = 0,
        ZIndex = 19,
        Parent = btnFrame
    }, {Create("UICorner", {CornerRadius = UDim.new(0, 14)})})

    Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(0, 26, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = icon,
        TextColor3 = PINK,
        TextSize = 15,
        ZIndex = 22,
        Parent = btnFrame
    })

    local textLabel = Create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 36, 0, 0),
        Size = UDim2.new(1, -50, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = labelText,
        TextColor3 = Color3.fromRGB(255, 220, 180),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 22,
        Parent = btnFrame
    })

    local statusDot = Create("Frame", {
        BackgroundColor3 = Color3.fromRGB(80, 80, 80),
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(1, -14, 0.5, -4),
        BorderSizePixel = 0,
        ZIndex = 22,
        Parent = btnFrame
    }, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})

    local isActive = Enabled[enabledKey] or false

    local function updateVisual(state)
        isActive = state
        TweenService:Create(statusDot, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(80, 80, 80)
        }):Play()
        TweenService:Create(btnFrame, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Color3.fromRGB(50, 20, 3) or Color3.fromRGB(18, 7, 2)
        }):Play()
        TweenService:Create(glowFrame, TweenInfo.new(0.2), {
            BackgroundTransparency = state and 0.6 or 0.85
        }):Play()
        TweenService:Create(textLabel, TweenInfo.new(0.2), {
            TextColor3 = state and PINK or Color3.fromRGB(255, 220, 180)
        }):Play()
    end

    local clickBtn = Create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
        ZIndex = 23,
        Parent = btnFrame
    })

    local fDragging, fDragStart, fStartPos, fMoved = false, nil, nil, false
    clickBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            fDragging = true
            fMoved = false
            fDragStart = input.Position
            fStartPos = btnFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then fDragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if fDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - fDragStart
            if delta.Magnitude > 5 then
                fMoved = true
                btnFrame.Position = UDim2.new(fStartPos.X.Scale, fStartPos.X.Offset + delta.X, fStartPos.Y.Scale, fStartPos.Y.Offset + delta.Y)
            end
        end
    end)

    clickBtn.MouseButton1Click:Connect(function()
        if fMoved then return end
        isActive = not isActive
        Enabled[enabledKey] = isActive
        updateVisual(isActive)
        onToggle(isActive, updateVisual)
    end)

    task.spawn(function()
        while btnFrame and btnFrame.Parent do
            if isActive then
                TweenService:Create(glowFrame, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), {
                    BackgroundTransparency = 0.72
                }):Play()
            end
            task.wait(0.9)
        end
    end)

    return updateVisual
end

-- These are declared upfront so cross-references work
local floatBtnUpdateRight, floatBtnUpdateLeft, floatBtnUpdateFloat, floatBtnUpdateAimbot

floatBtnUpdateRight = CreateFloatingButton(
    "Auto Right [E]", "➡",
    UDim2.new(1, -144, 0.5, -64),
    "AutoRight",
    function(state)
        if state then
            Enabled.AutoLeft = false
            if VisualSetters.AutoLeft then VisualSetters.AutoLeft(false, true) end
            if floatBtnUpdateLeft then floatBtnUpdateLeft(false) end
            stopStealPath()
            startStealPath(stealPath_Right)
        else
            stopStealPath()
        end
    end
)

floatBtnUpdateLeft = CreateFloatingButton(
    "Auto Left [Q]", "⬅",
    UDim2.new(1, -144, 0.5, -22),
    "AutoLeft",
    function(state)
        if state then
            Enabled.AutoRight = false
            if VisualSetters.AutoRight then VisualSetters.AutoRight(false, true) end
            if floatBtnUpdateRight then floatBtnUpdateRight(false) end
            stopStealPath()
            startStealPath(stealPath_Left)
        else
            stopStealPath()
        end
    end
)

floatBtnUpdateFloat = CreateFloatingButton(
    "Float [F]", "🚀",
    UDim2.new(1, -144, 0.5, 20),
    "Float",
    function(state)
        Enabled.Float = state
        if VisualSetters.Float then VisualSetters.Float(state, true) end
        if state then startFloat() else stopFloat() end
    end
)

floatBtnUpdateAimbot = CreateFloatingButton(
    "Bat Aimbot [X]", "🎯",
    UDim2.new(1, -144, 0.5, 62),
    "BatAimbot",
    function(state)
        Enabled.BatAimbot = state
        if VisualSetters.BatAimbot then VisualSetters.BatAimbot(state, true) end
        if state then startBatAimbot() else stopBatAimbot() end
    end
)

-- ============================================================
-- KEYBINDS & CHARACTER RESPAWN
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    if input.KeyCode == Enum.KeyCode.Delete then
        ScreenGui:Destroy()
    elseif input.KeyCode == Enum.KeyCode.U then
        uiVisible = not uiVisible
        MainContainer.Visible = uiVisible
        TweenService:Create(chCircle, TweenInfo.new(0.2), {
            BackgroundColor3 = uiVisible and Color3.fromRGB(20, 8, 1) or Color3.fromRGB(50, 20, 2)
        }):Play()

    elseif input.KeyCode == KEYBINDS.SPEED then
        Enabled.SpeedBoost = not Enabled.SpeedBoost
        if VisualSetters.SpeedBoost then VisualSetters.SpeedBoost(Enabled.SpeedBoost) end
        if Enabled.SpeedBoost then startSpeedBoost() else stopSpeedBoost() end

    elseif input.KeyCode == KEYBINDS.FLOAT then
        Enabled.Float = not Enabled.Float
        if VisualSetters.Float then VisualSetters.Float(Enabled.Float) end
        if floatBtnUpdateFloat then floatBtnUpdateFloat(Enabled.Float) end
        if Enabled.Float then startFloat() else stopFloat() end

    elseif input.KeyCode == KEYBINDS.BATAIMBOT then
        Enabled.BatAimbot = not Enabled.BatAimbot
        if VisualSetters.BatAimbot then VisualSetters.BatAimbot(Enabled.BatAimbot) end
        if floatBtnUpdateAimbot then floatBtnUpdateAimbot(Enabled.BatAimbot) end
        if Enabled.BatAimbot then startBatAimbot() else stopBatAimbot() end

    elseif input.KeyCode == KEYBINDS.AUTORIGHT then
        Enabled.AutoRight = not Enabled.AutoRight
        if VisualSetters.AutoRight then VisualSetters.AutoRight(Enabled.AutoRight) end
        if floatBtnUpdateRight then floatBtnUpdateRight(Enabled.AutoRight) end
        if Enabled.AutoRight then
            Enabled.AutoLeft = false
            if VisualSetters.AutoLeft then VisualSetters.AutoLeft(false, true) end
            if floatBtnUpdateLeft then floatBtnUpdateLeft(false) end
            stopStealPath() startStealPath(stealPath_Right)
        else
            stopStealPath()
        end

    elseif input.KeyCode == KEYBINDS.AUTOLEFT then
        Enabled.AutoLeft = not Enabled.AutoLeft
        if VisualSetters.AutoLeft then VisualSetters.AutoLeft(Enabled.AutoLeft) end
        if floatBtnUpdateLeft then floatBtnUpdateLeft(Enabled.AutoLeft) end
        if Enabled.AutoLeft then
            Enabled.AutoRight = false
            if VisualSetters.AutoRight then VisualSetters.AutoRight(false, true) end
            if floatBtnUpdateRight then floatBtnUpdateRight(false) end
            stopStealPath() startStealPath(stealPath_Left)
        else
            stopStealPath()
        end
    end
end)

Player.CharacterAdded:Connect(function()
    task.wait(1)
    if Enabled.SpeedBoost then startSpeedBoost() end
    if Enabled.AutoSteal then startAutoSteal() end
    if Enabled.SpeedWhileStealing then startSpeedWhileStealing() end
    if Enabled.AntiRagdoll then startAntiRagdoll() end
    if Enabled.HitCircle then stopHitCircle() task.wait(0.1) startHitCircle() end
    if Enabled.SpamBat then startSpamBat() end
    if Enabled.Helicopter then startHelicopter() end
    if Enabled.BatAimbot then stopBatAimbot() task.wait(0.1) startBatAimbot() end
end)
