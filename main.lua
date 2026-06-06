--[[
    Konfident Hunter v6.0 – z Rayfield GUI
    - Pobiera listę konfidentów z config.lua na GitHub
    - Odświeża co 30 sekund (dodaje/usuwa oznaczenia na żywo)
    - Podświetlenie i tekst "KONFIDENT" nad głową
    - GUI Rayfield (toggle klawiszem K)
]]

-- ===== KONFIGURACJA =====
local REFRESH_TIME = 30
local CONFIG_URL = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"
-- ========================

-- ===== Ładowanie Rayfield =====
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Zmienne
local currentConfig = { konfidenci = {}, ustawienia = {} }
local activeMarkers = {}

-- ===== DOMYŚLNE USTAWIENIA =====
local function getUstawienia()
    return currentConfig.ustawienia or {
        kolorPodswietlenia = {255, 170, 0},
        przezroczystosc    = 0.4,
        tekstNadGlowa      = "KONFIDENT",
        kolorTekstu        = {255, 255, 255},
    }
end

-- ===== Pobieranie konfiguracji z GitHub =====
local function pobierzKonfiguracje()
    local success, result = pcall(function()
        return game:HttpGet(CONFIG_URL)
    end)
    if not success then
        warn("❌ Nie udało się pobrać configu: " .. tostring(result))
        return nil
    end
    local func, err = loadstring(result)
    if not func then
        warn("❌ Błąd parsowania configu: " .. tostring(err))
        return nil
    end
    local ok, config = pcall(func)
    if not ok then
        warn("❌ Błąd wykonania configu: " .. tostring(config))
        return nil
    end
    return config
end

-- ===== Sprawdzanie konfidenta =====
local function czyJestKonfidentem(gracz)
    return currentConfig.konfidenci and currentConfig.konfidenci[gracz.Name:lower()] == true
end

-- ===== Usuwanie oznaczeń =====
local function usunOznaczenia(gracz)
    local folder = activeMarkers[gracz]
    if folder then
        folder:Destroy()
        activeMarkers[gracz] = nil
    end
end

-- ===== Dodawanie oznaczeń =====
local function dodajOznaczenia(gracz)
    if not czyJestKonfidentem(gracz) then return false end
    local character = gracz.Character
    if not character then return false end

    -- Highlight wymaga Model jako Adornee, tekst nad głową potrzebuje BasePart
    local headPart = character:FindFirstChild("Head")
                  or character:FindFirstChild("HumanoidRootPart")
                  or character:FindFirstChild("UpperTorso")
    if not headPart then return false end

    if activeMarkers[gracz] then usunOznaczenia(gracz) end

    local folder = Instance.new("Folder")
    folder.Name = "KonfidentMarkery"
    folder.Parent = gracz
    activeMarkers[gracz] = folder

    local ust = getUstawienia()

    -- Highlight – Adornee = cały Model (character), nie pojedyncza część!
    local highlight = Instance.new("Highlight")
    highlight.Name = "Podswietlenie"
    local k = ust.kolorPodswietlenia or {255, 170, 0}
    highlight.FillColor = Color3.fromRGB(k[1], k[2], k[3])
    highlight.FillTransparency = ust.przezroczystosc or 0.4
    highlight.OutlineColor = Color3.fromRGB(k[1], k[2], k[3])
    highlight.OutlineTransparency = 0.0
    highlight.Adornee = character  -- <-- MODEL, nie BasePart
    highlight.Parent = folder

    -- Tekst nad głową – Adornee = BasePart (Head)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TekstKonfidenta"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Adornee = headPart
    billboard.Parent = folder

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = ust.tekstNadGlowa or "KONFIDENT"
    local kt = ust.kolorTekstu or {255, 255, 255}
    textLabel.TextColor3 = Color3.fromRGB(kt[1], kt[2], kt[3])
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextStrokeTransparency = 0.2
    textLabel.Parent = billboard

    return true
end

-- ===== Sekcja Rayfield z listą =====
-- (referencja do zakładki, uzupełniana po inicjalizacji GUI)
local listaSection = nil
local listaTab     = nil
local statusLabel  = nil

local function odswiezListeRayfield()
    if not listaSection then return end

    -- Usuń stare elementy listy (TextLabel-y)
    for _, obj in ipairs(listaTab:GetChildren()) do
        if obj.Name == "KonfidentEntry" then
            obj:Destroy()
        end
    end

    local listaNazw = {}
    for nazwa, _ in pairs(currentConfig.konfidenci) do
        table.insert(listaNazw, nazwa)
    end
    table.sort(listaNazw)

    local liczbaOnline = 0
    for _, nazwa in ipairs(listaNazw) do
        local online = false
        for _, gracz in ipairs(Players:GetPlayers()) do
            if gracz.Name:lower() == nazwa then
                online = true
                liczbaOnline = liczbaOnline + 1
                break
            end
        end

        -- Rayfield Label (symulujemy przez Paragraph)
        listaTab:CreateParagraph({
            Title = (online and "🟢 " or "🔴 ") .. nazwa,
            Content = online and "ONLINE — oznaczony w grze" or "Offline",
        })
    end

    if #listaNazw == 0 then
        listaTab:CreateParagraph({
            Title = "Brak konfidentów",
            Content = "Lista jest pusta. Sprawdź config.lua na GitHubie.",
        })
    end

    -- Powiadomienie z podsumowaniem
    Rayfield:Notify({
        Title   = "Lista odświeżona",
        Content = "Konfidenci w bazie: " .. #listaNazw .. " | Online: " .. liczbaOnline,
        Duration = 4,
        Image   = "shield-alert",
    })
end

-- ===== Aktualizacja listy konfidentów =====
local function aktualizujListe(silent)
    local nowaKonfig = pobierzKonfiguracje()
    if not nowaKonfig then return end

    local nowi = {}
    for _, nazwa in ipairs(nowaKonfig.konfidenci or {}) do
        nowi[nazwa:lower()] = true
    end

    local starzy = currentConfig.konfidenci or {}

    -- Usuń oznaczenia dla usuniętych z listy
    for nazwa, _ in pairs(starzy) do
        if not nowi[nazwa] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.Name:lower() == nazwa then
                    usunOznaczenia(gracz)
                end
            end
        end
    end

    -- Dodaj oznaczenia dla nowych
    for nazwa, _ in pairs(nowi) do
        if not starzy[nazwa] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.Name:lower() == nazwa and gracz.Character then
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
            tekstNadGlowa      = "KONFIDENT",
            kolorTekstu        = {255, 255, 255},
        }
    end

    local liczba = 0
    for _ in pairs(nowi) do liczba = liczba + 1 end
    print("[KonfidentHunter] ✅ Odświeżono. Konfidenci w bazie: " .. liczba)

    -- Odśwież GUI
    odswiezListeRayfield()
end

-- ===== Monitorowanie graczy =====
local function monitorujGracza(gracz)
    if gracz == LocalPlayer then return end

    local function onCharacterAdded()
        task.wait(0.5)
        if czyJestKonfidentem(gracz) then
            dodajOznaczenia(gracz)
        end
    end

    if gracz.Character then onCharacterAdded() end
    gracz.CharacterAdded:Connect(onCharacterAdded)
    gracz.CharacterRemoving:Connect(function()
        usunOznaczenia(gracz)
    end)
end

-- ===== Auto-odświeżanie =====
local function startAutoRefresh()
    while true do
        task.wait(REFRESH_TIME)
        aktualizujListe(true)
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

-- ===== BUDOWANIE GUI RAYFIELD =====
local Window = Rayfield:CreateWindow({
    Name             = "Konfident Hunter",
    Icon             = "shield-alert",        -- ikona Lucide
    LoadingTitle     = "Konfident Hunter v6.0",
    LoadingSubtitle  = "Ładowanie listy...",
    Theme            = "Default",
    ToggleUIKeybind  = "K",                   -- toggle klawiszem K tak jak wcześniej
    DisableRayfieldPrompts  = false,
    DisableBuildWarnings    = false,
    ConfigurationSaving = {
        Enabled    = false,
        FolderName = nil,
        FileName   = "KonfidentHunter",
    },
    Discord = {
        Enabled      = false,
        Invite       = "noinvitelink",
        RememberJoins = true,
    },
    KeySystem = false,
})

-- ── Zakładka 1: Lista konfidentów ──
listaTab = Window:CreateTab("Lista", "users")
listaTab:CreateSection("Konfidenci")

listaTab:CreateButton({
    Name     = "🔄 Odśwież teraz",
    Callback = function()
        task.spawn(aktualizujListe)
    end,
})

listaTab:CreateDivider()
listaTab:CreateSection("Gracze na serwerze")

-- ── Zakładka 2: Ustawienia ──
local settingsTab = Window:CreateTab("Ustawienia", "settings")
settingsTab:CreateSection("Wykrywanie")

settingsTab:CreateSlider({
    Name    = "Przezroczystość podświetlenia",
    Range   = {0, 10},
    Increment = 1,
    CurrentValue = 4,   -- 0.4 * 10
    Flag    = "Przezroczystosc",
    Callback = function(value)
        if not currentConfig.ustawienia then
            currentConfig.ustawienia = {}
        end
        currentConfig.ustawienia.przezroczystosc = value / 10

        -- Zaktualizuj istniejące highlighty
        for gracz, folder in pairs(activeMarkers) do
            local hl = folder:FindFirstChild("Podswietlenie")
            if hl then
                hl.FillTransparency = value / 10
            end
        end
    end,
})

settingsTab:CreateInput({
    Name        = "Tekst nad głową",
    PlaceholderText = "KONFIDENT",
    RemoveTextAfterFocusLost = false,
    Flag        = "TekstNadGlowa",
    Callback    = function(value)
        if not currentConfig.ustawienia then
            currentConfig.ustawienia = {}
        end
        currentConfig.ustawienia.tekstNadGlowa = (value ~= "" and value or "KONFIDENT")

        -- Zaktualizuj istniejące etykiety
        for gracz, folder in pairs(activeMarkers) do
            local bb = folder:FindFirstChild("TekstKonfidenta")
            if bb then
                local lbl = bb:FindFirstChildOfClass("TextLabel")
                if lbl then
                    lbl.Text = currentConfig.ustawienia.tekstNadGlowa
                end
            end
        end
    end,
})

settingsTab:CreateSection("Informacje")

settingsTab:CreateParagraph({
    Title   = "Jak działa?",
    Content = "Skrypt pobiera listę konfidentów z GitHub co " .. REFRESH_TIME .. " sekund. "
           .. "Gracze z listy są podświetlani i oznaczani tekstem nad głową. "
           .. "Naciśnij K, aby otworzyć/zamknąć to menu.",
})

settingsTab:CreateParagraph({
    Title   = "Źródło danych",
    Content = CONFIG_URL,
})

-- ── Zakładka 3: O skrypcie ──
local aboutTab = Window:CreateTab("Info", "info")
aboutTab:CreateSection("Konfident Hunter v6.0")

aboutTab:CreateParagraph({
    Title   = "Autor",
    Content = "Skrypt stworzony na potrzeby społeczności.\nGUI: Rayfield by Sirius",
})

aboutTab:CreateButton({
    Name     = "Wymuś ponowne oznaczenie wszystkich",
    Callback = function()
        for _, gracz in ipairs(Players:GetPlayers()) do
            if gracz ~= LocalPlayer then
                usunOznaczenia(gracz)
                if czyJestKonfidentem(gracz) and gracz.Character then
                    dodajOznaczenia(gracz)
                end
            end
        end
        Rayfield:Notify({
            Title    = "Gotowe",
            Content  = "Oznaczenia odświeżone dla wszystkich graczy.",
            Duration = 3,
        })
    end,
})

aboutTab:CreateButton({
    Name     = "Usuń WSZYSTKIE oznaczenia (toggle off)",
    Callback = function()
        for _, gracz in ipairs(Players:GetPlayers()) do
            usunOznaczenia(gracz)
        end
        Rayfield:Notify({
            Title    = "Oznaczenia usunięte",
            Content  = "Wszystkie highlighty zostały usunięte.",
            Duration = 3,
        })
    end,
})

-- ===== INICJALIZACJA =====
local function inicjuj()
    local config = pobierzKonfiguracje()
    if config then
        local slownik = {}
        for _, nazwa in ipairs(config.konfidenci or {}) do
            slownik[nazwa:lower()] = true
        end
        currentConfig = config
        currentConfig.konfidenci = slownik
        if not currentConfig.ustawienia then
            currentConfig.ustawienia = {
                kolorPodswietlenia = {255, 170, 0},
                przezroczystosc    = 0.4,
                tekstNadGlowa      = "KONFIDENT",
                kolorTekstu        = {255, 255, 255},
            }
        end
    else
        currentConfig = {
            konfidenci = {},
            ustawienia = {
                kolorPodswietlenia = {255, 170, 0},
                przezroczystosc    = 0.4,
                tekstNadGlowa      = "KONFIDENT",
                kolorTekstu        = {255, 255, 255},
            },
        }
        print("[KonfidentHunter] ⚠️ Uruchomiono z domyślną pustą konfiguracją.")
    end

    local liczba = 0
    for _ in pairs(currentConfig.konfidenci) do liczba = liczba + 1 end
    print("[KonfidentHunter] 🟢 Uruchomiono. Konfidenci w bazie: " .. liczba)

    -- Wypełnij listę Rayfield
    odswiezListeRayfield()

    -- Powiadom
    Rayfield:Notify({
        Title    = "Konfident Hunter",
        Content  = "Załadowano! Konfidenci w bazie: " .. liczba .. ". Naciśnij K, aby otworzyć menu.",
        Duration = 6,
        Image    = "shield-alert",
    })

    -- Podłącz graczy
    for _, gracz in ipairs(Players:GetPlayers()) do
        if gracz ~= LocalPlayer then
            monitorujGracza(gracz)
        end
    end
    Players.PlayerAdded:Connect(function(gracz)
        if gracz ~= LocalPlayer then
            monitorujGracza(gracz)
        end
    end)
    Players.PlayerRemoving:Connect(function()
        odswiezListeRayfield()
    end)

    -- Auto-odświeżanie
    task.spawn(startAutoRefresh)
end

inicjuj()
