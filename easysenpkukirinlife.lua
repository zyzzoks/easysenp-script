
--[[
    EasySenp - Complete Scooter GUI
    Location: StarterPlayer > StarterPlayerScripts > LocalScript

    Features:
    - Premium purple GUI
    - Auto Wheelie
    - Attach to Scooter
    - Money Farm
    - Panic Button
    - Draggable panel
    - Floating ES toggle
    - 1-second pause after landing
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--==================================================
-- CONFIGURATION
--==================================================

local WHEELIE_ANGLE = math.rad(45)
local WHEELIE_RESPONSE = 5
local WHEELIE_TORQUE = 25000

local ATTACH_CHECK_INTERVAL = 0.15
local ATTACH_DISTANCE = 5

local FARM_HEIGHT = 18
local FARM_BACKFLIPS = 5
local FARM_SPINS = 5
local BACKFLIP_DURATION = 0.22
local SPIN_DURATION = 0.18
local FARM_GROUND_PAUSE = 1

local COLORS = {
    Background = Color3.fromRGB(17, 15, 25),
    Panel = Color3.fromRGB(27, 23, 39),
    Header = Color3.fromRGB(91, 49, 155),
    Purple = Color3.fromRGB(157, 91, 255),
    Blue = Color3.fromRGB(75, 145, 255),
    Green = Color3.fromRGB(52, 210, 132),
    Red = Color3.fromRGB(255, 76, 96),
    Text = Color3.fromRGB(248, 245, 255),
    Muted = Color3.fromRGB(166, 156, 185),
    Button = Color3.fromRGB(40, 34, 54),
    Border = Color3.fromRGB(75, 61, 99),
}

--==================================================
-- STATE
--==================================================

local runningFarm = false
local autoWheelie = false
local attachEnabled = false
local guiDestroyed = false

local farmToken = 0

local wheelieConnection
local wheelieAttachment
local wheelieAlign
local wheelieRoot

local attachConnection
local lastVehicle
local lastSeat

--==================================================
-- REMOVE OLD GUI
--==================================================

local oldGui = playerGui:FindFirstChild("EasySenpGui")
if oldGui then
    oldGui:Destroy()
end

--==================================================
-- GUI HELPERS
--==================================================

local function addCorner(object, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = object
    return c
end

local function addStroke(object, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = object
    return s
end

local function addGradient(object, firstColor, secondColor, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, firstColor),
        ColorSequenceKeypoint.new(1, secondColor),
    })
    g.Rotation = rotation or 0
    g.Parent = object
    return g
end

local function makeLabel(parent, name, text, size, position, textSize, color)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Size = size
    label.Position = position
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or COLORS.Text
    label.TextSize = textSize or 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local function makeButton(parent, name, text, position, size, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = color or COLORS.Button
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = COLORS.Text
    button.TextSize = 13
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = false
    button.Parent = parent

    addCorner(button, 10)

    local buttonStroke = addStroke(
        button,
        color or COLORS.Border,
        1,
        0.35
    )

    button.MouseEnter:Connect(function()
        if not guiDestroyed then
            TweenService:Create(
                button,
                TweenInfo.new(0.15),
                {BackgroundColor3 = (color or COLORS.Button):Lerp(
                    Color3.new(1, 1, 1), 0.09
                )}
            ):Play()
        end
    end)

    button.MouseLeave:Connect(function()
        if not guiDestroyed then
            TweenService:Create(
                button,
                TweenInfo.new(0.15),
                {BackgroundColor3 = color or COLORS.Button}
            ):Play()
        end
    end)

    return button, buttonStroke
end

--==================================================
-- MAIN GUI
--==================================================

local gui = Instance.new("ScreenGui")
gui.Name = "EasySenpGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.fromOffset(340, 435)
panel.Position = UDim2.new(0.5, -170, 0.5, -217)
panel.BackgroundColor3 = COLORS.Background
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = gui

addCorner(panel, 17)
addStroke(panel, COLORS.Purple, 1.5, 0.12)
addGradient(
    panel,
    Color3.fromRGB(31, 24, 46),
    Color3.fromRGB(15, 14, 22),
    90
)

--==================================================
-- HEADER
--==================================================

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 79)
header.BackgroundColor3 = COLORS.Header
header.BorderSizePixel = 0
header.Parent = panel

addCorner(header, 17)
addGradient(
    header,
    Color3.fromRGB(119, 66, 197),
    Color3.fromRGB(62, 39, 104),
    0
)

local logo = Instance.new("Frame")
logo.Size = UDim2.fromOffset(43, 43)
logo.Position = UDim2.fromOffset(16, 17)
logo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
logo.BackgroundTransparency = 0.85
logo.BorderSizePixel = 0
logo.Parent = header

addCorner(logo, 12)
addStroke(logo, Color3.fromRGB(220, 197, 255), 1, 0.4)

local logoText = makeLabel(
    logo,
    "LogoText",
    "ES",
    UDim2.fromScale(1, 1),
    UDim2.fromOffset(0, 0),
    17,
    Color3.new(1, 1, 1)
)
logoText.Font = Enum.Font.GothamBlack
logoText.TextXAlignment = Enum.TextXAlignment.Center

local title = makeLabel(
    header,
    "Title",
    "EasySenp",
    UDim2.new(1, -85, 0, 30),
    UDim2.fromOffset(70, 13),
    23,
    COLORS.Text
)
title.Font = Enum.Font.GothamBold

local subtitle = makeLabel(
    header,
    "Subtitle",
    "SCOOTER CONTROL CENTER",
    UDim2.new(1, -85, 0, 20),
    UDim2.fromOffset(72, 43),
    9,
    Color3.fromRGB(222, 202, 255)
)
subtitle.Font = Enum.Font.GothamMedium

--==================================================
-- DRAGGING
--==================================================

local dragging = false
local dragStart
local startPosition
local dragInput

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = panel.Position
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        local delta = input.Position - dragStart

        panel.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        dragInput = nil
    end
end)

--==================================================
-- SECTION LABEL
--==================================================

local sectionLabel = makeLabel(
    panel,
    "SectionLabel",
    "  FEATURES",
    UDim2.new(1, -30, 0, 23),
    UDim2.fromOffset(16, 87),
    10,
    COLORS.Muted
)
sectionLabel.Font = Enum.Font.GothamBold

--==================================================
-- FEATURE BUTTONS
--==================================================

local function createFeature(name, titleText, description, y, accent)
    local card = Instance.new("Frame")
    card.Name = name .. "Card"
    card.Size = UDim2.new(1, -30, 0, 59)
    card.Position = UDim2.fromOffset(15, y)
    card.BackgroundColor3 = COLORS.Panel
    card.BorderSizePixel = 0
    card.Parent = panel

    addCorner(card, 11)
    addStroke(card, COLORS.Border, 1, 0.45)

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 4, 0, 34)
    accentBar.Position = UDim2.new(0, 0, 0.5, -17)
    accentBar.BackgroundColor3 = accent
    accentBar.BorderSizePixel = 0
    accentBar.Parent = card

    addCorner(accentBar, 3)

    local nameLabel = makeLabel(
        card,
        "FeatureTitle",
        titleText,
        UDim2.new(1, -128, 0, 23),
        UDim2.fromOffset(14, 8),
        12,
        COLORS.Text
    )
    nameLabel.Font = Enum.Font.GothamBold

    local descLabel = makeLabel(
        card,
        "FeatureDescription",
        description,
        UDim2.new(1, -128, 0, 18),
        UDim2.fromOffset(14, 31),
        9,
        COLORS.Muted
    )

    descLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local action = Instance.new("TextButton")
    action.Name = "Action"
    action.Size = UDim2.fromOffset(104, 32)
    action.Position = UDim2.new(1, -115, 0.5, -16)
    action.BackgroundColor3 = Color3.fromRGB(48, 40, 64)
    action.BorderSizePixel = 0
    action.Text = "OFF"
    action.TextColor3 = COLORS.Text
    action.TextSize = 11
    action.Font = Enum.Font.GothamBold
    action.AutoButtonColor = false
    action.Parent = card

    addCorner(action, 8)
    addStroke(action, accent, 1, 0.4)

    return action
end

local wheelieButton = createFeature(
    "AutoWheelie",
    "AUTO WHEELIE",
    "Automatic wheelie control",
    116,
    COLORS.Purple
)

local attachButton = createFeature(
    "Attach",
    "ATTACH TO SCOOTER",
    "Reconnect after falling off",
    183,
    COLORS.Blue
)

local farmButton = createFeature(
    "MoneyFarm",
    "MONEY FARM",
    "Tricks, landing and repeat",
    250,
    COLORS.Green
)

--==================================================
-- PANIC BUTTON
--==================================================

local panicButton = Instance.new("TextButton")
panicButton.Name = "PanicButton"
panicButton.Size = UDim2.new(1, -30, 0, 43)
panicButton.Position = UDim2.fromOffset(15, 318)
panicButton.BackgroundColor3 = Color3.fromRGB(69, 28, 42)
panicButton.BorderSizePixel = 0
panicButton.Text = "  PANIC BUTTON     STOP ALL"
panicButton.TextColor3 = Color3.fromRGB(255, 123, 137)
panicButton.TextSize = 12
panicButton.Font = Enum.Font.GothamBold
panicButton.AutoButtonColor = false
panicButton.Parent = panel

addCorner(panicButton, 10)
addStroke(panicButton, COLORS.Red, 1, 0.25)

--==================================================
-- STATUS CARD
--==================================================

local statusCard = Instance.new("Frame")
statusCard.Name = "StatusCard"
statusCard.Size = UDim2.new(1, -30, 0, 47)
statusCard.Position = UDim2.fromOffset(15, 370)
statusCard.BackgroundColor3 = Color3.fromRGB(23, 22, 32)
statusCard.BorderSizePixel = 0
statusCard.Parent = panel

addCorner(statusCard, 10)
addStroke(statusCard, COLORS.Border, 1, 0.45)

local statusDot = Instance.new("Frame")
statusDot.Name = "StatusDot"
statusDot.Size = UDim2.fromOffset(8, 8)
statusDot.Position = UDim2.fromOffset(12, 19)
statusDot.BackgroundColor3 = COLORS.Green
statusDot.BorderSizePixel = 0
statusDot.Parent = statusCard

addCorner(statusDot, 8)

local statusHeading = makeLabel(
    statusCard,
    "StatusHeading",
    "STATUS",
    UDim2.fromOffset(58, 15),
    UDim2.fromOffset(28, 5),
    9,
    COLORS.Muted
)
statusHeading.Font = Enum.Font.GothamBold

local statusLabel = makeLabel(
    statusCard,
    "Status",
    "Ready",
    UDim2.new(1, -95, 0, 19),
    UDim2.fromOffset(28, 21),
    11,
    COLORS.Text
)
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd

local function setStatus(message, color)
    if guiDestroyed then
        return
    end

    statusLabel.Text = message

    if color then
        statusDot.BackgroundColor3 = color
    end
end

--==================================================
-- FLOATING ES BUTTON
--==================================================

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleGuiButton"
toggleButton.Size = UDim2.fromOffset(53, 53)
toggleButton.Position = UDim2.new(0, 15, 0.5, -26)
toggleButton.BackgroundColor3 = COLORS.Purple
toggleButton.BorderSizePixel = 0
toggleButton.Text = "ES"
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.TextSize = 19
toggleButton.Font = Enum.Font.GothamBlack
toggleButton.AutoButtonColor = false
toggleButton.Parent = gui

addCorner(toggleButton, 15)
addStroke(toggleButton, Color3.fromRGB(213, 184, 255), 1.5, 0.15)
addGradient(
    toggleButton,
    Color3.fromRGB(157, 91, 255),
    Color3.fromRGB(79, 45, 139),
    45
)

toggleButton.Activated:Connect(function()
    if guiDestroyed then
        return
    end

    panel.Visible = not panel.Visible
end)

--==================================================
-- VEHICLE HELPERS
--==================================================

local function getVehicle()
    local character = player.Character
    if not character then
        return nil, nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or not humanoid.SeatPart then
        return nil, nil
    end

    local seat = humanoid.SeatPart
    local vehicle = seat:FindFirstAncestorOfClass("Model")

    return vehicle or seat, seat
end

local function getRootPart(vehicle, seat)
    if seat and seat:IsA("BasePart") then
        return seat
    end

    if not vehicle then
        return nil
    end

    if vehicle:IsA("BasePart") then
        return vehicle
    end

    if vehicle:IsA("Model") then
        return vehicle.PrimaryPart
            or vehicle:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local function getPivot(vehicle)
    if not vehicle or not vehicle.Parent then
        return nil
    end

    if vehicle:IsA("Model") then
        return vehicle:GetPivot()
    elseif vehicle:IsA("BasePart") then
        return vehicle.CFrame
    end

    return nil
end

local function setPivot(vehicle, cf)
    if not vehicle or not vehicle.Parent then
        return
    end

    if vehicle:IsA("Model") then
        vehicle:PivotTo(cf)
    elseif vehicle:IsA("BasePart") then
        vehicle.CFrame = cf
    end
end

--==================================================
-- AUTO WHEELIE
--==================================================

local function stopWheelie()
    if wheelieConnection then
        wheelieConnection:Disconnect()
        wheelieConnection = nil
    end

    if wheelieAlign then
        wheelieAlign:Destroy()
        wheelieAlign = nil
    end

    if wheelieAttachment then
        wheelieAttachment:Destroy()
        wheelieAttachment = nil
    end

    wheelieRoot = nil
end

local function startWheelie()
    stopWheelie()

    local vehicle, seat = getVehicle()

    if not vehicle then
        autoWheelie = false
        wheelieButton.Text = "OFF"
        setStatus("Sit on your scooter first.", COLORS.Red)
        return
    end

    local root = getRootPart(vehicle, seat)

    if not root or root.Anchored then
        autoWheelie = false
        wheelieButton.Text = "OFF"
        setStatus("Cannot control this scooter.", COLORS.Red)
        return
    end

    wheelieRoot = root

    local attachment = Instance.new("Attachment")
    attachment.Name = "EasySenpWheelieAttachment"
    attachment.Parent = root
    wheelieAttachment = attachment

    local align = Instance.new("AlignOrientation")
    align.Name = "EasySenpWheelieAlign"
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.Attachment0 = attachment
    align.RigidityEnabled = false
    align.Responsiveness = WHEELIE_RESPONSE
    align.MaxTorque = WHEELIE_TORQUE
    align.MaxAngularVelocity = 4
    align.Parent = root
    wheelieAlign = align

    wheelieConnection = RunService.Heartbeat:Connect(function()
        if guiDestroyed or not autoWheelie then
            stopWheelie()
            return
        end

        if not wheelieRoot or not wheelieRoot.Parent then
            stopWheelie()
            autoWheelie = false
            wheelieButton.Text = "OFF"
            setStatus("Scooter not found.", COLORS.Red)
            return
        end

        local look = wheelieRoot.CFrame.LookVector
        local flatLook = Vector3.new(look.X, 0, look.Z)

        if flatLook.Magnitude > 0.001 then
            flatLook = flatLook.Unit

            local yaw = math.atan2(-flatLook.X, -flatLook.Z)
            local heading = CFrame.Angles(0, yaw, 0)

            align.CFrame = heading.Rotation
                * CFrame.Angles(WHEELIE_ANGLE, 0, 0)
        end
    end)

    setStatus("Auto Wheelie enabled.", COLORS.Green)
end

wheelieButton.Activated:Connect(function()
    if guiDestroyed then
        return
    end

    if autoWheelie then
        autoWheelie = false
        wheelieButton.Text = "OFF"
        stopWheelie()
        setStatus("Auto Wheelie disabled.", COLORS.Muted)
    else
        autoWheelie = true
        wheelieButton.Text = "ON"
        startWheelie()

        if not autoWheelie then
            wheelieButton.Text = "OFF"
        end
    end
end)

--==================================================
-- ATTACH TO SCOOTER
--==================================================

local function stopAttach()
    if attachConnection then
        attachConnection:Disconnect()
        attachConnection = nil
    end
end

local function startAttach()
    stopAttach()

    local vehicle, seat = getVehicle()

    if not vehicle or not seat then
        attachEnabled = false
        attachButton.Text = "OFF"
        setStatus("Sit on your scooter first.", COLORS.Red)
        return
    end

    lastVehicle = vehicle
    lastSeat = seat

    local elapsed = 0

    attachConnection = RunService.Heartbeat:Connect(function(dt)
        if guiDestroyed or not attachEnabled then
            stopAttach()
            return
        end

        elapsed += dt

        if elapsed < ATTACH_CHECK_INTERVAL then
            return
        end

        elapsed = 0

        if not lastVehicle or not lastVehicle.Parent
            or not lastSeat or not lastSeat.Parent then

            attachEnabled = false
            attachButton.Text = "OFF"
            setStatus("Scooter unavailable.", COLORS.Red)
            stopAttach()
            return
        end

        local character = player.Character
        if not character then
            return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")

        if not humanoid or not root then
            return
        end

        if humanoid.Health <= 0 or humanoid.SeatPart == lastSeat then
            return
        end

        local scooterPivot = getPivot(lastVehicle)
        if not scooterPivot then
            return
        end

        local distance = (root.Position - scooterPivot.Position).Magnitude

        if distance > ATTACH_DISTANCE or humanoid.SeatPart == nil then
            -- Move back to the remembered seat.
            root.CFrame = lastSeat.CFrame * CFrame.new(0, 2.5, 0)

            task.wait(0.05)

            if not guiDestroyed and attachEnabled
                and humanoid.Parent and lastSeat.Parent
                and humanoid.Health > 0 then

                lastSeat:Sit(humanoid)
            end
        end
    end)

    setStatus("Attach to Scooter enabled.", COLORS.Blue)
end

attachButton.Activated:Connect(function()
    if guiDestroyed then
        return
    end

    if attachEnabled then
        attachEnabled = false
        attachButton.Text = "OFF"
        stopAttach()

        lastVehicle = nil
        lastSeat = nil

        setStatus("Attach to Scooter disabled.", COLORS.Muted)
    else
        attachEnabled = true
        attachButton.Text = "ON"
        startAttach()

        if not attachEnabled then
            attachButton.Text = "OFF"
        end
    end
end)

--==================================================
-- MONEY FARM HELPERS
--==================================================

local function getGroundY(vehicle)
    local pivot = getPivot(vehicle)
    if not pivot then
        return nil
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        vehicle,
        player.Character
    }

    local result = workspace:Raycast(
        pivot.Position + Vector3.new(0, 5, 0),
        Vector3.new(0, -500, 0),
        params
    )

    return result and result.Position.Y or pivot.Position.Y
end

local function animateRotation(vehicle, rotation, duration, token)
    local startCF = getPivot(vehicle)

    if not startCF then
        return false
    end

    local elapsed = 0

    while elapsed < duration do
        if not runningFarm or farmToken ~= token or guiDestroyed then
            return false
        end

        if not vehicle.Parent then
            return false
        end

        local dt = RunService.Heartbeat:Wait()
        elapsed += dt

        local alpha = math.clamp(elapsed / duration, 0, 1)

        setPivot(
            vehicle,
            startCF * CFrame.Angles(rotation * alpha, 0, 0)
        )
    end

    return true
end

local function animateSpin(vehicle, duration, token)
    local startCF = getPivot(vehicle)

    if not startCF then
        return false
    end

    local elapsed = 0

    while elapsed < duration do
        if not runningFarm or farmToken ~= token or guiDestroyed then
            return false
        end

        if not vehicle.Parent then
            return false
        end

        local dt = RunService.Heartbeat:Wait()
        elapsed += dt

        local alpha = math.clamp(elapsed / duration, 0, 1)

        setPivot(
            vehicle,
            startCF * CFrame.Angles(0, math.rad(360) * alpha, 0)
        )
    end

    return true
end

local function waitOnGround(seconds, token)
    local elapsed = 0

    while elapsed < seconds do
        if not runningFarm or farmToken ~= token or guiDestroyed then
            return false
        end

        elapsed += RunService.Heartbeat:Wait()
    end

    return true
end

--==================================================
-- MONEY FARM CYCLE
--==================================================

local function doFarmCycle(token)
    local vehicle = getVehicle()

    if not vehicle then
        setStatus("Sit on your scooter to start.", COLORS.Red)
        return false
    end

    local groundY = getGroundY(vehicle)
    local startCF = getPivot(vehicle)

    if not groundY or not startCF then
        setStatus("Cannot find scooter position.", COLORS.Red)
        return false
    end

    -- Avoid competing orientation controls during tricks.
    stopWheelie()

    setStatus("Launching scooter...", COLORS.Green)

    -- Launch upwards.
    setPivot(
        vehicle,
        startCF + Vector3.new(0, FARM_HEIGHT, 0)
    )

    if not waitOnGround(0.1, token) then
        return false
    end

    -- Five backflips.
    for i = 1, FARM_BACKFLIPS do
        if not runningFarm or farmToken ~= token or guiDestroyed then
            return false
        end

        setStatus(
            "Backflip " .. i .. "/" .. FARM_BACKFLIPS,
            COLORS.Purple
        )

        if not animateRotation(
            vehicle,
            math.rad(360),
            BACKFLIP_DURATION,
            token
        ) then
            return false
        end
    end

    -- Five 360-degree spins.
    for i = 1, FARM_SPINS do
        if not runningFarm or farmToken ~= token or guiDestroyed then
            return false
        end

        setStatus(
            "360 Spin " .. i .. "/" .. FARM_SPINS,
            COLORS.Blue
        )

        if not animateSpin(vehicle, SPIN_DURATION, token) then
            return false
        end
    end

    if not runningFarm or farmToken ~= token or guiDestroyed then
        return false
    end

    -- Land near the ground and preserve the current heading.
    local current = getPivot(vehicle)

    if current then
        local _, yaw, _ = current:ToOrientation()

        setPivot(
            vehicle,
            CFrame.new(
                current.Position.X,
                groundY + 3,
                current.Position.Z
            ) * CFrame.Angles(0, yaw, 0)
        )
    end

    setStatus("Landed! Waiting 1 second...", COLORS.Green)

    -- Wait exactly one second before the next cycle.
    if not waitOnGround(FARM_GROUND_PAUSE, token) then
        return false
    end

    return true
end

--==================================================
-- MONEY FARM BUTTON
--==================================================

farmButton.Activated:Connect(function()
    if guiDestroyed then
        return
    end

    if runningFarm then
        runningFarm = false
        farmToken += 1

        farmButton.Text = "START"
        setStatus("Money Farm stopped.", COLORS.Muted)
        return
    end

    local vehicle = getVehicle()

    if not vehicle then
        setStatus("Sit on your scooter first.", COLORS.Red)
        return
    end

    runningFarm = true
    farmToken += 1

    local token = farmToken

    farmButton.Text = "STOP"
    setStatus("Money Farm starting...", COLORS.Green)

    task.spawn(function()
        while runningFarm and farmToken == token and not guiDestroyed do
            local success = doFarmCycle(token)

            if not success then
                if not runningFarm or farmToken ~= token or guiDestroyed then
                    break
                end

                -- Avoid repeatedly retrying too quickly.
                task.wait(0.5)
            end

            if runningFarm and farmToken == token and not guiDestroyed then
                task.wait(0.1)
            end
        end
    end)
end)

--==================================================
-- PANIC BUTTON
--==================================================

panicButton.Activated:Connect(function()
    if guiDestroyed then
        return
    end

    guiDestroyed = true

    runningFarm = false
    autoWheelie = false
    attachEnabled = false

    farmToken += 1

    stopWheelie()
    stopAttach()

    gui:Destroy()
end)

--==================================================
-- INITIAL STATUS
--==================================================

setStatus("Ready - choose a feature.", COLORS.Green)
