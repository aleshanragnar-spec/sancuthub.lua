-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ScriptContext = game:GetService("ScriptContext")

-- Global State
getgenv().AutoCrafting = false
getgenv().ESPEnabled = false
getgenv().ESPRadius = 100000 

-- Combat Global State (Silent Aim)
getgenv().SilentAimEnabled = false
getgenv().SilentAimDistance = 1000 -- Max Studs Silent Aim

--------------------------------------------------------------------------------
-- [PROTECTION] ANTI-CHEAT BYPASS & CLIENT SHIELD
--------------------------------------------------------------------------------
pcall(function()
    -- 1. Disable Error Log Reporting to Server
    if getconnections then
        for _, conn in pairs(getconnections(ScriptContext.Error)) do
            conn:Disable()
        end
    end

    -- 2. Hook Index / Namecall Protection Shield (Metatable Cloaking)
    local rawmetatable = getrawmetatable or debug.getmetatable
    local setreadonly = setreadonly or make_writeable

    if rawmetatable and setreadonly then
        local gmt = rawmetatable(game)
        setreadonly(gmt, false)
        local oldIndex = gmt.__index

        gmt.__index = newcclosure(function(self, key)
            -- Sembunyikan objek UI Sancut Hub jika Anti-Cheat mencoba memindai CoreGui/PlayerGui
            if not checkcaller() and (key == "SancutMarshmallowUI" or key == "SancutLoadingUI" or key == "SancutESP") then
                return nil
            end
            return oldIndex(self, key)
        end)

        setreadonly(gmt, true)
    end
end)

-- Cleanup Gui Lama jika ada
if CoreGui:FindFirstChild("SancutMarshmallowUI") then
    CoreGui.SancutMarshmallowUI:Destroy()
end
if CoreGui:FindFirstChild("SancutLoadingUI") then
    CoreGui.SancutLoadingUI:Destroy()
end

--------------------------------------------------------------------------------
-- 0. LOADING SCREEN ANIMATION (SANCUT HUB)
--------------------------------------------------------------------------------
local LoadingGui = Instance.new("ScreenGui")
LoadingGui.Name = "SancutLoadingUI"
LoadingGui.Parent = CoreGui

local LoadFrame = Instance.new("Frame")
LoadFrame.Size = UDim2.new(0, 320, 0, 150)
LoadFrame.Position = UDim2.new(0.5, -160, 0.5, -75)
LoadFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
LoadFrame.BorderSizePixel = 0
LoadFrame.Parent = LoadingGui

local LoadCorner = Instance.new("UICorner")
LoadCorner.CornerRadius = UDim.new(0, 12)
LoadCorner.Parent = LoadFrame

local LoadStroke = Instance.new("UIStroke")
LoadStroke.Color = Color3.fromRGB(85, 45, 150)
LoadStroke.Thickness = 2
LoadStroke.Parent = LoadFrame

local LoadTitle = Instance.new("TextLabel")
LoadTitle.Size = UDim2.new(1, 0, 0, 40)
LoadTitle.Position = UDim2.new(0, 0, 0, 15)
LoadTitle.Text = "⚡ SANCUT HUB ⚡"
LoadTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
LoadTitle.Font = Enum.Font.GothamBold
LoadTitle.TextSize = 20
LoadTitle.BackgroundTransparency = 1
LoadTitle.Parent = LoadFrame

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Position = UDim2.new(0, 0, 0, 55)
StatusText.Text = "Bypassing Anti-Cheat..."
StatusText.TextColor3 = Color3.fromRGB(160, 160, 190)
StatusText.Font = Enum.Font.Gotham
StatusText.TextSize = 12
StatusText.BackgroundTransparency = 1
StatusText.Parent = LoadFrame

-- Bar Background
local BarBackground = Instance.new("Frame")
BarBackground.Size = UDim2.new(0.85, 0, 0, 10)
BarBackground.Position = UDim2.new(0.075, 0, 0, 95)
BarBackground.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
BarBackground.BorderSizePixel = 0
BarBackground.Parent = LoadFrame

local BarBgCorner = Instance.new("UICorner")
BarBgCorner.CornerRadius = UDim.new(1, 0)
BarBgCorner.Parent = BarBackground

-- Bar Fill (Progress)
local BarFill = Instance.new("Frame")
BarFill.Size = UDim2.new(0, 0, 1, 0)
BarFill.BackgroundColor3 = Color3.fromRGB(120, 50, 220)
BarFill.BorderSizePixel = 0
BarFill.Parent = BarBackground

local BarFillCorner = Instance.new("UICorner")
BarFillCorner.CornerRadius = UDim.new(1, 0)
BarFillCorner.Parent = BarFill

--------------------------------------------------------------------------------
-- 1. ANTI-AFK & UTILITIES
--------------------------------------------------------------------------------
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
end)

local function humanDelay(baseSeconds)
    local randomOffset = math.random(2, 6) / 10
    task.wait(baseSeconds + randomOffset)
end

--------------------------------------------------------------------------------
-- 2. ESP & ADVANCED SILENT AIM LOGIC
--------------------------------------------------------------------------------
local Camera = Workspace.CurrentCamera
local espHighlights = {}

local function createESP(player)
    if player == LocalPlayer then return end
    
    local function applyHighlight(character)
        if not character then return end
        local hrp = character:WaitForChild("HumanoidRootPart", 5)
        if not hrp then return end
        
        if not character:FindFirstChild("SancutESP") then
            local highlight = Instance.new("Highlight")
            highlight.Name = "SancutESP"
            highlight.FillColor = Color3.fromRGB(255, 0, 80)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.Enabled = false
            highlight.Parent = character
            espHighlights[player] = highlight
        end
    end
    
    if player.Character then applyHighlight(player.Character) end
    player.CharacterAdded:Connect(applyHighlight)
end

for _, player in pairs(Players:GetPlayers()) do createESP(player) end
Players.PlayerAdded:Connect(createESP)

-- Target Selection (Jarak 3D Studs & Sudut Pandang Kamera)
local function getClosestTarget()
    local closestTarget = nil
    local shortestDistance = getgenv().SilentAimDistance
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

    if not myHrp then return nil end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetPart = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            
            if targetPart and humanoid and humanoid.Health > 0 then
                local worldDist = (myHrp.Position - targetPart.Position).Magnitude
                
                if worldDist <= shortestDistance then
                    local _, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        shortestDistance = worldDist
                        closestTarget = targetPart
                    end
                end
            end
        end
    end
    return closestTarget
end

-- Hook Namecall untuk Peluru Magnet / Reroute Raycast (Anti-Cheat Safe)
pcall(function()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if getgenv().SilentAimEnabled and (method == "Raycast" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "FindPartOnRayWithWhitelist") then
            local targetPart = getClosestTarget()
            if targetPart then
                if method == "Raycast" then
                    local origin = args[1]
                    args[2] = (targetPart.Position - origin).Unit * 5000
                    return oldNamecall(self, unpack(args))
                elseif method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "FindPartOnRayWithWhitelist" then
                    local origin = Camera.CFrame.Position
                    if args[1] and typeof(args[1]) == "Ray" then
                        origin = args[1].Origin
                    end
                    args[1] = Ray.new(origin, (targetPart.Position - origin).Unit * 5000)
                    return oldNamecall(self, unpack(args))
                end
            end
        end
        return oldNamecall(self, ...)
    end))
end)

-- RenderStepped Update untuk ESP
RunService.RenderStepped:Connect(function()
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local highlight = char:FindFirstChild("SancutESP")
            
            if highlight and myHrp and hrp then
                local dist = (myHrp.Position - hrp.Position).Magnitude
                if getgenv().ESPEnabled and dist <= getgenv().ESPRadius then
                    highlight.Enabled = true
                else
                    highlight.Enabled = false
                end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- 3. INVENTORY & CRAFTING FUNCTIONS
--------------------------------------------------------------------------------
local function getItemCount(itemName)
    local count = 0
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local char = LocalPlayer.Character

    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and string.find(string.lower(tool.Name), string.lower(itemName)) then
                count = count + 1
            end
        end
    end
    if char then
        for _, tool in pairs(char:GetChildren()) do
            if tool:IsA("Tool") and string.find(string.lower(tool.Name), string.lower(itemName)) then
                count = count + 1
            end
        end
    end
    return count
end

local function equipItemDirect(itemName)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    
    if not humanoid then return false end
    humanoid:UnequipTools()
    task.wait(0.2)
    
    if backpack then
        for _, item in pairs(backpack:GetChildren()) do
            if item:IsA("Tool") and string.find(string.lower(item.Name), string.lower(itemName)) then
                humanoid:EquipTool(item)
                humanDelay(0.3)
                return true
            end
        end
    end
    return false
end

local function forcePressE()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                local parent = obj.Parent
                local targetPos = parent:IsA("BasePart") and parent.Position or (parent:IsA("Model") and parent.PrimaryPart and parent.PrimaryPart.Position)
                
                if targetPos and (hrp.Position - targetPos).Magnitude <= 20 then
                    if fireproximityprompt then 
                        pcall(function() fireproximityprompt(obj) end)
                    end
                    break
                end
            end
        end
    end

    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(math.random(25, 40) / 100)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function countdownWait(seconds)
    for i = 1, seconds do
        if not getgenv().AutoCrafting then return false end
        task.wait(1)
    end
    return true
end

--------------------------------------------------------------------------------
-- 4. GUI CREATION (SANCUT HUB 2-COLUMN LAYOUT)
--------------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SancutMarshmallowUI"
ScreenGui.Parent = CoreGui
ScreenGui.Enabled = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 390)
MainFrame.Position = UDim2.new(0.5, -280, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(75, 40, 130)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

-- Header Title
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 0, 35)
TitleLabel.Position = UDim2.new(0, 15, 0, 5)
TitleLabel.Text = "⚡ Sancut Hub • Main Menu [K: Toggle]"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.BackgroundTransparency = 1
TitleLabel.Parent = MainFrame

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -30, 0, 10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.Parent = MainFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(1, 0)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    getgenv().AutoCrafting = false
    getgenv().ESPEnabled = false
    getgenv().SilentAimEnabled = false
    ScreenGui:Destroy()
end)

--------------------------------------------------------------------------------
-- 5. SISI KIRI (MAIN & INVENTORY)
--------------------------------------------------------------------------------
local LeftColumn = Instance.new("Frame")
LeftColumn.Size = UDim2.new(0.5, -20, 1, -50)
LeftColumn.Position = UDim2.new(0, 15, 0, 40)
LeftColumn.BackgroundTransparency = 1
LeftColumn.Parent = MainFrame

-- Inventory Container Card
local Card = Instance.new("Frame")
Card.Size = UDim2.new(1, 0, 0, 115)
Card.Position = UDim2.new(0, 0, 0, 0)
Card.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
Card.Parent = LeftColumn

local CardCorner = Instance.new("UICorner")
CardCorner.CornerRadius = UDim.new(0, 8)
CardCorner.Parent = Card

local CardTitle = Instance.new("TextLabel")
CardTitle.Size = UDim2.new(1, -20, 0, 22)
CardTitle.Position = UDim2.new(0, 10, 0, 2)
CardTitle.Text = "🎨 Inventory Status"
CardTitle.TextColor3 = Color3.fromRGB(160, 160, 180)
CardTitle.Font = Enum.Font.GothamSemibold
CardTitle.TextSize = 11
CardTitle.TextXAlignment = Enum.TextXAlignment.Left
CardTitle.BackgroundTransparency = 1
CardTitle.Parent = Card

local function createItemRow(iconText, nameText, posY)
    local lblName = Instance.new("TextLabel")
    lblName.Size = UDim2.new(0.6, 0, 0, 18)
    lblName.Position = UDim2.new(0, 15, 0, posY)
    lblName.Text = iconText .. " " .. nameText
    lblName.TextColor3 = Color3.fromRGB(180, 180, 200)
    lblName.Font = Enum.Font.Gotham
    lblName.TextSize = 11
    lblName.TextXAlignment = Enum.TextXAlignment.Left
    lblName.BackgroundTransparency = 1
    lblName.Parent = Card

    local lblVal = Instance.new("TextLabel")
    lblVal.Size = UDim2.new(0.3, 0, 0, 18)
    lblVal.Position = UDim2.new(0.65, 0, 0, posY)
    lblVal.Text = "0"
    lblVal.TextColor3 = Color3.fromRGB(220, 60, 60)
    lblVal.Font = Enum.Font.GothamBold
    lblVal.TextSize = 11
    lblVal.TextXAlignment = Enum.TextXAlignment.Right
    lblVal.BackgroundTransparency = 1
    lblVal.Parent = Card

    return lblVal
end

local WaterVal = createItemRow("💧", "Water", 25)
local SugarVal = createItemRow("🍬", "Sugar Block", 45)
local GelatinVal = createItemRow("🟡", "Gelatin", 65)
local CanMakeVal = createItemRow("🍳", "Can Make", 85)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 18)
StatusLabel.Position = UDim2.new(0, 0, 0, 125)
StatusLabel.Text = "⬛ Macro: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
StatusLabel.Font = Enum.Font.GothamSemibold
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.BackgroundTransparency = 1
StatusLabel.Parent = LeftColumn

local StartBtn = Instance.new("TextButton")
StartBtn.Size = UDim2.new(1, 0, 0, 30)
StartBtn.Position = UDim2.new(0, 0, 0, 148)
StartBtn.BackgroundColor3 = Color3.fromRGB(15, 140, 45)
StartBtn.Text = "▶ START AutoFarm"
StartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StartBtn.Font = Enum.Font.GothamBold
StartBtn.TextSize = 11
StartBtn.Parent = LeftColumn

local StartCorner = Instance.new("UICorner")
StartCorner.CornerRadius = UDim.new(0, 6)
StartCorner.Parent = StartBtn

local StopBtn = Instance.new("TextButton")
StopBtn.Size = UDim2.new(1, 0, 0, 30)
StopBtn.Position = UDim2.new(0, 0, 0, 184)
StopBtn.BackgroundColor3 = Color3.fromRGB(160, 25, 25)
StopBtn.Text = "⏹ STOP"
StopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StopBtn.Font = Enum.Font.GothamBold
StopBtn.TextSize = 11
StopBtn.Parent = LeftColumn

local StopCorner = Instance.new("UICorner")
StopCorner.CornerRadius = UDim.new(0, 6)
StopCorner.Parent = StopBtn

local CheckBtn = Instance.new("TextButton")
CheckBtn.Size = UDim2.new(1, 0, 0, 30)
CheckBtn.Position = UDim2.new(0, 0, 0, 220)
CheckBtn.BackgroundColor3 = Color3.fromRGB(20, 40, 130)
CheckBtn.Text = "🔍 Cek Inventory"
CheckBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CheckBtn.Font = Enum.Font.GothamBold
CheckBtn.TextSize = 11
CheckBtn.Parent = LeftColumn

local CheckCorner = Instance.new("UICorner")
CheckCorner.CornerRadius = UDim.new(0, 6)
CheckCorner.Parent = CheckBtn

--------------------------------------------------------------------------------
-- 6. SISI KANAN (COMBAT MENU - SILENT AIM & SLIDERS)
--------------------------------------------------------------------------------
local RightColumn = Instance.new("Frame")
RightColumn.Size = UDim2.new(0.5, -20, 1, -50)
RightColumn.Position = UDim2.new(0.5, 5, 0, 40)
RightColumn.BackgroundTransparency = 1
RightColumn.Parent = MainFrame

local CombatCard = Instance.new("Frame")
CombatCard.Size = UDim2.new(1, 0, 1, -5)
CombatCard.Position = UDim2.new(0, 0, 0, 0)
CombatCard.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
CombatCard.Parent = RightColumn

local CombatCardCorner = Instance.new("UICorner")
CombatCardCorner.CornerRadius = UDim.new(0, 8)
CombatCardCorner.Parent = CombatCard

local CombatTitle = Instance.new("TextLabel")
CombatTitle.Size = UDim2.new(1, -20, 0, 22)
CombatTitle.Position = UDim2.new(0, 10, 0, 5)
CombatTitle.Text = "⚔️ Combat Settings"
CombatTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
CombatTitle.Font = Enum.Font.GothamBold
CombatTitle.TextSize = 12
CombatTitle.TextXAlignment = Enum.TextXAlignment.Left
CombatTitle.BackgroundTransparency = 1
CombatTitle.Parent = CombatCard

-- ESP Toggle Button
local ToggleESPBtn = Instance.new("TextButton")
ToggleESPBtn.Size = UDim2.new(1, -20, 0, 26)
ToggleESPBtn.Position = UDim2.new(0, 10, 0, 32)
ToggleESPBtn.BackgroundColor3 = Color3.fromRGB(160, 25, 25)
ToggleESPBtn.Text = "👁️ ESP Player: OFF"
ToggleESPBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleESPBtn.Font = Enum.Font.GothamBold
ToggleESPBtn.TextSize = 10
ToggleESPBtn.Parent = CombatCard

local ESPCorner = Instance.new("UICorner")
ESPCorner.CornerRadius = UDim.new(0, 6)
ESPCorner.Parent = ToggleESPBtn

-- Silent Aim Toggle Button
local ToggleSilentBtn = Instance.new("TextButton")
ToggleSilentBtn.Size = UDim2.new(1, -20, 0, 26)
ToggleSilentBtn.Position = UDim2.new(0, 10, 0, 64)
ToggleSilentBtn.BackgroundColor3 = Color3.fromRGB(160, 25, 25)
ToggleSilentBtn.Text = "🎯 Silent Aim: OFF"
ToggleSilentBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleSilentBtn.Font = Enum.Font.GothamBold
ToggleSilentBtn.TextSize = 10
ToggleSilentBtn.Parent = CombatCard

local SilentCorner = Instance.new("UICorner")
SilentCorner.CornerRadius = UDim.new(0, 6)
SilentCorner.Parent = ToggleSilentBtn

--------------------------------------------------------------------------------
-- SLIDER 1: SILENT AIM STUDS DISTANCE (10 - 1000 STUDS)
--------------------------------------------------------------------------------
local SilentAimLabel = Instance.new("TextLabel")
SilentAimLabel.Size = UDim2.new(1, -20, 0, 16)
SilentAimLabel.Position = UDim2.new(0, 10, 0, 98)
SilentAimLabel.Text = "🎯 Silent Aim Range: 1,000 Studs"
SilentAimLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
SilentAimLabel.Font = Enum.Font.GothamSemibold
SilentAimLabel.TextSize = 10
SilentAimLabel.TextXAlignment = Enum.TextXAlignment.Left
SilentAimLabel.BackgroundTransparency = 1
SilentAimLabel.Parent = CombatCard

local SilentTrack = Instance.new("TextButton")
SilentTrack.Size = UDim2.new(1, -20, 0, 14)
SilentTrack.Position = UDim2.new(0, 10, 0, 118)
SilentTrack.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
SilentTrack.AutoButtonColor = false
SilentTrack.Text = ""
SilentTrack.Parent = CombatCard

local SilentTrackCorner = Instance.new("UICorner")
SilentTrackCorner.CornerRadius = UDim.new(1, 0)
SilentTrackCorner.Parent = SilentTrack

local SilentFill = Instance.new("Frame")
SilentFill.Size = UDim2.new(1, 0, 1, 0)
SilentFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
SilentFill.BorderSizePixel = 0
SilentFill.Parent = SilentTrack

local SilentFillCorner = Instance.new("UICorner")
SilentFillCorner.CornerRadius = UDim.new(1, 0)
SilentFillCorner.Parent = SilentTrack

--------------------------------------------------------------------------------
-- SLIDER 2: ESP RADIUS (10 - 100000 STUDS)
--------------------------------------------------------------------------------
local RadiusLabel = Instance.new("TextLabel")
RadiusLabel.Size = UDim2.new(1, -20, 0, 16)
RadiusLabel.Position = UDim2.new(0, 10, 0, 142)
RadiusLabel.Text = "📏 ESP Radius: 100,000 Studs"
RadiusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
RadiusLabel.Font = Enum.Font.GothamSemibold
RadiusLabel.TextSize = 10
RadiusLabel.TextXAlignment = Enum.TextXAlignment.Left
RadiusLabel.BackgroundTransparency = 1
RadiusLabel.Parent = CombatCard

local SliderTrack = Instance.new("TextButton")
SliderTrack.Size = UDim2.new(1, -20, 0, 14)
SliderTrack.Position = UDim2.new(0, 10, 0, 162)
SliderTrack.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
SliderTrack.AutoButtonColor = false
SliderTrack.Text = ""
SliderTrack.Parent = CombatCard

local TrackCorner = Instance.new("UICorner")
TrackCorner.CornerRadius = UDim.new(1, 0)
TrackCorner.Parent = SliderTrack

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(1, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(120, 50, 220)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = SliderTrack

local FillCorner = Instance.new("UICorner")
FillCorner.CornerRadius = UDim.new(1, 0)
FillCorner.Parent = SliderFill

--------------------------------------------------------------------------------
-- SLIDERS DRAG LOGIC
--------------------------------------------------------------------------------
local draggingSlider = nil

local function updateSliderESP(input)
    local trackPos = SliderTrack.AbsolutePosition.X
    local trackSize = SliderTrack.AbsoluteSize.X
    local mouseX = input.Position.X
    
    local percentage = math.clamp((mouseX - trackPos) / trackSize, 0, 1)
    local calculatedValue = math.floor(10 + percentage * (100000 - 10))
    
    getgenv().ESPRadius = calculatedValue
    SliderFill.Size = UDim2.new(percentage, 0, 1, 0)
    
    local formattedValue = tostring(calculatedValue):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    RadiusLabel.Text = "📏 ESP Radius: " .. formattedValue .. " Studs"
end

local function updateSliderSilent(input)
    local trackPos = SilentTrack.AbsolutePosition.X
    local trackSize = SilentTrack.AbsoluteSize.X
    local mouseX = input.Position.X
    
    local percentage = math.clamp((mouseX - trackPos) / trackSize, 0, 1)
    local calculatedValue = math.floor(10 + percentage * (1000 - 10))
    
    getgenv().SilentAimDistance = calculatedValue
    SilentFill.Size = UDim2.new(percentage, 0, 1, 0)
    
    local formattedValue = tostring(calculatedValue):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    SilentAimLabel.Text = "🎯 Silent Aim Range: " .. formattedValue .. " Studs"
end

SliderTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = "ESP"
        updateSliderESP(input)
    end
end)

SilentTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = "Silent"
        updateSliderSilent(input)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if draggingSlider == "ESP" then
            updateSliderESP(input)
        elseif draggingSlider == "Silent" then
            updateSliderSilent(input)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = nil
    end
end)

--------------------------------------------------------------------------------
-- 7. KEYBOARD SHORTCUT (TOGGLE BUKA / TUTUP SANCUT HUB DENGAN TOMBOL 'K')
--------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    -- Mengabaikan input jika pemain sedang mengetik di Chat atau Input UI lain
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.K then
        if ScreenGui then
            ScreenGui.Enabled = not ScreenGui.Enabled
        end
    end
end)

--------------------------------------------------------------------------------
-- 8. EVENTS & LOGIC CONNECTIONS
--------------------------------------------------------------------------------
local function updateInventoryUI()
    local w = getItemCount("Water")
    local s = getItemCount("Sugar")
    local g = getItemCount("Gelatin")
    
    WaterVal.Text = tostring(w)
    SugarVal.Text = tostring(s)
    GelatinVal.Text = tostring(g)
    
    local canMake = math.min(w, s, g)
    CanMakeVal.Text = tostring(canMake) .. "x Marsh"
end

ToggleESPBtn.MouseButton1Click:Connect(function()
    getgenv().ESPEnabled = not getgenv().ESPEnabled
    if getgenv().ESPEnabled then
        ToggleESPBtn.Text = "👁️ ESP Player: ON"
        ToggleESPBtn.BackgroundColor3 = Color3.fromRGB(15, 140, 45)
    else
        ToggleESPBtn.Text = "👁️ ESP Player: OFF"
        ToggleESPBtn.BackgroundColor3 = Color3.fromRGB(160, 25, 25)
    end
end)

ToggleSilentBtn.MouseButton1Click:Connect(function()
    getgenv().SilentAimEnabled = not getgenv().SilentAimEnabled
    if getgenv().SilentAimEnabled then
        ToggleSilentBtn.Text = "🎯 Silent Aim: ON"
        ToggleSilentBtn.BackgroundColor3 = Color3.fromRGB(15, 140, 45)
    else
        ToggleSilentBtn.Text = "🎯 Silent Aim: OFF"
        ToggleSilentBtn.BackgroundColor3 = Color3.fromRGB(160, 25, 25)
    end
end)

CheckBtn.MouseButton1Click:Connect(updateInventoryUI)

StartBtn.MouseButton1Click:Connect(function()
    if getgenv().AutoCrafting then return end
    getgenv().AutoCrafting = true
    StatusLabel.Text = "🟩 Macro: Running"
    StatusLabel.TextColor3 = Color3.fromRGB(50, 220, 100)
    
    task.spawn(function()
        while getgenv().AutoCrafting do
            updateInventoryUI()
            
            if not getgenv().AutoCrafting then break end
            equipItemDirect("Water")
            forcePressE()
            humanDelay(0.5)
            if not countdownWait(25) then break end

            if not getgenv().AutoCrafting then break end
            equipItemDirect("Sugar")
            forcePressE()
            humanDelay(0.5)
            if not countdownWait(1) then break end

            if not getgenv().AutoCrafting then break end
            equipItemDirect("Gelatin")
            forcePressE()
            humanDelay(0.5)
            if not countdownWait(60) then break end

            if not getgenv().AutoCrafting then break end
            equipItemDirect("Empty Bag")
            forcePressE()
            humanDelay(0.5)
            if not countdownWait(1) then break end
        end
        StatusLabel.Text = "⬛ Macro: Idle"
        StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
    end)
end)

StopBtn.MouseButton1Click:Connect(function()
    getgenv().AutoCrafting = false
    StatusLabel.Text = "🟥 Macro: Stopping..."
    StatusLabel.TextColor3 = Color3.fromRGB(240, 70, 70)
end)

updateInventoryUI()

--------------------------------------------------------------------------------
-- 9. EXECUTE ANIMATION SEQUENCE (FIXED & NON-BLOCKING)
--------------------------------------------------------------------------------
task.spawn(function()
    StatusText.Text = "Bypassing Anti-Cheat..."
    local tween1 = TweenService:Create(BarFill, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {Size = UDim2.new(0.4, 0, 1, 0)})
    tween1:Play()
    tween1.Completed:Wait()
    
    StatusText.Text = "Loading Anti-AFK & Protection..."
    local tween2 = TweenService:Create(BarFill, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {Size = UDim2.new(0.8, 0, 1, 0)})
    tween2:Play()
    tween2.Completed:Wait()
    
    StatusText.Text = "Finalizing Interface..."
    local tween3 = TweenService:Create(BarFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = UDim2.new(1, 0, 1, 0)})
    tween3:Play()
    tween3.Completed:Wait()
    
    task.wait(0.2)
    
    -- Transisi hapus Loading Screen dan tampilkan Main UI
    LoadingGui:Destroy()
    ScreenGui.Enabled = true
end)
