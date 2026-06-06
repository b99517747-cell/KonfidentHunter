--[[
    Konfident Hunter v2.0
    Główny skrypt - nie edytuj tego pliku!
    Aby zmienić konfigurację, edytuj plik config.lua
]]

-- Funkcja do pobierania konfiguracji
local function pobierzKonfiguracje()
    -- Próba pobrania config.lua z tego samego repo
    local url = "https://raw.githubusercontent.com/TWOJA_NAZWA_UZYTKOWNIKA/KonfidentHunter/main/config.lua"
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    
    if success and result then
        return result
    else
        -- DEFAULT CONFIG (gdyby nie dało się pobrać)
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

local config = pobierzKonfiguracje()
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Przygotowanie listy konfidentów
local czyKonfident = {}
for _, nazwa in ipairs(config.konfidenci) do
    czyKonfident[nazwa:lower()] = true
end

-- Funkcje pomocnicze
local function czyJestKonfidentem(gracz)
    return czyKonfident[gracz.Name:lower()]
end

local function czyGraczToJa(gracz)
    return gracz == LocalPlayer
end

-- Dodawanie oznaczeń
local function dodajOznaczenia(gracz)
    local postac = gracz.Character
    if not postac then return end
    
    local czescCiala = postac:FindFirstChild("HumanoidRootPart") or 
                       postac:FindFirstChild("Head") or
                       postac:FindFirstChild("UpperTorso")
    if not czescCiala then return end
    
    if czyJestKonfidentem(gracz) and not gracz:FindFirstChild("KonfidentMarkery") then
        local folder = Instance.new("Folder")
        folder.Name = "KonfidentMarkery"
        folder.Parent = gracz
        
        -- Podświetlenie
        local highlight = Instance.new("Highlight")
        highlight.Name = "Podswietlenie"
        highlight.FillColor = Color3.fromRGB(
            config.ustawienia.kolorPodswietlenia[1],
            config.ustawienia.kolorPodswietlenia[2],
            config.ustawienia.kolorPodswietlenia[3]
        )
        highlight.FillTransparency = config.ustawienia.przezroczystosc
        highlight.OutlineTransparency = 0.5
        highlight.Adornee = czescCiala
        highlight.Parent = folder
        
        -- Tekst nad głową
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "Tekst"
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.Adornee = czescCiala
        billboard.Parent = folder
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = config.ustawienia.tekstNadGlowa
        label.TextColor3 = Color3.fromRGB(
            config.ustawienia.kolorTekstu[1],
            config.ustawienia.kolorTekstu[2],
            config.ustawienia.kolorTekstu[3]
        )
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0.2
        label.Parent = billboard
    end
end

local function usunOznaczenia(gracz)
    local folder = gracz:FindFirstChild("KonfidentMarkery")
    if folder then folder:Destroy() end
end

local function monitorujGracza(gracz)
    if czyGraczToJa(gracz) then return end
    
    local function onCharacterAdded()
        usunOznaczenia(gracz)
        if czyJestKonfidentem(gracz) then
            dodajOznaczenia(gracz)
        end
    end
    
    if gracz.Character then
        onCharacterAdded()
    end
    
    gracz.CharacterAdded:Connect(onCharacterAdded)
    gracz.CharacterRemoving:Connect(function() usunOznaczenia(gracz) end)
end

-- Uruchomienie
for _, gracz in ipairs(Players:GetPlayers()) do
    monitorujGracza(gracz)
end

Players.PlayerAdded:Connect(monitorujGracza)

print("Konfident Hunter uruchomiony! Konfidenci w bazie: " .. #config.konfidenci)