local REFRESH_TIME = 30
local GUI_KEY = Enum.KeyCode.K

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local currentConfig = { konfidenci = {}, ustawienia = {} }
local activeMarkers = {}
local isGuiOpen = false
local mainGui = nil

local function pobierzKonfiguracje()
    local url = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url))()
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

local function aktualizujListeKonfidentow()
    local nowaKonfiguracja = pobierzKonfiguracje()
    local nowiKonfidenci = {}
    
    for _, nazwa in ipairs(nowaKonfiguracja.konfidenci) do
        nowiKonfidenci[nazwa:lower()] = true
    end
    
    local staraLista = currentConfig.konfidenci or {}
    local nowaLista = nowiKonfidenci
    
    for nazwa, _ in pairs(staraLista) do
        if not nowaLista[nazwa] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.Name:lower() == nazwa then
                    usunOznaczenia(gracz)
                end
            end
        end
    end
    
    for nazwa, _ in pairs(nowaLista) do
        if not staraLista[nazwa] then
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.Name:lower() == nazwa and gracz.Character then
                    dodajOznaczenia(gracz)
                end
            end
        end
    end
    
    currentConfig = nowaKonfiguracja
    currentConfig.konfidenci = nowiKonfidenci
    
    aktualizujKomunikat()
    
    if isGuiOpen then
        odswiezGui()
    end
    
    print("Konfiguracja odświeżona! Konfidenci w bazie: " .. #nowaKonfiguracja.konfidenci)
end

local function czyJestKonfidentem(gracz)
    return currentConfig.konfidenci and currentConfig.konfidenci[gracz.Name:lower()] == true
end

function dodajOznaczenia(gracz)
    local postac = gracz.Character
    if not postac then return false end
    
    local czescCiala = postac:FindFirstChild("HumanoidRootPart") or 
                       postac:FindFirstChild("Head") or
                       postac:FindFirstChild("UpperTorso")
    if not czescCiala then return false end
    
    if activeMarkers[gracz] then
        usunOznaczenia(gracz)
    end
    
    if czyJestKonfidentem(gracz) then
        local folder = Instance.new("Folder")
        folder.Name = "KonfidentMarkery"
        folder.Parent = gracz
        activeMarkers[gracz] = folder
        
        local highlight = Instance.new("Highlight")
        highlight.Name = "Podswietlenie"
        local kolor = currentConfig.ustawienia.kolorPodswietlenia or {255, 170, 0}
        highlight.FillColor = Color3.fromRGB(kolor[1], kolor[2], kolor[3])
        highlight.FillTransparency = currentConfig.ustawienia.przezroczystosc or 0.4
        highlight.OutlineTransparency = 0.5
        highlight.Adornee = czescCiala
        highlight.Parent = folder
        
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
        label.Text = currentConfig.ustawienia.tekstNadGlowa or "KONFIDENT"
        local kolorTekstu = currentConfig.ustawienia.kolorTekstu or {255, 255, 255}
        label.TextColor3 = Color3.fromRGB(kolorTekstu[1], kolorTekstu[2], kolorTekstu[3])
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0.2
        label.Parent = billboard
        
        return true
    end
    return false
end

function usunOznaczenia(gracz)
    local folder = activeMarkers[gracz]
    if folder then
        folder:Destroy()
        activeMarkers[gracz] = nil
    end
end

local dolnyKomunikat = nil
local function stworzKomunikat()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KonfidentHunterGUI"
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = false
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 30)
    frame.Position = UDim2.new(1, -210, 1, -40)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.7
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Text = "Ładowanie..."
    textLabel.Parent = frame
    
    dolnyKomunikat = {gui = screenGui, label = textLabel, frame = frame}
    
    frame.BackgroundTransparency = 1
    textLabel.TextTransparency = 1
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(frame, tweenInfo, {BackgroundTransparency = 0.7}):Play()
    TweenService:Create(textLabel, tweenInfo, {TextTransparency = 0}):Play()
end

local function aktualizujKomunikat()
    if not dolnyKomunikat then return end
    
    local licznik = 0
    for _, gracz in ipairs(Players:GetPlayers()) do
        if czyJestKonfidentem(gracz) and gracz ~= LocalPlayer then
            licznik = licznik + 1
        end
    end
    
    local calkowitaLiczba = 0
    for _, nazwa in pairs(currentConfig.konfidenci) do
        if nazwa then calkowitaLiczba = calkowitaLiczba + 1 end
    end
    
    dolnyKomunikat.label.Text = "🔍 Konfidenci na serwerze: " .. licznik .. " / " .. calkowitaLiczba
end

local function stworzGui()
    if mainGui then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KonfidentHunterListGUI"
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    screenGui.Enabled = false
    mainGui = screenGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 350, 0, 450)
    mainFrame.Position = UDim2.new(0.5, -175, 0.5, -225)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BackgroundTransparency = 0.15
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "📋 LISTA KONFIDENTÓW"
    title.TextColor3 = Color3.fromRGB(255, 170, 0)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeBtn.BackgroundTransparency = 0.3
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextScaled = true
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = mainFrame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        isGuiOpen = false
        screenGui.Enabled = false
    end)
    
    local listFrame = Instance.new("ScrollingFrame")
    listFrame.Size = UDim2.new(1, -20, 1, -50)
    listFrame.Position = UDim2.new(0, 10, 0, 45)
    listFrame.BackgroundTransparency = 1
    listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    listFrame.ScrollBarThickness = 6
    listFrame.Parent = mainFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = listFrame
    
    local function aktualizujListe()
        for _, child in pairs(listFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        local yOffset = 0
        for nazwa, _ in pairs(currentConfig.konfidenci) do
            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1, 0, 0, 35)
            item.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
            item.BackgroundTransparency = 0.3
            item.Text = "🔴 " .. nazwa
            item.TextColor3 = Color3.fromRGB(255, 255, 255)
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.Font = Enum.Font.Gotham
            item.TextSize = 14
            item.Parent = listFrame
            
            local itemCorner = Instance.new("UICorner")
            itemCorner.CornerRadius = UDim.new(0, 6)
            itemCorner.Parent = item
            
            for _, gracz in ipairs(Players:GetPlayers()) do
                if gracz.Name:lower() == nazwa then
                    item.Text = "🟢 " .. nazwa .. " (online)"
                    item.BackgroundColor3 = Color3.fromRGB(50, 205, 50)
                    item.BackgroundTransparency = 0.3
                    break
                end
            end
            
            yOffset = yOffset + 40
        end
        
        listFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset)
    end
    
    odswiezGui = aktualizujListe
    aktualizujListe()
end

function odswiezGui()
    if mainGui and mainGui.Enabled and odswiezGui then
        odswiezGui()
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == GUI_KEY then
        isGuiOpen = not isGuiOpen
        if isGuiOpen then
            if not mainGui then
                stworzGui()
            end
            mainGui.Enabled = true
            if odswiezGui then odswiezGui() end
        else
            if mainGui then
                mainGui.Enabled = false
            end
        end
    end
end)

local function monitorujGracza(gracz)
    if gracz == LocalPlayer then return end
    
    local function onCharacterAdded()
        wait(0.5)
        if czyJestKonfidentem(gracz) then
            dodajOznaczenia(gracz)
        end
        aktualizujKomunikat()
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

local function startOdswiezanie()
    while true do
        wait(REFRESH_TIME)
        aktualizujListeKonfidentow()
        
        for _, gracz in ipairs(Players:GetPlayers()) do
            if gracz ~= LocalPlayer then
                if czyJestKonfidentem(gracz) and gracz.Character then
                    dodajOznaczenia(gracz)
                elseif not czyJestKonfidentem(gracz) then
                    usunOznaczenia(gracz)
                end
            end
        end
    end
end

local function inicjuj()
    stworzKomunikat()
    
    currentConfig = pobierzKonfiguracje()
    currentConfig.konfidenci = currentConfig.konfidenci or {}
    
    local slownik = {}
    for _, nazwa in ipairs(currentConfig.konfidenci) do
        slownik[nazwa:lower()] = true
    end
    currentConfig.konfidenci = slownik
    
    print("Konfident Hunter uruchomiony! Konfidenci w bazie: " .. #currentConfig.konfidenci)
    
    for _, gracz in ipairs(Players:GetPlayers()) do
        monitorujGracza(gracz)
    end
    
    Players.PlayerAdded:Connect(monitorujGracza)
    Players.PlayerRemoving:Connect(function()
        aktualizujKomunikat()
        if isGuiOpen and odswiezGui then
            odswiezGui()
        end
    end)
    
    coroutine.wrap(startOdswiezanie)()
end

inicjuj()
