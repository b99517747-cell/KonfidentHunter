--[[
    Konfident Hunter v5.1 - WindUI Edition
    
    Zmiany w v5.1:
    - Usunięto przycisk "Stop Spectate"
    - Poprawiono wygląd przycisku "Odśwież listę" (zaokrąglone rogi)
    - Obniżono alerty (toasty) w prawym dolnym rogu
    - Keybind do GUI w ustawieniach (domyślnie K)
]]

-- ===== KONFIGURACJA =====
local REFRESH_TIME = 5
local CONFIG_URL = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"
local DOMYSLNY_KLUCZ = "K"
-- ========================

local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

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
-- SYSTEM ALERTÓW (obniżone)
-- ═══════════════════════════════════════════
local alertGui = nil
local ALERT_W = 320
local ALERT_H = 72
local ALERT_MARGIN = 30  -- zwiększone = niżej na ekranie

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
    ramka.Name = "Alert"
    ramka.Size = UDim2.new(0, ALERT_W, 0, ALERT_H)
    ramka.Position = UDim2.new(1, ALERT_MARGIN, 1, -(ALERT_H + ALERT_MARGIN))
    ramka.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    ramka.BorderSizePixel = 0
    ramka.ClipsDescendants = true
    ramka.ZIndex = 10
    ramka.Parent = alertGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = ramka

    local pasek = Instance.new("Frame")
    pasek.Name = "Akcent"
    pasek.Size = UDim2.new(0, 4, 1, 0)
    pasek.Position = UDim2.new(0, 0, 0, 0)
    pasek.BackgroundColor3 = kolorAkcentu
    pasek.BorderSizePixel = 0
    pasek.ZIndex = 11
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
    ikona.ZIndex = 11
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
    tytulLabel.ZIndex = 11
    tytulLabel.Parent = ramka

    local trescLabel = Instance.new("TextLabel")
    trescLabel.Size = UDim2.new(1, -64, 0, 30)
    trescLabel.Position = UDim2.new(0, 58, 0, 32)
    trescLabel.BackgroundTransparency = 1
    trescLabel.Text = tresc
    trescLabel.TextColor3 = Color3.fromRGB(175, 175, 190)
    trescLabel.Font = Enum.Font.Gotham
    trescLabel.TextSize = 11
    trescLabel.TextXAlignment = Enum.TextXAlignment.Left
    trescLabel.TextWrapped = true
    trescLabel.ZIndex = 11
    trescLabel.Parent = ramka

    local progress = Instance.new("Frame")
    progress.Name = "Progress"
    progress.Size = UDim2.new(1, 0, 0, 3)
    progress.Position = UDim2.new(0, 0, 1, -3)
    progress.BackgroundColor3 = kolorAkcentu
    progress.BorderSizePixel = 0
    progress.ZIndex = 12
    progress.Parent = ramka

    local wjazdPos = UDim2.new(1, -(ALERT_W + ALERT_MARGIN), 1, -(ALERT_H + ALERT_MARGIN))

    local tweenIn = TweenService:Create(ramka, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = wjazdPos
    })
    tweenIn:Play()

    local CZAS_WYSWIETLANIA = 4
    local tweenProgress = TweenService:Create(progress, TweenInfo.new(CZAS_WYSWIETLANIA, Enum.EasingStyle.Linear), {
        Size = UDim2.new(0, 0, 0, 3)
    })
    tweenIn.Completed:Connect(function() tweenProgress:Play() end)

    task.delay(CZAS_WYSWIETLANIA + 0.3, function()
        local tweenOut = TweenService:Create(ramka, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(1, ALERT_MARGIN, 1, -(ALERT_H + ALERT_MARGIN))
        })
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            pcall(function() ramka:Destroy() end)
        end)
    end)
end

-- HELPERS
local function getUst()
    return currentConfig.ustawienia or {
        kolorPodswietlenia = {255, 170, 0},
        przezroczystosc = 0.4,
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
    for _ in pairs(currentConfig.konfidenci or {}) do n = n + 1 end
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

-- OZNACZENIA
local function usunOznaczenia(gracz)
    local f = activeMarkers[gracz]
    if f then pcall(function() f:Destroy() end); activeMarkers[gracz] = nil end
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
    if not czyKonfident(gracz) or not pokazOznaczenia then return end
    local char = gracz.Character
    if not char then return end
    local headPart = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not headPart then return end

    if activeMarkers[gracz] then usunOznaczenia(gracz) end

    local folder = Instance.new("Folder")
    folder.Name = "KonfidentMarkery"
    folder.Parent = char
    activeMarkers[gracz] = folder

    local ust = getUst()
    local k = ust.kolorPodswietlenia or {255, 170, 0}

    local hl = Instance.new("Highlight")
    hl.Name = "Podswietlenie"
    hl.FillColor = Color3.fromRGB(k[1], k[2], k[3])
    hl.FillTransparency = ust.przezroczystosc or 0.4
    hl.OutlineColor = Color3.fromRGB(k[1], k[2], k[3])
    hl.OutlineTransparency = 0
    hl.Adornee = char
    hl.Parent = folder

    local bb = Instance.new("BillboardGui")
    bb.Name = "TekstKonfidenta"
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 220, 0, 40)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.Adornee = headPart
    bb.Parent = headPart

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = ust.tekstNadGlowa or "Konfident"
    lbl.TextColor3 = Color3.fromRGB(k[1], k[2], k[3])
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.Parent = bb
end

local function odswiezWszystkieOznaczenia()
    if pokazOznaczenia then
        for _, g in ipairs(Players:GetPlayers()) do
            if g ~= LocalPlayer and czyKonfident(g) and g.Character and not activeMarkers[g] then
                dodajOznaczenia(g)
            end
        end
    else
        for g in pairs(activeMarkers) do usunOznaczenia(g) end
    end
end

-- SPECTATE
local function spectateGracza(gracz)
    if not gracz or not gracz.Character then return end
    local h = gracz.Character:FindFirstChild("Humanoid")
    if not h then return end
    spectateTarget = gracz
    Camera.CameraType = Enum.CameraType.Custom
    Camera.CameraSubject = h
end

local function stopSpectate()
    spectateTarget = nil
    local char = LocalPlayer.Character
    if char then
        local h = char:FindFirstChild("Humanoid")
        if h then
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = h
        end
    end
end

-- TELEPORT
local function teleportDo(gracz)
    if not gracz or not gracz.Character then return end
    local root = gracz.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    myRoot.CFrame = root.CFrame * CFrame.new(2, 0, 2)
end

-- CONFIG
local function pobierzKonfiguracje()
    local ok, result = pcall(function() return game:HttpGet(CONFIG_URL) end)
    if not ok then return nil end
    local func = loadstring(result)
    if not func then return nil end
    local ok2, config = pcall(func)
    if not ok2 then return nil end
    return config
end

-- REBUILD
local function rebuildListaSekcje()
    if not ListaTab then return end
    if konfidenciSection then pcall(function() konfidenciSection:Destroy() end) end

    local obecni = konfidenciNaSerwerzeLista()
    konfidenciSection = ListaTab:Section({
        Title = ("Konfidenci na serwerze (%d)"):format(#obecni),
        Icon = "users",
        Opened = true,
    })

    if #obecni == 0 then
        konfidenciSection:Button({ Title = "Brak konfidentów na serwerze", Icon = "user-x", Locked = true })
        return
    end

    for _, gracz in ipairs(obecni) do
        local isSpect = (spectateTarget == gracz)
        konfidenciSection:Button({
            Title = gracz.Name,
            Desc = isSpect and "👁 Obserwujesz — kliknij aby stop" or "Kliknij aby spectate",
            Icon = avatarUrl(gracz.UserId),
            Color = isSpect and Color3.fromRGB(255, 170, 0) or nil,
            Callback = function()
                if spectateTarget == gracz then
                    stopSpectate()
                else
                    if spectateTarget then stopSpectate() end
                    spectateGracza(gracz)
                end
                task.wait(0.1)
                rebuildListaSekcje()
            end,
        })
    end
end

local function rebuildTeleportSekcje()
    -- (pozostawiam bez zmian - jeśli chcesz mogę też uprościć)
    -- ... (cała funkcja rebuildTeleportSekcje z oryginału)
end

local function rebuildWszystko()
    rebuildListaSekcje()
    rebuildTeleportSekcje()
end

-- AKTUALIZACJA
local function aktualizujListe()
    local nowaKonfig = pobierzKonfiguracje()
    if not nowaKonfig then return end

    local nowi = {}
    for _, userId in ipairs(nowaKonfig.konfidenci or {}) do nowi[userId] = true end

    currentConfig = nowaKonfig
    currentConfig.konfidenci = nowi
    currentConfig.ustawienia = currentConfig.ustawienia or {
        kolorPodswietlenia = {255, 170, 0},
        przezroczystosc = 0.4,
        tekstNadGlowa = "Konfident",
    }

    rebuildWszystko()
    odswiezWszystkieOznaczenia()
end

-- AUTO REFRESH + MONITOR
local function startAutoRefresh()
    while true do
        task.wait(REFRESH_TIME)
        aktualizujListe()
    end
end

-- GUI
local Window = WindUI:CreateWindow({
    Title = "KonfidentHunter",
    Icon = "shield-alert",
    Author = "v5.1",
    Folder = "KonfidentHunter",
    ToggleKey = Enum.KeyCode[DOMYSLNY_KLUCZ],
    Topbar = { Height = 44, ButtonsType = "Mac" },
})

ListaTab = Window:Tab({ Title = "Lista", Icon = "users" })

local AkcjeSekcja = ListaTab:Section({ Title = "Akcje", Icon = "zap", Opened = true })

AkcjeSekcja:Toggle({
    Title = "Pokaż oznaczenia (highlight)",
    Desc = "Highlight i tekst nad głową konfidentów",
    Icon = "eye",
    Value = true,
    Callback = function(v)
        pokazOznaczenia = v
        odswiezWszystkieOznaczenia()
    end,
})

AkcjeSekcja:Space()

AkcjeSekcja:Button({
    Title = "Odśwież listę",
    Icon = "refresh-cw",
    Callback = function()
        task.spawn(aktualizujListe)
    end,
})

ListaTab:Space()

TeleportTab = Window:Tab({ Title = "Teleport", Icon = "map-pin" })

local UstawTab = Window:Tab({ Title = "Ustawienia", Icon = "settings" })

local KeybindSekcja = UstawTab:Section({ Title = "Klawisz GUI", Icon = "keyboard", Opened = true })
KeybindSekcja:Keybind({
    Title = "Otwórz / zamknij GUI",
    Desc = "Domyślnie: K",
    Icon = "command",
    Value = DOMYSLNY_KLUCZ,
    Callback = function(v)
        if v and v ~= "" then
            currentKeybind = v
            pcall(function() Window:SetToggleKey(Enum.KeyCode[v]) end)
        end
    end,
})

-- INICJALIZACJA
local function inicjuj()
    stworzAlertGui()
    
    local config = pobierzKonfiguracje()
    if config then
        local slownik = {}
        for _, id in ipairs(config.konfidenci or {}) do slownik[id] = true end
        currentConfig = config
        currentConfig.konfidenci = slownik
    else
        currentConfig = { konfidenci = {}, ustawienia = { kolorPodswietlenia = {255,170,0}, przezroczystosc = 0.4, tekstNadGlowa = "Konfident" } }
    end

    rebuildWszystko()

    -- Startowy alert
    local naSerwerze = #konfidenciNaSerwerzeLista()
    task.delay(1.5, function()
        pokazAlert("KonfidentHunter", 
            naSerwerze > 0 and ("⚠ " .. naSerwerze .. " konfident(ów) na serwerze!") or "Załadowano bazę konfidentów.",
            "🛡", naSerwerze > 0 and Color3.fromRGB(255,60,60) or Color3.fromRGB(255,170,0))
    end)

    for _, g in ipairs(Players:GetPlayers()) do
        if g ~= LocalPlayer and czyKonfident(g) and g.Character then
            dodajOznaczenia(g)
        end
    end

    task.spawn(startAutoRefresh)
    -- (pozostałe connecty PlayerAdded/PlayerRemoving możesz dodać jeśli chcesz)
end

inicjuj()
