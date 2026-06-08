--[[
    Konfident Hunter v5.2 - WindUI Edition
    
    Zmiany:
    - Usunięto przycisk "Stop Spectate"
    - Teleport po kliknięciu w liście (jak spectate)
    - Billboard "Konfident" ukrywa się gdy blisko + pokazuje dystans
    - Nowy slider: Grubość obrysu Highlight
    - Alerty niżej na ekranie
    - Poprawiony przycisk Odśwież
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

-- ═══════════════════════════════════════════
-- SYSTEM ALERTÓW (niżej na ekranie)
-- ═══════════════════════════════════════════
local alertGui = nil
local ALERT_W = 320
local ALERT_H = 72
local ALERT_MARGIN = 32 -- zwiększone = niżej

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

local function pokazAlert(tytul, tresc, ikonaTekst, kolorAkcentu)
    kolorAkcentu = kolorAkcentu or Color3.fromRGB(255, 170, 0)
    ikonaTekst = ikonaTekst or "⚠"
    if not alertGui or not alertGui.Parent then stworzAlertGui() end

    local ramka = Instance.new("Frame")
    ramka.Size = UDim2.new(0, ALERT_W, 0, ALERT_H)
    ramka.Position = UDim2.new(1, ALERT_MARGIN, 1, -(ALERT_H + ALERT_MARGIN))
    ramka.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    ramka.BorderSizePixel = 0
    ramka.ClipsDescendants = true
    ramka.ZIndex = 10
    ramka.Parent = alertGui

    Instance.new("UICorner", ramka).CornerRadius = UDim.new(0, 10)

    local pasek = Instance.new("Frame")
    pasek.Size = UDim2.new(0, 4, 1, 0)
    pasek.BackgroundColor3 = kolorAkcentu
    pasek.Parent = ramka
    Instance.new("UICorner", pasek).CornerRadius = UDim.new(0, 4)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(50, 50, 58)
    stroke.Thickness = 1
    stroke.Parent = ramka

    local ikona = Instance.new("TextLabel")
    ikona.Size = UDim2.new(0, 36, 0, 36)
    ikona.Position = UDim2.new(0, 16, 0.5, -18)
    ikona.BackgroundTransparency = 1
    ikona.Text = ikonaTekst
    ikona.TextSize = 22
    ikona.Font = Enum.Font.GothamBold
    ikona.TextColor3 = kolorAkcentu
    ikona.Parent = ramka

    local tytulLabel = Instance.new("TextLabel")
    tytulLabel.Size = UDim2.new(1, -64, 0, 20)
    tytulLabel.Position = UDim2.new(0, 58, 0, 12)
    tytulLabel.BackgroundTransparency = 1
    tytulLabel.Text = tytul
    tytulLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    tytulLabel.Font = Enum.Font.GothamBold
    tytulLabel.TextSize = 13
    tytulLabel.TextXAlignment = Enum.TextXAlignment.Left
    tytulLabel.Parent = ramka

    local trescLabel = Instance.new("TextLabel")
    trescLabel.Size = UDim2.new(1, -64, 0, 30)
    trescLabel.Position = UDim2.new(0, 58, 0, 32)
    trescLabel.BackgroundTransparency = 1
    trescLabel.Text = tresc
    trescLabel.TextColor3 = Color3.fromRGB(175, 175, 190)
    trescLabel.Font = Enum.Font.Gotham
    trescLabel.TextSize = 11
    trescLabel.TextWrapped = true
    trescLabel.Parent = ramka

    local progress = Instance.new("Frame")
    progress.Size = UDim2.new(1, 0, 0, 3)
    progress.Position = UDim2.new(0, 0, 1, -3)
    progress.BackgroundColor3 = kolorAkcentu
    progress.Parent = ramka

    local wjazdPos = UDim2.new(1, -(ALERT_W + ALERT_MARGIN), 1, -(ALERT_H + ALERT_MARGIN))

    local tweenIn = TweenService:Create(ramka, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = wjazdPos})
    tweenIn:Play()

    local tweenProgress = TweenService:Create(progress, TweenInfo.new(4, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 3)})
    tweenIn.Completed:Connect(function() tweenProgress:Play() end)

    task.delay(4.3, function()
        local tweenOut = TweenService:Create(ramka, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(1, ALERT_MARGIN, 1, -(ALERT_H + ALERT_MARGIN))
        })
        tweenOut:Play()
        tweenOut.Completed:Connect(function() ramka:Destroy() end)
    end)
end

-- HELPERS
local function getUst()
    return currentConfig.ustawienia or {
        kolorPodswietlenia = {255, 170, 0},
        przezroczystosc = 0.4,
        outlineThickness = 0,
        tekstNadGlowa = "Konfident",
    }
end

local function czyKonfident(gracz)
    return currentConfig.konfidenci and currentConfig.konfidenci[gracz.UserId] == true
end

local function avatarUrl(userId)
    return ("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=150&height=150&format=png"):format(userId)
end

local function liczbaKonfidentow()
    local n = 0
    for _ in pairs(currentConfig.konfidenci or {}) do n += 1 end
    return n
end

local function konfidenciNaSerwerzeLista()
    local lista = {}
    for _, g in ipairs(Players:GetPlayers()) do
        if g ~= LocalPlayer and czyKonfident(g) then
            table.insert(lista, g)
        end
    end
    return lista
end

-- OZNACZENIA + DYSTANS
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
    local k = ust.kolorPodswietlenia or {255, 170, 0}

    -- Highlight
    local hl = Instance.new("Highlight")
    hl.Name = "Podswietlenie"
    hl.FillColor = Color3.fromRGB(k[1], k[2], k[3])
    hl.FillTransparency = ust.przezroczystosc or 0.4
    hl.OutlineColor = Color3.fromRGB(k[1], k[2], k[3])
    hl.OutlineTransparency = 0
    hl.OutlineThickness = ust.outlineThickness or 0
    hl.Adornee = char
    hl.Parent = folder

    -- Billboard z dystansem
    local headPart = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if headPart then
        local bb = Instance.new("BillboardGui")
        bb.Name = "TekstKonfidenta"
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0, 240, 0, 50)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.Adornee = headPart
        bb.Parent = headPart

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(k[1], k[2], k[3])
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBold
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.new(0,0,0)
        lbl.Parent = bb

        -- Aktualizacja tekstu + dystansu
        local conn
        conn = game:GetService("RunService").RenderStepped:Connect(function()
            if not char.Parent or not lbl.Parent then
                conn:Disconnect()
                return
            end
            local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local targetRoot = char:FindFirstChild("HumanoidRootPart")
            if myRoot and targetRoot then
                local dist = (myRoot.Position - targetRoot.Position).Magnitude
                if dist < 12 then
                    lbl.Text = ""  -- ukryj gdy blisko
                else
                    lbl.Text = (ust.tekstNadGlowa or "Konfident") .. string.format(" [%.0f studs]", dist)
                end
            else
                lbl.Text = ust.tekstNadGlowa or "Konfident"
            end
        end)
    end
end

local function odswiezWszystkieOznaczenia()
    for g in pairs(activeMarkers) do usunOznaczenia(g) end
    if pokazOznaczenia then
        for _, g in ipairs(Players:GetPlayers()) do
            if g ~= LocalPlayer and czyKonfident(g) and g.Character then
                dodajOznaczenia(g)
            end
        end
    end
end

-- SPECTATE + TELEPORT
local function spectateGracza(gracz)
    if not gracz or not gracz.Character then return end
    local h = gracz.Character:FindFirstChild("Humanoid")
    if h then
        spectateTarget = gracz
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = h
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

local function teleportDo(gracz)
    if not gracz or not gracz.Character then return end
    local root = gracz.Character:FindFirstChild("HumanoidRootPart")
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root and myRoot then
        myRoot.CFrame = root.CFrame * CFrame.new(3, 0, 3)
        WindUI:Notify({Title = "Teleport", Content = "Teleportowano do " .. gracz.Name, Icon = "map-pin", Duration = 2})
    end
end

-- CONFIG
local function pobierzKonfiguracje()
    local ok, res = pcall(game.HttpGet, game, CONFIG_URL)
    if not ok then return nil end
    local f = loadstring(res)
    if not f then return nil end
    local s, c = pcall(f)
    return s and c or nil
end

-- REBUILD
local function rebuildListaSekcje()
    if not ListaTab then return end
    if konfidenciSection then pcall(konfidenciSection.Destroy, konfidenciSection) end

    local obecni = konfidenciNaSerwerzeLista()
    konfidenciSection = ListaTab:Section({
        Title = ("Konfidenci na serwerze (%d)"):format(#obecni),
        Icon = "users",
        Opened = true,
    })

    if #obecni == 0 then
        konfidenciSection:Button({Title = "Brak konfidentów", Icon = "user-x", Locked = true})
        return
    end

    for _, gracz in ipairs(obecni) do
        local isSpect = spectateTarget == gracz
        konfidenciSection:Button({
            Title = gracz.Name,
            Desc = isSpect and "👁 Obserwujesz" or "Kliknij = Spectate + Teleport",
            Icon = avatarUrl(gracz.UserId),
            Color = isSpect and Color3.fromRGB(255,170,0) or nil,
            Callback = function()
                if spectateTarget == gracz then
                    stopSpectate()
                else
                    if spectateTarget then stopSpectate() end
                    spectateGracza(gracz)
                end
                teleportDo(gracz)  -- teleport przy kliknięciu
                task.wait(0.1)
                rebuildListaSekcje()
            end,
        })
    end
end

local function rebuildTeleportSekcje() end -- zostawiamy pusty, skoro teleport jest w liście

local function rebuildWszystko()
    rebuildListaSekcje()
end

local function aktualizujListe()
    local nowa = pobierzKonfiguracje()
    if not nowa then return end

    local nowi = {}
    for _, id in ipairs(nowa.konfidenci or {}) do nowi[id] = true end

    currentConfig = nowa
    currentConfig.konfidenci = nowi
    currentConfig.ustawienia = currentConfig.ustawienia or getUst()

    rebuildWszystko()
    odswiezWszystkieOznaczenia()
end

-- GUI
local Window = WindUI:CreateWindow({
    Title = "KonfidentHunter v5.2",
    Icon = "shield-alert",
    Author = "v5.2",
    Folder = "KonfidentHunter",
    ToggleKey = Enum.KeyCode[DOMYSLNY_KLUCZ],
    Topbar = {Height = 44, ButtonsType = "Mac"},
})

ListaTab = Window:Tab({Title = "Lista", Icon = "users"})

local Akcje = ListaTab:Section({Title = "Akcje", Icon = "zap", Opened = true})

Akcje:Toggle({
    Title = "Pokaż oznaczenia",
    Value = true,
    Callback = function(v)
        pokazOznaczenia = v
        odswiezWszystkieOznaczenia()
    end,
})

Akcje:Button({
    Title = "Odśwież listę",
    Icon = "refresh-cw",
    Callback = function() task.spawn(aktualizujListe) end,
})

TeleportTab = Window:Tab({Title = "Teleport", Icon = "map-pin"})
local Ustaw = Window:Tab({Title = "Ustawienia", Icon = "settings"})

-- Keybind
Ustaw:Section({Title = "Klawisz GUI", Icon = "keyboard", Opened = true}):Keybind({
    Title = "Otwórz / Zamknij GUI",
    Value = DOMYSLNY_KLUCZ,
    Callback = function(v)
        if v then
            currentKeybind = v
            pcall(function() Window:SetToggleKey(Enum.KeyCode[v]) end)
        end
    end,
})

-- Wizualne
local Wiz = Ustaw:Section({Title = "Wizualne", Icon = "palette", Opened = true})

Wiz:Slider({
    Title = "Przezroczystość wypełnienia",
    Value = {Min = 0, Max = 10, Default = 4},
    Callback = function(v)
        currentConfig.ustawienia.przezroczystosc = v/10
        odswiezWszystkieOznaczenia()
    end,
})

Wiz:Slider({
    Title = "Grubość obrysu (outline)",
    Value = {Min = 0, Max = 5, Default = 0},
    Callback = function(v)
        currentConfig.ustawienia.outlineThickness = v
        odswiezWszystkieOznaczenia()
    end,
})

Wiz:Input({
    Title = "Tekst nad głową",
    Placeholder = "Konfident",
    Callback = function(v)
        currentConfig.ustawienia.tekstNadGlowa = v ~= "" and v or "Konfident"
        odswiezWszystkieOznaczenia()
    end,
})

-- INIT
local function inicjuj()
    stworzAlertGui()

    local cfg = pobierzKonfiguracje()
    if cfg then
        local dict = {}
        for _, id in ipairs(cfg.konfidenci or {}) do dict[id] = true end
        currentConfig = cfg
        currentConfig.konfidenci = dict
    end

    rebuildWszystko()

    task.delay(1.5, function()
        local naSerw = #konfidenciNaSerwerzeLista()
        pokazAlert("KonfidentHunter", naSerw > 0 and ("⚠ " .. naSerw .. " konfidentów na serwerze!") or "Brak konfidentów na serwerze.", "🛡", naSerw > 0 and Color3.fromRGB(255,60,60) or Color3.fromRGB(255,170,0))
    end)

    task.spawn(function()
        while true do
            task.wait(REFRESH_TIME)
            aktualizujListe()
        end
    end)
end

inicjuj()
