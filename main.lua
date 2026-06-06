--[[
    Konfident Hunter v5.0 - Rayfield GUI + Live Update
    - Wykrywa konfidentów z config.lua na GitHub (odświeżanie co 30 sekund)
    - Oznacza graczy na serwerze pomarańczowym podświetleniem i tekstem "KONFIDENT"
    - GUI Rayfield z listą online/offline i ustawieniami wizualnymi
    - Wszystkie zmiany na żywo
]]

-- =========== KONFIGURACJA ===========
local REFRESH_TIME = 30 -- co ile sekund sprawdzać nową listę
local CONFIG_URL = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"
local GUI_TOGGLE_KEY = "K" -- Klawisz do otwierania/zamykania GUI (jako string)
-- ===================================

-- Załaduj bibliotekę Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Serwisy Roblox
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- Zmienne globalne
local currentConfig = { konfidenci = {}, ustawienia = {} }
local activeMarkers = {} -- słownik: gracz -> folder z markerami
local window = nil
local mainTab = nil
local listaElement = nil -- referencja do elementu listy w GUI
local colorPicker = nil
local sliderPrzezroczystosc = nil
local inputTekst = nil

-- === Pobieranie konfiguracji z GitHub ===
local function pobierzKonfiguracje()
    local success, result = pcall(function()
        return game:HttpGet(CONFIG_URL)
    end)
    if not success then
        warn("Nie udało się pobrać configu: " .. tostring(result))
        return nil
    end
    local func, err = loadstring(result)
    if not func then
        warn("Błąd parsowania configu: " .. tostring(err))
        return nil
    end
    local ok, config = pcall(func)
    if not ok then
        warn("Błąd wykonania configu: " .. tostring(config))
        return nil
    end
    return config
end

-- === Aktualizacja słownika konfidentów ===
local function aktualizujSłownikKonfidentow()
    local nowaKonfig = pobierzKonfiguracje()
    if not nowaKonfig then return end

    -- Buduj słownik nowych konfidentów
    local nowi = {}
    for _, nazwa in ipairs(nowaKonfig.konfidenci or {}) do
        nowi[nazwa:lower()] = true
    end

    -- Porównaj ze starą listą
    local starzy = currentConfig.konfidenci or {}

    -- Usuń oznaczenia dla tych, którzy już nie są konfidentami
    for nazwa, _ in pairs(starzy) do
        if not nowi[nazwa] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.Name:lower() == nazwa then
                    usunOznaczenia(gracz)
                end
            end
        end
    end

    -- Dodaj oznaczenia dla nowych konfidentów (jeśli mają postać)
    for nazwa, _ in pairs(nowi) do
        if not starzy[nazwa] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.Name:lower() == nazwa and gracz.Character then
                    dodajOznaczenia(gracz)
                end
            end
        end
    end

    -- Zaktualizuj obecną konfigurację
    currentConfig = nowaKonfig
    currentConfig.konfidenci = nowi
    if not currentConfig.ustawienia then
        currentConfig.ustawienia = {
            kolorPodswietlenia = {255, 170, 0},
            przezroczystosc = 0.4,
            tekstNadGlowa = "KONFIDENT",
            kolorTekstu = {255, 255, 255},
        }
    end

    -- Odśwież element listy w GUI, jeśli istnieje
    if listaElement then
        local items = {}
        for nazwa, _ in pairs(nowi) do
            local online = false
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.Name:lower() == nazwa then
                    online = true
                    break
                end
            end
            table.insert(items, {
                Name = nazwa,
                Value = online and "🟢 ONLINE" or "⚫ OFFLINE"
            })
        end
        listaElement:Set(items)
    end

    -- Aktualizuj wartości w GUI (jeśli istnieją)
    if colorPicker then
        local kolor = currentConfig.ustawienia.kolorPodswietlenia
        colorPicker:Set(Color3.fromRGB(kolor[1], kolor[2], kolor[3]))
    end
    if sliderPrzezroczystosc then
        sliderPrzezroczystosc:Set(currentConfig.ustawienia.przezroczystosc)
    end
    if inputTekst then
        inputTekst:Set(currentConfig.ustawienia.tekstNadGlowa)
    end

    print("[KonfidentHunter] Odświeżono. Liczba konfidentów: " .. #(nowaKonfig.konfidenci or {}))
end

-- === Sprawdzanie czy gracz jest konfidentem ===
local function czyJestKonfidentem(gracz)
    return currentConfig.konfidenci and currentConfig.konfidenci[gracz.Name:lower()] == true
end

-- === Dodawanie podświetlenia i tekstu ===
function dodajOznaczenia(gracz)
    if not czyJestKonfidentem(gracz) then return false end

    local character = gracz.Character
    if not character then return false end

    -- Znajdź część ciała
    local adornee = character:FindFirstChild("HumanoidRootPart") or 
                    character:FindFirstChild("Head") or
                    character:FindFirstChild("UpperTorso")
    if not adornee then return false end

    -- Usuń stare markery jeśli istnieją
    if activeMarkers[gracz] then
        usunOznaczenia(gracz)
    end

    local folder = Instance.new("Folder")
    folder.Name = "KonfidentMarkery"
    folder.Parent = gracz
    activeMarkers[gracz] = folder

    -- Highlight (podświetlenie)
    local highlight = Instance.new("Highlight")
    highlight.Name = "Podswietlenie"
    local kolor = currentConfig.ustawienia.kolorPodswietlenia or {255, 170, 0}
    highlight.FillColor = Color3.fromRGB(kolor[1], kolor[2], kolor[3])
    highlight.FillTransparency = currentConfig.ustawienia.przezroczystosc or 0.4
    highlight.OutlineTransparency = 0.2
    highlight.Adornee = adornee
    highlight.Parent = folder

    -- BillboardGui (tekst nad głową)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TekstKonfidenta"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Adornee = adornee
    billboard.Parent = folder

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = currentConfig.ustawienia.tekstNadGlowa or "KONFIDENT"
    local kolorTekstu = currentConfig.ustawienia.kolorTekstu or {255, 255, 255}
    textLabel.TextColor3 = Color3.fromRGB(kolorTekstu[1], kolorTekstu[2], kolorTekstu[3])
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextStrokeTransparency = 0.2
    textLabel.Parent = billboard

    return true
end

function usunOznaczenia(gracz)
    local folder = activeMarkers[gracz]
    if folder then
        folder:Destroy()
        activeMarkers[gracz] = nil
    end
end

-- === Tworzenie GUI Rayfield ===
local function stworzGUI()
    -- Główne okno
    window = Rayfield:CreateWindow({
        Name = "Konfident Hunter",
        LoadingTitle = "Konfident Hunter",
        LoadingSubtitle = "by TwojeImię",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "KonfidentHunter",
            FileName = "Ustawienia"
        },
        Discord = {
            Enabled = false,
            Invite = "",
            RememberJoins = true
        },
        KeySystem = false,
        KeySettings = {
            Title = "Klucz",
            Subtitle = "Wpisz klucz",
            Note = ""
        }
    })

    -- Zakładki
    local glowneTab = window:CreateTab("🏠 Główna", nil) -- nil = bez ikony
    local listaTab = window:CreateTab("📋 Lista konfidentów", nil)
    local ustawieniaTab = window:CreateTab("⚙️ Ustawienia", nil)

    -- GŁÓWNA zakładka
    glowneTab:CreateParagraph({
        Title = "Informacje",
        Content = "Skrypt automatycznie wykrywa konfidentów z listy GitHub.\nOdświeżanie co " .. REFRESH_TIME .. " sekund.\n\n📌 Oznaczeni gracze mają podświetlenie i napis nad głową."
    })

    glowneTab:CreateButton({
        Name = "🔄 Ręcznie odśwież listę",
        Callback = function()
            task.spawn(aktualizujSłownikKonfidentow)
            Rayfield:Notify({
                Title = "Odświeżono",
                Content = "Lista konfidentów została zaktualizowana.",
                Duration = 3,
            })
        end
    })

    -- LISTA konfidentów
    local listaSection = listaTab:CreateSection("Lista konfidentów z bazy")
    listaElement = listaTab:CreateList({
        Name = "ListaKonfidentow",
        CurrentValue = {},
        Values = {},
        Multiple = false,
        Flag = "lista_konfidentow"
    })

    -- USTAWIENIA wizualne
    local ustawieniaSection = ustawieniaTab:CreateSection("Wygląd znacznika")
    colorPicker = ustawieniaTab:CreateColorPicker({
        Name = "Kolor podświetlenia",
        Color = Color3.fromRGB(255, 170, 0),
        Flag = "KolorPodswietlenia",
        Callback = function(color)
            -- Aktualizuj kolor dla wszystkich aktywnych markerów
            for gracz, folder in pairs(activeMarkers) do
                local highlight = folder:FindFirstChild("Podswietlenie")
                if highlight then
                    highlight.FillColor = color
                end
            end
            -- Zapisz do configu
            if currentConfig.ustawienia then
                currentConfig.ustawienia.kolorPodswietlenia = {color.R * 255, color.G * 255, color.B * 255}
            end
        end
    })

    sliderPrzezroczystosc = ustawieniaTab:CreateSlider({
        Name = "Przezroczystość podświetlenia",
        Range = {0, 1},
        Increment = 0.05,
        Suffix = "",
        CurrentValue = 0.4,
        Flag = "Przezroczystosc",
        Callback = function(value)
            for gracz, folder in pairs(activeMarkers) do
                local highlight = folder:FindFirstChild("Podswietlenie")
                if highlight then
                    highlight.FillTransparency = value
                end
            end
        end
    })

    inputTekst = ustawieniaTab:CreateInput({
        Name = "Tekst nad głową",
        PlaceholderText = "KONFIDENT",
        RemoveTextAfterFocus = false,
        Flag = "TekstNadGlowa",
        Callback = function(text)
            for gracz, folder in pairs(activeMarkers) do
                local billboard = folder:FindFirstChild("TekstKonfidenta")
                if billboard then
                    local label = billboard:FindFirstChild("TextLabel")
                    if label then
                        label.Text = text
                    end
                end
            end
        end
    })

    -- Notyfikacja startowa
    Rayfield:Notify({
        Title = "Konfident Hunter",
        Content = "GUI gotowe! Użyj klawisza '" .. GUI_TOGGLE_KEY .. "' aby otworzyć/zamknąć.",
        Duration = 5,
    })
end

-- === Obsługa klawisza do otwierania/zamykania GUI ===
-- Rayfield domyślnie używa przycisku w prawym górnym rogu, ale dodajemy też własną obsługę klawisza
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode[GUI_TOGGLE_KEY] then
        if window then
            window:Toggle()
        end
    end
end)

-- === Monitorowanie postaci graczy ===
local function monitorujGracza(gracz)
    if gracz == LocalPlayer then return end

    local function onCharacterAdded()
        task.wait(0.5) -- daj czas na załadowanie
        if czyJestKonfidentem(gracz) then
            dodajOznaczenia(gracz)
        end
    end

    local function onCharacterRemoving()
        usunOznaczenia(gracz)
    end

    if gracz.Character then
        onCharacterAdded()
    end
    gracz.CharacterAdded:Connect(onCharacterAdded)
    gracz.CharacterRemoving:Connect(onCharacterRemoving)
end

-- === Pętla auto-odświeżania ===
local function startAutoRefresh()
    while true do
        task.wait(REFRESH_TIME)
        aktualizujSłownikKonfidentow()
        -- Dodatkowo sprawdź wszystkich graczy (na wypadek gdyby nowy konfident nie dostał znacznika)
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

-- === Inicjalizacja ===
local function inicjuj()
    -- Wczytaj konfigurację początkową
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
                przezroczystosc = 0.4,
                tekstNadGlowa = "KONFIDENT",
                kolorTekstu = {255, 255, 255},
            }
        end
    else
        -- Domyślna pusta konfiguracja
        currentConfig = {
            konfidenci = {},
            ustawienia = {
                kolorPodswietlenia = {255, 170, 0},
                przezroczystosc = 0.4,
                tekstNadGlowa = "KONFIDENT",
                kolorTekstu = {255, 255, 255},
            }
        }
    end

    print("[KonfidentHunter] Uruchomiono. Konfidenci w bazie: " .. #(currentConfig.konfidenci and table.getn(currentConfig.konfidenci) or 0))

    -- Stwórz GUI
    stworzGUI()

    -- Podłącz wszystkich graczy
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
        -- Odśwież listę w GUI przy wyjściu gracza
        if listaElement then
            local items = {}
            for nazwa, _ in pairs(currentConfig.konfidenci) do
                local online = false
                for _, gracz in ipairs(Players:GetPlayers()) do
                    if gracz.Name:lower() == nazwa then
                        online = true
                        break
                    end
                end
                table.insert(items, {
                    Name = nazwa,
                    Value = online and "🟢 ONLINE" or "⚫ OFFLINE"
                })
            end
            listaElement:Set(items)
        end
    end)

    -- Uruchom auto-odświeżanie
    task.spawn(startAutoRefresh)
end

-- Start
inicjuj()
