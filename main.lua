local REFRESH_TIME = 30
local CONFIG_URL = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"

local Rayfield
if not game:IsLoaded() then game.Loaded:Wait() end

local success, result = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/xzffz/Rayfield/main/source.lua"))()
end)
if success and result then
    Rayfield = result
else
    warn("Nie udało się załadować Rayfield. GUI nie będzie dostępne.")
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

local currentConfig = { konfidenci = {}, ustawienia = {} }
local activeMarkers = {}
local window = nil
local mainTab = nil
local listaSection = nil
local refreshInterval = nil

local function pobierzKonfiguracje()
    local success, result = pcall(function()
        return loadstring(game:HttpGet(CONFIG_URL))()
    end)
    if success and result then
        return result
    else
        return {
            konfidenci = {},
            ustawienia = {
                kolorPodswietlenia = {255, 170, 0},
                przezroczystosc = 0.4,
                tekstNadGlowa = "KONFIDENT",
                kolorTekstu = {255, 255, 255},
            }
        }
    end
end

local function czyJestKonfidentem(gracz)
    if not currentConfig.konfidenci then return false end
    return currentConfig.konfidenci[gracz.Name:lower()] == true
end

function dodajOznaczenia(gracz)
    if not czyJestKonfidentem(gracz) then return false end
    
    local character = gracz.Character
    if not character then return false end
    
    local adornee = character:FindFirstChild("HumanoidRootPart") or 
                    character:FindFirstChild("Head") or
                    character:FindFirstChild("UpperTorso")
    if not adornee then return false end
    
    if activeMarkers[gracz] then
        usunOznaczenia(gracz)
    end
    
    local folder = Instance.new("Folder")
    folder.Name = "KonfidentMarkery"
    folder.Parent = gracz
    activeMarkers[gracz] = folder
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "Podswietlenie"
    local kolor = currentConfig.ustawienia.kolorPodswietlenia or {255, 170, 0}
    highlight.FillColor = Color3.fromRGB(kolor[1], kolor[2], kolor[3])
    highlight.FillTransparency = currentConfig.ustawienia.przezroczystosc or 0.4
    highlight.OutlineTransparency = 0.3
    highlight.Adornee = adornee
    highlight.Parent = folder
    
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

local function aktualizujListeKonfidentow()
    local nowaKonfig = pobierzKonfiguracje()
    local nowi = {}
    for _, nazwa in ipairs(nowaKonfig.konfidenci) do
        nowi[nazwa:lower()] = true
    end
    
    local starzy = currentConfig.konfidenci or {}
    
    for nazwa, _ in pairs(starzy) do
        if not nowi[nazwa] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.Name:lower() == nazwa then
                    usunOznaczenia(gracz)
                end
            end
        end
    end
    
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
    
    if window and listaSection then
        local listaElementow = listaSection:Get("ListaKonfidentow")
        if listaElementow then
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
            listaElementow:Set(items)
        end
    end
    
    print("[KonfidentHunter] Odświeżono. Liczba konfidentów: " .. #nowaKonfig.konfidenci)
end

local function monitorujGracza(gracz)
    if gracz == LocalPlayer then return end
    
    local function onCharAdded()
        task.wait(0.5)
        if czyJestKonfidentem(gracz) then
            dodajOznaczenia(gracz)
        end
    end
    
    local function onCharRemoving()
        usunOznaczenia(gracz)
    end
    
    if gracz.Character then
        onCharAdded()
    end
    gracz.CharacterAdded:Connect(onCharAdded)
    gracz.CharacterRemoving:Connect(onCharRemoving)
end

local function stworzGui()
    if not Rayfield then
        warn("Rayfield nie jest dostępny. GUI nie zostanie utworzone.")
        return
    end
    
    window = Rayfield:CreateWindow({
        Name = "Konfident Hunter",
        LoadingTitle = "Konfident Hunter",
        LoadingSubtitle = "by TwojeImię",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "KonfidentHunter",
            FileName = "Settings"
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
    
    mainTab = window:CreateTab("🏠 Główna")
    local konfidenciTab = window:CreateTab("📋 Lista konfidentów")
    local ustawieniaTab = window:CreateTab("⚙️ Ustawienia")
    
    mainTab:CreateParagraph({
        Title = "Informacje",
        Content = "Skrypt automatycznie wykrywa konfidentów z listy GitHub.\nOdświeżanie co " .. REFRESH_TIME .. " sekund.\n\n📌 Oznaczeni gracze mają pomarańczowe podświetlenie i napis 'KONFIDENT' nad głową."
    })
    
    mainTab:CreateButton({
        Name = "🔄 Ręcznie odśwież listę",
        Callback = function()
            aktualizujListeKonfidentow()
            Rayfield:Notify({
                Title = "Odświeżono",
                Content = "Lista konfidentów została zaktualizowana.",
                Duration = 3,
            })
        end
    })
    
    listaSection = konfidenciTab:CreateSection("Lista konfidentów z bazy")
    
    local listaElement = konfidenciTab:CreateList({
        Name = "ListaKonfidentow",
        CurrentValue = {},
        Values = {},
        Multiple = false,
        Flag = "lista_konfidentow"
    })
    
    local function wypelnijListe()
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
    
    local kolorPicker = ustawieniaTab:CreateColorPicker({
        Name = "Kolor podświetlenia",
        Color = Color3.fromRGB(255, 170, 0),
        Flag = "KolorPodswietlenia",
        Callback = function(color)
            for gracz, folder in pairs(activeMarkers) do
                local highlight = folder:FindFirstChild("Podswietlenie")
                if highlight then
                    highlight.FillColor = color
                end
            end
            if currentConfig.ustawienia then
                currentConfig.ustawienia.kolorPodswietlenia = {color.R * 255, color.G * 255, color.B * 255}
            end
        end
    })
    
    local sliderPrzezroczystosc = ustawieniaTab:CreateSlider({
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
    
    local inputTekst = ustawieniaTab:CreateInput({
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
    
    Rayfield:Notify({
        Title = "Konfident Hunter",
        Content = "GUI gotowe! Naciśnij przycisk na ekranie lub użyj /kh",
        Duration = 5,
    })
    
    wypelnijListe()
    
    Players.PlayerAdded:Connect(function()
        task.wait(1)
        wypelnijListe()
    end)
    Players.PlayerRemoving:Connect(function()
        task.wait(1)
        wypelnijListe()
    end)
    
    odswiezListeGui = wypelnijListe
end

local function startAutoRefresh()
    while true do
        task.wait(REFRESH_TIME)
        aktualizujListeKonfidentow()
        for _, gracz in ipairs(Players:GetPlayers()) do
            if gracz ~= LocalPlayer then
                if czyJestKonfidentem(gracz) and gracz.Character then
                    if not activeMarkers[gracz] then
                        dodajOznaczenia(gracz)
                    end
                elseif not czyJestKonfidentem(gracz) and activeMarkers[gracz] then
                    usunOznaczenia(gracz)
                end
            end
        end
    end
end

local function inicjuj()
    local rawConfig = pobierzKonfiguracje()
    currentConfig = rawConfig
    local slownik = {}
    for _, nazwa in ipairs(rawConfig.konfidenci or {}) do
        slownik[nazwa:lower()] = true
    end
    currentConfig.konfidenci = slownik
    
    print("[KonfidentHunter] Uruchomiono. Konfidenci w bazie: " .. #rawConfig.konfidenci)
    
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
    
    stworzGui()
    
    task.spawn(startAutoRefresh)
end

inicjuj()
