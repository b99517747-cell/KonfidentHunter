--[[
    Konfident Hunter
    - Config oparty na ID kont Roblox
    - Dropdown w Rayfield do wyboru gracza (spectate)
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

local currentConfig  = { konfidenci = {}, ustawienia = {} }
local activeMarkers  = {}
local spectateTarget = nil
local playerDropdown = nil  -- referencja do dropdownu

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
    -- Resetuj dropdown do "None"
    if playerDropdown then
        pcall(function() playerDropdown:Set("None") end)
    end
end

-- ===== AKTUALIZACJA DROPDOWNU =====
local function aktualizujDropdown()
    if not playerDropdown then return end
    local options = {"None"}
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer and czyJestKonfidentem(gracz) then
            table.insert(options, gracz.Name)
        end
    end
    -- Jeśli obserwowany gracz już nie istnieje → stop
    if spectateTarget and not spectateTarget.Parent then
        stopSpectate()
    end
    pcall(function()
        playerDropdown:Refresh(options, false)
    end)
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

    aktualizujDropdown()
end

-- ===== MONITOROWANIE GRACZY =====
local function monitorujGracza(gracz)
    if gracz == LocalPlayer then return end
    gracz.CharacterAdded:Connect(function()
        task.wait(0.3)
        if czyJestKonfidentem(gracz) then dodajOznaczenia(gracz) end
        aktualizujDropdown()
    end)
    gracz.CharacterRemoving:Connect(function()
        usunOznaczenia(gracz)
        if spectateTarget == gracz then stopSpectate() end
        aktualizujDropdown()
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

-- ── Lista ──
local listaTab = Window:CreateTab("Lista", "users")
listaTab:CreateSection("Obserwowanie")

-- Dropdown do wyboru gracza
playerDropdown = listaTab:CreateDropdown({
    Name           = "Wybierz konfidenta",
    Options        = {"None"},
    CurrentOption  = {"None"},
    MultipleOptions = false,
    Flag           = "KonfidentSelect",
    Callback       = function(value)
        -- value może być stringiem lub tabelą
        local nazwa = type(value) == "table" and value[1] or value
        if not nazwa or nazwa == "None" then
            stopSpectate()
            return
        end
        for _, gracz in ipairs(Players:GetPlayers()) do
            if gracz.Name == nazwa then
                spectateGracza(gracz)
                return
            end
        end
    end,
})

listaTab:CreateButton({
    Name = "⏹ Stop spectate",
    Callback = function()
        stopSpectate()
    end,
})

listaTab:CreateButton({
    Name = "🔄 Odśwież listę",
    Callback = function()
        task.spawn(aktualizujListe)
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
        warn("[KonfidentHunter] ⚠️ Pusta konfiguracja.")
    end

    local liczba = 0
    for _ in pairs(currentConfig.konfidenci) do liczba = liczba + 1 end
    print("[KonfidentHunter] 🟢 Start. Konfidenci: " .. liczba)

    -- Natychmiastowe oznaczenie graczy już na serwerze
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer and czyJestKonfidentem(gracz) and gracz.Character then
            dodajOznaczenia(gracz)
        end
    end

    -- Wypełnij dropdown
    aktualizujDropdown()

    Rayfield:Notify({
        Title   = "KonfidentHunter",
        Content = "Załadowano. Baza: " .. liczba .. " ID. Naciśnij K.",
        Duration = 5,
        Image   = "shield-alert",
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
            aktualizujDropdown()
        end
    end)

    Players.PlayerRemoving:Connect(function(gracz)
        task.wait(0.1)
        aktualizujDropdown()
    end)

    task.spawn(startAutoRefresh)
end

inicjuj()
