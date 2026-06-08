--[[
    Konfident Hunter v2
    - Lista konfidentów jako ScrollingFrame wewnątrz Rayfield (zamiast Dropdown)
    - Avatar gracza pobierany z Roblox Thumbs API
    - Kliknięcie na gracza → spectate / wyłącz spectate (toggle)
    - Auto-odświeżanie co 5 sekund
]]

-- ===== KONFIGURACJA =====
local REFRESH_TIME = 5
local CONFIG_URL   = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"
-- ========================

local Rayfield    = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Players     = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local currentConfig  = { konfidenci = {}, ustawienia = {} }
local activeMarkers  = {}
local spectateTarget = nil

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

-- ===== POBIERANIE CONFIGU =====
local function pobierzKonfiguracje()
    local ok, result = pcall(function() return game:HttpGet(CONFIG_URL) end)
    if not ok then warn("[KH] HttpGet: " .. tostring(result)); return nil end
    local func, err = loadstring(result)
    if not func then warn("[KH] loadstring: " .. tostring(err)); return nil end
    local ok2, config = pcall(func)
    if not ok2 then warn("[KH] pcall: " .. tostring(config)); return nil end
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
    highlight.Name                = "Podswietlenie"
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
    spectateTarget = gracz
    Camera.CameraType    = Enum.CameraType.Custom
    Camera.CameraSubject = humanoid
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
end

-- ===== LISTA GUI =====
-- Znajdziemy kontener Rayfield żeby wstrzyknąć własny ScrollingFrame
local listaContainer = nil   -- tutaj trzymamy referencję do ramki z kartami
local kartyGraczy    = {}    -- { [gracz] = frameKarty }

local CARD_HEIGHT  = 60
local CARD_PADDING = 8
local ACCENT_AKTYWNY  = Color3.fromRGB(255, 170, 0)
local ACCENT_NORMALNY = Color3.fromRGB(40, 40, 45)
local TLO_KARTY       = Color3.fromRGB(30, 30, 35)
local TLO_AKTYWNY     = Color3.fromRGB(50, 40, 20)

local function getAvatarUrl(userId)
    -- Roblox thumbnail API — headshot 150x150
    return string.format(
        "https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=150&height=150&format=png",
        userId
    )
end

local function stworzKarteGracza(gracz, scrollFrame)
    if kartyGraczy[gracz] then return end  -- już istnieje

    -- Policz istniejące karty żeby ustawić pozycję
    local idx = 0
    for _ in pairs(kartyGraczy) do idx = idx + 1 end

    local karta = Instance.new("Frame")
    karta.Name            = "Karta_" .. gracz.Name
    karta.Size            = UDim2.new(1, -12, 0, CARD_HEIGHT)
    karta.Position        = UDim2.new(0, 6, 0, idx * (CARD_HEIGHT + CARD_PADDING) + 4)
    karta.BackgroundColor3 = TLO_KARTY
    karta.BorderSizePixel  = 0
    karta.Parent           = scrollFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent       = karta

    local stroke = Instance.new("UIStroke")
    stroke.Color     = ACCENT_NORMALNY
    stroke.Thickness = 1.5
    stroke.Parent    = karta

    -- Avatar (ImageLabel)
    local avatarBg = Instance.new("Frame")
    avatarBg.Size               = UDim2.new(0, 44, 0, 44)
    avatarBg.Position           = UDim2.new(0, 8, 0.5, -22)
    avatarBg.BackgroundColor3   = Color3.fromRGB(20, 20, 25)
    avatarBg.BorderSizePixel    = 0
    avatarBg.Parent             = karta
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 8)
    bgCorner.Parent       = avatarBg

    local avatarImg = Instance.new("ImageLabel")
    avatarImg.Size              = UDim2.new(1, 0, 1, 0)
    avatarImg.BackgroundTransparency = 1
    avatarImg.Image             = getAvatarUrl(gracz.UserId)
    avatarImg.ScaleType         = Enum.ScaleType.Fit
    avatarImg.Parent            = avatarBg
    local imgCorner = Instance.new("UICorner")
    imgCorner.CornerRadius = UDim.new(0, 8)
    imgCorner.Parent       = avatarImg

    -- Nazwa gracza
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size                   = UDim2.new(1, -66, 0, 20)
    nameLabel.Position               = UDim2.new(0, 60, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text                   = gracz.Name
    nameLabel.TextColor3             = Color3.fromRGB(230, 230, 230)
    nameLabel.Font                   = Enum.Font.GothamBold
    nameLabel.TextSize               = 14
    nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
    nameLabel.TextTruncate           = Enum.TextTruncate.AtEnd
    nameLabel.Parent                 = karta

    -- Status spectate
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size                   = UDim2.new(1, -66, 0, 16)
    statusLabel.Position               = UDim2.new(0, 60, 0, 32)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text                   = "Kliknij aby spectate"
    statusLabel.TextColor3             = Color3.fromRGB(140, 140, 150)
    statusLabel.Font                   = Enum.Font.Gotham
    statusLabel.TextSize               = 11
    statusLabel.TextXAlignment         = Enum.TextXAlignment.Left
    statusLabel.Parent                 = karta

    -- Przycisk-overlay (cały frame klikalny)
    local btn = Instance.new("TextButton")
    btn.Size                   = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                   = ""
    btn.Parent                 = karta

    -- Strzałka/ikona po prawej
    local arrow = Instance.new("TextLabel")
    arrow.Size                   = UDim2.new(0, 24, 0, 24)
    arrow.Position               = UDim2.new(1, -32, 0.5, -12)
    arrow.BackgroundTransparency = 1
    arrow.Text                   = "▶"
    arrow.TextColor3             = Color3.fromRGB(100, 100, 110)
    arrow.Font                   = Enum.Font.GothamBold
    arrow.TextSize               = 12
    arrow.Parent                 = karta

    kartyGraczy[gracz] = {
        frame       = karta,
        stroke      = stroke,
        statusLabel = statusLabel,
        arrow       = arrow,
        nameLabel   = nameLabel,
    }

    -- Toggle spectate przy kliknięciu
    btn.MouseButton1Click:Connect(function()
        if spectateTarget == gracz then
            -- Wyłącz spectate
            stopSpectate()
            -- Resetuj wygląd tej karty
            TweenService:Create(karta, TweenInfo.new(0.2), {BackgroundColor3 = TLO_KARTY}):Play()
            stroke.Color = ACCENT_NORMALNY
            statusLabel.Text = "Kliknij aby spectate"
            statusLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
            arrow.TextColor3 = Color3.fromRGB(100, 100, 110)
            arrow.Text = "▶"
            nameLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
        else
            -- Wyłącz poprzedni spectate i zresetuj jego kartę
            if spectateTarget then
                local stareKarty = kartyGraczy[spectateTarget]
                if stareKarty then
                    TweenService:Create(stareKarty.frame, TweenInfo.new(0.2), {BackgroundColor3 = TLO_KARTY}):Play()
                    stareKarty.stroke.Color = ACCENT_NORMALNY
                    stareKarty.statusLabel.Text = "Kliknij aby spectate"
                    stareKarty.statusLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
                    stareKarty.arrow.TextColor3 = Color3.fromRGB(100, 100, 110)
                    stareKarty.arrow.Text = "▶"
                    stareKarty.nameLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
                end
            end
            -- Włącz nowy spectate
            spectateGracza(gracz)
            TweenService:Create(karta, TweenInfo.new(0.2), {BackgroundColor3 = TLO_AKTYWNY}):Play()
            stroke.Color = ACCENT_AKTYWNY
            statusLabel.Text = "👁 Obserwujesz"
            statusLabel.TextColor3 = ACCENT_AKTYWNY
            arrow.TextColor3 = ACCENT_AKTYWNY
            arrow.Text = "■"
            nameLabel.TextColor3 = Color3.fromRGB(255, 210, 100)
        end
    end)

    -- Aktualizuj CanvasSize
    local count = 0
    for _ in pairs(kartyGraczy) do count = count + 1 end
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, count * (CARD_HEIGHT + CARD_PADDING) + 8)
end

local function usunKarteGracza(gracz)
    local dane = kartyGraczy[gracz]
    if not dane then return end
    pcall(function() dane.frame:Destroy() end)
    kartyGraczy[gracz] = nil

    -- Przelicz pozycje pozostałych kart
    local i = 0
    for _, innyDane in pairs(kartyGraczy) do
        innyDane.frame.Position = UDim2.new(0, 6, 0, i * (CARD_HEIGHT + CARD_PADDING) + 4)
        i = i + 1
    end

    if listaContainer then
        listaContainer.CanvasSize = UDim2.new(0, 0, 0, i * (CARD_HEIGHT + CARD_PADDING) + 8)
    end
end

local function odswiezListeGUI()
    if not listaContainer then return end

    -- Dodaj nowych konfidentów na serwerze
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer and czyJestKonfidentem(gracz) then
            if not kartyGraczy[gracz] then
                stworzKarteGracza(gracz, listaContainer)
            end
        end
    end

    -- Usuń tych co już nie są konfidentami lub wyszli
    for gracz, _ in pairs(kartyGraczy) do
        if not gracz.Parent or not czyJestKonfidentem(gracz) then
            if spectateTarget == gracz then stopSpectate() end
            usunKarteGracza(gracz)
        end
    end
end

-- ===== AKTUALIZACJA LISTY KONFIDENTÓW =====
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
    print("[KonfidentHunter] ✅ Odświeżono. Konfidenci: " .. liczba)

    odswiezListeGUI()
end

-- ===== MONITOROWANIE GRACZY =====
local function monitorujGracza(gracz)
    if gracz == LocalPlayer then return end
    gracz.CharacterAdded:Connect(function()
        task.wait(0.3)
        if czyJestKonfidentem(gracz) then
            dodajOznaczenia(gracz)
            odswiezListeGUI()
        end
    end)
    gracz.CharacterRemoving:Connect(function()
        usunOznaczenia(gracz)
        if spectateTarget == gracz then stopSpectate() end
        odswiezListeGUI()
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

-- ── Tab Lista ──
local listaTab = Window:CreateTab("Lista", "users")
listaTab:CreateSection("Konfidenci na serwerze")

-- ── Wstrzyknięcie własnego ScrollingFrame w zakładkę Rayfield ──
-- Czekamy chwilę aż Rayfield zbuduje UI
task.wait(0.5)

local function znajdzTabFrame()
    -- Szukamy SurfaceGui / ScreenGui Rayfield i nawigujemy do zawartości aktywnej zakładki
    for _, gui in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if gui.Name == "Rayfield" then
            local main = gui:FindFirstChild("Main", true)
            if main then return main end
        end
    end
    -- Fallback: PlayerGui
    for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        if gui.Name == "Rayfield" or gui:FindFirstChild("Main", true) then
            local main = gui:FindFirstChild("Main", true)
            if main then return main end
        end
    end
    return nil
end

-- Szukamy kontenera sekcji wewnątrz aktywnej zakładki
-- Rayfield tworzy Frame dla każdej zakładki — szukamy wewnątrz listaTab
local tabContent = nil
local function znajdzKontenerZakladki()
    -- Rayfield tworzy obiekt zakładki z properties — próbujemy dostać się do instancji
    -- Szukamy przez PlayerGui, CoreGui
    local function szukajRekurencyjnie(parent, depth)
        if depth > 8 then return nil end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Frame") or child:IsA("ScrollingFrame") then
                -- Szukamy sekcji "Konfidenci na serwerze"
                for _, inner in ipairs(child:GetDescendants()) do
                    if inner:IsA("TextLabel") and inner.Text == "Konfidenci na serwerze" then
                        -- Zwróć ScrollingFrame lub Frame rodzic tej sekcji
                        return child
                    end
                end
            end
            local found = szukajRekurencyjnie(child, depth + 1)
            if found then return found end
        end
        return nil
    end

    local guiParents = {game:GetService("CoreGui"), LocalPlayer.PlayerGui}
    for _, parent in ipairs(guiParents) do
        local result = szukajRekurencyjnie(parent, 0)
        if result then return result end
    end
    return nil
end

task.spawn(function()
    task.wait(1)  -- poczekaj aż Rayfield się załaduje
    tabContent = znajdzKontenerZakladki()

    if tabContent then
        -- Stwórz ScrollingFrame wewnątrz znalezionego kontenera
        local scroll = Instance.new("ScrollingFrame")
        scroll.Name                          = "KonfidentLista"
        scroll.Size                          = UDim2.new(1, 0, 0, 280)
        scroll.BackgroundTransparency        = 1
        scroll.BorderSizePixel               = 0
        scroll.ScrollBarThickness           = 4
        scroll.ScrollBarImageColor3         = Color3.fromRGB(255, 170, 0)
        scroll.CanvasSize                    = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize           = Enum.AutomaticSize.None
        scroll.ScrollingDirection            = Enum.ScrollingDirection.Y
        scroll.Parent                        = tabContent
        scroll.LayoutOrder                   = 999

        listaContainer = scroll
        odswiezListeGUI()
    else
        warn("[KH] ⚠️ Nie znaleziono kontenera zakładki – używam fallback label")
    end
end)

-- Przyciski pod listą
listaTab:CreateButton({
    Name = "⏹ Stop spectate",
    Callback = function()
        -- Resetuj aktywną kartę
        if spectateTarget then
            local dane = kartyGraczy[spectateTarget]
            if dane then
                TweenService:Create(dane.frame, TweenInfo.new(0.2), {BackgroundColor3 = TLO_KARTY}):Play()
                dane.stroke.Color = ACCENT_NORMALNY
                dane.statusLabel.Text = "Kliknij aby spectate"
                dane.statusLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
                dane.arrow.TextColor3 = Color3.fromRGB(100, 100, 110)
                dane.arrow.Text = "▶"
                dane.nameLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
            end
        end
        stopSpectate()
    end,
})

listaTab:CreateButton({
    Name = "🔄 Odśwież listę",
    Callback = function()
        task.spawn(aktualizujListe)
    end,
})

-- ── Tab Ustawienia ──
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
        warn("[KonfidentHunter] ⚠️ Pusta konfiguracja.")
    end

    local liczba = 0
    for _ in pairs(currentConfig.konfidenci) do liczba = liczba + 1 end
    print("[KonfidentHunter] 🟢 Start. Konfidenci: " .. liczba)

    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer and czyJestKonfidentem(gracz) and gracz.Character then
            dodajOznaczenia(gracz)
        end
    end

    Rayfield:Notify({
        Title    = "KonfidentHunter",
        Content  = "Załadowano. Baza: " .. liczba .. " ID. Naciśnij K.",
        Duration = 5,
        Image    = "shield-alert",
    })

    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer then monitorujGracza(gracz) end
    end

    Players.PlayerAdded:Connect(function(gracz)
        if gracz ~= LocalPlayer then
            monitorujGracza(gracz)
            task.wait(0.3)
            if czyJestKonfidentem(gracz) and gracz.Character then
                dodajOznaczenia(gracz)
            end
            task.wait(0.2)
            odswiezListeGUI()
        end
    end)

    Players.PlayerRemoving:Connect(function(gracz)
        task.wait(0.1)
        odswiezListeGUI()
    end)

    task.spawn(startAutoRefresh)
end

inicjuj()
