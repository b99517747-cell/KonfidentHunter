--[[
    Konfident Hunter v7.0
    - Config oparty na ID kont Roblox (nie nickach)
    - Rayfield GUI (klawisz K)
    - Osobny panel listy z avatarami z Roblox API
    - Spectate po kliknięciu gracza na liście
    - Highlight + tekst "Konfident" nad głową
    - Auto-odświeżanie co 30 sekund
]]

-- ===== KONFIGURACJA =====
local REFRESH_TIME = 30
local CONFIG_URL   = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"
-- ========================

local Rayfield    = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local currentConfig  = { konfidenci = {}, ustawienia = {} }
local activeMarkers  = {}   -- [gracz] = Folder w character
local userNameCache  = {}   -- [userId] = "nick"
local userAvatarCache = {}  -- [userId] = "rbxthumb://..."
local spectateTarget = nil
local listVisible    = false
local listGui        = nil
local listFrame      = nil

-- ===== HELPERS =====
local function getUstawienia()
    return currentConfig.ustawienia or {
        kolorPodswietlenia = {255, 170, 0},
        przezroczystosc    = 0.4,
        tekstNadGlowa      = "Konfident",
        kolorTekstu        = {255, 255, 255},
    }
end

local function czyJestKonfidentem(gracz)
    return currentConfig.konfidenci and currentConfig.konfidenci[gracz.UserId] == true
end

-- ===== ROBLOX API – nick z ID =====
local function getNazwa(userId)
    if userNameCache[userId] then return userNameCache[userId] end
    local ok, name = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)
    if ok and name then
        userNameCache[userId] = name
        return name
    end
    return "ID:" .. tostring(userId)
end

-- ===== ROBLOX API – avatar headshot =====
local function getAvatar(userId)
    if userAvatarCache[userId] then return userAvatarCache[userId] end
    local ok, url = pcall(function()
        local thumbUrl, _ = Players:GetUserThumbnailAsync(
            userId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size150x150
        )
        return thumbUrl
    end)
    if ok and url then
        userAvatarCache[userId] = url
        return url
    end
    return ""
end

-- ===== POBIERANIE CONFIGU =====
local function pobierzKonfiguracje()
    local ok, result = pcall(function() return game:HttpGet(CONFIG_URL) end)
    if not ok then warn("❌ HttpGet: " .. tostring(result)); return nil end
    local func, err = loadstring(result)
    if not func then warn("❌ loadstring: " .. tostring(err)); return nil end
    local ok2, config = pcall(func)
    if not ok2 then warn("❌ pcall: " .. tostring(config)); return nil end
    return config
end

-- ===== OZNACZENIA =====
local function usunOznaczenia(gracz)
    local folder = activeMarkers[gracz]
    if folder then
        pcall(function() folder:Destroy() end)
        activeMarkers[gracz] = nil
    end
    local char = gracz.Character
    if char then
        local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if head then
            local bb = head:FindFirstChild("TekstKonfidenta")
            if bb then pcall(function() bb:Destroy() end) end
        end
    end
end

local function dodajOznaczenia(gracz)
    if not czyJestKonfidentem(gracz) then return false end
    local character = gracz.Character
    if not character then return false end

    local headPart = character:FindFirstChild("Head")
                  or character:FindFirstChild("HumanoidRootPart")
                  or character:FindFirstChild("UpperTorso")
    if not headPart then return false end

    if activeMarkers[gracz] then usunOznaczenia(gracz) end

    local folder = Instance.new("Folder")
    folder.Name = "KonfidentMarkery"
    folder.Parent = character
    activeMarkers[gracz] = folder

    local ust = getUstawienia()
    local k   = ust.kolorPodswietlenia or {255, 170, 0}

    -- Highlight (cały model)
    local highlight = Instance.new("Highlight")
    highlight.FillColor          = Color3.fromRGB(k[1], k[2], k[3])
    highlight.FillTransparency   = ust.przezroczystosc or 0.4
    highlight.OutlineColor       = Color3.fromRGB(k[1], k[2], k[3])
    highlight.OutlineTransparency = 0.0
    highlight.Adornee            = character
    highlight.Parent             = folder

    -- Tekst nad głową
    local billboard = Instance.new("BillboardGui")
    billboard.Name         = "TekstKonfidenta"
    billboard.AlwaysOnTop  = true
    billboard.Size         = UDim2.new(0, 220, 0, 40)
    billboard.StudsOffset  = Vector3.new(0, 2.3, 0)
    billboard.Adornee      = headPart
    billboard.Parent       = headPart

    local lbl = Instance.new("TextLabel")
    lbl.Size                  = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                  = ust.tekstNadGlowa or "Konfident"
    lbl.TextColor3            = Color3.fromRGB(k[1], k[2], k[3])
    lbl.TextScaled            = true
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0.0
    lbl.Parent                = billboard

    return true
end

-- ===== SPECTATE =====
local function spectateGracza(gracz)
    if not gracz or not gracz.Character then return end
    local humanoid = gracz.Character:FindFirstChild("Humanoid")
    if not humanoid then return end
    spectateTarget = gracz
    Camera.CameraType    = Enum.CameraType.Custom
    Camera.CameraSubject = humanoid
    Rayfield:Notify({
        Title   = "👁 Spectate",
        Content = "Obserwujesz: " .. gracz.Name,
        Duration = 3,
        Image    = "eye",
    })
end

local function stopSpectate()
    spectateTarget = nil
    local char = LocalPlayer.Character
    if char then
        local h = char:FindFirstChild("Humanoid")
        if h then
            Camera.CameraType    = Enum.CameraType.Custom
            Camera.CameraSubject = h
        end
    end
    Rayfield:Notify({ Title = "⏹ Spectate", Content = "Wróciłeś do siebie.", Duration = 2, Image = "eye-off" })
end

-- ===== PANEL LISTY Z AVATARAMI =====
local function odswiezListGui()
    if not listGui then return end
    local scroll = listFrame:FindFirstChild("PlayerScroll")
    if not scroll then return end

    -- Wyczyść
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end

    -- Zbierz konfidentów online
    local online = {}
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer and czyJestKonfidentem(gracz) then
            table.insert(online, gracz)
        end
    end

    if #online == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size               = UDim2.new(1, 0, 0, 60)
        empty.BackgroundTransparency = 1
        empty.Text               = "Żaden konfident nie jest teraz\nna tym serwerze."
        empty.TextColor3         = Color3.fromRGB(140, 140, 140)
        empty.TextSize           = 13
        empty.Font               = Enum.Font.Gotham
        empty.TextWrapped        = true
        empty.Parent             = scroll
        return
    end

    for _, gracz in ipairs(online) do
        local userId = gracz.UserId

        -- Karta
        local card = Instance.new("Frame")
        card.Size                = UDim2.new(1, 0, 0, 74)
        card.BackgroundColor3    = Color3.fromRGB(26, 26, 34)
        card.BackgroundTransparency = 0.05
        card.BorderSizePixel     = 0
        card.Parent              = scroll

        local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 10); cc.Parent = card
        local cs = Instance.new("UIStroke")
        cs.Color = Color3.fromRGB(255, 170, 0); cs.Thickness = 1; cs.Transparency = 0.65
        cs.Parent = card

        -- Avatar
        local avatar = Instance.new("ImageLabel")
        avatar.Size             = UDim2.new(0, 56, 0, 56)
        avatar.Position         = UDim2.new(0, 9, 0.5, -28)
        avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
        avatar.BorderSizePixel  = 0
        avatar.Image            = ""
        avatar.ScaleType        = Enum.ScaleType.Fit
        avatar.Parent           = card
        local ac = Instance.new("UICorner"); ac.CornerRadius = UDim.new(0, 8); ac.Parent = avatar

        -- Załaduj avatar asynchronicznie
        task.spawn(function()
            local url = getAvatar(userId)
            if avatar and avatar.Parent then
                avatar.Image = url
            end
        end)

        -- Nick
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size             = UDim2.new(1, -140, 0, 24)
        nameLabel.Position         = UDim2.new(0, 73, 0, 10)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text             = gracz.Name
        nameLabel.TextColor3       = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize         = 14
        nameLabel.Font             = Enum.Font.GothamBold
        nameLabel.TextXAlignment   = Enum.TextXAlignment.Left
        nameLabel.TextTruncate     = Enum.TextTruncate.AtEnd
        nameLabel.Parent           = card

        -- ID
        local idLabel = Instance.new("TextLabel")
        idLabel.Size               = UDim2.new(1, -140, 0, 16)
        idLabel.Position           = UDim2.new(0, 73, 0, 36)
        idLabel.BackgroundTransparency = 1
        idLabel.Text               = "ID: " .. tostring(userId)
        idLabel.TextColor3         = Color3.fromRGB(255, 170, 0)
        idLabel.TextSize           = 11
        idLabel.Font               = Enum.Font.Gotham
        idLabel.TextXAlignment     = Enum.TextXAlignment.Left
        idLabel.Parent             = card

        -- Przycisk Spectate
        local specBtn = Instance.new("TextButton")
        specBtn.Size              = UDim2.new(0, 56, 0, 32)
        specBtn.Position          = UDim2.new(1, -64, 0.5, -16)
        specBtn.BackgroundColor3  = Color3.fromRGB(255, 170, 0)
        specBtn.BackgroundTransparency = 0.1
        specBtn.Text              = "👁 Spec"
        specBtn.TextColor3        = Color3.fromRGB(0, 0, 0)
        specBtn.TextSize          = 12
        specBtn.Font              = Enum.Font.GothamBold
        specBtn.Parent            = card
        local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 7); sc.Parent = specBtn

        local captured = gracz
        specBtn.MouseButton1Click:Connect(function()
            spectateGracza(captured)
        end)
    end
end

local function stworzListGui()
    if listGui then return end

    listGui = Instance.new("ScreenGui")
    listGui.Name          = "KonfidentListGui"
    listGui.ResetOnSpawn  = false
    listGui.Enabled       = false
    listGui.Parent        = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name               = "MainFrame"
    frame.Size               = UDim2.new(0, 300, 0, 460)
    frame.Position           = UDim2.new(0, 20, 0.5, -230)
    frame.BackgroundColor3   = Color3.fromRGB(15, 15, 20)
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel    = 0
    frame.Parent             = listGui
    listFrame                = frame

    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 14); fc.Parent = frame
    local fs = Instance.new("UIStroke")
    fs.Color = Color3.fromRGB(255, 170, 0); fs.Thickness = 1.5; fs.Transparency = 0.4
    fs.Parent = frame

    -- Tytuł
    local title = Instance.new("TextLabel")
    title.Size             = UDim2.new(1, -48, 0, 42)
    title.Position         = UDim2.new(0, 14, 0, 0)
    title.BackgroundTransparency = 1
    title.Text             = "🔍  Konfidenci online"
    title.TextColor3       = Color3.fromRGB(255, 170, 0)
    title.TextSize         = 15
    title.Font             = Enum.Font.GothamBold
    title.TextXAlignment   = Enum.TextXAlignment.Left
    title.Parent           = frame

    -- Zamknij
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size             = UDim2.new(0, 28, 0, 28)
    closeBtn.Position         = UDim2.new(1, -36, 0, 7)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeBtn.BackgroundTransparency = 0.25
    closeBtn.Text             = "✕"
    closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize         = 14
    closeBtn.Font             = Enum.Font.GothamBold
    closeBtn.Parent           = frame
    local clc = Instance.new("UICorner"); clc.CornerRadius = UDim.new(0, 6); clc.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        listGui.Enabled = false
        listVisible = false
    end)

    -- Separator
    local sep = Instance.new("Frame")
    sep.Size             = UDim2.new(1, -28, 0, 1)
    sep.Position         = UDim2.new(0, 14, 0, 42)
    sep.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
    sep.BackgroundTransparency = 0.6
    sep.BorderSizePixel  = 0
    sep.Parent           = frame

    -- ScrollingFrame
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name                  = "PlayerScroll"
    scroll.Size                  = UDim2.new(1, -28, 1, -100)
    scroll.Position              = UDim2.new(0, 14, 0, 50)
    scroll.BackgroundTransparency = 1
    scroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness    = 4
    scroll.ScrollBarImageColor3  = Color3.fromRGB(255, 170, 0)
    scroll.Parent                = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent  = scroll
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end)

    -- Stop Spectate
    local stopBtn = Instance.new("TextButton")
    stopBtn.Size              = UDim2.new(1, -28, 0, 34)
    stopBtn.Position          = UDim2.new(0, 14, 1, -46)
    stopBtn.BackgroundColor3  = Color3.fromRGB(255, 170, 0)
    stopBtn.BackgroundTransparency = 0.15
    stopBtn.Text              = "⏹  Stop spectate — wróć do siebie"
    stopBtn.TextColor3        = Color3.fromRGB(0, 0, 0)
    stopBtn.TextSize          = 13
    stopBtn.Font              = Enum.Font.GothamBold
    stopBtn.Parent            = frame
    local stc = Instance.new("UICorner"); stc.CornerRadius = UDim.new(0, 8); stc.Parent = stopBtn
    stopBtn.MouseButton1Click:Connect(stopSpectate)
end

-- ===== AKTUALIZACJA LISTY =====
local function aktualizujListe()
    local nowaKonfig = pobierzKonfiguracje()
    if not nowaKonfig then return end

    local nowi = {}
    for _, userId in ipairs(nowaKonfig.konfidenci or {}) do
        nowi[userId] = true
    end

    local starzy = currentConfig.konfidenci or {}

    -- Usuń oznaczenia starych
    for userId, _ in pairs(starzy) do
        if not nowi[userId] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.UserId == userId then usunOznaczenia(gracz) end
            end
        end
    end

    -- Dodaj oznaczenia nowych
    for userId, _ in pairs(nowi) do
        if not starzy[userId] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.UserId == userId and gracz.Character then
                    dodajOznaczenia(gracz)
                end
            end
        end
    end

    currentConfig = nowaKonfig
    currentConfig.konfidenci = nowi
    if not currentConfig.ustawienia then
        currentConfig.ustawienia = {
            kolorPodswietlenia = {255, 170, 0},
            przezroczystosc    = 0.4,
            tekstNadGlowa      = "Konfident",
            kolorTekstu        = {255, 255, 255},
        }
    end

    local liczba = 0
    for _ in pairs(nowi) do liczba = liczba + 1 end
    print("[KonfidentHunter] ✅ Odświeżono. Konfidenci w bazie: " .. liczba)

    if listVisible then odswiezListGui() end

    Rayfield:Notify({
        Title   = "Lista odświeżona",
        Content = "Konfidenci w bazie: " .. liczba,
        Duration = 3,
        Image   = "shield-alert",
    })
end

-- ===== MONITOROWANIE GRACZY =====
local function monitorujGracza(gracz)
    if gracz == LocalPlayer then return end

    local function onCharAdded()
        task.wait(0.5)
        if czyJestKonfidentem(gracz) then dodajOznaczenia(gracz) end
        if listVisible then odswiezListGui() end
    end

    if gracz.Character then onCharAdded() end
    gracz.CharacterAdded:Connect(onCharAdded)
    gracz.CharacterRemoving:Connect(function()
        usunOznaczenia(gracz)
        if spectateTarget == gracz then stopSpectate() end
        if listVisible then task.wait(0.1); odswiezListGui() end
    end)
end

-- ===== AUTO-ODŚWIEŻANIE =====
local function startAutoRefresh()
    while true do
        task.wait(REFRESH_TIME)
        aktualizujListe()
        for _, gracz in ipairs(Players:GetPlayers()) do
            if gracz ~= LocalPlayer then
                if czyJestKonfidentem(gracz) and gracz.Character and not activeMarkers[gracz] then
                    dodajOznaczenia(gracz)
                elseif not czyJestKonfidentem(gracz) and activeMarkers[gracz] then
                    usunOznaczenia(gracz)
                end
            end
        end
    end
end

-- ===== RAYFIELD GUI =====
local Window = Rayfield:CreateWindow({
    Name             = "Konfident Hunter",
    Icon             = "shield-alert",
    LoadingTitle     = "Konfident Hunter v7.0",
    LoadingSubtitle  = "Ładowanie...",
    Theme            = "Default",
    ToggleUIKeybind  = "K",
    DisableRayfieldPrompts  = false,
    DisableBuildWarnings    = false,
    ConfigurationSaving = { Enabled = false, FolderName = nil, FileName = "KonfidentHunter" },
    Discord  = { Enabled = false, Invite = "noinvitelink", RememberJoins = true },
    KeySystem = false,
})

-- ── Lista ──
local listaTab = Window:CreateTab("Lista", "users")
listaTab:CreateSection("Panel gracza")

listaTab:CreateButton({
    Name = "📋 Otwórz listę z avatarami",
    Callback = function()
        stworzListGui()
        odswiezListGui()
        listGui.Enabled = true
        listVisible = true
    end,
})

listaTab:CreateButton({
    Name = "🔄 Odśwież z GitHub",
    Callback = function()
        task.spawn(aktualizujListe)
    end,
})

listaTab:CreateDivider()
listaTab:CreateButton({
    Name = "⏹ Stop spectate",
    Callback = stopSpectate,
})

-- ── Ustawienia ──
local settingsTab = Window:CreateTab("Ustawienia", "settings")
settingsTab:CreateSection("Wizualne")

settingsTab:CreateSlider({
    Name         = "Przezroczystość podświetlenia",
    Range        = {0, 10},
    Increment    = 1,
    CurrentValue = 4,
    Flag         = "Przezroczystosc",
    Callback     = function(value)
        if not currentConfig.ustawienia then currentConfig.ustawienia = {} end
        currentConfig.ustawienia.przezroczystosc = value / 10
        for _, folder in pairs(activeMarkers) do
            local hl = folder:FindFirstChild("Podswietlenie")
            if hl then hl.FillTransparency = value / 10 end
        end
    end,
})

settingsTab:CreateInput({
    Name                      = "Tekst nad głową",
    PlaceholderText           = "Konfident",
    RemoveTextAfterFocusLost  = false,
    Flag                      = "TekstNadGlowa",
    Callback = function(value)
        if not currentConfig.ustawienia then currentConfig.ustawienia = {} end
        currentConfig.ustawienia.tekstNadGlowa = (value ~= "" and value or "Konfident")
        for gracz, _ in pairs(activeMarkers) do
            local char = gracz.Character
            if char then
                local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
                if head then
                    local bb = head:FindFirstChild("TekstKonfidenta")
                    if bb then
                        local lbl = bb:FindFirstChildOfClass("TextLabel")
                        if lbl then lbl.Text = currentConfig.ustawienia.tekstNadGlowa end
                    end
                end
            end
        end
    end,
})

settingsTab:CreateSection("Config")
settingsTab:CreateParagraph({
    Title   = "Format config.lua (ID, nie nick!)",
    Content = "konfidenci = {\n  123456789,\n  987654321,\n}",
})
settingsTab:CreateParagraph({
    Title   = "Jak znaleźć ID?",
    Content = "Wejdź na profil gracza na Roblox.\nID jest w URL: roblox.com/users/TUTAJ/profile",
})

-- ── Info ──
local infoTab = Window:CreateTab("Info", "info")
infoTab:CreateSection("Konfident Hunter v7.0")
infoTab:CreateParagraph({
    Title   = "Jak działa?",
    Content = "Config używa ID kont Roblox. Odświeżanie co "
           .. REFRESH_TIME .. "s. Otwórz panel listy aby widzieć avatary i spectować.",
})
infoTab:CreateButton({
    Name = "Wymuś oznaczenie wszystkich",
    Callback = function()
        for _, gracz in ipairs(Players:GetPlayers()) do
            if gracz ~= LocalPlayer then
                usunOznaczenia(gracz)
                if czyJestKonfidentem(gracz) and gracz.Character then
                    dodajOznaczenia(gracz)
                end
            end
        end
        Rayfield:Notify({ Title = "Gotowe", Content = "Oznaczenia odświeżone.", Duration = 3 })
    end,
})

-- ===== INICJALIZACJA =====
local function inicjuj()
    local config = pobierzKonfiguracje()
    if config then
        local slownik = {}
        for _, userId in ipairs(config.konfidenci or {}) do
            slownik[userId] = true
        end
        currentConfig = config
        currentConfig.konfidenci = slownik
        if not currentConfig.ustawienia then
            currentConfig.ustawienia = {
                kolorPodswietlenia = {255, 170, 0},
                przezroczystosc    = 0.4,
                tekstNadGlowa      = "Konfident",
                kolorTekstu        = {255, 255, 255},
            }
        end
    else
        currentConfig = {
            konfidenci = {},
            ustawienia = {
                kolorPodswietlenia = {255, 170, 0},
                przezroczystosc    = 0.4,
                tekstNadGlowa      = "Konfident",
                kolorTekstu        = {255, 255, 255},
            },
        }
        print("[KonfidentHunter] ⚠️ Pusta konfiguracja — sprawdź CONFIG_URL.")
    end

    local liczba = 0
    for _ in pairs(currentConfig.konfidenci) do liczba = liczba + 1 end
    print("[KonfidentHunter] 🟢 Start. Konfidenci w bazie: " .. liczba)

    stworzListGui()

    Rayfield:Notify({
        Title   = "Konfident Hunter",
        Content = "Załadowano! Baza: " .. liczba .. " ID. Naciśnij K → Lista z avatarami.",
        Duration = 6,
        Image   = "shield-alert",
    })

    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer then monitorujGracza(gracz) end
    end
    Players.PlayerAdded:Connect(function(gracz)
        if gracz ~= LocalPlayer then monitorujGracza(gracz) end
    end)
    Players.PlayerRemoving:Connect(function(gracz)
        if listVisible then task.wait(0.1); odswiezListGui() end
    end)

    task.spawn(startAutoRefresh)
end

inicjuj()
