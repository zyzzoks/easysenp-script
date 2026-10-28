--[[
    EasySenp Loader - Panda Auth PUSL-V4
    Flow: Enter key -> Authenticate -> Check game.PlaceId -> Load supported game script.

    Intended for an executor/runtime that supports loadstring and game:HttpGet.
    Configure serviceId and your Panda Auth dashboard before distributing.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PANDA_LIBRARY_URL = "https://secure.pandauth.com/pv4/lib"
local PANDA_SERVICE_ID = "easysenp"

local GAMES = {
    {
        name = "Kukirin Live",
        description = "Scooter game",
        placeId = 122840796290491,
        scriptUrl = "https://raw.githubusercontent.com/zyzzoks/easysenp-script/refs/heads/main/easysenpkukirinlife.lua",
    },
}

local COLORS = {
    background = Color3.fromRGB(15, 12, 23),
    panel = Color3.fromRGB(26, 21, 38),
    panel2 = Color3.fromRGB(35, 28, 50),
    purple = Color3.fromRGB(157, 91, 255),
    purpleDark = Color3.fromRGB(91, 49, 155),
    text = Color3.fromRGB(248, 245, 255),
    muted = Color3.fromRGB(170, 158, 190),
    green = Color3.fromRGB(72, 215, 143),
    red = Color3.fromRGB(255, 93, 111),
    border = Color3.fromRGB(79, 62, 103),
}

local old = playerGui:FindFirstChild("EasySenpLoader")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "EasySenpLoader"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = playerGui

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
    return c
end

local function stroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = obj
    return s
end

local function gradient(obj, c1, c2, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rotation or 0
    g.Parent = obj
    return g
end

local function label(parent, text, size, position, fontSize, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = size
    l.Position = position
    l.Text = text
    l.TextColor3 = color or COLORS.text
    l.TextSize = fontSize or 12
    l.Font = font or Enum.Font.Gotham
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function button(parent, text, size, position, primary)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = position
    b.BackgroundColor3 = primary and COLORS.purple or COLORS.panel2
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = COLORS.text
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = false
    b.Parent = parent
    corner(b, 10)
    if primary then
        gradient(b, COLORS.purple, COLORS.purpleDark, 0)
    else
        stroke(b, COLORS.border, 1, 0.2)
    end
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {
            BackgroundTransparency = 0.08
        }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {
            BackgroundTransparency = 0
        }):Play()
    end)
    return b
end

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.28
backdrop.BorderSizePixel = 0
backdrop.Parent = gui

local card = Instance.new("Frame")
card.Name = "MainCard"
card.Size = UDim2.fromOffset(390, 340)
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.BackgroundColor3 = COLORS.background
card.BorderSizePixel = 0
card.Parent = backdrop
corner(card, 18)
stroke(card, COLORS.purple, 1.4, 0.12)
gradient(card, Color3.fromRGB(34, 24, 49), COLORS.background, 90)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 78)
header.BackgroundColor3 = COLORS.purpleDark
header.BorderSizePixel = 0
header.Parent = card
corner(header, 18)
gradient(header, Color3.fromRGB(119, 66, 197), COLORS.purpleDark, 0)

local logo = Instance.new("Frame")
logo.Size = UDim2.fromOffset(43, 43)
logo.Position = UDim2.fromOffset(18, 17)
logo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
logo.BackgroundTransparency = 0.84
logo.BorderSizePixel = 0
logo.Parent = header
corner(logo, 12)
label(logo, "ES", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 16, COLORS.text, Enum.Font.GothamBlack).TextXAlignment = Enum.TextXAlignment.Center

label(header, "EasySenp", UDim2.new(1, -90, 0, 30), UDim2.fromOffset(72, 14), 22, COLORS.text, Enum.Font.GothamBold)
label(header, "PANDA AUTH  •  GAME LOADER", UDim2.new(1, -90, 0, 18), UDim2.fromOffset(74, 43), 9, Color3.fromRGB(229, 211, 255), Enum.Font.GothamBold)

local pageLabel = label(card, "KEY AUTHENTICATION", UDim2.new(1, -40, 0, 20), UDim2.fromOffset(20, 94), 10, COLORS.muted, Enum.Font.GothamBold)
local infoLabel = label(card, "Enter your Panda Auth key to continue.", UDim2.new(1, -40, 0, 35), UDim2.fromOffset(20, 116), 12, COLORS.text)

local keyInput = Instance.new("TextBox")
keyInput.Name = "KeyInput"
keyInput.Size = UDim2.new(1, -40, 0, 43)
keyInput.Position = UDim2.fromOffset(20, 158)
keyInput.BackgroundColor3 = COLORS.panel
keyInput.BorderSizePixel = 0
keyInput.PlaceholderText = "Enter your key..."
keyInput.PlaceholderColor3 = COLORS.muted
keyInput.Text = ""
keyInput.TextColor3 = COLORS.text
keyInput.TextSize = 13
keyInput.Font = Enum.Font.Code
keyInput.ClearTextOnFocus = false
keyInput.TextXAlignment = Enum.TextXAlignment.Center
keyInput.Parent = card
corner(keyInput, 10)
stroke(keyInput, COLORS.border, 1, 0.15)

local status = label(card, "Waiting for key...", UDim2.new(1, -40, 0, 24), UDim2.fromOffset(20, 207), 10, COLORS.muted, Enum.Font.GothamMedium)
status.TextXAlignment = Enum.TextXAlignment.Center

local verifyButton = button(card, "VERIFY KEY  →", UDim2.new(1, -40, 0, 40), UDim2.fromOffset(20, 235), true)
local getKeyButton = button(card, "GET KEY URL", UDim2.new(1, -40, 0, 32), UDim2.fromOffset(20, 282), false)

local busy = false
local authenticated = false

local function setStatus(text, color)
    status.Text = text
    status.TextColor3 = color or COLORS.muted
end

local function loadSupportedGame(authResult)
    authenticated = true
    pageLabel.Text = "CHECKING GAME"
    infoLabel.Text = "Key accepted. Checking the current game automatically..."
    keyInput.Visible = false
    verifyButton.Visible = false
    getKeyButton.Visible = false
    status.Position = UDim2.fromOffset(20, 205)
    status.TextXAlignment = Enum.TextXAlignment.Center
    status.Text = "Key accepted. Checking PlaceId..."
    status.TextColor3 = COLORS.green

    task.spawn(function()
        local currentGameID = game.PlaceId
        local supportedGame = nil

        for _, gameInfo in ipairs(GAMES) do
            if currentGameID == gameInfo.placeId then
                supportedGame = gameInfo
                break
            end
        end

        if not supportedGame then
            pageLabel.Text = "UNSUPPORTED GAME"
            infoLabel.Text = "Panda Auth passed, but this game is not supported."
            setStatus("Unsupported PlaceId: " .. tostring(currentGameID), COLORS.red)
            return
        end

        pageLabel.Text = "LOADING SCRIPT"
        infoLabel.Text = "Supported game detected: " .. supportedGame.name
        setStatus("Loading " .. supportedGame.name .. "...", COLORS.green)

        local ok, err = pcall(function()
            local source = game:HttpGet(supportedGame.scriptUrl)
            if type(source) ~= "string" or #source == 0 then
                error("The game script returned no content.")
            end

            local chunk, compileError = loadstring(source)
            if not chunk then
                error(compileError or "Could not compile the game script.")
            end

            chunk()
        end)

        if not ok then
            setStatus("Load failed: " .. tostring(err), COLORS.red)
            warn("[EasySenp] Script load failed: " .. tostring(err))
        else
            setStatus("Game script started.", COLORS.green)
            task.wait(0.6)
            gui:Destroy()
        end
    end)
end

local function getPandaLibrary()
    local ok, library = pcall(function()
        local source = game:HttpGet(PANDA_LIBRARY_URL)
        local chunk, compileError = loadstring(source)
        if not chunk then error(compileError or "Could not compile Panda Auth library.") end
        return chunk()
    end)
    if not ok then return nil, tostring(library) end
    return library
end

local function verifyKey()
    if busy or authenticated then return end
    local key = keyInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if key == "" then
        setStatus("Please enter your key.", COLORS.red)
        return
    end

    busy = true
    verifyButton.Text = "VERIFYING..."
    setStatus("Connecting to Panda Auth...", COLORS.muted)

    task.spawn(function()
        local PUSL, libraryError = getPandaLibrary()
        if not PUSL or type(PUSL.configure) ~= "function" or type(PUSL.validate) ~= "function" then
            setStatus("Panda Auth library failed to initialize.", COLORS.red)
            warn("[Panda] Library failed: " .. tostring(libraryError))
            verifyButton.Text = "VERIFY KEY  →"
            busy = false
            return
        end

        local configured, configureError = pcall(function()
            PUSL.configure({ serviceId = PANDA_SERVICE_ID })
        end)
        if not configured then
            setStatus("Panda Auth configuration failed.", COLORS.red)
            warn("[Panda] Configure failed: " .. tostring(configureError))
            verifyButton.Text = "VERIFY KEY  →"
            busy = false
            return
        end

        local validCall, result = pcall(function()
            return PUSL.validate(key)
        end)
        if not validCall or type(result) ~= "table" or result.success ~= true then
            setStatus("Invalid key or verification failed.", COLORS.red)
            warn("[Panda] Get a key: " .. tostring(PUSL.getKeyUrl()))
            verifyButton.Text = "VERIFY KEY  →"
            busy = false
            return
        end

        print("[Panda] Authenticated. Premium:", result.isPremium)
        verifyButton.Text = "ACCESS GRANTED ✓"
        verifyButton.BackgroundColor3 = COLORS.green
        setStatus("Key accepted!", COLORS.green)
        busy = false
        task.wait(0.45)
        loadSupportedGame(result)
    end)
end

verifyButton.Activated:Connect(verifyKey)
keyInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then verifyKey() end
end)

getKeyButton.Activated:Connect(function()
    local PUSL, err = getPandaLibrary()
    if not PUSL or type(PUSL.configure) ~= "function" then
        setStatus("Could not connect to Panda Auth.", COLORS.red)
        warn("[Panda] " .. tostring(err))
        return
    end
    local ok, url = pcall(function()
        PUSL.configure({ serviceId = PANDA_SERVICE_ID })
        return PUSL.getKeyUrl()
    end)
    if not ok or type(url) ~= "string" or url == "" then
        setStatus("Could not get the key URL.", COLORS.red)
        return
    end
    if type(setclipboard) == "function" then
        local copied = pcall(setclipboard, url)
        if copied then
            setStatus("Key URL copied to clipboard.", COLORS.green)
        else
            setStatus("Key URL: " .. url, COLORS.muted)
        end
    else
        setStatus("Key URL: " .. url, COLORS.muted)
        warn("[Panda] Get a key: " .. url)
    end
end)
