local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local runningFarm = false
local autoWheelie = false
local attachEnabled = false
local guiDestroyed = false
local farmToken = 0

local WHEELIE_ANGLE = math.rad(45)
local WHEELIE_RESPONSE = 5
local WHEELIE_TORQUE = 25000
local ATTACH_CHECK_INTERVAL = 0.15
local ATTACH_DISTANCE = 5

local wheelieConnection
local wheelieAttachment
local wheelieAlign
local wheelieRoot

local attachConnection
local lastVehicle
local lastSeat

local oldGui = playerGui:FindFirstChild("EasySenpGui")
if oldGui then
	oldGui:Destroy()
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "EasySenpGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.fromOffset(310, 390)
panel.Position = UDim2.new(0.5, -155, 0.5, -195)
panel.BackgroundColor3 = Color3.fromRGB(28, 22, 40)
panel.BorderSizePixel = 0
panel.Parent = gui

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(155, 85, 255)
outline.Thickness = 2
outline.Parent = panel

-- Draggable title
local dragArea = Instance.new("TextButton")
dragArea.Size = UDim2.new(1, 0, 0, 48)
dragArea.BackgroundColor3 = Color3.fromRGB(65, 35, 100)
dragArea.BorderSizePixel = 0
dragArea.Text = "EasySenp Script V1"
dragArea.TextColor3 = Color3.new(1, 1, 1)
dragArea.TextSize = 20
dragArea.Font = Enum.Font.GothamBold
dragArea.Parent = panel

Instance.new("UICorner", dragArea).CornerRadius = UDim.new(0, 14)

local dragging = false
local dragStart
local startPosition

dragArea.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPosition = panel.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (
		input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
	) then
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
	end
end)

-- Button creator
local function createButton(name, text, y, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, -30, 0, 42)
	button.Position = UDim2.fromOffset(15, y)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 14
	button.Font = Enum.Font.GothamBold
	button.Parent = panel

	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 9)
	return button
end

local wheelieButton = createButton(
	"AutoWheelieButton",
	"Auto Wheelie: OFF",
	60,
	Color3.fromRGB(105, 65, 175)
)

local attachButton = createButton(
	"AttachButton",
	"Attach to Scooter: OFF",
	110,
	Color3.fromRGB(65, 105, 175)
)

local farmButton = createButton(
	"MoneyFarmButton",
	"Money Farm: START",
	160,
	Color3.fromRGB(65, 145, 90)
)

local panicButton = createButton(
	"PanicButton",
	"PANIC BUTTON",
	210,
	Color3.fromRGB(200, 45, 60)
)

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -30, 0, 95)
statusLabel.Position = UDim2.fromOffset(15, 265)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Ready"
statusLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
statusLabel.TextSize = 13
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextWrapped = true
statusLabel.Parent = panel

-- ES toggle
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleGuiButton"
toggleButton.Size = UDim2.fromOffset(55, 45)
toggleButton.Position = UDim2.new(0, 15, 0.5, -22)
toggleButton.BackgroundColor3 = Color3.fromRGB(110, 55, 180)
toggleButton.BorderSizePixel = 0
toggleButton.Text = "ES"
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.TextSize = 19
toggleButton.Font = Enum.Font.GothamBold
toggleButton.Parent = gui

Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 10)

toggleButton.Activated:Connect(function()
	if not guiDestroyed then
		panel.Visible = not panel.Visible
	end
end)

-- Vehicle helpers
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
	if not vehicle then
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

-- AUTO WHEELIE
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
		wheelieButton.Text = "Auto Wheelie: OFF"
		statusLabel.Text = "Sit on your scooter first."
		return
	end

	local root = getRootPart(vehicle, seat)
	if not root or root.Anchored then
		autoWheelie = false
		wheelieButton.Text = "Auto Wheelie: OFF"
		statusLabel.Text = "Cannot control this scooter."
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
			wheelieButton.Text = "Auto Wheelie: OFF"
			statusLabel.Text = "Scooter not found."
			return
		end

		-- Read yaw every frame so steering direction can change.
		-- Keep the 45-degree pitch while following the scooter's heading.
		local look = wheelieRoot.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)

		if flatLook.Magnitude > 0.001 then
			flatLook = flatLook.Unit

			local yaw = math.atan2(-flatLook.X, -flatLook.Z)
			local heading = CFrame.Angles(0, yaw, 0)

			-- The wheelie tilt is relative to the current heading.
			align.CFrame = heading.Rotation
				* CFrame.Angles(WHEELIE_ANGLE, 0, 0)
		end
	end)

	statusLabel.Text = "Auto Wheelie enabled: 45 degrees."
end

wheelieButton.Activated:Connect(function()
	if guiDestroyed then
		return
	end

	autoWheelie = not autoWheelie

	if autoWheelie then
		wheelieButton.Text = "Auto Wheelie: ON"
		startWheelie()
	else
		wheelieButton.Text = "Auto Wheelie: OFF"
		stopWheelie()
		statusLabel.Text = "Auto Wheelie disabled."
	end
end)

-- ATTACH TO SCOOTER
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
		attachButton.Text = "Attach to Scooter: OFF"
		statusLabel.Text = "Sit on your scooter first."
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
			attachButton.Text = "Attach to Scooter: OFF"
			statusLabel.Text = "Scooter unavailable."
			stopAttach()
			return
		end

		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")

		if not humanoid or not root or humanoid.SeatPart == lastSeat then
			return
		end

		local scooterPivot = getPivot(lastVehicle)
		if not scooterPivot then
			return
		end

		local distance = (root.Position - scooterPivot.Position).Magnitude
		if distance > ATTACH_DISTANCE or humanoid.SeatPart == nil then
			root.CFrame = lastSeat.CFrame * CFrame.new(0, 2.5, 0)
			task.wait(0.05)

			if humanoid.Parent and lastSeat.Parent then
				lastSeat:Sit(humanoid)
			end
		end
	end)

	statusLabel.Text = "Attach to Scooter enabled."
end

attachButton.Activated:Connect(function()
	if guiDestroyed then
		return
	end

	attachEnabled = not attachEnabled

	if attachEnabled then
		attachButton.Text = "Attach to Scooter: ON"
		startAttach()
	else
		attachButton.Text = "Attach to Scooter: OFF"
		stopAttach()
		lastVehicle = nil
		lastSeat = nil
		statusLabel.Text = "Attach to Scooter disabled."
	end
end)

-- MONEY FARM
local function getGroundY(vehicle)
	local pivot = getPivot(vehicle)
	if not pivot then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {vehicle, player.Character}

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

		local dt = RunService.Heartbeat:Wait()
		elapsed += dt

		local alpha = math.clamp(elapsed / duration, 0, 1)
		setPivot(vehicle, startCF * CFrame.Angles(rotation * alpha, 0, 0))
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

		local dt = RunService.Heartbeat:Wait()
		elapsed += dt

		local alpha = math.clamp(elapsed / duration, 0, 1)
		setPivot(vehicle, startCF * CFrame.Angles(0, math.rad(360) * alpha, 0))
	end

	return true
end

local function doFarmCycle(token)
	local vehicle = getVehicle()
	if not vehicle then
		statusLabel.Text = "Sit on your scooter to start Money Farm."
		return false
	end

	local groundY = getGroundY(vehicle)
	local startCF = getPivot(vehicle)
	if not groundY or not startCF then
		return false
	end

	stopWheelie()

	setPivot(vehicle, startCF + Vector3.new(0, 18, 0))
	task.wait(0.1)

	for _ = 1, 5 do
		if not animateRotation(vehicle, math.rad(360), 0.22, token) then
			return false
		end
	end

	for _ = 1, 5 do
		if not animateSpin(vehicle, 0.18, token) then
			return false
		end
	end

	if not runningFarm or farmToken ~= token or guiDestroyed then
		return false
	end

	local current = getPivot(vehicle)
	if current then
		setPivot(
			vehicle,
			CFrame.new(current.Position.X, groundY + 3, current.Position.Z)
		)
	end

	return true
end

farmButton.Activated:Connect(function()
	if guiDestroyed then
		return
	end

	if runningFarm then
		runningFarm = false
		farmToken += 1
		farmButton.Text = "Money Farm: START"
		statusLabel.Text = "Money Farm stopped."
		return
	end

	runningFarm = true
	farmToken += 1

	local token = farmToken
	farmButton.Text = "Money Farm: STOP"
	statusLabel.Text = "Money Farm running..."

	task.spawn(function()
		while runningFarm and farmToken == token and not guiDestroyed do
			doFarmCycle(token)
			task.wait(0.1)
		end
	end)
end)

-- PANIC BUTTON
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
