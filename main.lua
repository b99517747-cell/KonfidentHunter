--[[
    Konfident Hunter v3 - WindUI Edition
    - UI: WindUI zamiast Rayfield
    - Lista konfidentów jako ScrollingFrame z kartami (avatar + nazwa + toggle spectate)
    - Avatar pobierany z Roblox Headshot Thumbnail API
    - Kliknięcie = toggle spectate (raz włącz, drugi raz wyłącz, klik w innego = przełącz)
    - Auto-odświeżanie co 5 sekund
    - Highlight + BillboardGui nad głową
]]

-- ===== KONFIGURACJA =====
local REFRESH_TIME = 5
local CONFIG_URL   = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"
-- ========================

-- Ładowanie WindUI
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer  = Players.LocalPlayer
local Camera       = workspace.CurrentCamera

local currentConfig = { konfidenci = {}, ustawienia = {} }
local activeMarkers = {}
local spectateTarget = nil

-- Referencje do UI kart graczy
local kartyGraczy   = {}   -- { [gracz] = { frame, stroke, statusLabel, arrow, nameLabel } }
local listaScroll   = nil  -- ScrollingFrame wewnątrz zakładki

local CARD_H   = 62
local CARD_PAD = 6

local C_AKTYWNY  = Color3.fromRGB(255, 170, 0)
local C_NORMALNY = Color3.fromRGB(55, 55, 62)
local C_TLO      = Color3.fromRGB(30, 30, 36)
local C_TLO_AKT  = Color3.fromRGB(52, 42, 18)

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

local function avatarUrl(userId)
    return ("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=150&height=150&format=png"):format(userId)
end

-- ===== POBIERANIE CONFIGU =====
local function pobierzKonfiguracje()
    local ok, result = pcall(function() return game:HttpGet(CONFIG_URL) end)
    if not ok then warn("[KH] HttpGet error: " .. tostring(result)); return nil end
    local func, err = loadstring(result)
    if not func then warn("[KH] loadstring error: " .. tostring(err)); return nil end
    local ok2, config = pcall(func)
    if not ok2 then warn("[KH] pcall error: " .. tostring(config)); return nil end
    return config
end

-- ===== OZNACZENIA =====
local function usunOznaczenia(gracz)
    local folder = activeMarkers[gracz]
    if folder then pcall(function() folder:Destroy() end); activeMarkers[gracz] = nil end
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
    local char = gracz.Character
    if not char then return false end
    local headPart = char:FindFirstChild("Head")
                  or char:FindFirstChild("HumanoidRootPart")
                  or char:FindFirstChild("UpperTorso")
    if not headPart then return false end
    if activeMarkers[gracz] then usunOznaczenia(gracz) end

    local folder = Instance.new("Folder")
    folder.Name   = "KonfidentMarkery"
    folder.Parent = char
    activeMarkers[gracz] = folder

    local ust = getUstawienia()
    local k   = ust.kolorPodswietlenia or {255, 170, 0}

    local hl = Instance.new("Highlight")
    hl.Name                = "Podswietlenie"
    hl.FillColor           = Color3.fromRGB(k[1], k[2], k[3])
    hl.FillTransparency    = ust.przezroczystosc or 0.4
    hl.OutlineColor        = Color3.fromRGB(k[1], k[2], k[3])
    hl.OutlineTransparency = 0
    hl.Adornee             = char
    hl.Parent              = folder

    local bb = Instance.new("BillboardGui")
    bb.Name        = "TekstKonfidenta"
    bb.AlwaysOnTop = true
    bb.Size        = UDim2.new(0, 220, 0, 40)
    bb.StudsOffset = Vector3.new(0, 2.3, 0)
    bb.Adornee     = headPart
    bb.Parent      = headPart

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = ust.tekstNadGlowa or "Konfident"
    lbl.TextColor3             = Color3.fromRGB(k[1], k[2], k[3])
    lbl.TextScaled             = true
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.Parent                 = bb

    return true
end

-- ===== SPECTATE =====
local function spectateGracza(gracz)
    if not gracz or not gracz.Character then return end
    local h = gracz.Character:FindFirstChild("Humanoid")
    if not h then return end
    spectateTarget = gracz
    Camera.CameraType    = Enum.CameraType.Custom
    Camera.CameraSubject = h
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

-- ===== KARTA GRACZA =====
local function resetKarty(dane)
    if not dane then return end
    TweenService:Create(dane.frame, TweenInfo.new(0.18), { BackgroundColor3 = C_TLO }):Play()
    dane.stroke.Color          = C_NORMALNY
    dane.statusLabel.Text      = "Kliknij aby spectate"
    dane.statusLabel.TextColor3 = Color3.fromRGB(130, 130, 145)
    dane.arrow.TextColor3      = Color3.fromRGB(90, 90, 105)
    dane.arrow.Text            = "▶"
    dane.nameLabel.TextColor3  = Color3.fromRGB(220, 220, 220)
end

local function aktywujKarte(dane)
    if not dane then return end
    TweenService:Create(dane.frame, TweenInfo.new(0.18), { BackgroundColor3 = C_TLO_AKT }):Play()
    dane.stroke.Color          = C_AKTYWNY
    dane.statusLabel.Text      = "👁  Obserwujesz"
    dane.statusLabel.TextColor3 = C_AKTYWNY
    dane.arrow.TextColor3      = C_AKTYWNY
    dane.arrow.Text            = "■"
    dane.nameLabel.TextColor3  = Color3.fromRGB(255, 210, 90)
end

local function obliczCanvasSize()
    if not listaScroll then return end
    local count = 0
    for _ in pairs(kartyGraczy) do count = count + 1 end
    listaScroll.CanvasSize = UDim2.new(0, 0, 0, count * (CARD_H + CARD_PAD) + 8)
end

local function przeliczPozycje()
    local i = 0
    for _, dane in pairs(kartyGraczy) do
        dane.frame.Position = UDim2.new(0, 6, 0, i * (CARD_H + CARD_PAD) + 4)
        i = i + 1
    end
    obliczCanvasSize()
end

local function stworzKarteGracza(gracz)
    if not listaScroll then return end
    if kartyGraczy[gracz] then return end

    local idx = 0
    for _ in pairs(kartyGraczy) do idx = idx + 1 end

    -- Główna ramka
    local karta = Instance.new("Frame")
    karta.Name             = "Karta_" .. gracz.Name
    karta.Size             = UDim2.new(1, -12, 0, CARD_H)
    karta.Position         = UDim2.new(0, 6, 0, idx * (CARD_H + CARD_PAD) + 4)
    karta.BackgroundColor3 = C_TLO
    karta.BorderSizePixel  = 0
    karta.ClipsDescendants = true
    karta.Parent           = listaScroll

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = karta

    local stroke = Instance.new("UIStroke")
    stroke.Color     = C_NORMALNY
    stroke.Thickness = 1.5
    stroke.Parent    = karta

    -- Avatar background
    local avatarBg = Instance.new("Frame")
    avatarBg.Size             = UDim2.new(0, 46, 0, 46)
    avatarBg.Position         = UDim2.new(0, 8, 0.5, -23)
    avatarBg.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    avatarBg.BorderSizePixel  = 0
    avatarBg.Parent           = karta
    Instance.new("UICorner", avatarBg).CornerRadius = UDim.new(0, 9)

    -- Avatar image
    local img = Instance.new("ImageLabel")
    img.Size              = UDim2.new(1, 0, 1, 0)
    img.BackgroundTransparency = 1
    img.Image             = avatarUrl(gracz.UserId)
    img.ScaleType         = Enum.ScaleType.Fit
    img.Parent            = avatarBg
    Instance.new("UICorner", img).CornerRadius = UDim.new(0, 9)

    -- Nazwa
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size                   = UDim2.new(1, -72, 0, 22)
    nameLabel.Position               = UDim2.new(0, 62, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text                   = gracz.Name
    nameLabel.TextColor3             = Color3.fromRGB(220, 220, 220)
    nameLabel.Font                   = Enum.Font.GothamBold
    nameLabel.TextSize               = 14
    nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
    nameLabel.TextTruncate           = Enum.TextTruncate.AtEnd
    nameLabel.Parent                 = karta

    -- Status
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size                   = UDim2.new(1, -72, 0, 16)
    statusLabel.Position               = UDim2.new(0, 62, 0, 34)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text                   = "Kliknij aby spectate"
    statusLabel.TextColor3             = Color3.fromRGB(130, 130, 145)
    statusLabel.Font                   = Enum.Font.Gotham
    statusLabel.TextSize               = 11
    statusLabel.TextXAlignment         = Enum.TextXAlignment.Left
    statusLabel.Parent                 = karta

    -- Strzałka
    local arrow = Instance.new("TextLabel")
    arrow.Size                   = UDim2.new(0, 22, 0, 22)
    arrow.Position               = UDim2.new(1, -30, 0.5, -11)
    arrow.BackgroundTransparency = 1
    arrow.Text                   = "▶"
    arrow.TextColor3             = Color3.fromRGB(90, 90, 105)
    arrow.Font                   = Enum.Font.GothamBold
    arrow.TextSize               = 11
    arrow.Parent                 = karta

    -- Klikalny overlay
    local btn = Instance.new("TextButton")
    btn.Size                   = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                   = ""
    btn.ZIndex                 = 5
    btn.Parent                 = karta

    local dane = {
        frame       = karta,
        stroke      = stroke,
        statusLabel = statusLabel,
        arrow       = arrow,
        nameLabel   = nameLabel,
    }
    kartyGraczy[gracz] = dane

    -- Toggle spectate
    btn.MouseButton1Click:Connect(function()
        if spectateTarget == gracz then
            -- Wyłącz spectate
            stopSpectate()
            resetKarty(dane)
        else
            -- Wyłącz poprzedni
            if spectateTarget then
                resetKarty(kartyGraczy[spectateTarget])
            end
            -- Włącz nowy
            spectateGracza(gracz)
            aktywujKarte(dane)
        end
    end)

    obliczCanvasSize()
end

local function usunKarteGracza(gracz)
    local dane = kartyGraczy[gracz]
    if not dane then return end
    pcall(function() dane.frame:Destroy() end)
    kartyGraczy[gracz] = nil
    przeliczPozycje()
end

local function odswiezListeGUI()
    if not listaScroll then return end

    -- Dodaj nowych
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer and czyJestKonfidentem(gracz) then
            stworzKarteGracza(gracz)
        end
    end

    -- Usuń starych
    for gracz in pairs(kartyGraczy) do
        if not gracz.Parent or not czyJestKonfidentem(gracz) then
            if spectateTarget == gracz then stopSpectate() end
            usunKarteGracza(gracz)
        end
    end
end

-- ===== AKTUALIZACJA KONFIG =====
local function aktualizujListe()
    local nowaKonfig = pobierzKonfiguracje()
    if not nowaKonfig then return end

    local nowi = {}
    for _, userId in ipairs(nowaKonfig.konfidenci or {}) do
        nowi[userId] = true
    end

    -- Usuń oznaczenia usuniętych konfidentów
    local starzy = currentConfig.konfidenci or {}
    for userId in pairs(starzy) do
        if not nowi[userId] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.UserId == userId then usunOznaczenia(gracz) end
            end
        end
    end
    -- Dodaj oznaczenia nowych konfidentów
    for userId in pairs(nowi) do
        if not starzy[userId] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.UserId == userId and gracz.Character then
                    dodajOznaczenia(gracz)
                end
            end
        end
    end

    currentConfig          = nowaKonfig
    currentConfig.konfidenci = nowi
    currentConfig.ustawienia = currentConfig.ustawienia or {
        kolorPodswietlenia = {255, 170, 0},
        przezroczystosc    = 0.4,
        tekstNadGlowa      = "Konfident",
    }

    local n = 0
    for _ in pairs(nowi) do n = n + 1 end
    print(("[KonfidentHunter] ✅ Odświeżono. Konfidenci: %d"):format(n))

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
        if spectateTarget == gracz then
            stopSpectate()
            resetKarty(kartyGraczy[gracz])
        end
        odswiezListeGUI()
    end)
end

-- ===== AUTO-ODŚWIEŻANIE =====
local function startAutoRefresh()
    while true do
        task.wait(REFRESH_TIME)
        aktualizujListe()
        -- Uzupełnij brakujące highlights
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

-- ===== WIND UI =====
local Window = WindUI:CreateWindow({
    Title  = "KonfidentHunter",
    Icon   = "shield-alert",
    Author = "by KonfidentHunter",
    Folder = "KonfidentHunter",
    NewElements   = true,
    HideSearchBar = true,
    Topbar = {
        Height      = 44,
        ButtonsType = "Mac",
    },
})

-- ── Zakładka: Lista ──
local ListaTab = Window:Tab({
    Title = "Lista",
    Icon  = "users",
})

-- Sekcja: Konfidenci
ListaTab:Section({
    Title = "Konfidenci na serwerze",
})

-- ── Wstrzykujemy własny ScrollingFrame w zakładkę WindUI ──
-- WindUI tworzy normalny ScrollingFrame / Frame dla zawartości zakładki.
-- Szukamy go po nazwie lub przez hierarchię po kilku sekundach.
task.spawn(function()
    task.wait(1.2)

    -- Szukaj rekurencyjnie miejsca gdzie jest zawartość zakładki "Lista"
    -- WindUI wkłada elementy do ScrollingFrame w oknie
    local function szukajListaFrame(parent, depth)
        if depth > 10 then return nil end
        for _, child in ipairs(parent:GetChildren()) do
            if (child:IsA("ScrollingFrame") or child:IsA("Frame")) then
                -- Szukamy TextLabel z tytułem sekcji
                for _, desc in ipairs(child:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Text == "Konfidenci na serwerze" then
                        -- Zwróć bezpośredniego rodzica tej sekcji (ScrollingFrame zakładki)
                        return child
                    end
                end
            end
            local found = szukajListaFrame(child, depth + 1)
            if found then return found end
        end
        return nil
    end

    local guiRoots = { game:GetService("CoreGui"), LocalPlayer.PlayerGui }
    local tabContainer = nil

    for _, root in ipairs(guiRoots) do
        tabContainer = szukajListaFrame(root, 0)
        if tabContainer then break end
    end

    if tabContainer then
        -- Twórz ScrollingFrame z kartami
        local scroll = Instance.new("ScrollingFrame")
        scroll.Name                  = "KonfidentListaScroll"
        scroll.Size                  = UDim2.new(1, 0, 0, 270)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel       = 0
        scroll.ScrollBarThickness    = 4
        scroll.ScrollBarImageColor3  = Color3.fromRGB(255, 170, 0)
        scroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
        scroll.ScrollingDirection    = Enum.ScrollingDirection.Y
        scroll.LayoutOrder           = 100
        scroll.Parent                = tabContainer

        listaScroll = scroll
        odswiezListeGUI()
        print("[KH] ✅ ScrollingFrame zainstalowany w zakładce WindUI")
    else
        warn("[KH] ⚠️ Nie znaleziono kontenera zakładki WindUI")
    end
end)

-- Przyciski akcji w zakładce Lista
ListaTab:Space()

ListaTab:Button({
    Title = "⏹  Stop Spectate",
    Icon  = "square",
    Callback = function()
        if spectateTarget then
            resetKarty(kartyGraczy[spectateTarget])
        end
        stopSpectate()
    end,
})

ListaTab:Space()

ListaTab:Button({
    Title = "🔄  Odśwież listę",
    Icon  = "refresh-cw",
    Callback = function()
        task.spawn(aktualizujListe)
    end,
})

-- ── Zakładka: Ustawienia ──
local UstawTab = Window:Tab({
    Title = "Ustawienia",
    Icon  = "settings",
})

UstawTab:Section({ Title = "Wizualne" })

UstawTab:Slider({
    Title = "Przezroczystość podświetlenia",
    Step  = 1,
    Value = { Min = 0, Max = 10, Default = 4 },
    Callback = function(v)
        if not currentConfig.ustawienia then currentConfig.ustawienia = {} end
        currentConfig.ustawienia.przezroczystosc = v / 10
        for _, folder in pairs(activeMarkers) do
            local hl = folder:FindFirstChild("Podswietlenie")
            if hl then hl.FillTransparency = v / 10 end
        end
    end,
})

UstawTab:Space()

UstawTab:Input({
    Title           = "Tekst nad głową",
    Placeholder     = "Konfident",
    Callback = function(v)
        if not currentConfig.ustawienia then currentConfig.ustawienia = {} end
        currentConfig.ustawienia.tekstNadGlowa = (v ~= "" and v or "Konfident")
        for gracz in pairs(activeMarkers) do
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
        currentConfig.ustawienia = currentConfig.ustawienia or {
            kolorPodswietlenia = {255, 170, 0},
            przezroczystosc    = 0.4,
            tekstNadGlowa      = "Konfident",
        }
    else
        currentConfig = {
            konfidenci = {},
            ustawienia = { kolorPodswietlenia = {255, 170, 0}, przezroczystosc = 0.4, tekstNadGlowa = "Konfident" },
        }
        warn("[KonfidentHunter] ⚠️ Pusta konfiguracja!")
    end

    local n = 0
    for _ in pairs(currentConfig.konfidenci) do n = n + 1 end
    print(("[KonfidentHunter] 🟢 Start. Konfidenci: %d"):format(n))

    -- Natychmiastowe oznaczenie obecnych graczy
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer and czyJestKonfidentem(gracz) and gracz.Character then
            dodajOznaczenia(gracz)
        end
    end

    WindUI:Notify({
        Title    = "KonfidentHunter",
        Content  = ("Załadowano. Baza: %d ID."):format(n),
        Icon     = "shield-alert",
        Duration = 5,
    })

    -- Monitorowanie aktualnych graczy
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer then monitorujGracza(gracz) end
    end

    -- Nowi gracze
    Players.PlayerAdded:Connect(function(gracz)
        if gracz == LocalPlayer then return end
        monitorujGracza(gracz)
        task.wait(0.3)
        if czyJestKonfidentem(gracz) and gracz.Character then
            dodajOznaczenia(gracz)
        end
        task.wait(0.2)
        odswiezListeGUI()
    end)

    -- Gracze opuszczający serwer
    Players.PlayerRemoving:Connect(function(gracz)
        task.wait(0.1)
        if spectateTarget == gracz then
            stopSpectate()
        end
        odswiezListeGUI()
    end)

    task.spawn(startAutoRefresh)
end

inicjuj()
