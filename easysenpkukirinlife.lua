--[[
    EasySenp - Complete Scooter GUI
    Location: StarterPlayer > StarterPlayerScripts > LocalScript

    Features:
    - Halloween GUI theme (pumpkin orange, violet and midnight black)
    - Home, Scooter Colors and Custom Helmets tabs
    - Speed Changer slider (1–1000 KM/H)
    - Auto Wheelie continuously holds the front end up with a 1-90 degree slider (no AlignOrientation)
- Rounded red/blue Fullface helmets; hair is hidden while equipped
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

local wheelieAngleDegrees = 45 -- Slider range: 1 to 90 degrees
-- Stable closed-loop pitch control using AssemblyAngularVelocity only.
-- No AlignOrientation, Attachment, PivotTo loop, or alignment constraint.
local WHEELIE_P_GAIN = 13.5
local WHEELIE_D_GAIN = 3.8
local WHEELIE_MAX_ANGULAR_SPEED = math.rad(230)
local WHEELIE_MAX_TARGET_PITCH = math.rad(88.5)

local ATTACH_CHECK_INTERVAL = 0.15
local ATTACH_DISTANCE = 5

local FARM_HEIGHT = 18
local FARM_BACKFLIPS = 5
local FARM_SPINS = 5
local BACKFLIP_DURATION = 0.22
local SPIN_DURATION = 0.18
local FARM_GROUND_PAUSE = 1

local COLORS = {
    -- Halloween palette: midnight black, pumpkin orange, violet and ghost-lime.
    Background = Color3.fromRGB(14, 10, 15),
    Panel = Color3.fromRGB(30, 18, 27),
    Header = Color3.fromRGB(116, 43, 14),
    Purple = Color3.fromRGB(255, 119, 26),
    Blue = Color3.fromRGB(151, 81, 226),
    Green = Color3.fromRGB(169, 211, 76),
    Red = Color3.fromRGB(235, 72, 42),
    Text = Color3.fromRGB(255, 244, 225),
    Muted = Color3.fromRGB(188, 166, 173),
    Button = Color3.fromRGB(48, 29, 38),
    Border = Color3.fromRGB(111, 66, 77),
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
local wheelieRoot
local wheelieVehicle
local wheelieSeat
local wheelieBasePitch

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
panel.Size = UDim2.fromOffset(390, 670)
panel.Position = UDim2.new(0.5, -195, 0.5, -335)
panel.BackgroundColor3 = COLORS.Background
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Visible = true -- Key system removed; show the main panel immediately
panel.Parent = gui

addCorner(panel, 17)
addStroke(panel, COLORS.Purple, 1.5, 0.12)
addGradient(
    panel,
    Color3.fromRGB(51, 24, 28),
    Color3.fromRGB(16, 10, 15),
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
    Color3.fromRGB(194, 79, 19),
    Color3.fromRGB(94, 36, 73),
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
addStroke(logo, Color3.fromRGB(255, 201, 151), 1, 0.4)

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
    "🎃 HALLOWEEN SCOOTER CONTROL 🎃",
    UDim2.new(1, -85, 0, 20),
    UDim2.fromOffset(72, 43),
    9,
    Color3.fromRGB(255, 210, 170)
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
customizationPage.CanvasSize = UDim2.new(0, 0, 0, 390)
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

local function createFeature(name, titleText, description, y, accent, cardHeight)
    local card = Instance.new("Frame")
    card.Name = name .. "Card"
    card.Size = UDim2.new(1, -8, 0, cardHeight or 67)
    card.Position = UDim2.fromOffset(4, y)
    card.BackgroundColor3 = COLORS.Panel
    card.BorderSizePixel = 0
    card.Parent = homePage

    addCorner(card, 11)
    addStroke(card, COLORS.Border, 1, 0.4)
    addGradient(card, Color3.fromRGB(48, 29, 34), Color3.fromRGB(23, 13, 18), 90)

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
    action.BackgroundColor3 = Color3.fromRGB(58, 31, 26)
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
                BackgroundColor3 = Color3.fromRGB(91, 47, 35)
            }):Play()
        end
    end)
    action.MouseLeave:Connect(function()
        if not guiDestroyed then
            local active = action.Text == "ON" or action.Text == "STOP"
            TweenService:Create(action, TweenInfo.new(0.12), {
                BackgroundColor3 = active and accent:Lerp(COLORS.Background, 0.35) or Color3.fromRGB(58, 31, 26)
            }):Play()
        end
    end)

    return action, card
end

local wheelieButton, wheelieCard = createFeature(
    "AutoWheelie",
    "AUTO WHEELIE",
    "Lift the front wheel while seated",
    31,
    COLORS.Purple,
    112
)

local attachButton = createFeature(
    "Attach",
    "ATTACH TO SCOOTER",
    "Reconnect after falling off",
    151,
    COLORS.Blue
)

local farmButton = createFeature(
    "MoneyFarm",
    "MONEY FARM",
    "Tricks, landing and repeat",
    225,
    COLORS.Green
)

--==================================================
-- AUTO WHEELIE ANGLE SLIDER (1-90 DEGREES)
--==================================================

local wheelieSliderDragging = false
local wheelieSliderInputChanged
local wheelieSliderInputEnded
local setStatus -- Defined below; forward-declared for the slider callback.

local wheelieAngleLabel = makeLabel(
    wheelieCard,
    "WheelieAngleLabel",
    "FRONT WHEEL ANGLE: " .. tostring(wheelieAngleDegrees) .. "°",
    UDim2.new(1, -132, 0, 16),
    UDim2.fromOffset(15, 65),
    9,
    Color3.fromRGB(255, 183, 105)
)
wheelieAngleLabel.Font = Enum.Font.GothamBold

local wheelieAngleTrack = Instance.new("Frame")
wheelieAngleTrack.Name = "WheelieAngleSliderTrack"
wheelieAngleTrack.Size = UDim2.new(1, -132, 0, 8)
wheelieAngleTrack.Position = UDim2.fromOffset(15, 91)
wheelieAngleTrack.BackgroundColor3 = Color3.fromRGB(66, 39, 42)
wheelieAngleTrack.BorderSizePixel = 0
wheelieAngleTrack.Active = true
wheelieAngleTrack.Parent = wheelieCard
addCorner(wheelieAngleTrack, 5)

local wheelieAngleFill = Instance.new("Frame")
wheelieAngleFill.Name = "WheelieAngleSliderFill"
wheelieAngleFill.Size = UDim2.new((wheelieAngleDegrees - 1) / 89, 0, 1, 0)
wheelieAngleFill.BackgroundColor3 = Color3.fromRGB(255, 119, 26)
wheelieAngleFill.BorderSizePixel = 0
wheelieAngleFill.Active = true
wheelieAngleFill.Parent = wheelieAngleTrack
addCorner(wheelieAngleFill, 5)

local wheelieAngleKnob = Instance.new("TextButton")
wheelieAngleKnob.Name = "WheelieAngleSliderKnob"
wheelieAngleKnob.Size = UDim2.fromOffset(16, 16)
wheelieAngleKnob.AnchorPoint = Vector2.new(0.5, 0.5)
wheelieAngleKnob.Position = UDim2.new((wheelieAngleDegrees - 1) / 89, 0, 0.5, 0)
wheelieAngleKnob.BackgroundColor3 = Color3.fromRGB(255, 238, 218)
wheelieAngleKnob.BorderSizePixel = 0
wheelieAngleKnob.Text = ""
wheelieAngleKnob.AutoButtonColor = false
wheelieAngleKnob.Active = true
wheelieAngleKnob.ZIndex = 3
wheelieAngleKnob.Parent = wheelieAngleTrack
addCorner(wheelieAngleKnob, 8)
addStroke(wheelieAngleKnob, Color3.fromRGB(255, 119, 26), 2, 0)

local function updateWheelieAngleVisuals()
    local ratio = (wheelieAngleDegrees - 1) / 89
    wheelieAngleLabel.Text = "FRONT WHEEL ANGLE: " .. tostring(wheelieAngleDegrees) .. "°"
    wheelieAngleFill.Size = UDim2.new(ratio, 0, 1, 0)
    wheelieAngleKnob.Position = UDim2.new(ratio, 0, 0.5, 0)
end

local function updateWheelieAngleFromX(screenX)
    local trackStart = wheelieAngleTrack.AbsolutePosition.X
    local trackWidth = math.max(wheelieAngleTrack.AbsoluteSize.X, 1)
    local ratio = math.clamp((screenX - trackStart) / trackWidth, 0, 1)
    wheelieAngleDegrees = math.clamp(math.floor(1 + ratio * 89 + 0.5), 1, 90)
    updateWheelieAngleVisuals()
end

local function beginWheelieAngleDrag(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    wheelieSliderDragging = true
    updateWheelieAngleFromX(input.Position.X)
end

wheelieAngleTrack.InputBegan:Connect(beginWheelieAngleDrag)
wheelieAngleFill.InputBegan:Connect(beginWheelieAngleDrag)
wheelieAngleKnob.InputBegan:Connect(beginWheelieAngleDrag)

wheelieSliderInputChanged = UserInputService.InputChanged:Connect(function(input)
    if not wheelieSliderDragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        updateWheelieAngleFromX(input.Position.X)
    end
end)

wheelieSliderInputEnded = UserInputService.InputEnded:Connect(function(input)
    if not wheelieSliderDragging then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        wheelieSliderDragging = false
        setStatus("Auto Wheelie angle: " .. tostring(wheelieAngleDegrees) .. "°", COLORS.Purple)
    end
end)

updateWheelieAngleVisuals()

--==================================================
-- SPEED CHANGER UI (HOME)
--==================================================

local speedEnabled = false
local speedKmh = 50
local speedConnection

local speedCard = Instance.new("Frame")
speedCard.Name = "SpeedChangerCard"
speedCard.Size = UDim2.new(1, -8, 0, 100)
speedCard.Position = UDim2.fromOffset(4, 299)
speedCard.BackgroundColor3 = COLORS.Panel
speedCard.BorderSizePixel = 0
speedCard.Parent = homePage
addCorner(speedCard, 11)
addStroke(speedCard, COLORS.Border, 1, 0.4)
addGradient(speedCard, Color3.fromRGB(48, 29, 34), Color3.fromRGB(23, 13, 18), 90)

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
    speedCard, "SpeedChangerDescription", "Scooter speed • 1–1000 KM/H (smooth acceleration)",
    UDim2.new(1, -135, 0, 16), UDim2.fromOffset(15, 29), 9, COLORS.Muted
)

-- Speed value display and draggable slider (1–1000 KM/H)
local speedValueLabel = makeLabel(
    speedCard,
    "SpeedValueLabel",
    "50 KM/H",
    UDim2.new(1, -145, 0, 18),
    UDim2.fromOffset(15, 47),
    11,
    Color3.fromRGB(255, 190, 112)
)
speedValueLabel.Font = Enum.Font.GothamBold

local speedTrack = Instance.new("Frame")
speedTrack.Name = "SpeedSliderTrack"
speedTrack.Size = UDim2.new(1, -145, 0, 8)
speedTrack.Position = UDim2.fromOffset(15, 73)
speedTrack.BackgroundColor3 = Color3.fromRGB(66, 39, 42)
speedTrack.BorderSizePixel = 0
speedTrack.Active = true
speedTrack.Parent = speedCard
addCorner(speedTrack, 5)

local speedFill = Instance.new("Frame")
speedFill.Name = "SpeedSliderFill"
speedFill.Size = UDim2.new((speedKmh - 1) / 999, 0, 1, 0)
speedFill.BackgroundColor3 = Color3.fromRGB(255, 170, 70)
speedFill.BorderSizePixel = 0
speedFill.Active = true
speedFill.Parent = speedTrack
addCorner(speedFill, 5)

local speedKnob = Instance.new("TextButton")
speedKnob.Name = "SpeedSliderKnob"
speedKnob.Size = UDim2.fromOffset(16, 16)
speedKnob.AnchorPoint = Vector2.new(0.5, 0.5)
speedKnob.Position = UDim2.new((speedKmh - 1) / 999, 0, 0.5, 0)
speedKnob.BackgroundColor3 = Color3.fromRGB(255, 236, 211)
speedKnob.BorderSizePixel = 0
speedKnob.Text = ""
speedKnob.AutoButtonColor = false
speedKnob.Active = true
speedKnob.ZIndex = 3
speedKnob.Parent = speedTrack
addCorner(speedKnob, 8)
addStroke(speedKnob, Color3.fromRGB(255, 170, 70), 2, 0)

local speedButton = Instance.new("TextButton")
speedButton.Name = "SpeedChangerToggle"
speedButton.Size = UDim2.fromOffset(96, 36)
speedButton.Position = UDim2.new(1, -106, 0.5, -18)
speedButton.BackgroundColor3 = Color3.fromRGB(58, 31, 26)
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
panicButton.Position = UDim2.fromOffset(4, 409)
panicButton.BackgroundColor3 = Color3.fromRGB(72, 26, 20)
panicButton.BorderSizePixel = 0
panicButton.Text = "⚠   PANIC BUTTON     •     STOP ALL"
panicButton.TextColor3 = Color3.fromRGB(255, 158, 82)
panicButton.TextSize = 12
panicButton.Font = Enum.Font.GothamBold
panicButton.AutoButtonColor = false
panicButton.Parent = homePage

addCorner(panicButton, 10)
addStroke(panicButton, COLORS.Red, 1, 0.25)
addGradient(panicButton, Color3.fromRGB(112, 37, 24), Color3.fromRGB(41, 17, 20), 0)

--==================================================
-- STATUS CARD
--==================================================

local statusCard = Instance.new("Frame")
statusCard.Name = "StatusCard"
statusCard.Size = UDim2.new(1, -8, 0, 50)
statusCard.Position = UDim2.fromOffset(4, 464)
statusCard.BackgroundColor3 = Color3.fromRGB(24, 14, 18)
statusCard.BorderSizePixel = 0
statusCard.Parent = homePage

addCorner(statusCard, 10)
addStroke(statusCard, COLORS.Border, 1, 0.4)
addGradient(statusCard, Color3.fromRGB(39, 20, 25), Color3.fromRGB(18, 11, 16), 0)

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

setStatus = function(message, color)
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
toggleButton.Visible = true -- Key system removed; show the floating toggle immediately
toggleButton.Parent = gui

addCorner(toggleButton, 15)
addStroke(toggleButton, Color3.fromRGB(255, 185, 125), 1.5, 0.15)
addGradient(
    toggleButton,
    Color3.fromRGB(157, 91, 255),
    Color3.fromRGB(123, 44, 20),
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

local function updateSpeedSliderVisuals()
    local ratio = (speedKmh - 1) / 999
    speedValueLabel.Text = tostring(speedKmh) .. " KM/H"
    speedFill.Size = UDim2.new(ratio, 0, 1, 0)
    speedKnob.Position = UDim2.new(ratio, 0, 0.5, 0)
end

local function updateSpeedFromScreenX(screenX)
    local trackStart = speedTrack.AbsolutePosition.X
    local trackWidth = math.max(speedTrack.AbsoluteSize.X, 1)
    local ratio = math.clamp((screenX - trackStart) / trackWidth, 0, 1)
    speedKmh = math.clamp(math.floor(1 + ratio * 999 + 0.5), 1, 1000)
    updateSpeedSliderVisuals()
end

local speedDragging = false

local function beginSpeedSliderDrag(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    speedDragging = true
    updateSpeedFromScreenX(input.Position.X)
end

speedTrack.InputBegan:Connect(beginSpeedSliderDrag)
speedFill.InputBegan:Connect(beginSpeedSliderDrag)
speedKnob.InputBegan:Connect(beginSpeedSliderDrag)

UserInputService.InputChanged:Connect(function(input)
    if not speedDragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        updateSpeedFromScreenX(input.Position.X)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if not speedDragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        speedDragging = false
        setStatus(
            "Selected speed: " .. speedKmh .. " KM/H",
            speedEnabled and COLORS.Green or COLORS.Muted
        )
    end
end)

updateSpeedSliderVisuals()

-- Find every movable physical assembly inside the scooter. Some scooter models
-- have an unconnected seat, deck, or body, so controlling only PrimaryPart can
-- move just one piece. We use scooter descendants, never HumanoidRootPart directly.
local function getScooterDriveParts(vehicle, seat)
    local driveParts = {}
    local seenAssemblies = {}

    local function addPart(part)
        if not part or not part:IsA("BasePart") or part.Anchored then
            return
        end

        local assemblyRoot = part.AssemblyRootPart or part
        if seenAssemblies[assemblyRoot] then
            return
        end

        seenAssemblies[assemblyRoot] = true
        table.insert(driveParts, part)
    end

    if vehicle and vehicle:IsA("Model") then
        -- Include the primary part first, but do not assume it is the only
        -- movable assembly in the scooter.
        addPart(vehicle.PrimaryPart)
        for _, descendant in ipairs(vehicle:GetDescendants()) do
            if descendant:IsA("BasePart") then
                addPart(descendant)
            end
        end
    elseif vehicle and vehicle:IsA("BasePart") then
        addPart(vehicle)
    end

    -- Last resort for vehicles represented by a seat/basepart only.
    if #driveParts == 0 and seat and seat:IsA("BasePart") then
        addPart(seat)
    end

    return driveParts
end

local SPEED_ACCELERATION = 120 -- studs/s^2; ramps up instead of instantly flinging the rider

local function startSpeedChanger()
    stopSpeedChanger()
    speedConnection = RunService.Heartbeat:Connect(function(dt)
        if guiDestroyed or not speedEnabled then
            stopSpeedChanger()
            return
        end

        local vehicle, seat = getVehicle()
        if not vehicle or not seat then
            return
        end

        local driveParts = getScooterDriveParts(vehicle, seat)
        if #driveParts == 0 then
            return
        end

        local look = seat.CFrame.LookVector
        local forward = Vector3.new(look.X, 0, look.Z)
        if forward.Magnitude < 0.01 then
            local rootLook = driveParts[1].CFrame.LookVector
            forward = Vector3.new(rootLook.X, 0, rootLook.Z)
        end
        if forward.Magnitude < 0.01 then
            return
        end
        forward = forward.Unit

        local targetSpeed = speedKmh / 1.008 -- approx. KM/H -> Roblox studs/second
        local maxStep = SPEED_ACCELERATION * math.max(dt, 0)

        -- Smoothly accelerate the scooter's physical assemblies. This avoids the
        -- old instant velocity assignment that could fling the rider out of place.
        -- Vertical velocity is preserved for ramps and jumps.
        for _, drivePart in ipairs(driveParts) do
            if drivePart and drivePart.Parent and not drivePart.Anchored then
                local velocity = drivePart.AssemblyLinearVelocity
                local currentHorizontal = Vector3.new(velocity.X, 0, velocity.Z)

                local direction = forward
                if currentHorizontal.Magnitude > 3 then
                    local currentDirection = currentHorizontal.Unit
                    if currentDirection:Dot(forward) > 0.25 then
                        direction = currentDirection
                    end
                end

                local targetHorizontal = direction * targetSpeed
                local difference = targetHorizontal - currentHorizontal
                if difference.Magnitude > maxStep and difference.Magnitude > 0 then
                    difference = difference.Unit * maxStep
                end

                local nextHorizontal = currentHorizontal + difference
                drivePart.AssemblyLinearVelocity = Vector3.new(
                    nextHorizontal.X,
                    velocity.Y,
                    nextHorizontal.Z
                )
            end
        end
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
        speedButton.BackgroundColor3 = Color3.fromRGB(58, 31, 26)
        setStatus("Speed Changer disabled.", COLORS.Muted)
    else
        speedEnabled = true
        speedButton.Text = "ON"
        speedButton.BackgroundColor3 = Color3.fromRGB(255, 170, 70):Lerp(COLORS.Background, 0.35)
        startSpeedChanger()
        setStatus("Speed Changer enabled: " .. speedKmh .. " KM/H", COLORS.Green)
    end
end)

--==================================================
-- SCOOTER COLOR CUSTOMIZATION / CUSTOM HELMETS
--==================================================

--==================================================
-- CUSTOMIZATION SUB-TABS
--==================================================

local customizationSubTabBar = Instance.new("Frame")
customizationSubTabBar.Name = "CustomizationSubTabBar"
customizationSubTabBar.Size = UDim2.new(1, -8, 0, 34)
customizationSubTabBar.Position = UDim2.fromOffset(4, 3)
customizationSubTabBar.BackgroundTransparency = 1
customizationSubTabBar.Parent = customizationPage

local scooterColorsSubTab = makeButton(
    customizationSubTabBar,
    "ScooterColorsSubTab",
    "SCOOTER COLORS",
    UDim2.fromOffset(0, 0),
    UDim2.new(0.5, -4, 1, 0),
    COLORS.Purple
)
scooterColorsSubTab.TextSize = 10

local customHelmetsSubTab = makeButton(
    customizationSubTabBar,
    "CustomHelmetsSubTab",
    "CUSTOM HELMETS",
    UDim2.new(0.5, 4, 0, 0),
    UDim2.new(0.5, -4, 1, 0),
    COLORS.Button
)
customHelmetsSubTab.TextSize = 10

local scooterColorsContent = Instance.new("Frame")
scooterColorsContent.Name = "ScooterColorsContent"
scooterColorsContent.Position = UDim2.fromOffset(0, 42)
scooterColorsContent.Size = UDim2.new(1, 0, 0, 326)
scooterColorsContent.BackgroundTransparency = 1
scooterColorsContent.Parent = customizationPage

local customHelmetsContent = Instance.new("Frame")
customHelmetsContent.Name = "CustomHelmetsContent"
customHelmetsContent.Position = UDim2.fromOffset(0, 42)
customHelmetsContent.Size = UDim2.new(1, 0, 0, 300)
customHelmetsContent.BackgroundTransparency = 1
customHelmetsContent.Visible = false
customHelmetsContent.Parent = customizationPage

local function showCustomizationSection(sectionName)
    local showColors = sectionName == "ScooterColors"
    scooterColorsContent.Visible = showColors
    customHelmetsContent.Visible = not showColors

    scooterColorsSubTab.BackgroundColor3 = showColors and COLORS.Purple or COLORS.Button
    customHelmetsSubTab.BackgroundColor3 = showColors and COLORS.Button or COLORS.Purple
end

scooterColorsSubTab.Activated:Connect(function()
    showCustomizationSection("ScooterColors")
end)

customHelmetsSubTab.Activated:Connect(function()
    showCustomizationSection("CustomHelmets")
end)

showCustomizationSection("ScooterColors")

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
    scooterColorsContent, "CustomizationTitle", "SCOOTER COLOR",
    UDim2.new(1, -8, 0, 27), UDim2.fromOffset(4, 3), 15, COLORS.Text
)
customizationTitle.Font = Enum.Font.GothamBold

local customizationDescription = makeLabel(
    scooterColorsContent, "CustomizationDescription",
    "Choose a color for your scooter body.",
    UDim2.new(1, -8, 0, 20), UDim2.fromOffset(4, 33), 10, COLORS.Muted
)

local palette = Instance.new("Frame")
palette.Name = "ColorPalette"
palette.Size = UDim2.new(1, -8, 0, 152)
palette.Position = UDim2.fromOffset(4, 59)
palette.BackgroundTransparency = 1
palette.Parent = scooterColorsContent

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
rainbowButton.Parent = scooterColorsContent
addCorner(rainbowButton, 11)
addStroke(rainbowButton, Color3.fromRGB(255, 255, 255), 1, 0.45)

rainbowGradient = addGradient(
    rainbowButton,
    Color3.fromRGB(255, 60, 90),
    Color3.fromRGB(100, 60, 255),
    0
)

local colorHint = makeLabel(
    scooterColorsContent, "ColorHint",
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
-- CUSTOM HELMETS
--==================================================

local selectedCustomHelmet = nil
local activeCustomHelmetModel = nil
local helmetRespawnConnection
local hiddenHairParts = {}
local hairAddedConnection

local function restoreHelmetHiddenHair()
    if hairAddedConnection then
        hairAddedConnection:Disconnect()
        hairAddedConnection = nil
    end

    for part, oldTransparency in pairs(hiddenHairParts) do
        if part and part.Parent then
            pcall(function()
                part.LocalTransparencyModifier = oldTransparency
            end)
        end
    end
    table.clear(hiddenHairParts)
end

local function isHairAccessory(accessory)
    if not accessory or not accessory:IsA("Accessory") then
        return false
    end

    local ok, accessoryType = pcall(function()
        return accessory.AccessoryType
    end)
    if ok and accessoryType == Enum.AccessoryType.Hair then
        return true
    end

    return string.find(string.lower(accessory.Name), "hair", 1, true) ~= nil
end

local function hideHairAccessory(accessory)
    if not isHairAccessory(accessory) then
        return
    end

    for _, descendant in ipairs(accessory:GetDescendants()) do
        if descendant:IsA("BasePart") then
            if hiddenHairParts[descendant] == nil then
                hiddenHairParts[descendant] = descendant.LocalTransparencyModifier
            end
            descendant.LocalTransparencyModifier = 1
        end
    end
end

local function hideCharacterHair(character)
    restoreHelmetHiddenHair()

    for _, child in ipairs(character:GetChildren()) do
        hideHairAccessory(child)
    end

    -- Also hide hair accessories that finish loading after the helmet is equipped.
    hairAddedConnection = character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Accessory") then
            task.defer(function()
                if descendant.Parent and isHairAccessory(descendant) then
                    hideHairAccessory(descendant)
                end
            end)
        elseif descendant:IsA("BasePart") then
            local accessory = descendant:FindFirstAncestorWhichIsA("Accessory")
            if accessory and isHairAccessory(accessory) then
                if hiddenHairParts[descendant] == nil then
                    hiddenHairParts[descendant] = descendant.LocalTransparencyModifier
                end
                descendant.LocalTransparencyModifier = 1
            end
        end
    end)
end

local function removeCustomHelmet()
    if activeCustomHelmetModel then
        pcall(function()
            activeCustomHelmetModel:Destroy()
        end)
        activeCustomHelmetModel = nil
    end
    restoreHelmetHiddenHair()
end

local function addHelmetPart(model, head, name, size, offset, color, shape, transparency, material)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Shape = shape or Enum.PartType.Block
    part.Color = color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Transparency = transparency or 0
    part.Anchored = false
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Massless = true
    part.CastShadow = false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.CFrame = head.CFrame * CFrame.new(offset)
    part.Parent = model

    local weld = Instance.new("WeldConstraint")
    weld.Name = name .. "Weld"
    weld.Part0 = head
    weld.Part1 = part
    weld.Parent = part

    return part
end

local function equipCustomFullface(colorName)
    local character = player.Character
    local head = character and character:FindFirstChild("Head")

    if not character or not head or not head:IsA("BasePart") then
        setStatus("Character head not found.", COLORS.Red)
        return false
    end

    local shellColor
    local chinColor
    if colorName == "Red" then
        shellColor = Color3.fromRGB(190, 35, 48)
        chinColor = Color3.fromRGB(125, 22, 32)
    elseif colorName == "Blue" then
        shellColor = Color3.fromRGB(35, 105, 220)
        chinColor = Color3.fromRGB(23, 65, 145)
    else
        return false
    end

    removeCustomHelmet()
    hideCharacterHair(character)

    local helmetModel = Instance.new("Model")
    helmetModel.Name = "EasySenpCustomHelmet"
    helmetModel.Parent = character

    -- Scale a rounded full-face shell to the avatar's actual head dimensions.
    local headSize = head.Size
    local shellWidth = math.max(headSize.X * 1.08, 1.42)
    local shellHeight = math.max(headSize.Y * 1.48, 1.34)
    local shellDepth = math.max(headSize.Z * 1.58, 1.38)

    -- Rounded outer dome. The oversized spherical shell fully covers the hairline.
    addHelmetPart(
        helmetModel, head, "HelmetShell",
        Vector3.new(shellWidth, shellHeight, shellDepth),
        Vector3.new(0, 0.10, 0.025),
        shellColor, Enum.PartType.Ball
    )

    -- Rounded lower chin section gives the helmet a full-face silhouette.
    addHelmetPart(
        helmetModel, head, "FullFaceChinGuard",
        Vector3.new(shellWidth * 0.66, shellHeight * 0.47, shellDepth * 0.52),
        Vector3.new(0, -0.27, -shellDepth * 0.30),
        chinColor, Enum.PartType.Ball
    )

    -- Curved dark visor across the front of the helmet.
    addHelmetPart(
        helmetModel, head, "DarkVisor",
        Vector3.new(shellWidth * 0.73, shellHeight * 0.30, 0.13),
        Vector3.new(0, 0.13, -shellDepth * 0.485),
        Color3.fromRGB(20, 23, 31), Enum.PartType.Ball, 0.14, Enum.Material.Glass
    )

    -- Rounded side pieces and a small front vent complete the full-face shape.
    addHelmetPart(
        helmetModel, head, "LeftSidePlate",
        Vector3.new(shellWidth * 0.22, shellHeight * 0.47, shellDepth * 0.52),
        Vector3.new(-shellWidth * 0.36, -0.04, -0.04),
        chinColor, Enum.PartType.Ball
    )

    addHelmetPart(
        helmetModel, head, "RightSidePlate",
        Vector3.new(shellWidth * 0.22, shellHeight * 0.47, shellDepth * 0.52),
        Vector3.new(shellWidth * 0.36, -0.04, -0.04),
        chinColor, Enum.PartType.Ball
    )

    addHelmetPart(
        helmetModel, head, "FrontVent",
        Vector3.new(shellWidth * 0.20, 0.09, 0.055),
        Vector3.new(0, -0.34, -shellDepth * 0.53),
        Color3.fromRGB(30, 30, 35), Enum.PartType.Ball
    )

    activeCustomHelmetModel = helmetModel
    selectedCustomHelmet = colorName
    setStatus(colorName .. " rounded Fullface helmet equipped. Hair hidden.", COLORS.Green)
    return true
end

local helmetTitle = makeLabel(
    customHelmetsContent,
    "CustomHelmetsTitle",
    "CUSTOM HELMETS",
    UDim2.new(1, -8, 0, 27),
    UDim2.fromOffset(4, 3),
    15,
    COLORS.Text
)
helmetTitle.Font = Enum.Font.GothamBold

local helmetDescription = makeLabel(
    customHelmetsContent,
    "CustomHelmetsDescription",
    "Choose a rounded full-face helmet. Hair is hidden while equipped.",
    UDim2.new(1, -8, 0, 34),
    UDim2.fromOffset(4, 32),
    10,
    COLORS.Muted
)
helmetDescription.TextWrapped = true

local redHelmetButton = makeButton(
    customHelmetsContent,
    "RedFullfaceHelmet",
    "RED  •  FULLFACE",
    UDim2.fromOffset(4, 77),
    UDim2.new(1, -8, 0, 58),
    Color3.fromRGB(150, 34, 46)
)
redHelmetButton.TextSize = 13

local blueHelmetButton = makeButton(
    customHelmetsContent,
    "BlueFullfaceHelmet",
    "BLUE  •  FULLFACE",
    UDim2.fromOffset(4, 146),
    UDim2.new(1, -8, 0, 58),
    Color3.fromRGB(35, 87, 170)
)
blueHelmetButton.TextSize = 13

local removeHelmetButton = makeButton(
    customHelmetsContent,
    "RemoveCustomHelmet",
    "REMOVE HELMET",
    UDim2.fromOffset(4, 215),
    UDim2.new(1, -8, 0, 42),
    COLORS.Button
)
removeHelmetButton.TextSize = 11

redHelmetButton.Activated:Connect(function()
    equipCustomFullface("Red")
end)

blueHelmetButton.Activated:Connect(function()
    equipCustomFullface("Blue")
end)

removeHelmetButton.Activated:Connect(function()
    selectedCustomHelmet = nil
    removeCustomHelmet()
    setStatus("Custom helmet removed. Hair restored.", COLORS.Muted)
end)

helmetRespawnConnection = player.CharacterAdded:Connect(function(character)
    local helmetToRestore = selectedCustomHelmet
    if not helmetToRestore then
        restoreHelmetHiddenHair()
        return
    end

    task.spawn(function()
        local head = character:WaitForChild("Head", 8)
        if head and not guiDestroyed and selectedCustomHelmet == helmetToRestore then
            equipCustomFullface(helmetToRestore)
        end
    end)
end)

--==================================================
-- AUTO WHEELIE - SUSTAINED FRONT-WHEEL LIFT (NO ALIGNORIENTATION)
--==================================================

-- The pitch controller keeps applying a correction while Auto Wheelie is ON.
-- This holds the scooter at the selected angle, so the front wheel stays up
-- instead of receiving only one short rotation impulse.
-- It uses the vehicle assembly's angular velocity; it creates no AlignOrientation,
-- Attachment, AlignPosition, or other alignment objects.

local function getPitchFromRoot(root)
    if not root or not root.Parent then
        return nil
    end

    -- A Roblox vehicle facing its LookVector has positive pitch when its nose rises.
    local look = root.CFrame.LookVector
    return math.asin(math.clamp(look.Y, -1, 1))
end

local function stopWheelie()
    if wheelieConnection then
        wheelieConnection:Disconnect()
        wheelieConnection = nil
    end

    -- Remove the controller's pitch spin, but leave yaw/roll spin untouched.
    if wheelieRoot and wheelieRoot.Parent and not wheelieRoot.Anchored then
        local axis = wheelieRoot.CFrame.RightVector
        local angularVelocity = wheelieRoot.AssemblyAngularVelocity
        local pitchRate = angularVelocity:Dot(axis)
        wheelieRoot.AssemblyAngularVelocity = angularVelocity - axis * pitchRate
    end

    wheelieRoot = nil
    wheelieVehicle = nil
    wheelieSeat = nil
    wheelieBasePitch = nil
end

local function stopWheelieState(message, color)
    autoWheelie = false
    wheelieButton.Text = "OFF"
    wheelieButton.BackgroundColor3 = COLORS.Button
    stopWheelie()
    if message then
        setStatus(message, color or COLORS.Muted)
    end
end

local function startWheelie()
    stopWheelie()

    local vehicle, seat = getVehicle()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if not vehicle or not seat or not humanoid or humanoid.SeatPart ~= seat then
        stopWheelieState("Sit on your scooter first.", COLORS.Red)
        return
    end

    if not seat:IsA("BasePart") then
        stopWheelieState("The scooter seat is not a BasePart.", COLORS.Red)
        return
    end

    -- Use the physical assembly root connected to the seat. This makes the
    -- complete welded scooter chassis pitch together, including its front wheel.
    local fallbackRoot = getRootPart(vehicle, seat)
    local root = seat.AssemblyRootPart or fallbackRoot

    if not root or not root:IsA("BasePart") or root.Anchored then
        stopWheelieState("Cannot control the scooter's physical assembly.", COLORS.Red)
        return
    end

    local basePitch = getPitchFromRoot(root)
    if basePitch == nil then
        stopWheelieState("Could not read the scooter angle.", COLORS.Red)
        return
    end

    wheelieRoot = root
    wheelieVehicle = vehicle
    wheelieSeat = seat
    wheelieBasePitch = basePitch

    wheelieConnection = RunService.Heartbeat:Connect(function(dt)
        if guiDestroyed or not autoWheelie then
            stopWheelie()
            return
        end

        if not wheelieRoot or not wheelieRoot.Parent or wheelieRoot.Anchored
            or not wheelieVehicle or not wheelieVehicle.Parent
            or not wheelieSeat or not wheelieSeat.Parent then
            stopWheelieState("Scooter assembly was lost.", COLORS.Red)
            return
        end

        local currentVehicle, currentSeat = getVehicle()
        if currentVehicle ~= wheelieVehicle or currentSeat ~= wheelieSeat then
            stopWheelieState("Auto Wheelie stopped because you left the scooter.", COLORS.Muted)
            return
        end

        local currentPitch = getPitchFromRoot(wheelieRoot)
        if currentPitch == nil then
            stopWheelieState("Could not measure the scooter angle.", COLORS.Red)
            return
        end

        -- Slider sets the actual nose-up pitch relative to the angle at activation.
        -- 88.5 degrees is used internally at the 90-degree end to avoid a vertical
        -- orientation singularity while keeping the requested maximum near-vertical.
        local requestedAngle = math.rad(wheelieAngleDegrees)
        local targetPitch = math.clamp(
            wheelieBasePitch + requestedAngle,
            -WHEELIE_MAX_TARGET_PITCH,
            WHEELIE_MAX_TARGET_PITCH
        )
        local pitchError = targetPitch - currentPitch

        -- The local RightVector is the scooter's pitch axis. The PD controller
        -- continuously corrects gravity, wheel contact and physics drift, holding
        -- the selected front-wheel lift while the option remains ON.
        local pitchAxis = wheelieRoot.CFrame.RightVector
        local assemblyAngularVelocity = wheelieRoot.AssemblyAngularVelocity
        local currentPitchRate = assemblyAngularVelocity:Dot(pitchAxis)

        local desiredPitchRate = math.clamp(
            pitchError * WHEELIE_P_GAIN - currentPitchRate * WHEELIE_D_GAIN,
            -WHEELIE_MAX_ANGULAR_SPEED,
            WHEELIE_MAX_ANGULAR_SPEED
        )

        -- Keep angular velocity around the other axes (steering/roll) intact.
        local otherAngularVelocity = assemblyAngularVelocity
            - pitchAxis * currentPitchRate

        wheelieRoot.AssemblyAngularVelocity =
            otherAngularVelocity + pitchAxis * desiredPitchRate
    end)

    setStatus(
        "Front wheel held up • " .. tostring(wheelieAngleDegrees) .. "°",
        COLORS.Green
    )
end

wheelieButton.Activated:Connect(function()
    if guiDestroyed then
        return
    end

    if autoWheelie then
        autoWheelie = false
        wheelieButton.Text = "OFF"
        wheelieButton.BackgroundColor3 = Color3.fromRGB(58, 31, 26)
        stopWheelie()
        setStatus("Auto Wheelie disabled.", COLORS.Muted)
    else
        autoWheelie = true
        wheelieButton.Text = "ON"
        wheelieButton.BackgroundColor3 = COLORS.Purple:Lerp(COLORS.Background, 0.35)
        startWheelie()

        if not autoWheelie then
            wheelieButton.Text = "OFF"
            wheelieButton.BackgroundColor3 = Color3.fromRGB(58, 31, 26)
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
        attachButton.BackgroundColor3 = Color3.fromRGB(58, 31, 26)
        stopAttach()
        setStatus("Attach to Scooter disabled.", COLORS.Muted)
    else
        attachEnabled = true
        attachButton.Text = "ON"
        attachButton.BackgroundColor3 = COLORS.Blue:Lerp(COLORS.Background, 0.35)
        startAttach()
        if not attachEnabled then
            attachButton.Text = "OFF"
            attachButton.BackgroundColor3 = Color3.fromRGB(58, 31, 26)
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
        farmButton.BackgroundColor3 = Color3.fromRGB(58, 31, 26)
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
    wheelieSliderDragging = false
    if wheelieSliderInputChanged then
        wheelieSliderInputChanged:Disconnect()
        wheelieSliderInputChanged = nil
    end
    if wheelieSliderInputEnded then
        wheelieSliderInputEnded:Disconnect()
        wheelieSliderInputEnded = nil
    end

    farmToken += 1

    stopWheelie()
    stopAttach()
    stopSpeedChanger()

    -- Remove the custom helmet and restore hair visibility during emergency cleanup.
    if selectedCustomHelmet ~= nil then
        selectedCustomHelmet = nil
    end
    if removeCustomHelmet then
        removeCustomHelmet()
    end
    if helmetRespawnConnection then
        helmetRespawnConnection:Disconnect()
        helmetRespawnConnection = nil
    end

    gui:Destroy()
end)

--==================================================
-- INITIAL STATUS
--==================================================

setStatus("Ready - choose a feature.", COLORS.Green)
