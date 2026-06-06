--[[
    Konfident Hunter
    - Config oparty na ID kont Roblox
    - Rayfield GUI (klawisz K)
    - Panel listy z avatarami + kliknięcie = zaznacz/spectate (toggle)
    - Kliknięcie innego = przełącz spectate
    - Kliknięcie tego samego = odznacz i stop spectate
    - Auto-odświeżanie co 5 sekund
    - Natychmiastowe oznaczanie przy injeccie
]]

-- ===== KONFIGURACJA =====
local REFRESH_TIME = 5
local CONFIG_URL   = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"
-- ========================

local Rayfield    = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local currentConfig   = { konfidenci = {}, ustawienia = {} }
local activeMarkers   = {}
local userAvatarCache = {}
local selectedGracz   = nil   -- aktualnie zaznaczony gracz
local selectedCard    = nil   -- aktualnie zaznaczona karta (Frame/Button)
local listVisible     = false
local listGui         = nil
local listFrame       = nil

-- ===== HELPERS =====
local function getUstawienia()
    return currentConfig.ustawienia or {
        kolorPodswietlenia = {255, 170, 0},
        przezroczystosc    = 0.4,
        tekstNadGlowa      = "Konfident",
    }
end

local function czyJestKonfidentem(gracz)
    return currentConfig.konfidenci and currentConfig.konfidenci[gracz.UserId] == true
end

-- ===== ROBLOX API – avatar =====
local function getAvatar(userId)
    if userAvatarCache[userId] then return userAvatarCache[userId] end
    local ok, url = pcall(function()
        local u, _ = Players:GetUserThumbnailAsync(
            userId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size150x150
        )
        return u
    end)
    if ok and url then userAvatarCache[userId] = url; return url end
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
    folder.Name   = "KonfidentMarkery"
    folder.Parent = character
    activeMarkers[gracz] = folder

    local ust = getUstawienia()
    local k   = ust.kolorPodswietlenia or {255, 170, 0}

    local highlight = Instance.new("Highlight")
    highlight.FillColor           = Color3.fromRGB(k[1], k[2], k[3])
    highlight.FillTransparency    = ust.przezroczystosc or 0.4
    highlight.OutlineColor        = Color3.fromRGB(k[1], k[2], k[3])
    highlight.OutlineTransparency = 0.0
    highlight.Adornee             = character
    highlight.Parent              = folder

    local billboard = Instance.new("BillboardGui")
    billboard.Name        = "TekstKonfidenta"
    billboard.AlwaysOnTop = true
    billboard.Size        = UDim2.new(0, 220, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.3, 0)
    billboard.Adornee     = headPart
    billboard.Parent      = headPart

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = ust.tekstNadGlowa or "Konfident"
    lbl.TextColor3             = Color3.fromRGB(k[1], k[2], k[3])
    lbl.TextScaled             = true
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0.0
    lbl.Parent                 = billboard

    return true
end

-- ===== SPECTATE =====
local function spectateGracza(gracz)
    if not gracz or not gracz.Character then return end
    local humanoid = gracz.Character:FindFirstChild("Humanoid")
    if not humanoid then return end
    Camera.CameraType    = Enum.CameraType.Custom
    Camera.CameraSubject = humanoid
end

local function stopSpectate()
    selectedGracz = nil
    selectedCard  = nil
    local char = LocalPlayer.Character
    if char then
        local h = char:FindFirstChild("Humanoid")
        if h then
            Camera.CameraType    = Enum.CameraType.Custom
            Camera.CameraSubject = h
        end
    end
end

-- ===== PANEL LISTY =====
local function odswiezListGui()
    if not listGui or not listFrame then return end
    local scroll = listFrame:FindFirstChild("PlayerScroll")
    if not scroll then return end

    -- Wyczyść karty
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end

    -- Jeśli zaznaczony gracz już nie istnieje na serwerze → reset
    if selectedGracz and not selectedGracz.Parent then
        stopSpectate()
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
        empty.Size                = UDim2.new(1, 0, 0, 60)
        empty.BackgroundTransparency = 1
        empty.Text                = "Żaden konfident nie jest teraz na tym serwerze."
        empty.TextColor3          = Color3.fromRGB(130, 130, 130)
        empty.TextSize            = 13
        empty.Font                = Enum.Font.Gotham
        empty.TextWrapped         = true
        empty.Parent              = scroll
        return
    end

    for _, gracz in ipairs(online) do
        local userId   = gracz.UserId
        local isSelected = (gracz == selectedGracz)

        -- Karta (TextButton żeby obsługiwać klik)
        local card = Instance.new("TextButton")
        card.Size                = UDim2.new(1, 0, 0, 72)
        card.BackgroundColor3    = isSelected
            and Color3.fromRGB(60, 40, 10)
            or  Color3.fromRGB(24, 24, 32)
        card.BackgroundTransparency = 0.05
        card.BorderSizePixel     = 0
        card.Text                = ""
        card.AutoButtonColor     = false
        card.Parent              = scroll

        local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 10); cc.Parent = card

        local cs = Instance.new("UIStroke")
        cs.Color       = isSelected
            and Color3.fromRGB(255, 170, 0)
            or  Color3.fromRGB(80, 80, 100)
        cs.Thickness   = isSelected and 2 or 1
        cs.Transparency = isSelected and 0 or 0.5
        cs.Parent      = card

        -- Avatar
        local avatar = Instance.new("ImageLabel")
        avatar.Size             = UDim2.new(0, 54, 0, 54)
        avatar.Position         = UDim2.new(0, 9, 0.5, -27)
        avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
        avatar.BorderSizePixel  = 0
        avatar.Image            = ""
        avatar.ScaleType        = Enum.ScaleType.Fit
        avatar.Parent           = card
        local ac = Instance.new("UICorner"); ac.CornerRadius = UDim.new(0, 8); ac.Parent = avatar

        task.spawn(function()
            local url = getAvatar(userId)
            if avatar and avatar.Parent then avatar.Image = url end
        end)

        -- Nick
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size                = UDim2.new(1, -76, 0, 26)
        nameLabel.Position            = UDim2.new(0, 71, 0, 10)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text                = gracz.Name
        nameLabel.TextColor3          = isSelected
            and Color3.fromRGB(255, 200, 80)
            or  Color3.fromRGB(240, 240, 240)
        nameLabel.TextSize            = 14
        nameLabel.Font                = Enum.Font.GothamBold
        nameLabel.TextXAlignment      = Enum.TextXAlignment.Left
        nameLabel.TextTruncate        = Enum.TextTruncate.AtEnd
        nameLabel.Parent              = card

        -- Status
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Size                = UDim2.new(1, -76, 0, 18)
        statusLabel.Position            = UDim2.new(0, 71, 0, 38)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text                = isSelected and "👁 Obserwujesz..." or "🟢 online"
        statusLabel.TextColor3          = isSelected
            and Color3.fromRGB(255, 170, 0)
            or  Color3.fromRGB(80, 200, 80)
        statusLabel.TextSize            = 12
        statusLabel.Font                = Enum.Font.Gotham
        statusLabel.TextXAlignment      = Enum.TextXAlignment.Left
        statusLabel.Parent              = card

        -- Klik: toggle zaznaczenia
        local capturedGracz = gracz
        card.MouseButton1Click:Connect(function()
            if selectedGracz == capturedGracz then
                -- Kliknięcie tego samego → odznacz
                stopSpectate()
            else
                -- Kliknięcie innego → przełącz
                selectedGracz = capturedGracz
                spectateGracza(capturedGracz)
            end
            -- Odśwież karty żeby pokazać nowy stan
            odswiezListGui()
        end)
    end
end

local function stworzListGui()
    if listGui then return end

    listGui = Instance.new("ScreenGui")
    listGui.Name         = "KonfidentListGui"
    listGui.ResetOnSpawn = false
    listGui.Enabled      = false
    listGui.Parent       = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name                 = "MainFrame"
    frame.Size                 = UDim2.new(0, 290, 0, 440)
    frame.Position             = UDim2.new(0, 20, 0.5, -220)
    frame.BackgroundColor3     = Color3.fromRGB(12, 12, 18)
    frame.BackgroundTransparency = 0.04
    frame.BorderSizePixel      = 0
    frame.Parent               = listGui
    listFrame                  = frame

    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 14); fc.Parent = frame
    local fs = Instance.new("UIStroke")
    fs.Color = Color3.fromRGB(255, 170, 0); fs.Thickness = 1.5; fs.Transparency = 0.45
    fs.Parent = frame

    -- Tytuł
    local title = Instance.new("TextLabel")
    title.Size                = UDim2.new(1, -46, 0, 40)
    title.Position            = UDim2.new(0, 14, 0, 0)
    title.BackgroundTransparency = 1
    title.Text                = "🔍  Konfidenci online"
    title.TextColor3          = Color3.fromRGB(255, 170, 0)
    title.TextSize            = 15
    title.Font                = Enum.Font.GothamBold
    title.TextXAlignment      = Enum.TextXAlignment.Left
    title.Parent              = frame

    -- Zamknij
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size                = UDim2.new(0, 26, 0, 26)
    closeBtn.Position            = UDim2.new(1, -34, 0, 7)
    closeBtn.BackgroundColor3    = Color3.fromRGB(200, 50, 50)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.Text                = "✕"
    closeBtn.TextColor3          = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize            = 13
    closeBtn.Font                = Enum.Font.GothamBold
    closeBtn.Parent              = frame
    local clc = Instance.new("UICorner"); clc.CornerRadius = UDim.new(0,6); clc.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        listGui.Enabled = false
        listVisible = false
    end)

    -- Separator
    local sep = Instance.new("Frame")
    sep.Size             = UDim2.new(1, -28, 0, 1)
    sep.Position         = UDim2.new(0, 14, 0, 40)
    sep.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
    sep.BackgroundTransparency = 0.6
    sep.BorderSizePixel  = 0
    sep.Parent           = frame

    -- ScrollingFrame
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name                   = "PlayerScroll"
    scroll.Size                   = UDim2.new(1, -28, 1, -52)
    scroll.Position               = UDim2.new(0, 14, 0, 48)
    scroll.BackgroundTransparency = 1
    scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness     = 4
    scroll.ScrollBarImageColor3   = Color3.fromRGB(255, 170, 0)
    scroll.Parent                 = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.Parent  = scroll
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end)
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

    for userId, _ in pairs(starzy) do
        if not nowi[userId] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.UserId == userId then usunOznaczenia(gracz) end
            end
        end
    end

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
        }
    end

    local liczba = 0
    for _ in pairs(nowi) do liczba = liczba + 1 end
    print("[KonfidentHunter] ✅ Odświeżono. Konfidenci w bazie: " .. liczba)

    if listVisible then odswiezListGui() end
end

-- ===== MONITOROWANIE GRACZY =====
local function monitorujGracza(gracz)
    if gracz == LocalPlayer then return end

    gracz.CharacterAdded:Connect(function(char)
        -- Krótkie czekanie aż postać w pełni się załaduje
        task.wait(0.3)
        if czyJestKonfidentem(gracz) then dodajOznaczenia(gracz) end
        if listVisible then odswiezListGui() end
    end)

    gracz.CharacterRemoving:Connect(function()
        usunOznaczenia(gracz)
        if selectedGracz == gracz then stopSpectate() end
        if listVisible then task.wait(0.1); odswiezListGui() end
    end)
end

-- ===== AUTO-ODŚWIEŻANIE =====
local function startAutoRefresh()
    while true do
        task.wait(REFRESH_TIME)
        aktualizujListe()
        -- Zabezpieczenie: sprawdź oznaczenia dla wszystkich
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
    Name            = "KonfidentHunter",
    Icon            = "shield-alert",
    LoadingTitle    = "KonfidentHunter",
    LoadingSubtitle = "Ładowanie...",
    Theme           = "Default",
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings   = false,
    ConfigurationSaving = { Enabled = false, FolderName = nil, FileName = "KonfidentHunter" },
    Discord  = { Enabled = false, Invite = "noinvitelink", RememberJoins = true },
    KeySystem = false,
})

-- ── Lista ──
local listaTab = Window:CreateTab("Lista", "users")
listaTab:CreateSection("Konfidenci na serwerze")

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
    Callback = function()
        stopSpectate()
        if listVisible then odswiezListGui() end
    end,
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
    Name                     = "Tekst nad głową",
    PlaceholderText          = "Konfident",
    RemoveTextAfterFocusLost = false,
    Flag                     = "TekstNadGlowa",
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
            }
        end
    else
        currentConfig = {
            konfidenci = {},
            ustawienia = { kolorPodswietlenia = {255, 170, 0}, przezroczystosc = 0.4, tekstNadGlowa = "Konfident" },
        }
        print("[KonfidentHunter] ⚠️ Pusta konfiguracja — sprawdź CONFIG_URL.")
    end

    local liczba = 0
    for _ in pairs(currentConfig.konfidenci) do liczba = liczba + 1 end
    print("[KonfidentHunter] 🟢 Start. Konfidenci w bazie: " .. liczba)

    -- Natychmiastowe oznaczenie graczy już na serwerze
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer and czyJestKonfidentem(gracz) and gracz.Character then
            dodajOznaczenia(gracz)
        end
    end

    stworzListGui()

    Rayfield:Notify({
        Title   = "KonfidentHunter",
        Content = "Załadowano! Baza: " .. liczba .. " ID. Naciśnij K aby otworzyć.",
        Duration = 5,
        Image   = "shield-alert",
    })

    -- Podłącz monitorowanie dla obecnych graczy
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer then monitorujGracza(gracz) end
    end

    Players.PlayerAdded:Connect(function(gracz)
        if gracz ~= LocalPlayer then
            monitorujGracza(gracz)
            -- Jeśli gracz jest już na liście konfidentów i ma postać
            task.wait(0.3)
            if czyJestKonfidentem(gracz) and gracz.Character then
                dodajOznaczenia(gracz)
            end
            if listVisible then odswiezListGui() end
        end
    end)

    Players.PlayerRemoving:Connect(function(gracz)
        if listVisible then task.wait(0.1); odswiezListGui() end
    end)

    task.spawn(startAutoRefresh)
end

inicjuj()
