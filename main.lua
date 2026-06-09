--[[
    Konfident Hunter v5 - WindUI Edition
]]

-- ===== KONFIGURACJA =====
local REFRESH_TIME   = 30
local CONFIG_URL     = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"
local DOMYSLNY_KLUCZ = "K"
local DISCORD_URL    = "https://discord.gg/YjTWGZYD"
-- ========================

local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer  = Players.LocalPlayer
local Camera       = workspace.CurrentCamera

-- ===== STAN GLOBALNY =====
local currentConfig   = { konfidenci = {}, ustawienia = {} }
local activeMarkers   = {}
local spectateTarget  = nil
local pokazOznaczenia = true
local currentKeybind  = DOMYSLNY_KLUCZ
local monitorowani    = {}
local rebuildPending  = false

local ListaTab            = nil
local TeleportTab         = nil
local konfidenciSection   = nil
local teleportListSection = nil
local teleportFilter      = ""

-- ===================================================
--  SYSTEM ALERTOW (prawy dolny rog)
-- ===================================================

local alertGui = nil

local function stworzAlertGui()
    if alertGui then pcall(function() alertGui:Destroy() end) end
    local gui = Instance.new("ScreenGui")
    gui.Name           = "KH_AlertGui"
    gui.ResetOnSpawn   = false
    gui.DisplayOrder   = 999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local ok = pcall(function() gui.Parent = gethui() end)
    if not ok then
        ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
        if not ok then gui.Parent = LocalPlayer.PlayerGui end
    end
    alertGui = gui
end

local ALERT_W      = 300
local ALERT_H      = 68
local ALERT_MARGIN = 20   -- margines od prawej/dolu
local ALERT_BOTTOM = 80   -- dodatkowy offset od dolu (zeby bylo nizej)

local function pokazAlert(tytul, tresc, ikonaTekst, kolorAkcentu)
    kolorAkcentu = kolorAkcentu or Color3.fromRGB(255, 170, 0)
    ikonaTekst   = ikonaTekst   or "!"
    if not alertGui or not alertGui.Parent then stworzAlertGui() end

    -- Pozycja startowa (poza ekranem z prawej) i docelowa
    local posOff    = -(ALERT_H + ALERT_MARGIN + ALERT_BOTTOM)
    local startPos  = UDim2.new(1, ALERT_MARGIN,           1, posOff)
    local targetPos = UDim2.new(1, -(ALERT_W + ALERT_MARGIN), 1, posOff)

    -- Glowna ramka
    local ramka = Instance.new("Frame")
    ramka.Size             = UDim2.new(0, ALERT_W, 0, ALERT_H)
    ramka.Position         = startPos
    ramka.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    ramka.BorderSizePixel  = 0
    ramka.ClipsDescendants = false
    ramka.ZIndex           = 10
    ramka.Parent           = alertGui
    Instance.new("UICorner", ramka).CornerRadius = UDim.new(0, 14)

    -- Subtelny border
    local stroke = Instance.new("UIStroke")
    stroke.Color             = Color3.fromRGB(55, 55, 65)
    stroke.Thickness         = 1
    stroke.ApplyStrokeMode   = Enum.ApplyStrokeMode.Border
    stroke.Parent            = ramka

    -- Kolorowe kolo z ikona (zamiast lewego paska)
    local ikonaBg = Instance.new("Frame")
    ikonaBg.Size             = UDim2.new(0, 36, 0, 36)
    ikonaBg.Position         = UDim2.new(0, 14, 0.5, -18)
    ikonaBg.BackgroundColor3 = Color3.fromRGB(
        math.clamp(kolorAkcentu.R * 255 * 0.18, 0, 255),
        math.clamp(kolorAkcentu.G * 255 * 0.18, 0, 255),
        math.clamp(kolorAkcentu.B * 255 * 0.18, 0, 255)
    )
    ikonaBg.BorderSizePixel  = 0
    ikonaBg.ZIndex           = 11
    ikonaBg.Parent           = ramka
    Instance.new("UICorner", ikonaBg).CornerRadius = UDim.new(1, 0)

    local ikona = Instance.new("TextLabel")
    ikona.Size                   = UDim2.new(1, 0, 1, 0)
    ikona.BackgroundTransparency = 1
    ikona.Text                   = ikonaTekst
    ikona.TextSize               = 16
    ikona.Font                   = Enum.Font.GothamBold
    ikona.TextColor3             = kolorAkcentu
    ikona.TextXAlignment         = Enum.TextXAlignment.Center
    ikona.TextYAlignment         = Enum.TextYAlignment.Center
    ikona.ZIndex                 = 12
    ikona.Parent                 = ikonaBg

    -- Tytul
    local tytulLabel = Instance.new("TextLabel")
    tytulLabel.Size                   = UDim2.new(1, -62, 0, 18)
    tytulLabel.Position               = UDim2.new(0, 58, 0, 13)
    tytulLabel.BackgroundTransparency = 1
    tytulLabel.Text                   = tytul
    tytulLabel.TextColor3             = Color3.fromRGB(235, 235, 235)
    tytulLabel.Font                   = Enum.Font.GothamBold
    tytulLabel.TextSize               = 12
    tytulLabel.TextXAlignment         = Enum.TextXAlignment.Left
    tytulLabel.TextTruncate           = Enum.TextTruncate.AtEnd
    tytulLabel.ZIndex                 = 11
    tytulLabel.Parent                 = ramka

    -- Tresc
    local trescLabel = Instance.new("TextLabel")
    trescLabel.Size                   = UDim2.new(1, -62, 0, 26)
    trescLabel.Position               = UDim2.new(0, 58, 0, 31)
    trescLabel.BackgroundTransparency = 1
    trescLabel.Text                   = tresc
    trescLabel.TextColor3             = Color3.fromRGB(155, 155, 170)
    trescLabel.Font                   = Enum.Font.Gotham
    trescLabel.TextSize               = 10
    trescLabel.TextXAlignment         = Enum.TextXAlignment.Left
    trescLabel.TextWrapped            = true
    trescLabel.ZIndex                 = 11
    trescLabel.Parent                 = ramka

    -- Pasek postepu (na dole, bez rogów)
    local progressBg = Instance.new("Frame")
    progressBg.Size             = UDim2.new(1, 0, 0, 2)
    progressBg.Position         = UDim2.new(0, 0, 1, -2)
    progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    progressBg.BorderSizePixel  = 0
    progressBg.ZIndex           = 11
    progressBg.Parent           = ramka

    local progress = Instance.new("Frame")
    progress.Size             = UDim2.new(1, 0, 1, 0)
    progress.BackgroundColor3 = kolorAkcentu
    progress.BorderSizePixel  = 0
    progress.ZIndex           = 12
    progress.Parent           = progressBg

    -- Animacja wjazdu
    local CZAS = 4
    local tweenIn = TweenService:Create(ramka,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = targetPos })
    tweenIn:Play()

    local tweenProg = TweenService:Create(progress,
        TweenInfo.new(CZAS, Enum.EasingStyle.Linear),
        { Size = UDim2.new(0, 0, 1, 0) })
    tweenIn.Completed:Connect(function() tweenProg:Play() end)

    task.delay(CZAS + 0.3, function()
        local tweenOut = TweenService:Create(ramka,
            TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            { Position = startPos })
        tweenOut:Play()
        tweenOut.Completed:Connect(function() pcall(function() ramka:Destroy() end) end)
    end)
end

-- ===================================================
--  HELPERS
-- ===================================================

local function getUst()
    return currentConfig.ustawienia or {
        kolorPodswietlenia = {255, 170, 0},
        przezroczystosc    = 0.4,
        tekstNadGlowa      = "Konfident",
    }
end

local function czyKonfident(gracz)
    return currentConfig.konfidenci and currentConfig.konfidenci[gracz.UserId] == true
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

-- ===================================================
--  OZNACZENIA
-- ===================================================

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
    local headPart = char:FindFirstChild("Head")
                  or char:FindFirstChild("HumanoidRootPart")
                  or char:FindFirstChild("UpperTorso")
    if not headPart then return end
    if activeMarkers[gracz] then usunOznaczenia(gracz) end

    local folder = Instance.new("Folder")
    folder.Name   = "KonfidentMarkery"
    folder.Parent = char
    activeMarkers[gracz] = folder

    local ust = getUst()
    local k   = ust.kolorPodswietlenia or {255, 170, 0}

    local hl = Instance.new("Highlight")
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
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
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
end

local function usunWszystkieOznaczenia()
    for g in pairs(activeMarkers) do usunOznaczenia(g) end
end

local function odswiezWszystkieOznaczenia()
    if pokazOznaczenia then
        for _, g in ipairs(Players:GetPlayers()) do
            if g ~= LocalPlayer and czyKonfident(g) and g.Character and not activeMarkers[g] then
                dodajOznaczenia(g)
            end
        end
    else
        usunWszystkieOznaczenia()
    end
end

-- ===================================================
--  SPECTATE
-- ===================================================

local function spectateGracza(gracz)
    if not gracz or not gracz.Character then return end
    local h = gracz.Character:FindFirstChild("Humanoid")
    if not h then return end
    spectateTarget       = gracz
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

-- ===================================================
--  TELEPORT
-- ===================================================

local function teleportDo(gracz)
    if not gracz or not gracz.Character then
        WindUI:Notify({ Title = "Teleport", Content = "Gracz nie ma postaci!", Icon = "alert-circle", Duration = 3 })
        return
    end
    local root = gracz.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    myRoot.CFrame = root.CFrame * CFrame.new(2, 0, 2)
    WindUI:Notify({ Title = "Teleport", Content = "Teleportowano do " .. gracz.Name, Icon = "map-pin", Duration = 3 })
end

-- ===================================================
--  POBIERANIE CONFIGU
-- ===================================================

local function pobierzKonfiguracje()
    local ok, result = pcall(function() return game:HttpGet(CONFIG_URL) end)
    if not ok then warn("[KH] HttpGet: " .. tostring(result)); return nil end
    local func, err = loadstring(result)
    if not func then warn("[KH] loadstring: " .. tostring(err)); return nil end
    local ok2, config = pcall(func)
    if not ok2 then warn("[KH] pcall: " .. tostring(config)); return nil end
    return config
end

-- ===================================================
--  THROTTLED REBUILD - max 1 rebuild na klatke
-- ===================================================

local function scheduleRebuild()
    if rebuildPending then return end
    rebuildPending = true
    task.defer(function()
        rebuildPending = false

        -- Rebuild: Lista
        if ListaTab then
            if konfidenciSection then
                pcall(function() konfidenciSection:Destroy() end)
                konfidenciSection = nil
            end
            local obecni = konfidenciNaSerwerzeLista()
            konfidenciSection = ListaTab:Section({
                Title  = ("Konfidenci na serwerze (%d)"):format(#obecni),
                Icon   = "users",
                Opened = true,
            })
            if #obecni == 0 then
                konfidenciSection:Button({ Title = "Brak konfidentow na serwerze", Icon = "user-x", Locked = true })
            else
                for _, gracz in ipairs(obecni) do
                    local g = gracz
                    local isSpect = (spectateTarget == g)
                    konfidenciSection:Button({
                        Title    = g.Name,
                        Desc     = isSpect and "Obserwujesz - kliknij aby stop" or "Kliknij aby spectate",
                        Icon     = "user",
                        Color    = isSpect and Color3.fromRGB(255, 170, 0) or nil,
                        Callback = function()
                            if spectateTarget == g then
                                stopSpectate()
                            else
                                if spectateTarget then stopSpectate() end
                                spectateGracza(g)
                            end
                            scheduleRebuild()
                        end,
                    })
                end
            end
        end

        -- Rebuild: Teleport (tylko lista, nie Input)
        if TeleportTab then
            if teleportListSection then
                pcall(function() teleportListSection:Destroy() end)
                teleportListSection = nil
            end
            local obecni = konfidenciNaSerwerzeLista()
            local filtered = {}
            if teleportFilter ~= "" then
                local szukaj = teleportFilter:lower()
                for _, g in ipairs(obecni) do
                    if g.Name:lower():find(szukaj, 1, true) then
                        table.insert(filtered, g)
                    end
                end
            else
                filtered = obecni
            end

            teleportListSection = TeleportTab:Section({
                Title  = ("Konfidenci na serwerze (%d)"):format(#filtered),
                Icon   = "map-pin",
                Opened = true,
            })

            if #obecni == 0 then
                teleportListSection:Button({ Title = "Brak konfidentow na serwerze", Icon = "user-x", Locked = true })
            elseif #filtered == 0 then
                teleportListSection:Button({ Title = "Nie znaleziono: " .. teleportFilter, Icon = "user-x", Locked = true })
            else
                for _, gracz in ipairs(filtered) do
                    local g = gracz
                    teleportListSection:Button({
                        Title    = g.Name,
                        Desc     = "Kliknij aby teleportowac",
                        Icon     = "map-pin",
                        Justify  = "Between",
                        Callback = function() teleportDo(g) end,
                    })
                end
            end
        end
    end)
end

-- ===================================================
--  AKTUALIZACJA KONFIG (zawsze w osobnym watku)
-- ===================================================

local function aktualizujListe()
    task.spawn(function()
        local nowaKonfig = pobierzKonfiguracje()
        if not nowaKonfig then return end

        local nowi  = {}
        for _, userId in ipairs(nowaKonfig.konfidenci or {}) do nowi[userId] = true end
        local starzy = currentConfig.konfidenci or {}

        for userId in pairs(starzy) do
            if not nowi[userId] then
                for _, g in ipairs(Players:GetPlayers()) do
                    if g.UserId == userId then usunOznaczenia(g) end
                end
            end
        end
        for userId in pairs(nowi) do
            if not starzy[userId] then
                for _, g in ipairs(Players:GetPlayers()) do
                    if g.UserId == userId and g.Character then dodajOznaczenia(g) end
                end
            end
        end

        currentConfig            = nowaKonfig
        currentConfig.konfidenci = nowi
        currentConfig.ustawienia = currentConfig.ustawienia or {
            kolorPodswietlenia = {255, 170, 0},
            przezroczystosc    = 0.4,
            tekstNadGlowa      = "Konfident",
        }

        print(("[KH] Odswiezono. Konfidenci w bazie: %d"):format(liczbaKonfidentow()))
        scheduleRebuild()
    end)
end

-- ===================================================
--  MONITOROWANIE GRACZY (bez duplikatow)
-- ===================================================

local function monitorujGracza(gracz)
    if gracz == LocalPlayer then return end
    if monitorowani[gracz] then return end
    monitorowani[gracz] = true

    gracz.CharacterAdded:Connect(function()
        task.wait(0.3)
        if czyKonfident(gracz) then dodajOznaczenia(gracz) end
        scheduleRebuild()
    end)

    gracz.CharacterRemoving:Connect(function()
        usunOznaczenia(gracz)
        if spectateTarget == gracz then stopSpectate() end
        scheduleRebuild()
    end)
end

-- ===================================================
--  AUTO-ODSWIEZ
-- ===================================================

local function startAutoRefresh()
    while true do
        task.wait(REFRESH_TIME)
        aktualizujListe()
    end
end

-- ===================================================
--  WIND UI - OKNO
-- ===================================================

local Window = WindUI:CreateWindow({
    Title         = "KonfidentHunter",
    Icon          = "shield-alert",
    Author        = "v5",
    Folder        = "KonfidentHunter",
    NewElements   = true,
    HideSearchBar = true,
    ToggleKey     = Enum.KeyCode[DOMYSLNY_KLUCZ],
    Topbar = {
        Height      = 44,
        ButtonsType = "Mac",
    },
})

-- ZAKLADKA: LISTA
ListaTab = Window:Tab({ Title = "Lista", Icon = "users" })

local AkcjeSekcja = ListaTab:Section({ Title = "Akcje", Icon = "zap", Opened = true })

AkcjeSekcja:Toggle({
    Title    = "Pokaz oznaczenia",
    Desc     = "Highlight i tekst nad glowa konfidentow",
    Icon     = "eye",
    Value    = true,
    Callback = function(v)
        pokazOznaczenia = v
        odswiezWszystkieOznaczenia()
    end,
})

AkcjeSekcja:Space()

AkcjeSekcja:Button({
    Title    = "Odswież liste",
    Desc     = "Pobiera aktualna liste konfidentow",
    Icon     = "refresh-cw",
    Justify  = "Between",
    Callback = function() aktualizujListe() end,
})

ListaTab:Space()

-- ZAKLADKA: TELEPORT
TeleportTab = Window:Tab({ Title = "Teleport", Icon = "map-pin" })

-- Sekcja filtrowania - tworzona raz, nigdy nie niszczona
local teleportInputSection = TeleportTab:Section({ Title = "Szukaj konfidenta", Icon = "search", Opened = true })
teleportInputSection:Input({
    Title       = "Wpisz nick",
    Placeholder = "np. bartos_GTKM",
    Callback    = function(v)
        teleportFilter = v or ""
        scheduleRebuild()
    end,
})

TeleportTab:Space()

-- ZAKLADKA: DISCORD
local DiscordTab    = Window:Tab({ Title = "Discord", Icon = "message-circle" })
local DiscordSekcja = DiscordTab:Section({ Title = "Dolacz do nas", Icon = "link", Opened = true })

DiscordSekcja:Button({
    Title    = "Skopiuj link do Discorda",
    Desc     = DISCORD_URL,
    Icon     = "copy",
    Justify  = "Between",
    Callback = function()
        local ok = pcall(function() setclipboard(DISCORD_URL) end)
        WindUI:Notify({
            Title    = "Discord",
            Content  = ok and "Link skopiowany do schowka!" or DISCORD_URL,
            Icon     = ok and "check-circle" or "message-circle",
            Duration = ok and 3 or 6,
        })
    end,
})

-- ZAKLADKA: USTAWIENIA
local UstawTab = Window:Tab({ Title = "Ustawienia", Icon = "settings" })

local KeybindSekcja = UstawTab:Section({ Title = "Klawisz GUI", Icon = "keyboard", Opened = true })
KeybindSekcja:Keybind({
    Title    = "Otworz / zamknij GUI",
    Desc     = "Nacisnij klawisz, ktory chcesz przypisac",
    Icon     = "command",
    Value    = DOMYSLNY_KLUCZ,
    Callback = function(v)
        if not v or v == "" then return end
        currentKeybind = v
        local ok = pcall(function() Window:SetToggleKey(Enum.KeyCode[v]) end)
        if ok then
            WindUI:Notify({ Title = "Keybind", Content = "Klawisz GUI: " .. v, Icon = "keyboard", Duration = 3 })
        end
    end,
})

UstawTab:Space()

local WizualneSekcja = UstawTab:Section({ Title = "Wizualne", Icon = "palette", Opened = true })

WizualneSekcja:Slider({
    Title    = "Przezroczystosc podswietlenia",
    Desc     = "0 = pelny kolor, 10 = niewidoczny",
    Step     = 1,
    Value    = { Min = 0, Max = 10, Default = 4 },
    Callback = function(v)
        if not currentConfig.ustawienia then currentConfig.ustawienia = {} end
        currentConfig.ustawienia.przezroczystosc = v / 10
        for _, folder in pairs(activeMarkers) do
            local hl = folder:FindFirstChild("Podswietlenie")
            if hl then hl.FillTransparency = v / 10 end
        end
    end,
})

WizualneSekcja:Space()

WizualneSekcja:Input({
    Title       = "Tekst nad glowa",
    Placeholder = "Konfident",
    Callback    = function(v)
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

-- ===================================================
--  INICJALIZACJA
-- ===================================================

local function inicjuj()
    stworzAlertGui()

    -- Wszystko w osobnym watku - nie blokuje glownego
    task.spawn(function()
        local config = pobierzKonfiguracje()
        if config then
            local slownik = {}
            for _, userId in ipairs(config.konfidenci or {}) do slownik[userId] = true end
            currentConfig            = config
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
            warn("[KH] Pusta konfiguracja!")
        end

        local bazaLiczba = liczbaKonfidentow()
        print(("[KH] Start. Konfidenci w bazie: %d"):format(bazaLiczba))

        for _, g in ipairs(Players:GetPlayers()) do
            if g ~= LocalPlayer and czyKonfident(g) and g.Character then
                dodajOznaczenia(g)
            end
        end

        scheduleRebuild()

        task.delay(1.5, function()
            local naSerwerze = #konfidenciNaSerwerzeLista()
            if bazaLiczba == 0 then
                pokazAlert("KonfidentHunter", "Baza jest pusta. Brak konfidentow.", "!", Color3.fromRGB(100, 100, 120))
            elseif naSerwerze == 0 then
                pokazAlert("KonfidentHunter", ("Zaladowano %d konfidentow. Brak na serwerze."):format(bazaLiczba), "!", Color3.fromRGB(255, 170, 0))
            else
                pokazAlert("KonfidentHunter", ("! %d konfident(ow) NA SERWERZE!"):format(naSerwerze), "!", Color3.fromRGB(255, 60, 60))
            end
        end)

        WindUI:Notify({
            Title    = "KonfidentHunter",
            Content  = ("Baza: %d ID | Nacisnij %s"):format(bazaLiczba, currentKeybind),
            Icon     = "shield-alert",
            Duration = 5,
        })

        for _, g in ipairs(Players:GetPlayers()) do
            monitorujGracza(g)
        end

        Players.PlayerAdded:Connect(function(gracz)
            if gracz == LocalPlayer then return end
            monitorujGracza(gracz)
            task.wait(0.5)
            if czyKonfident(gracz) then
                pokazAlert("Konfident na serwerze!", gracz.Name .. " wbil na serwer!", "!", Color3.fromRGB(255, 60, 60))
                WindUI:Notify({ Title = "Konfident wbil!", Content = gracz.Name .. " jest na serwerze!", Icon = "alert-triangle", Duration = 6 })
                if gracz.Character then dodajOznaczenia(gracz) end
            end
            scheduleRebuild()
        end)

        Players.PlayerRemoving:Connect(function(gracz)
            task.wait(0.15)
            monitorowani[gracz] = nil
            if spectateTarget == gracz then stopSpectate() end
            if czyKonfident(gracz) then
                pokazAlert("Konfident opuscil serwer", gracz.Name .. " wyszedl.", "!", Color3.fromRGB(100, 180, 100))
            end
            scheduleRebuild()
        end)

        task.spawn(startAutoRefresh)
    end)
end

inicjuj()
