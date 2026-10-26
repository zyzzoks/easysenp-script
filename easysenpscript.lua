
-- MONEY FARM GUI
-- LocalScript w StarterPlayer > StarterPlayerScripts
-- TOGGLE otwiera/zamyka panel.
-- MONEY FARM włącza/wyłącza sekwencję.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local running = false
local session = 0

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "MoneyFarmGUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local toggle = Instance.new("TextButton")
toggle.Name = "ToggleButton"
toggle.Size = UDim2.fromOffset(150, 42)
toggle.Position = UDim2.new(0.5, -75, 0, 8)
toggle.BackgroundColor3 = Color3.fromRGB(105, 55, 220)
toggle.Text = "TOGGLE"
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 16
toggle.Parent = gui

Instance.new("UICorner", toggle).CornerRadius =
    UDim.new(0, 10)

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.fromOffset(340, 210)
panel.Position = UDim2.new(0.5, -170, 0.5, -105)
panel.BackgroundColor3 = Color3.fromRGB(23, 23, 32)
panel.Visible = false
panel.Parent = gui

Instance.new("UICorner", panel).CornerRadius =
    UDim.new(0, 14)

local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(130, 75, 255)
outline.Thickness = 2
outline.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 45)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.Text = "MONEY FARM"
title.TextColor3 = Color3.fromRGB(180, 130, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -20, 0, 30)
status.Position = UDim2.fromOffset(10, 55)
status.BackgroundTransparency = 1
status.Text = "STATUS: OFF"
status.TextColor3 = Color3.fromRGB(255, 100, 100)
status.Font = Enum.Font.GothamBold
status.TextSize = 16
status.Parent = panel

local farmButton = Instance.new("TextButton")
farmButton.Name = "MoneyFarmButton"
farmButton.Size = UDim2.new(1, -40, 0, 48)
farmButton.Position = UDim2.fromOffset(20, 100)
farmButton.BackgroundColor3 = Color3.fromRGB(55, 145, 85)
farmButton.Text = "MONEY FARM: OFF"
farmButton.TextColor3 = Color3.new(1, 1, 1)
farmButton.Font = Enum.Font.GothamBold
farmButton.TextSize = 16
farmButton.Parent = panel

Instance.new("UICorner", farmButton).CornerRadius =
    UDim.new(0, 10)

local function updateStatus()
    if running then
        status.Text = "STATUS: ON"
        status.TextColor3 = Color3.fromRGB(100, 255, 140)
        farmButton.Text = "MONEY FARM: ON"
        farmButton.BackgroundColor3 = Color3.fromRGB(180, 55, 65)
    else
        status.Text = "STATUS: OFF"
        status.TextColor3 = Color3.fromRGB(255, 100, 100)
        farmButton.Text = "MONEY FARM: OFF"
        farmButton.BackgroundColor3 = Color3.fromRGB(55, 145, 85)
    end
end

-- Znajdź postać i ewentualny pojazd.
local function getCharacterAndVehicle()
    local character = player.Character
    if not character then
        return nil, nil, nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        return character, humanoid, nil
    end

    local seat = humanoid.SeatPart
    local vehicle = nil

    if seat then
        vehicle = seat:FindFirstAncestorOfClass("Model")
    end

    return character, humanoid, vehicle
end

-- Sekwencja wizualna: uniesienie, 5 obrotów, lądowanie.
-- Gdy gracz siedzi, animacja dotyczy modelu pojazdu,
-- o ile siedzenie należy do modelu hulajnogi.
local function animateModel(model, mySession)
    if not model or not model.Parent then
        return
    end

    local startPivot = model:GetPivot()
    local startPosition = startPivot.Position
    local startRotation = startPivot.Rotation
    local height = 10

    local function moveTo(cf)
        if not running or session ~= mySession
            or not model.Parent then
            return false
        end

        model:PivotTo(cf)
        return true
    end

    -- Podniesienie
    local elapsed = 0
    while elapsed < 0.8 and running and session == mySession do
        elapsed += RunService.Heartbeat:Wait()
        local alpha = math.clamp(elapsed / 0.8, 0, 1)
        local position = startPosition + Vector3.new(0, height * alpha, 0)

        if not moveTo(CFrame.new(position) * startRotation) then
            return
        end
    end

    -- 5 backflipów
    for flip = 1, 5 do
        local flipElapsed = 0
        while flipElapsed < 0.45
            and running and session == mySession do

            flipElapsed += RunService.Heartbeat:Wait()
            local alpha = math.clamp(flipElapsed / 0.45, 0, 1)
            local angle = -2 * math.pi * (flip - 1 + alpha)

            local cf = CFrame.new(
                startPosition + Vector3.new(0, height, 0)
            ) * startRotation * CFrame.Angles(angle, 0, 0)

            if not moveTo(cf) then
                return
            end
        end
    end

    -- Powrót na miejsce
    elapsed = 0
    while elapsed < 0.8 and running and session == mySession do
        elapsed += RunService.Heartbeat:Wait()
        local alpha = math.clamp(elapsed / 0.8, 0, 1)
        local position = startPosition
            + Vector3.new(0, height * (1 - alpha), 0)

        if not moveTo(CFrame.new(position) * startRotation) then
            return
        end
    end

    if running and session == mySession and model.Parent then
        model:PivotTo(startPivot)
    end
end

local function farmLoop(mySession)
    while running and session == mySession do
        local character, humanoid, vehicle = getCharacterAndVehicle()

        if humanoid and humanoid.Health > 0 then
            if humanoid.SeatPart and vehicle then
                -- Gdy siedzisz, animujemy model hulajnogi.
                animateModel(vehicle, mySession)
            elseif character and character:FindFirstChild("HumanoidRootPart") then
                -- Gdy nie siedzisz, animujemy postać.
                animateModel(character, mySession)
            else
                task.wait(0.5)
            end
        else
            task.wait(0.5)
        end

        if running and session == mySession then
            task.wait(0.2)
        end
    end
end

toggle.Activated:Connect(function()
    panel.Visible = not panel.Visible
end)

farmButton.Activated:Connect(function()
    running = not running
    session += 1
    updateStatus()

    if running then
        task.spawn(farmLoop, session)
    end
end)

player.CharacterAdded:Connect(function()
    running = false
    session += 1
    updateStatus()
end)

updateStatus()
print("Money Farm GUI załadowane!")
