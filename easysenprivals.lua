-- EasySenp - one-file LocalScript for Roblox Studio
-- Place in StarterPlayer > StarterPlayerScripts.
-- Options: Silent Aim visual target indicator, Fly, Noclip, Ragebot practice-target teleport, Panic Button.
-- Safety note: target-dependent options intentionally work only with NPC models marked/tagged PracticeDummy,
-- or models named PracticeDummy / TrainingDummy. Silent Aim is a visual indicator and does not alter weapon shots.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("EasySenpUI")
if oldGui then oldGui:Destroy() end

local COLORS = {
    Background = Color3.fromRGB(15, 13, 22),
    Panel = Color3.fromRGB(24, 21, 35),
    Header = Color3.fromRGB(91, 55, 145),
    Purple = Color3.fromRGB(151, 94, 238),
    PurpleDark = Color3.fromRGB(75, 48, 118),
    Button = Color3.fromRGB(43, 37, 60),
    Border = Color3.fromRGB(91, 76, 120),
    Text = Color3.fromRGB(246, 241, 255),
    Muted = Color3.fromRGB(177, 165, 197),
    Green = Color3.fromRGB(87, 211, 142),
    Red = Color3.fromRGB(235, 78, 101),
    Track = Color3.fromRGB(49, 42, 66),
}

local gui = Instance.new("ScreenGui")
gui.Name = "EasySenpUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local connections = {}
local destroyed = false
local states = { silentAim = false, fly = false, noclip = false, ragebot = false }
local flySpeed = 60
local currentTarget = nil
local highlight = Instance.new("Highlight")
highlight.Name = "EasySenpTargetHighlight"
highlight.FillColor = COLORS.Purple
highlight.OutlineColor = Color3.fromRGB(225, 206, 255)
highlight.FillTransparency = 0.82
highlight.OutlineTransparency = 0.05
highlight.Enabled = false
highlight.Parent = Workspace

local function keepConnection(connection)
    table.insert(connections, connection)
    return connection
end

local function corner(instance, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = instance
    return c
end

local function stroke(instance, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = instance
    return s
end

local function makeLabel(parent, name, text, size, position, textSize, color, font)
    local obj = Instance.new("TextLabel")
    obj.Name = name
    obj.Text = text
    obj.Size = size
    obj.Position = position
    obj.BackgroundTransparency = 1
    obj.TextColor3 = color or COLORS.Text
    obj.TextSize = textSize or 13
    obj.Font = font or Enum.Font.Gotham
    obj.TextXAlignment = Enum.TextXAlignment.Left
    obj.TextYAlignment = Enum.TextYAlignment.Center
    obj.Parent = parent
    return obj
end

local function makeButton(parent, name, text, size, position, color)
    local obj = Instance.new("TextButton")
    obj.Name = name
    obj.Text = text
    obj.Size = size
    obj.Position = position
    obj.BackgroundColor3 = color or COLORS.Button
    obj.BorderSizePixel = 0
    obj.TextColor3 = COLORS.Text
    obj.TextSize = 11
    obj.Font = Enum.Font.GothamBold
    obj.AutoButtonColor = true
    obj.Parent = parent
    corner(obj, 9)
    stroke(obj, COLORS.Border, 1, 0.25)
    return obj
end

-- Floating launcher button
local openButton = Instance.new("TextButton")
openButton.Name = "EasySenpToggle"
openButton.Size = UDim2.fromOffset(54, 54)
openButton.Position = UDim2.new(0, 16, 0.5, -27)
openButton.BackgroundColor3 = COLORS.Purple
openButton.BorderSizePixel = 0
openButton.Text = "ES"
openButton.TextColor3 = Color3.new(1, 1, 1)
openButton.TextSize = 19
openButton.Font = Enum.Font.GothamBlack
openButton.Parent = gui
corner(openButton, 16)
stroke(openButton, Color3.fromRGB(215, 191, 255), 1.5, 0.12)

-- Main panel
local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.fromOffset(410, 600)
panel.Position = UDim2.new(0.5, -205, 0.5, -300)
panel.BackgroundColor3 = COLORS.Background
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = gui
corner(panel, 16)
stroke(panel, COLORS.Purple, 1.4, 0.18)

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 72)
header.BackgroundColor3 = COLORS.Header
header.BorderSizePixel = 0
header.Parent = panel
corner(header, 16)

local logo = Instance.new("Frame")
logo.Size = UDim2.fromOffset(42, 42)
logo.Position = UDim2.fromOffset(15, 14)
logo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
logo.BackgroundTransparency = 0.86
logo.BorderSizePixel = 0
logo.Parent = header
corner(logo, 12)
local logoText = makeLabel(logo, "LogoText", "ES", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 16, COLORS.Text, Enum.Font.GothamBlack)
logoText.TextXAlignment = Enum.TextXAlignment.Center
makeLabel(header, "Title", "EasySenp", UDim2.new(1, -90, 0, 29), UDim2.fromOffset(68, 10), 22, COLORS.Text, Enum.Font.GothamBold)
makeLabel(header, "Subtitle", "CONTROL CENTER", UDim2.new(1, -90, 0, 18), UDim2.fromOffset(70, 39), 9, Color3.fromRGB(222, 202, 255), Enum.Font.GothamMedium)

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "OptionsScroll"
scroll.Position = UDim2.fromOffset(12, 82)
scroll.Size = UDim2.new(1, -24, 0, 397)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = COLORS.Purple
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.Parent = panel

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 9)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll

local function makeCard(name, titleText, descriptionText, height, order)
    local card = Instance.new("Frame")
    card.Name = name
    card.Size = UDim2.new(1, -5, 0, height)
    card.BackgroundColor3 = COLORS.Panel
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = scroll
    corner(card, 12)
    stroke(card, COLORS.Border, 1, 0.42)
    makeLabel(card, "Title", titleText, UDim2.new(1, -114, 0, 22), UDim2.fromOffset(13, 7), 12, COLORS.Text, Enum.Font.GothamBold)
    makeLabel(card, "Description", descriptionText, UDim2.new(1, -114, 0, 31), UDim2.fromOffset(13, 29), 9, COLORS.Muted, Enum.Font.Gotham)
    local toggle = makeButton(card, "Toggle", "OFF", UDim2.fromOffset(82, 32), UDim2.new(1, -95, 0, 13), COLORS.Button)
    return card, toggle
end

local silentCard, silentToggle = makeCard("SilentAimCard", "SILENT AIM", "Target marker inside the center circle", 72, 1)
local flyCard, flyToggle = makeCard("FlyCard", "FLY", "WASD move • Space up • Ctrl down", 106, 2)
local noclipCard, noclipToggle = makeCard("NoclipCard", "NOCLIP", "Pass through collidable map parts", 72, 3)
local rageCard, rageToggle = makeCard("RagebotCard", "RAGEBOT", "Teleport to the nearest marked target", 72, 4)

-- Fly speed slider
local speedLabel = makeLabel(flyCard, "SpeedLabel", "FLY SPEED: 60", UDim2.new(1, -30, 0, 15), UDim2.fromOffset(13, 77), 9, COLORS.Text, Enum.Font.GothamBold)
local speedTrack = Instance.new("Frame")
speedTrack.Name = "SpeedTrack"
speedTrack.Size = UDim2.new(1, -28, 0, 8)
speedTrack.Position = UDim2.fromOffset(14, 95)
speedTrack.BackgroundColor3 = COLORS.Track
speedTrack.BorderSizePixel = 0
speedTrack.Parent = flyCard
corner(speedTrack, 6)
local speedFill = Instance.new("Frame")
speedFill.Name = "SpeedFill"
speedFill.Size = UDim2.new((flySpeed - 20) / 160, 0, 1, 0)
speedFill.BackgroundColor3 = COLORS.Purple
speedFill.BorderSizePixel = 0
speedFill.Parent = speedTrack
corner(speedFill, 6)
local speedKnob = Instance.new("Frame")
speedKnob.Name = "SpeedKnob"
speedKnob.Size = UDim2.fromOffset(15, 15)
speedKnob.AnchorPoint = Vector2.new(0.5, 0.5)
speedKnob.Position = UDim2.new((flySpeed - 20) / 160, 0, 0.5, 0)
speedKnob.BackgroundColor3 = Color3.fromRGB(247, 238, 255)
speedKnob.BorderSizePixel = 0
speedKnob.Parent = speedTrack
corner(speedKnob, 9)
stroke(speedKnob, COLORS.Purple, 1.5, 0)

local statusCard = Instance.new("Frame")
statusCard.Name = "StatusCard"
statusCard.Size = UDim2.new(1, -24, 0, 34)
statusCard.Position = UDim2.fromOffset(12, 488)
statusCard.BackgroundColor3 = COLORS.Panel
statusCard.BorderSizePixel = 0
statusCard.Parent = panel
corner(statusCard, 10)
local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.fromOffset(8, 8)
statusDot.Position = UDim2.fromOffset(12, 13)
statusDot.BackgroundColor3 = COLORS.Green
statusDot.BorderSizePixel = 0
statusDot.Parent = statusCard
corner(statusDot, 8)
local status = makeLabel(statusCard, "Status", "Ready", UDim2.new(1, -35, 1, 0), UDim2.fromOffset(27, 0), 10, COLORS.Text)

local panicButton = makeButton(panel, "PanicButton", "PANIC BUTTON  •  DISABLE ALL", UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 532), COLORS.Red)
panicButton.TextSize = 12

local function setStatus(text, color)
    if destroyed or not status then return end
    status.Text = text
    statusDot.BackgroundColor3 = color or COLORS.Green
end

local function setToggleVisual(button, enabled)
    button.Text = enabled and "ON" or "OFF"
    button.BackgroundColor3 = enabled and COLORS.PurpleDark or COLORS.Button
    local uiStroke = button:FindFirstChildOfClass("UIStroke")
    if uiStroke then uiStroke.Color = enabled and COLORS.Purple or COLORS.Border end
end

-- Center circle used by Silent Aim's visual target selector
local aimCircle = Instance.new("Frame")
aimCircle.Name = "AimFOVCircle"
aimCircle.Size = UDim2.fromOffset(220, 220)
aimCircle.AnchorPoint = Vector2.new(0.5, 0.5)
aimCircle.Position = UDim2.fromScale(0.5, 0.5)
aimCircle.BackgroundTransparency = 1
aimCircle.Visible = false
aimCircle.Parent = gui
corner(aimCircle, 110)
stroke(aimCircle, COLORS.Purple, 2, 0.08)

-- Allowed target models are deliberately marked NPCs only.
local function isAllowedTarget(model)
    if not model or not model:IsA("Model") or model == player.Character then return false end
    local tagged = false
    pcall(function()
        tagged = CollectionService:HasTag(model, "PracticeDummy")
    end)
    return tagged
        or model:GetAttribute("PracticeDummy") == true
        or model.Name == "PracticeDummy"
        or model.Name == "TrainingDummy"
end

local function getAliveTargetParts(model)
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    local head = model and model:FindFirstChild("Head")
    local root = model and model:FindFirstChild("HumanoidRootPart")
    if humanoid and humanoid.Health > 0 and head and head:IsA("BasePart") and root and root:IsA("BasePart") then
        return humanoid, head, root
    end
    return nil
end

local function getAllAllowedTargets()
    local results = {}
    for _, item in ipairs(Workspace:GetDescendants()) do
        if item:IsA("Model") and isAllowedTarget(item) then
            local humanoid, head, root = getAliveTargetParts(item)
            if humanoid and head and root then
                table.insert(results, { model = item, humanoid = humanoid, head = head, root = root })
            end
        end
    end
    return results
end

local function getNearestAllowedTarget()
    local character = player.Character
    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local nearest, nearestDistance = nil, math.huge
    for _, target in ipairs(getAllAllowedTargets()) do
        local distance = (target.root.Position - myRoot.Position).Magnitude
        if distance < nearestDistance then
            nearest, nearestDistance = target, distance
        end
    end
    return nearest
end

local function getTargetInsideCircle()
    local camera = Workspace.CurrentCamera
    if not camera then return nil end
    local view = camera.ViewportSize
    local center = Vector2.new(view.X / 2, view.Y / 2)
    local radius = aimCircle.AbsoluteSize.X / 2
    local best, bestOffset = nil, math.huge
    for _, target in ipairs(getAllAllowedTargets()) do
        local point, onScreen = camera:WorldToViewportPoint(target.head.Position)
        if onScreen and point.Z > 0 then
            local offset = (Vector2.new(point.X, point.Y) - center).Magnitude
            if offset <= radius and offset < bestOffset then
                best, bestOffset = target, offset
            end
        end
    end
    return best
end

-- Flight controller. Controls are camera-relative and are local to this character.
local flyRoot = nil
local flyAttachment = nil
local flyVelocity = nil
local flyHumanoid = nil
local previousPlatformStand = false
local previousAutoRotate = true
local heldKeys = { W = false, A = false, S = false, D = false, Up = false, Down = false }

local function removeFlightParts()
    if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
    if flyAttachment then flyAttachment:Destroy(); flyAttachment = nil end
    if flyHumanoid and flyHumanoid.Parent then
        flyHumanoid.PlatformStand = previousPlatformStand
        flyHumanoid.AutoRotate = previousAutoRotate
        flyHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    flyRoot = nil
    flyHumanoid = nil
end

local function setupFlightForCharacter(character)
    removeFlightParts()
    if not states.fly or not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return end
    flyHumanoid = humanoid
    flyRoot = root
    previousPlatformStand = humanoid.PlatformStand
    previousAutoRotate = humanoid.AutoRotate
    humanoid.PlatformStand = true
    humanoid.AutoRotate = false
    flyAttachment = Instance.new("Attachment")
    flyAttachment.Name = "EasySenpFlyAttachment"
    flyAttachment.Parent = root
    flyVelocity = Instance.new("LinearVelocity")
    flyVelocity.Name = "EasySenpFlyVelocity"
    flyVelocity.Attachment0 = flyAttachment
    flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    flyVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    flyVelocity.VectorVelocity = Vector3.zero
    flyVelocity.MaxForce = 1000000
    flyVelocity.Parent = root
end

local function stopFly()
    states.fly = false
    removeFlightParts()
    setToggleVisual(flyToggle, false)
end

local function setFly(enabled)
    states.fly = enabled
    setToggleVisual(flyToggle, enabled)
    if enabled then
        setupFlightForCharacter(player.Character)
        setStatus("Fly enabled • WASD / Space / Ctrl", COLORS.Green)
    else
        removeFlightParts()
        setStatus("Fly disabled", COLORS.Muted)
    end
end

local noclipOriginal = {}
local function restoreNoclip()
    for part, oldValue in pairs(noclipOriginal) do
        if part and part.Parent then
            part.CanCollide = oldValue
        end
    end
    table.clear(noclipOriginal)
end

local function setNoclip(enabled)
    states.noclip = enabled
    setToggleVisual(noclipToggle, enabled)
    if enabled then
        setStatus("Noclip enabled", COLORS.Green)
    else
        restoreNoclip()
        setStatus("Noclip disabled", COLORS.Muted)
    end
end

local function setSilentAim(enabled)
    states.silentAim = enabled
    setToggleVisual(silentToggle, enabled)
    aimCircle.Visible = enabled
    if not enabled then
        currentTarget = nil
        highlight.Adornee = nil
        highlight.Enabled = false
    end
    setStatus(enabled and "Target indicator enabled" or "Target indicator disabled", enabled and COLORS.Green or COLORS.Muted)
end

local function setRagebot(enabled)
    states.ragebot = enabled
    setToggleVisual(rageToggle, enabled)
    if enabled then
        setStatus("Ragebot enabled • marked targets only", COLORS.Green)
        task.spawn(function()
            while states.ragebot and not destroyed do
                local target = getNearestAllowedTarget()
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if target and character and humanoid and humanoid.Health > 0 and root then
                    local targetTopY = target.head.Position.Y + target.head.Size.Y / 2
                    local offsetY = targetTopY + 0.5 + humanoid.HipHeight + root.Size.Y / 2 - target.root.Position.Y
                    local _, yaw, _ = root.CFrame:ToOrientation()
                    character:PivotTo(target.root.CFrame * CFrame.new(0, offsetY, 0) * CFrame.Angles(0, yaw, 0))
                else
                    setStatus("No marked target found", COLORS.Red)
                end
                task.wait(0.5)
            end
        end)
    else
        setStatus("Ragebot disabled", COLORS.Muted)
    end
end

silentToggle.Activated:Connect(function()
    if not destroyed then setSilentAim(not states.silentAim) end
end)
flyToggle.Activated:Connect(function()
    if not destroyed then setFly(not states.fly) end
end)
noclipToggle.Activated:Connect(function()
    if not destroyed then setNoclip(not states.noclip) end
end)
rageToggle.Activated:Connect(function()
    if not destroyed then setRagebot(not states.ragebot) end
end)

-- Fly input
local keyMap = {
    [Enum.KeyCode.W] = "W", [Enum.KeyCode.A] = "A", [Enum.KeyCode.S] = "S", [Enum.KeyCode.D] = "D",
    [Enum.KeyCode.Space] = "Up", [Enum.KeyCode.LeftControl] = "Down", [Enum.KeyCode.RightControl] = "Down",
}
keepConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    local key = keyMap[input.KeyCode]
    if key then heldKeys[key] = true end
end))
keepConnection(UserInputService.InputEnded:Connect(function(input)
    local key = keyMap[input.KeyCode]
    if key then heldKeys[key] = false end
end))

-- Fly slider: 20 to 180 studs/sec
local draggingSlider = false
local function setSpeedFromX(x)
    local trackLeft = speedTrack.AbsolutePosition.X
    local trackWidth = speedTrack.AbsoluteSize.X
    if trackWidth <= 0 then return end
    local alpha = math.clamp((x - trackLeft) / trackWidth, 0, 1)
    flySpeed = math.floor(20 + alpha * 160 + 0.5)
    speedLabel.Text = "FLY SPEED: " .. tostring(flySpeed)
    speedFill.Size = UDim2.new(alpha, 0, 1, 0)
    speedKnob.Position = UDim2.new(alpha, 0, 0.5, 0)
end
local function sliderInput(input)
    draggingSlider = true
    setSpeedFromX(input.Position.X)
end
keepConnection(speedTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliderInput(input) end
end))
keepConnection(speedKnob.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliderInput(input) end
end))
keepConnection(UserInputService.InputChanged:Connect(function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        setSpeedFromX(input.Position.X)
    end
end))
keepConnection(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSlider = false end
end))

-- Per-frame flight, noclip, and target indicator updates
keepConnection(RunService.Heartbeat:Connect(function()
    if destroyed then return end
    if states.fly then
        local character = player.Character
        if character and (not flyRoot or not flyRoot.Parent or flyRoot.Parent ~= character) then
            setupFlightForCharacter(character)
        end
        local camera = Workspace.CurrentCamera
        if flyVelocity and camera then
            local direction = Vector3.zero
            if heldKeys.W then direction += camera.CFrame.LookVector end
            if heldKeys.S then direction -= camera.CFrame.LookVector end
            if heldKeys.D then direction += camera.CFrame.RightVector end
            if heldKeys.A then direction -= camera.CFrame.RightVector end
            if heldKeys.Up then direction += Vector3.yAxis end
            if heldKeys.Down then direction -= Vector3.yAxis end
            if direction.Magnitude > 0 then direction = direction.Unit end
            flyVelocity.VectorVelocity = direction * flySpeed
        end
    end
    if states.noclip then
        local character = player.Character
        if character then
            for _, item in ipairs(character:GetDescendants()) do
                if item:IsA("BasePart") then
                    if noclipOriginal[item] == nil then noclipOriginal[item] = item.CanCollide end
                    item.CanCollide = false
                end
            end
        end
    end
end))

keepConnection(RunService.RenderStepped:Connect(function()
    if destroyed or not states.silentAim then return end
    local target = getTargetInsideCircle()
    if target then
        currentTarget = target.model
        highlight.Adornee = target.model
        highlight.Enabled = true
        setStatus("Target in circle", COLORS.Green)
    else
        currentTarget = nil
        highlight.Adornee = nil
        highlight.Enabled = false
        setStatus("Searching marked targets", COLORS.Muted)
    end
end))

keepConnection(player.CharacterAdded:Connect(function(character)
    if states.fly then
        task.wait(0.35)
        if not destroyed and states.fly then setupFlightForCharacter(character) end
    end
    if not states.noclip then table.clear(noclipOriginal) end
end))

-- Drag panel from the header
local draggingPanel = false
local dragStart, startPanelPosition, dragInput
keepConnection(header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingPanel = true
        dragStart = input.Position
        startPanelPosition = panel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then draggingPanel = false end
        end)
    end
end))
keepConnection(header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end))
keepConnection(UserInputService.InputChanged:Connect(function(input)
    if destroyed or not draggingPanel or input ~= dragInput then return end
    local delta = input.Position - dragStart
    panel.Position = UDim2.new(startPanelPosition.X.Scale, startPanelPosition.X.Offset + delta.X, startPanelPosition.Y.Scale, startPanelPosition.Y.Offset + delta.Y)
end))
keepConnection(openButton.Activated:Connect(function()
    if not destroyed then panel.Visible = not panel.Visible end
end))

local function panic()
    if destroyed then return end
    destroyed = true
    states.silentAim = false
    states.ragebot = false
    states.fly = false
    states.noclip = false
    draggingSlider = false
    draggingPanel = false
    restoreNoclip()
    removeFlightParts()
    if highlight then highlight:Destroy() end
    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    gui:Destroy()
end
panicButton.Activated:Connect(panic)

setStatus("Ready", COLORS.Green)
