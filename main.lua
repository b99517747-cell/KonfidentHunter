--[[
    Konfident Hunter v5.3
    - Lista = tylko Spectate
    - Teleport = osobna zakładka
    - Naprawione highlight + tagi
    - Alerty niżej
]]

-- ===== KONFIGURACJA =====
local REFRESH_TIME = 5
local CONFIG_URL = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"
local DOMYSLNY_KLUCZ = "K"
-- ========================

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ===== STAN GLOBALNY =====
local currentConfig = { konfidenci = {}, ustawienia = {} }
local activeMarkers = {}
local spectateTarget = nil
local pokazOznaczenia = true
local currentKeybind = DOMYSLNY_KLUCZ

local ListaTab = nil
local TeleportTab = nil
local konfidenciSection = nil
local teleportDropSection = nil
local teleportInputSection = nil

-- ALERTY (niżej)
local alertGui = nil
local ALERT_MARGIN = 32

local function stworzAlertGui()
    if alertGui then pcall(function() alertGui:Destroy() end) end
    local gui = Instance.new("ScreenGui")
    gui.Name = "KH_AlertGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local ok = pcall(function() gui.Parent = gethui() end)
    if not ok then
        ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
        if not ok then gui.Parent = LocalPlayer.PlayerGui end
    end
    alertGui = gui
end

local function pokazAlert(tytul, tresc, ikona, kolor)
    kolor = kolor or Color3.fromRGB(255,170,0)
    ikona = ikona or "⚠"
    if not alertGui then stworzAlertGui() end

    local ramka = Instance.new("Frame")
    ramka.Size = UDim2.new(0, 320, 0, 72)
    ramka.Position = UDim2.new(1, ALERT_MARGIN, 1, -(72 + ALERT_MARGIN))
    ramka.BackgroundColor3 = Color3.fromRGB(20,20,24)
    ramka.Parent = alertGui
    Instance.new("UICorner", ramka).CornerRadius = UDim.new(0,10)

    local pasek = Instance.new("Frame", ramka)
    pasek.Size = UDim2.new(0,4,1,0)
    pasek.BackgroundColor3 = kolor
    Instance.new("UICorner", pasek)

    -- ikona, teksty, progress... (skrócone dla czytelności)
    local ik = Instance.new("TextLabel", ramka)
    ik.Size = UDim2.new(0,36,0,36)
    ik.Position = UDim2.new(0,16,0.5,-18)
    ik.Text = ikona
    ik.TextSize = 24
    ik.BackgroundTransparency = 1
    ik.TextColor3 = kolor

    local title = Instance.new("TextLabel", ramka)
    title.Position = UDim2.new(0,60,0,12)
    title.Size = UDim2.new(1,-80,0,20)
    title.Text = tytul
    title.TextColor3 = Color3.fromRGB(240,240,240)
    title.Font = Enum.Font.GothamBold
    title.BackgroundTransparency = 1

    local desc = Instance.new("TextLabel", ramka)
    desc.Position = UDim2.new(0,60,0,34)
    desc.Size = UDim2.new(1,-80,0,28)
    desc.Text = tresc
    desc.TextColor3 = Color3.fromRGB(180,180,190)
    desc.Font = Enum.Font.Gotham
    desc.TextWrapped = true
    desc.BackgroundTransparency = 1

    local progress = Instance.new("Frame", ramka)
    progress.Size = UDim2.new(1,0,0,3)
    progress.Position = UDim2.new(0,0,1,-3)
    progress.BackgroundColor3 = kolor

    local tweenIn = TweenService:Create(ramka, TweenInfo.new(0.35), {Position = UDim2.new(1, -320-ALERT_MARGIN, 1, -(72+ALERT_MARGIN))})
    tweenIn:Play()

    TweenService:Create(progress, TweenInfo.new(4), {Size = UDim2.new(0,0,0,3)}):Play()

    task.delay(4.3, function()
        TweenService:Create(ramka, TweenInfo.new(0.3), {Position = UDim2.new(1, ALERT_MARGIN, 1, -(72+ALERT_MARGIN))}):Play()
        task.wait(0.3)
        ramka:Destroy()
    end)
end

-- HELPERS
local function getUst()
    return currentConfig.ustawienia or {kolorPodswietlenia = {255,170,0}, przezroczystosc = 0.4, tekstNadGlowa = "Konfident"}
end

local function czyKonfident(gracz)
    return currentConfig.konfidenci and currentConfig.konfidenci[gracz.UserId] == true
end

local function avatarUrl(id)
    return "https://www.roblox.com/headshot-thumbnail/image?userId="..id.."&width=150&height=150&format=png"
end

local function konfidenciNaSerwerzeLista()
    local t = {}
    for _, p in Players:GetPlayers() do
        if p ~= LocalPlayer and czyKonfident(p) then table.insert(t, p) end
    end
    return t
end

-- OZNACZENIA
local function usunOznaczenia(gracz)
    if activeMarkers[gracz] then
        pcall(function() activeMarkers[gracz]:Destroy() end)
        activeMarkers[gracz] = nil
    end
end

local function dodajOznaczenia(gracz)
    if not czyKonfident(gracz) or not pokazOznaczenia then return end
    local char = gracz.Character
    if not char then return end

    usunOznaczenia(gracz)

    local folder = Instance.new("Folder")
    folder.Name = "KonfidentMarkery"
    folder.Parent = char
    activeMarkers[gracz] = folder

    local ust = getUst()
    local col = Color3.fromRGB(unpack(ust.kolorPodswietlenia or {255,170,0}))

    local hl = Instance.new("Highlight")
    hl.FillColor = col
    hl.FillTransparency = ust.przezroczystosc or 0.4
    hl.OutlineColor = col
    hl.Adornee = char
    hl.Parent = folder

    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if head then
        local bb = Instance.new("BillboardGui")
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0,220,0,40)
        bb.StudsOffset = Vector3.new(0,3,0)
        bb.Adornee = head
        bb.Parent = head

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1,0,1,0)
        label.BackgroundTransparency = 1
        label.Text = ust.tekstNadGlowa or "Konfident"
        label.TextColor3 = col
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.new(0,0,0)
        label.Parent = bb
    end
end

local function odswiezWszystkieOznaczenia()
    for g in pairs(activeMarkers) do usunOznaczenia(g) end
    if pokazOznaczenia then
        for _, g in Players:GetPlayers() do
            if g ~= LocalPlayer and czyKonfident(g) and g.Character then
                dodajOznaczenia(g)
            end
        end
    end
end

-- SPECTATE
local function spectateGracza(gracz)
    if not gracz or not gracz.Character then return end
    local hum = gracz.Character:FindFirstChild("Humanoid")
    if hum then
        spectateTarget = gracz
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = hum
    end
end

local function stopSpectate()
    spectateTarget = nil
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = char.Humanoid
    end
end

-- TELEPORT
local function teleportDo(gracz)
    if not gracz or not gracz.Character then return end
    local root = gracz.Character:FindFirstChild("HumanoidRootPart")
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root and myRoot then
        myRoot.CFrame = root.CFrame * CFrame.new(3, 0, 3)
        WindUI:Notify({Title="Teleport", Content="Teleportowano do "..gracz.Name, Duration=2})
    end
end

-- CONFIG + REBUILD
local function pobierzKonfiguracje()
    local ok, res = pcall(game.HttpGet, game, CONFIG_URL)
    if not ok then return nil end
    return loadstring(res)()
end

local function rebuildListaSekcje()
    if not ListaTab then return end
    if konfidenciSection then konfidenciSection:Destroy() end

    local obecni = konfidenciNaSerwerzeLista()
    konfidenciSection = ListaTab:Section({
        Title = "Konfidenci na serwerze ("..#obecni..")",
        Icon = "users",
        Opened = true
    })

    if #obecni == 0 then
        konfidenciSection:Button({Title = "Brak konfidentów", Locked = true})
        return
    end

    for _, gracz in ipairs(obecni) do
        local isSpect = spectateTarget == gracz
        konfidenciSection:Button({
            Title = gracz.Name,
            Desc = isSpect and "👁 Obserwujesz — kliknij aby stop" or "Kliknij aby spectate",
            Icon = avatarUrl(gracz.UserId),
            Color = isSpect and Color3.fromRGB(255,170,0),
            Callback = function()
                if spectateTarget == gracz then
                    stopSpectate()
                else
                    if spectateTarget then stopSpectate() end
                    spectateGracza(gracz)
                end
                task.wait(0.1)
                rebuildListaSekcje()
            end
        })
    end
end

local function rebuildTeleportSekcje()
    if not TeleportTab then return end
    if teleportDropSection then teleportDropSection:Destroy() end
    if teleportInputSection then teleportInputSection:Destroy() end

    local obecni = konfidenciNaSerwerzeLista()
    local opcje = {}
    for _, g in ipairs(obecni) do table.insert(opcje, g.Name) end

    -- Dropdown
    teleportDropSection = TeleportTab:Section({Title = "Teleport z listy", Icon = "list", Opened = true})
    if #opcje == 0 then
        teleportDropSection:Button({Title = "Brak konfidentów", Locked = true})
    else
        local wybrany = opcje[1]
        teleportDropSection:Dropdown({Title = "Wybierz gracza", Values = opcje, Callback = function(v) wybrany = v end})
        teleportDropSection:Button({Title = "Teleportuj →", Color = Color3.fromRGB(255,170,0), Callback = function()
            for _, g in Players:GetPlayers() do
                if g.Name == wybrany then teleportDo(g) return end
            end
        end})
    end

    -- Input
    teleportInputSection = TeleportTab:Section({Title = "Wpisz nazwę", Icon = "keyboard", Opened = true})
    local wpis = ""
    teleportInputSection:Input({Title = "Nazwa gracza", Placeholder = "nick", Callback = function(v) wpis = v end})
    teleportInputSection:Button({Title = "Teleportuj →", Color = Color3.fromRGB(255,170,0), Callback = function()
        if wpis == "" then return end
        for _, g in Players:GetPlayers() do
            if g.Name:lower() == wpis:lower() then teleportDo(g) return end
        end
        WindUI:Notify({Title = "Teleport", Content = "Nie znaleziono: "..wpis})
    end})
end

local function rebuildWszystko()
    rebuildListaSekcje()
    rebuildTeleportSekcje()
end

local function aktualizujListe()
    local cfg = pobierzKonfiguracje()
    if not cfg then return end
    local dict = {}
    for _, id in ipairs(cfg.konfidenci or {}) do dict[id] = true end
    currentConfig.konfidenci = dict
    rebuildWszystko()
    odswiezWszystkieOznaczenia()
end

-- GUI
local Window = WindUI:CreateWindow({
    Title = "KonfidentHunter v5.3",
    Icon = "shield-alert",
    ToggleKey = Enum.KeyCode[DOMYSLNY_KLUCZ],
    Topbar = {Height = 44, ButtonsType = "Mac"}
})

ListaTab = Window:Tab({Title = "Lista", Icon = "users"})
local Akcje = ListaTab:Section({Title = "Akcje", Opened = true})

Akcje:Toggle({Title = "Pokaż oznaczenia", Value = true, Callback = function(v)
    pokazOznaczenia = v
    odswiezWszystkieOznaczenia()
end})

Akcje:Button({Title = "Odśwież listę", Callback = aktualizujListe})

TeleportTab = Window:Tab({Title = "Teleport", Icon = "map-pin"})

local Ustaw = Window:Tab({Title = "Ustawienia", Icon = "settings"})
Ustaw:Section({Title = "Klawisz GUI"}):Keybind({Title = "Otwórz/Zamknij", Value = "K", Callback = function(v)
    pcall(function() Window:SetToggleKey(Enum.KeyCode[v]) end)
end})

-- INIT
local function inicjuj()
    stworzAlertGui()
    local cfg = pobierzKonfiguracje()
    if cfg then
        local d = {}
        for _,id in ipairs(cfg.konfidenci or {}) do d[id]=true end
        currentConfig.konfidenci = d
    end
    rebuildWszystko()
    task.spawn(function()
        while true do task.wait(REFRESH_TIME) aktualizujListe() end
    end)
end

inicjuj()
