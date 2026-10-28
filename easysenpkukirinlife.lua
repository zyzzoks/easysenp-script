--[[
    EasySenp - Complete Scooter GUI
    Location: StarterPlayer > StarterPlayerScripts > LocalScript

    Features:
    - Refined, aligned purple GUI
    - Home and scooter customization tabs
    - Speed Changer (1–1000 KM/H)
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
panel.Size = UDim2.fromOffset(390, 650)
panel.Position = UDim2.new(0.5, -195, 0.5, -325)
panel.BackgroundColor3 = COLORS.Background
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Visible = false -- Hidden until the access key is entered
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
header.Size = UDim2.new(1, 0, 0, 80)
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
-- HOME / CUSTOMIZATION TABS
--==================================================

local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(1, -28, 0, 36)
tabBar.Position = UDim2.fromOffset(14, 88)
tabBar.BackgroundTransparency = 1
tabBar.Parent = panel

local function makeTab(name, text, x)
    local button = Instance.new("TextButton")
    button.Name = name .. "Tab"
    button.Size = UDim2.new(0.5, -4, 1, 0)
    button.Position = UDim2.new(x, x == 0 and 0 or 8, 0, 0)
    button.BackgroundColor3 = COLORS.Button
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = COLORS.Muted
    button.TextSize = 12
    button.Font = Enum.Font.GothamBold
    button.TextWrapped = false
    button.AutoButtonColor = false
    button.Parent = tabBar
    addCorner(button, 9)
    addStroke(button, COLORS.Border, 1, 0.4)
    return button
end

local homeTab = makeTab("Home", "⌂   HOME", 0)
local customizationTab = makeTab("Customization", "✦   CUSTOMIZATION", 0.5)

local homePage = Instance.new("Frame")
homePage.Name = "HomePage"
homePage.Position = UDim2.fromOffset(12, 132)
homePage.Size = UDim2.new(1, -24, 1, -144)
homePage.BackgroundTransparency = 1
homePage.Parent = panel

local customizationPage = Instance.new("ScrollingFrame")
customizationPage.Name = "CustomizationPage"
customizationPage.Position = UDim2.fromOffset(12, 132)
customizationPage.Size = UDim2.new(1, -24, 1, -144)
customizationPage.BackgroundTransparency = 1
customizationPage.BorderSizePixel = 0
customizationPage.ScrollBarThickness = 3
customizationPage.CanvasSize = UDim2.new(0, 0, 0, 326)
customizationPage.Visible = false
customizationPage.Parent = panel

local function showPage(pageName)
    local home = pageName == "Home"
    homePage.Visible = home
    customizationPage.Visible = not home
    TweenService:Create(homeTab, TweenInfo.new(0.12), {BackgroundColor3 = home and COLORS.Purple or COLORS.Button}):Play()
    homeTab.TextColor3 = home and COLORS.Text or COLORS.Muted
    TweenService:Create(customizationTab, TweenInfo.new(0.12), {BackgroundColor3 = home and COLORS.Button or COLORS.Purple}):Play()
    customizationTab.TextColor3 = home and COLORS.Muted or COLORS.Text
end

homeTab.Activated:Connect(function() showPage("Home") end)
customizationTab.Activated:Connect(function() showPage("Customization") end)
showPage("Home")

local tabDivider = Instance.new("Frame")
tabDivider.Name = "TabDivider"
tabDivider.Size = UDim2.new(1, -32, 0, 1)
tabDivider.Position = UDim2.fromOffset(16, 127)
tabDivider.BackgroundColor3 = COLORS.Border
tabDivider.BackgroundTransparency = 0.45
tabDivider.BorderSizePixel = 0
tabDivider.Parent = panel

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
    homePage,
    "SectionLabel",
    "  FEATURES",
    UDim2.new(1, -30, 0, 23),
    UDim2.fromOffset(4, 0),
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
    card.Size = UDim2.new(1, -8, 0, 67)
    card.Position = UDim2.fromOffset(4, y)
    card.BackgroundColor3 = COLORS.Panel
    card.BorderSizePixel = 0
    card.Parent = homePage

    addCorner(card, 11)
    addStroke(card, COLORS.Border, 1, 0.4)
    addGradient(card, Color3.fromRGB(38, 32, 52), Color3.fromRGB(25, 22, 35), 90)

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 4, 0, 41)
    accentBar.Position = UDim2.new(0, 0, 0.5, -20)
    accentBar.BackgroundColor3 = accent
    accentBar.BorderSizePixel = 0
    accentBar.Parent = card

    addCorner(accentBar, 3)

    local nameLabel = makeLabel(
        card,
        "FeatureTitle",
        titleText,
        UDim2.new(1, -132, 0, 25),
        UDim2.fromOffset(15, 9),
        12,
        COLORS.Text
    )
    nameLabel.Font = Enum.Font.GothamBold

    local descLabel = makeLabel(
        card,
        "FeatureDescription",
        description,
        UDim2.new(1, -132, 0, 18),
        UDim2.fromOffset(15, 36),
        9,
        COLORS.Muted
    )

    descLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local action = Instance.new("TextButton")
    action.Name = "Action"
    action.Size = UDim2.fromOffset(96, 34)
    action.Position = UDim2.new(1, -106, 0.5, -17)
    action.BackgroundColor3 = Color3.fromRGB(48, 40, 64)
    action.BorderSizePixel = 0
    action.Text = "OFF"
    action.TextColor3 = COLORS.Text
    action.TextSize = 11
    action.Font = Enum.Font.GothamBold
    action.AutoButtonColor = false
    action.Parent = card

    addCorner(action, 8)
    addStroke(action, accent, 1, 0.25)

    action.MouseEnter:Connect(function()
        if not guiDestroyed then
            TweenService:Create(action, TweenInfo.new(0.12), {
                BackgroundColor3 = Color3.fromRGB(65, 54, 86)
            }):Play()
        end
    end)
    action.MouseLeave:Connect(function()
        if not guiDestroyed then
            local active = action.Text == "ON" or action.Text == "STOP"
            TweenService:Create(action, TweenInfo.new(0.12), {
                BackgroundColor3 = active and accent:Lerp(COLORS.Background, 0.35) or Color3.fromRGB(48, 40, 64)
            }):Play()
        end
    end)

    return action
end

local wheelieButton = createFeature(
    "AutoWheelie",
    "AUTO WHEELIE",
    "Automatic wheelie control",
    31,
    COLORS.Purple
)

local attachButton = createFeature(
    "Attach",
    "ATTACH TO SCOOTER",
    "Reconnect after falling off",
    105,
    COLORS.Blue
)

local farmButton = createFeature(
    "MoneyFarm",
    "MONEY FARM",
    "Tricks, landing and repeat",
    179,
    COLORS.Green
)

--==================================================
-- SPEED CHANGER UI (HOME)
--==================================================

local speedEnabled = false
local speedKmh = 50
local speedConnection

local speedCard = Instance.new("Frame")
speedCard.Name = "SpeedChangerCard"
speedCard.Size = UDim2.new(1, -8, 0, 100)
speedCard.Position = UDim2.fromOffset(4, 253)
speedCard.BackgroundColor3 = COLORS.Panel
speedCard.BorderSizePixel = 0
speedCard.Parent = homePage
addCorner(speedCard, 11)
addStroke(speedCard, COLORS.Border, 1, 0.4)
addGradient(speedCard, Color3.fromRGB(38, 32, 52), Color3.fromRGB(25, 22, 35), 90)

local speedAccent = Instance.new("Frame")
speedAccent.Size = UDim2.new(0, 4, 0, 72)
speedAccent.Position = UDim2.new(0, 0, 0.5, -36)
speedAccent.BackgroundColor3 = Color3.fromRGB(255, 170, 70)
speedAccent.BorderSizePixel = 0
speedAccent.Parent = speedCard
addCorner(speedAccent, 3)

local speedTitle = makeLabel(
    speedCard, "SpeedChangerTitle", "SPEED CHANGER",
    UDim2.new(1, -135, 0, 23), UDim2.fromOffset(15, 7), 12, COLORS.Text
)
speedTitle.Font = Enum.Font.GothamBold

local speedDescription = makeLabel(
    speedCard, "SpeedChangerDescription", "Scooter speed • 1–1000 KM/H",
    UDim2.new(1, -135, 0, 16), UDim2.fromOffset(15, 29), 9, COLORS.Muted
)

local speedInput = Instance.new("TextBox")
speedInput.Name = "SpeedKmhInput"
speedInput.Size = UDim2.fromOffset(94, 29)
speedInput.Position = UDim2.fromOffset(15, 59)
speedInput.BackgroundColor3 = Color3.fromRGB(42, 35, 56)
speedInput.BorderSizePixel = 0
speedInput.Text = tostring(speedKmh)
speedInput.PlaceholderText = "1–1000"
speedInput.PlaceholderColor3 = COLORS.Muted
speedInput.TextColor3 = COLORS.Text
speedInput.TextSize = 12
speedInput.Font = Enum.Font.GothamBold
speedInput.ClearTextOnFocus = false
speedInput.TextXAlignment = Enum.TextXAlignment.Center
speedInput.Parent = speedCard
addCorner(speedInput, 8)
addStroke(speedInput, COLORS.Border, 1, 0.25)

local speedUnit = makeLabel(
    speedCard, "SpeedUnit", "KM/H",
    UDim2.fromOffset(44, 29), UDim2.fromOffset(113, 59), 10, COLORS.Muted
)
speedUnit.Font = Enum.Font.GothamBold

local speedButton = Instance.new("TextButton")
speedButton.Name = "SpeedChangerToggle"
speedButton.Size = UDim2.fromOffset(96, 36)
speedButton.Position = UDim2.new(1, -106, 0.5, -18)
speedButton.BackgroundColor3 = Color3.fromRGB(48, 40, 64)
speedButton.BorderSizePixel = 0
speedButton.Text = "OFF"
speedButton.TextColor3 = COLORS.Text
speedButton.TextSize = 11
speedButton.Font = Enum.Font.GothamBold
speedButton.AutoButtonColor = false
speedButton.Parent = speedCard
addCorner(speedButton, 8)
addStroke(speedButton, speedAccent.BackgroundColor3, 1, 0.25)


--==================================================
-- PANIC BUTTON
--==================================================

local panicButton = Instance.new("TextButton")
panicButton.Name = "PanicButton"
panicButton.Size = UDim2.new(1, -8, 0, 45)
panicButton.Position = UDim2.fromOffset(4, 363)
panicButton.BackgroundColor3 = Color3.fromRGB(69, 28, 42)
panicButton.BorderSizePixel = 0
panicButton.Text = "⚠   PANIC BUTTON     •     STOP ALL"
panicButton.TextColor3 = Color3.fromRGB(255, 123, 137)
panicButton.TextSize = 12
panicButton.Font = Enum.Font.GothamBold
panicButton.AutoButtonColor = false
panicButton.Parent = homePage

addCorner(panicButton, 10)
addStroke(panicButton, COLORS.Red, 1, 0.25)
addGradient(panicButton, Color3.fromRGB(91, 33, 49), Color3.fromRGB(56, 24, 37), 0)

--==================================================
-- STATUS CARD
--==================================================

local statusCard = Instance.new("Frame")
statusCard.Name = "StatusCard"
statusCard.Size = UDim2.new(1, -8, 0, 50)
statusCard.Position = UDim2.fromOffset(4, 418)
statusCard.BackgroundColor3 = Color3.fromRGB(23, 22, 32)
statusCard.BorderSizePixel = 0
statusCard.Parent = homePage

addCorner(statusCard, 10)
addStroke(statusCard, COLORS.Border, 1, 0.4)
addGradient(statusCard, Color3.fromRGB(29, 27, 41), Color3.fromRGB(21, 20, 31), 0)

local statusDot = Instance.new("Frame")
statusDot.Name = "StatusDot"
statusDot.Size = UDim2.fromOffset(8, 8)
statusDot.Position = UDim2.fromOffset(14, 21)
statusDot.BackgroundColor3 = COLORS.Green
statusDot.BorderSizePixel = 0
statusDot.Parent = statusCard

addCorner(statusDot, 8)

local statusHeading = makeLabel(
    statusCard,
    "StatusHeading",
    "STATUS",
    UDim2.fromOffset(58, 15),
    UDim2.fromOffset(31, 6),
    9,
    COLORS.Muted
)
statusHeading.Font = Enum.Font.GothamBold

local statusLabel = makeLabel(
    statusCard,
    "Status",
    "Ready",
    UDim2.new(1, -95, 0, 19),
    UDim2.fromOffset(31, 23),
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
toggleButton.Visible = false -- Hidden until the access key is entered
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
-- SPEED CHANGER LOGIC
--==================================================

local function stopSpeedChanger()
    if speedConnection then
        speedConnection:Disconnect()
        speedConnection = nil
    end
end

local function parseSpeedInput()
    local value = tonumber(speedInput.Text)
    if not value then
        speedInput.Text = tostring(speedKmh)
        setStatus("Enter a number from 1 to 1000 KM/H.", COLORS.Red)
        return false
    end

    value = math.floor(value + 0.5)
    value = math.clamp(value, 1, 1000)
    speedKmh = value
    speedInput.Text = tostring(speedKmh)
    return true
end

speedInput.FocusLost:Connect(function()
    parseSpeedInput()
    if speedEnabled then
        setStatus("Speed Changer: " .. speedKmh .. " KM/H", COLORS.Green)
    end
end)

local function startSpeedChanger()
    stopSpeedChanger()
    speedConnection = RunService.Heartbeat:Connect(function()
        if guiDestroyed or not speedEnabled then
            stopSpeedChanger()
            return
        end

        local vehicle, seat = getVehicle()
        if not vehicle or not seat then
            return
        end

        local root
        if vehicle:IsA("Model") then
            root = vehicle.PrimaryPart or seat
        elseif vehicle:IsA("BasePart") then
            root = vehicle
        end

        if not root or not root.Parent or root.Anchored then
            return
        end

        -- Roblox vehicle speed is approximated in studs/second (about 1 KM/H per stud/second).
        local velocity = root.AssemblyLinearVelocity
        local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
        local direction

        if horizontal.Magnitude > 1 then
            direction = horizontal.Unit
        else
            local look = seat.CFrame.LookVector
            direction = Vector3.new(look.X, 0, look.Z)
            if direction.Magnitude < 0.01 then
                return
            end
            direction = direction.Unit
        end

        local targetStudsPerSecond = speedKmh / 1.008
        root.AssemblyLinearVelocity = Vector3.new(
            direction.X * targetStudsPerSecond,
            velocity.Y,
            direction.Z * targetStudsPerSecond
        )
    end)
end

speedButton.Activated:Connect(function()
    if guiDestroyed then
        return
    end

    if speedEnabled then
        speedEnabled = false
        stopSpeedChanger()
        speedButton.Text = "OFF"
        speedButton.BackgroundColor3 = Color3.fromRGB(48, 40, 64)
        setStatus("Speed Changer disabled.", COLORS.Muted)
    else
        if not parseSpeedInput() then
            return
        end
        speedEnabled = true
        speedButton.Text = "ON"
        speedButton.BackgroundColor3 = Color3.fromRGB(255, 170, 70):Lerp(COLORS.Background, 0.35)
        startSpeedChanger()
        setStatus("Speed Changer enabled: " .. speedKmh .. " KM/H", COLORS.Green)
    end
end)

--==================================================
-- SCOOTER COLOR CUSTOMIZATION
--==================================================

local selectedScooterColor = Color3.fromRGB(157, 91, 255)
local rainbowEnabled = false
local rainbowConnection
local colorButtons = {}
local rainbowButton
local rainbowGradient

local function getScooterForCustomization()
    local vehicle = getVehicle()
    if vehicle then
        return vehicle
    end
    return lastVehicle
end

local function paintScooter(color, quiet)
    local vehicle = getScooterForCustomization()
    if not vehicle or not vehicle.Parent then
        if not quiet then
            setStatus("Sit on your scooter first.", COLORS.Red)
        end
        return false
    end

    local changed = 0
    local parts = {}
    if vehicle:IsA("BasePart") then
        table.insert(parts, vehicle)
    else
        for _, item in ipairs(vehicle:GetDescendants()) do
            if item:IsA("BasePart") then
                table.insert(parts, item)
            end
        end
    end

    for _, part in ipairs(parts) do
        -- Keep wheels and seats unchanged; color the scooter body/frame.
        local lowerName = part.Name:lower()
        if not lowerName:find("wheel") and not lowerName:find("tire")
            and not lowerName:find("seat") then
            part.Color = color
            changed += 1
        end
    end

    if changed == 0 then
        if not quiet then
            setStatus("No scooter body parts found.", COLORS.Red)
        end
        return false
    end

    selectedScooterColor = color
    if not quiet then
        setStatus("Scooter color changed!", color)
    end
    return true
end

local customizationTitle = makeLabel(
    customizationPage, "CustomizationTitle", "SCOOTER COLOR",
    UDim2.new(1, -8, 0, 27), UDim2.fromOffset(4, 3), 15, COLORS.Text
)
customizationTitle.Font = Enum.Font.GothamBold

local customizationDescription = makeLabel(
    customizationPage, "CustomizationDescription",
    "Choose a color for your scooter body.",
    UDim2.new(1, -8, 0, 20), UDim2.fromOffset(4, 33), 10, COLORS.Muted
)

local palette = Instance.new("Frame")
palette.Name = "ColorPalette"
palette.Size = UDim2.new(1, -8, 0, 152)
palette.Position = UDim2.fromOffset(4, 59)
palette.BackgroundTransparency = 1
palette.Parent = customizationPage

local paletteLayout = Instance.new("UIGridLayout")
paletteLayout.CellSize = UDim2.new(0.25, -8, 0, 43)
paletteLayout.CellPadding = UDim2.fromOffset(8, 8)
paletteLayout.SortOrder = Enum.SortOrder.LayoutOrder
paletteLayout.Parent = palette

local paletteColors = {
    {"Purple", Color3.fromRGB(157, 91, 255)},
    {"Blue", Color3.fromRGB(65, 145, 255)},
    {"Cyan", Color3.fromRGB(40, 220, 230)},
    {"Green", Color3.fromRGB(52, 210, 132)},
    {"Yellow", Color3.fromRGB(255, 215, 65)},
    {"Orange", Color3.fromRGB(255, 135, 55)},
    {"Red", Color3.fromRGB(255, 65, 90)},
    {"Pink", Color3.fromRGB(255, 90, 190)},
    {"White", Color3.fromRGB(245, 245, 255)},
    {"Black", Color3.fromRGB(35, 35, 42)},
    {"Gold", Color3.fromRGB(220, 165, 45)},
    {"Mint", Color3.fromRGB(125, 255, 210)},
}

for index, entry in ipairs(paletteColors) do
    local name, color = entry[1], entry[2]
    local swatch = Instance.new("TextButton")
    swatch.Name = name .. "Swatch"
    swatch.BackgroundColor3 = color
    swatch.BorderSizePixel = 0
    swatch.Text = string.upper(name)
    swatch.TextSize = 9
    swatch.Font = Enum.Font.GothamBold
    swatch.TextColor3 = (color.R + color.G + color.B) / 3 > 0.62 and Color3.fromRGB(28, 24, 35) or Color3.new(1, 1, 1)
    swatch.TextStrokeTransparency = 1
    swatch.LayoutOrder = index
    swatch.AutoButtonColor = false
    swatch.Parent = palette
    addCorner(swatch, 10)
    local swatchStroke = addStroke(swatch, Color3.fromRGB(255, 255, 255), 1, 0.55)
    swatch.Activated:Connect(function()
        rainbowEnabled = false
        if rainbowConnection then
            rainbowConnection:Disconnect()
            rainbowConnection = nil
        end
        rainbowButton.Text = "🌈 RAINBOW COLOR: OFF"
        rainbowButton.BackgroundColor3 = COLORS.Button
        rainbowGradient.Color = ColorSequence.new(Color3.fromRGB(255, 60, 90), Color3.fromRGB(100, 60, 255))
        for _, otherButton in ipairs(colorButtons) do
            if otherButton and otherButton.Parent then
                local outline = otherButton:FindFirstChildOfClass("UIStroke")
                if outline then
                    outline.Thickness = 1
                    outline.Transparency = 0.55
                end
            end
        end
        swatchStroke.Thickness = 2.5
        swatchStroke.Transparency = 0
        paintScooter(color)
    end)
    colorButtons[#colorButtons + 1] = swatch
end

rainbowButton = Instance.new("TextButton")
rainbowButton.Name = "RainbowColorButton"
rainbowButton.Size = UDim2.new(1, -8, 0, 48)
rainbowButton.Position = UDim2.fromOffset(4, 222)
rainbowButton.BackgroundColor3 = COLORS.Purple
rainbowButton.BorderSizePixel = 0
rainbowButton.Text = "🌈 RAINBOW COLOR: OFF"
rainbowButton.TextColor3 = COLORS.Text
rainbowButton.TextSize = 12
rainbowButton.Font = Enum.Font.GothamBold
rainbowButton.AutoButtonColor = false
rainbowButton.Parent = customizationPage
addCorner(rainbowButton, 11)
addStroke(rainbowButton, Color3.fromRGB(255, 255, 255), 1, 0.45)

rainbowGradient = addGradient(
    rainbowButton,
    Color3.fromRGB(255, 60, 90),
    Color3.fromRGB(100, 60, 255),
    0
)

local colorHint = makeLabel(
    customizationPage, "ColorHint",
    "Rainbow smoothly cycles through every color.",
    UDim2.new(1, -8, 0, 30), UDim2.fromOffset(4, 278), 10, COLORS.Muted
)

rainbowButton.Activated:Connect(function()
    rainbowEnabled = not rainbowEnabled

    if rainbowConnection then
        rainbowConnection:Disconnect()
        rainbowConnection = nil
    end

    if rainbowEnabled then
        rainbowButton.Text = "🌈 RAINBOW COLOR: ON"
        for _, otherButton in ipairs(colorButtons) do
            if otherButton and otherButton.Parent then
                local outline = otherButton:FindFirstChildOfClass("UIStroke")
                if outline then
                    outline.Thickness = 1
                    outline.Transparency = 0.55
                end
            end
        end
        setStatus("Rainbow color enabled.", COLORS.Purple)
        local hue = 0
        local elapsed = 0
        rainbowConnection = RunService.Heartbeat:Connect(function(dt)
            if guiDestroyed or not rainbowEnabled then
                return
            end
            hue = (hue + dt * 0.18) % 1
            local colorA = Color3.fromHSV(hue, 0.9, 1)
            local colorB = Color3.fromHSV((hue + 0.32) % 1, 0.9, 1)
            rainbowGradient.Color = ColorSequence.new(colorA, colorB)
            rainbowButton.BackgroundColor3 = colorA
            elapsed += dt
            if elapsed >= 0.12 then
                elapsed = 0
                paintScooter(colorA, true)
            end
        end)
    else
        rainbowButton.Text = "🌈 RAINBOW COLOR: OFF"
        rainbowButton.BackgroundColor3 = COLORS.Button
        rainbowGradient.Color = ColorSequence.new(
            Color3.fromRGB(255, 60, 90),
            Color3.fromRGB(100, 60, 255)
        )
        if rainbowConnection then
            rainbowConnection:Disconnect()
            rainbowConnection = nil
        end
        setStatus("Rainbow color disabled.", COLORS.Muted)
    end
end)

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
        wheelieButton.BackgroundColor3 = Color3.fromRGB(48, 40, 64)
        stopWheelie()
        setStatus("Auto Wheelie disabled.", COLORS.Muted)
    else
        autoWheelie = true
        wheelieButton.Text = "ON"
        wheelieButton.BackgroundColor3 = COLORS.Purple:Lerp(COLORS.Background, 0.35)
        startWheelie()

        if not autoWheelie then
            wheelieButton.Text = "OFF"
            wheelieButton.BackgroundColor3 = Color3.fromRGB(48, 40, 64)
        end
    end
end)

--==================================================
-- ATTACH TO SCOOTER - CONTINUOUS RE-SEAT / ANTI-FALL
--==================================================

local attachHumanoid

local function restoreAttachHumanoid()
    if attachHumanoid and attachHumanoid.Parent then
        pcall(function()
            attachHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        end)
        attachHumanoid.Jump = false
    end
    attachHumanoid = nil
end

local function stopAttach()
    if attachConnection then
        attachConnection:Disconnect()
        attachConnection = nil
    end
    restoreAttachHumanoid()
end

local function startAttach()
    stopAttach()

    local vehicle, seat = getVehicle()

    if not vehicle or not seat or not seat:IsA("BasePart") then
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
        if elapsed < 0.08 then
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
        if not humanoid or not root or humanoid.Health <= 0 then
            return
        end

        if attachHumanoid ~= humanoid then
            restoreAttachHumanoid()
            attachHumanoid = humanoid
            pcall(function()
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
            end)
        end

        -- Do not allow the jump input to eject the player from the scooter.
        humanoid.Jump = false

        local seatPart = humanoid.SeatPart
        local distance = (root.Position - lastSeat.Position).Magnitude

        -- If the seat occupant was lost or the character was thrown away,
        -- immediately move the character back and ask the seat to sit them down.
        if seatPart ~= lastSeat or distance > ATTACH_DISTANCE then
            root.CFrame = lastSeat.CFrame * CFrame.new(0, 2.5, 0)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            humanoid.Jump = false
            pcall(function()
                lastSeat:Sit(humanoid)
            end)
        end
    end)

    setStatus("Anti-fall enabled - reattaching automatically.", COLORS.Blue)
end

attachButton.Activated:Connect(function()
    if guiDestroyed then
        return
    end

    if attachEnabled then
        attachEnabled = false
        attachButton.Text = "OFF"
        attachButton.BackgroundColor3 = Color3.fromRGB(48, 40, 64)
        stopAttach()
        setStatus("Attach to Scooter disabled.", COLORS.Muted)
    else
        attachEnabled = true
        attachButton.Text = "ON"
        attachButton.BackgroundColor3 = COLORS.Blue:Lerp(COLORS.Background, 0.35)
        startAttach()
        if not attachEnabled then
            attachButton.Text = "OFF"
            attachButton.BackgroundColor3 = Color3.fromRGB(48, 40, 64)
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
        farmButton.BackgroundColor3 = Color3.fromRGB(48, 40, 64)
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
    farmButton.BackgroundColor3 = COLORS.Green:Lerp(COLORS.Background, 0.35)
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

    rainbowEnabled = false
    if rainbowConnection then
        rainbowConnection:Disconnect()
        rainbowConnection = nil
    end

    runningFarm = false
    autoWheelie = false
    attachEnabled = false
    speedEnabled = false

    farmToken += 1

    stopWheelie()
    stopAttach()
    stopSpeedChanger()

    gui:Destroy()
end)

--==================================================
-- INITIAL STATUS
--==================================================

setStatus("Ready - choose a feature.", COLORS.Green)
