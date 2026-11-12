-- HipHub GrowBlox loader (verbatim retrieval, 2026-03-28)
-- Retrieved from: https://hiphub.cloud/api/script-roblox/growblox
-- Request context: no query parameters (plain GET).
-- Response: HTTP 200 with the bootstrap source below.
-- Note: with the provided premium key the same endpoint returns a
--       dynamically generated "HWID is max" error UI instead of this
--       bootstrap source. See the reverse engineering report for details.

repeat task.wait() until game:IsLoaded()

local player = game:GetService("Players").LocalPlayer
while not player do
    task.wait(0.5)
    player = game:GetService("Players").LocalPlayer
end

local function findGuiInParents(name)
    if gethui then
        local g = gethui():FindFirstChild(name)
        if g then return g end
    end
    local c = game:GetService("CoreGui"):FindFirstChild(name)
    if c then return c end
    local p = player:WaitForChild("PlayerGui"):FindFirstChild(name)
    if p then return p end
    return nil
end

local gui = findGuiInParents("HipHub_GrowBlox") or findGuiInParents("HipHub")
if gui then
    return
end

local key = _G.hiphub_key or (shared and shared.hiphub_key) or (getgenv and getgenv().hiphub_key) or hiphub_key
if not key and isfile and readfile then
    if isfile("HipHub/key.txt") then
        local saved = readfile("HipHub/key.txt")
        if saved and saved ~= "" then
            key = saved:gsub("%s+", "")
        end
    elseif isfile("hiphub_key.txt") then
        local saved = readfile("hiphub_key.txt")
        if saved and saved ~= "" then
            key = saved:gsub("%s+", "")
        end
    end
end

local function showLocalError(errorMessage)
    local player = game:GetService("Players").LocalPlayer
    local errGui = Instance.new("ScreenGui")
    errGui.Name = "HipHubError"
    errGui.ResetOnSpawn = false
    errGui.DisplayOrder = 2147483647

    pcall(function()
        local oldErr = findGuiInParents("HipHubError")
        if oldErr then oldErr:Destroy() end
    end)

    pcall(function()
        local parentGui
        if gethui then
            parentGui = gethui()
        else
            local coreGui = game:GetService("CoreGui")
            local successCore, _ = pcall(function()
                local test = Instance.new("Folder")
                test.Parent = coreGui
                test:Destroy()
            end)
            if successCore then
                parentGui = coreGui
            else
                parentGui = player:WaitForChild("PlayerGui")
            end
        end
        errGui.Parent = parentGui

        local TweenService = game:GetService("TweenService")

        local COLORS = {
            glassSurface  = Color3.fromRGB(16, 20, 36),
            glassCard     = Color3.fromRGB(20, 24, 44),
            accentCyan    = Color3.fromRGB(0, 200, 255),
            accentViolet  = Color3.fromRGB(140, 120, 255),
            textPrimary   = Color3.fromRGB(225, 235, 255),
            textSecondary = Color3.fromRGB(140, 155, 185),
            borderGlass   = Color3.fromRGB(50, 65, 110),
        }

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 480, 0, 180)
        frame.Position = UDim2.new(0.5, -240, 0.5, -90)
        frame.BackgroundColor3 = COLORS.glassSurface
        frame.BackgroundTransparency = 0.05
        frame.BorderSizePixel = 0
        frame.ClipsDescendants = true
        frame.Parent = errGui

        local errCorner = Instance.new("UICorner")
        errCorner.CornerRadius = UDim.new(0, 12)
        errCorner.Parent = frame

        local errStroke = Instance.new("UIStroke")
        errStroke.Color = COLORS.borderGlass
        errStroke.Thickness = 1
        errStroke.Transparency = 0.55
        errStroke.Parent = frame

        local topBar = Instance.new("Frame")
        topBar.Size = UDim2.new(1, 0, 0, 38)
        topBar.BackgroundColor3 = COLORS.glassCard
        topBar.BackgroundTransparency = 0.08
        topBar.BorderSizePixel = 0
        topBar.Parent = frame

        local topBarCorner = Instance.new("UICorner")
        topBarCorner.CornerRadius = UDim.new(0, 12)
        topBarCorner.Parent = topBar

        local topBarStroke = Instance.new("UIStroke")
        topBarStroke.Color = COLORS.borderGlass
        topBarStroke.Thickness = 1
        topBarStroke.Transparency = 0.75
        topBarStroke.Parent = topBar

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -40, 1, 0)
        title.Position = UDim2.new(0, 16, 0, 0)
        title.BackgroundTransparency = 1
        title.Text = "HIPHUB ACCESS DENIED"
        title.TextColor3 = Color3.fromRGB(255, 100, 100)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 10
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = topBar

        local closeButton = Instance.new("TextButton")
        closeButton.Size = UDim2.new(0, 28, 0, 28)
        closeButton.Position = UDim2.new(1, -34, 0.5, -14)
        closeButton.BackgroundTransparency = 1
        closeButton.Text = "X"
        closeButton.TextColor3 = COLORS.textSecondary
        closeButton.Font = Enum.Font.GothamBold
        closeButton.TextSize = 12
        closeButton.Parent = topBar

        closeButton.MouseEnter:Connect(function()
            TweenService:Create(closeButton, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 80, 80)}):Play()
        end)
        closeButton.MouseLeave:Connect(function()
            TweenService:Create(closeButton, TweenInfo.new(0.15), {TextColor3 = COLORS.textSecondary}):Play()
        end)

        closeButton.MouseButton1Click:Connect(function()
            errGui:Destroy()
        end)

        local body = Instance.new("TextLabel")
        body.Size = UDim2.new(1, -32, 0, 60)
        body.Position = UDim2.new(0, 16, 0, 52)
        body.BackgroundTransparency = 1
        body.Text = errorMessage
        body.TextColor3 = COLORS.textPrimary
        body.Font = Enum.Font.Gotham
        body.TextSize = 11
        body.TextWrapped = true
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.Parent = frame

        local actionButton = Instance.new("TextButton")
        actionButton.Size = UDim2.new(1, -32, 0, 36)
        actionButton.Position = UDim2.new(0, 16, 1, -52)
        actionButton.BackgroundColor3 = COLORS.accentViolet
        actionButton.BackgroundTransparency = 0.15
        actionButton.Text = "BUY PREMIUM KEY (CLICK TO COPY LINK)"
        actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        actionButton.Font = Enum.Font.GothamBold
        actionButton.TextSize = 10
        actionButton.Parent = frame

        local actionCorner = Instance.new("UICorner")
        actionCorner.CornerRadius = UDim.new(0, 6)
        actionCorner.Parent = actionButton

        local actionStroke = Instance.new("UIStroke")
        actionStroke.Color = COLORS.accentViolet
        actionStroke.Thickness = 1
        actionStroke.Transparency = 0.4
        actionStroke.Parent = actionButton

        actionButton.MouseEnter:Connect(function()
            TweenService:Create(actionButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.05}):Play()
        end)
        actionButton.MouseLeave:Connect(function()
            TweenService:Create(actionButton, TweenInfo.new(0.2), {BackgroundTransparency = 0.15}):Play()
        end)

        actionButton.MouseButton1Click:Connect(function()
            pcall(function()
                if setclipboard then
                    setclipboard("https://hiphub.cloud/")
                    actionButton.Text = "COPIED LINK TO CLIPBOARD!"
                    task.wait(2)
                    actionButton.Text = "BUY PREMIUM KEY (CLICK TO COPY LINK)"
                else
                    actionButton.Text = "YOUR EXECUTOR DOESN'T SUPPORT SETCLIPBOARD!"
                end
            end)
        end)
    end)
end

if not key then
    warn("HipHub Access Denied: Key is missing. Checked _G.hiphub_key, shared.hiphub_key, getgenv().hiphub_key, and files.")
    showLocalError("Access Denied. Please set _G.hiphub_key before executing! Purchase a premium key at https://hiphub.cloud/")
    return
end

_G.hiphub_key = key
if getgenv then getgenv().hiphub_key = key end

local hwid = "unknown"
local playername = "unknown"
local executor = "unknown"
pcall(function()
    hwid = (gethwid and gethwid()) or game:GetService("RbxAnalyticsService"):GetClientId() or "unknown"
    playername = game:GetService("Players").LocalPlayer.Name or "unknown"
    local execName = identifyexecutor or getexecutorname
    if execName then
        executor = execName()
    end
end)

local encodedExecutor = "unknown"
pcall(function()
    encodedExecutor = game:GetService("HttpService"):UrlEncode(executor)
end)

local url = "https://hiphub.cloud/api/script-roblox/growblox?key=" .. tostring(key) .. "&hwid=" .. tostring(hwid) .. "&username=" .. tostring(playername) .. "&gameId=" .. tostring(game.GameId) .. "&placeId=" .. tostring(game.PlaceId) .. "&executor=" .. tostring(encodedExecutor) .. "&cb=" .. tostring(math.random(100000, 999999))
local success, content
for i = 1, 3 do
    success, content = pcall(function()
        return game:HttpGet(url)
    end)
    if success then
        break
    end
    if i < 3 then
        task.wait(1.5)
    end
end

if not success then
    showLocalError("Execute error: network latency. Please check your connection and try again!")
    return
end

local func, err = loadstring(content)
if not func then
    local errStr = tostring(err)
    warn("HipHub Loader Error: " .. errStr)
    showLocalError("Execute error: script initialization failure. Please try again!")
    return
end

func()
