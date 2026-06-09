--[[
    Konfident Hunter v5.2 - WindUI Edition
    Zmiany:
      - Statystyki nie powielają sie (flaga + jeden rebuild)
      - Brak "Locked" - zastąpiono Paragraph
      - Profil i serwer uproszczone
      - Powiadomienia nie nakladaja sie na siebie
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

-- Flagi rebuild - zapobiega powielaniu
local rebuildPending      = false
local mainStatBuilding    = false  -- zabezpieczenie przed rownoleglym rebuild

local MainTab             = nil
local ListaTab            = nil
local TeleportTab         = nil
local konfidenciSection   = nil
local teleportListSection = nil
local mainStatSection     = nil
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
local ALERT_MARGIN = 20
local ALERT_BOTTOM = 80

local function pokazAlert(tytul, tresc, kolorAkcentu)
    kolorAkcentu = kolorAkcentu or Color3.fromRGB(255, 170, 0)
    if not alertGui or not alertGui.Parent then stworzAlertGui() end

    local posOff    = -(ALERT_H + ALERT_MARGIN + ALERT_BOTTOM)
    local startPos  = UDim2.new(1, ALERT_MARGIN,              1, posOff)
    local targetPos = UDim2.new(1, -(ALERT_W + ALERT_MARGIN), 1, posOff)

    local ramka = Instance.new("Frame")
    ramka.Size             = UDim2.new(0, ALERT_W, 0, ALERT_H)
    ramka.Position         = startPos
    ramka.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    ramka.BorderSizePixel  = 0
    ramka.ZIndex           = 10
    ramka.Parent           = alertGui
    Instance.new("UICorner", ramka).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke")
    stroke.Color           = Color3.fromRGB(55, 55, 65)
    stroke.Thickness       = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent          = ramka

    local ikonaBg = Instance.new("Frame")
    ikonaBg.Size             = UDim2.new(0, 36, 0, 36)
    ikonaBg.Position         = UDim2.new(0, 14, 0.5, -18)
    ikonaBg.BackgroundColor3 = Color3.fromRGB(
        math.clamp(math.floor(kolorAkcentu.R * 255 * 0.18), 0, 255),
        math.clamp(math.floor(kolorAkcentu.G * 255 * 0.18), 0, 255),
        math.clamp(math.floor(kolorAkcentu.B * 255 * 0.18), 0, 255)
    )
    ikonaBg.BorderSizePixel = 0
    ikonaBg.ZIndex          = 11
    ikonaBg.Parent          = ramka
    Instance.new("UICorner", ikonaBg).CornerRadius = UDim.new(1, 0)
    local ikona = Instance.new("TextLabel")
    ikona.Size                   = UDim2.new(1, 0, 1, 0)
    ikona.BackgroundTransparency = 1
    ikona.Text                   = "!"
    ikona.TextSize               = 16
    ikona.Font                   = Enum.Font.GothamBold
    ikona.TextColor3             = kolorAkcentu
    ikona.TextXAlignment         = Enum.TextXAlignment.Center
    ikona.TextYAlignment         = Enum.TextYAlignment.Center
    ikona.ZIndex                 = 12
    ikona.Parent                 = ikonaBg

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

    local CZAS    = 4
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

local function kopiujDo(tekst)
    local ok = pcall(function() setclipboard(tekst) end)
    return ok
end

local function pobierzJobId()
    local ok, result = pcall(function() return game.JobId end)
    if ok and result and result ~= "" then return result end
    return ""
end

local function pobierzGameId()
    local ok, result = pcall(function() return tostring(game.PlaceId) end)
    if ok and result then return result end
    return ""
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
--  REBUILD STATYSTYK NA MAIN
--  Wywołuje sie raz - flaga mainStatBuilding blokuje
--  równoległy rebuild
-- ===================================================

local function rebuildMainStats()
    if mainStatBuilding then return end
    if not MainTab then return end
    mainStatBuilding = true

    -- Zniszcz stara sekcje jesli istnieje
    if mainStatSection then
        pcall(function() mainStatSection:Destroy() end)
        mainStatSection = nil
    end

    -- Zbuduj nowa sekcje z aktualnymi danymi
    pcall(function()
        local bazaLiczba = liczbaKonfidentow()
        local naSerwerze = #konfidenciNaSerwerzeLista()

        mainStatSection = MainTab:Section({
            Title  = "Statystyki",
            Icon   = "bar-chart-2",
            Opened = true,
        })

        mainStatSection:Paragraph({
            Title   = "Kont w bazie konfidentow",
            Content = tostring(bazaLiczba),
        })

        mainStatSection:Paragraph({
            Title   = "Konfidentow na tym serwerze",
            Content = tostring(naSerwerze),
        })

        mainStatSection:Space()

        mainStatSection:Button({
            Title    = "Odswiez",
            Icon     = "refresh-cw",
            Justify  = "Between",
            Callback = function()
                mainStatBuilding = false   -- reset flagi przed przebudowa
                rebuildMainStats()
                WindUI:Notify({ Title = "Statystyki", Content = "Zaktualizowano!", Icon = "check-circle", Duration = 2 })
            end,
        })
    end)

    mainStatBuilding = false
end

-- ===================================================
--  THROTTLED REBUILD LIST (Lista + Teleport)
-- ===================================================

local function scheduleRebuild()
    if rebuildPending then return end
    rebuildPending = true
    task.defer(function()
        rebuildPending = false

        -- Rebuild: sekcja Lista (konfidenci na serwerze)
        if ListaTab then
            pcall(function()
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
                    konfidenciSection:Paragraph({ Title = "Brak konfidentow", Content = "Nikt z listy nie jest na tym serwerze" })
                else
                    for _, gracz in ipairs(obecni) do
                        local g       = gracz
                        local isSpect = (spectateTarget == g)
                        konfidenciSection:Button({
                            Title    = g.Name,
                            Desc     = isSpect and "Obserwujesz – kliknij aby stop" or "Kliknij aby spectate",
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
            end)
        end

        -- Rebuild: sekcja Teleport
        if TeleportTab then
            pcall(function()
                if teleportListSection then
                    pcall(function() teleportListSection:Destroy() end)
                    teleportListSection = nil
                end
                local obecni   = konfidenciNaSerwerzeLista()
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
                    Title  = ("Wyniki (%d)"):format(#filtered),
                    Icon   = "map-pin",
                    Opened = true,
                })
                if #obecni == 0 then
                    teleportListSection:Paragraph({ Title = "Brak konfidentow", Content = "Nikt z listy nie jest na tym serwerze" })
                elseif #filtered == 0 then
                    teleportListSection:Paragraph({ Title = "Brak wynikow", Content = "Nie znaleziono: " .. teleportFilter })
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
            end)
        end

        -- Odswiez statystyki (Main) – reset flagi zeby moc odbudowac
        mainStatBuilding = false
        rebuildMainStats()
    end)
end

-- ===================================================
--  AKTUALIZACJA KONFIG
-- ===================================================

local function aktualizujListe()
    task.spawn(function()
        local nowaKonfig = pobierzKonfiguracje()
        if not nowaKonfig then return end

        local nowi  = {}
        for _, uid in ipairs(nowaKonfig.konfidenci or {}) do nowi[uid] = true end
        local starzy = currentConfig.konfidenci or {}

        for uid in pairs(starzy) do
            if not nowi[uid] then
                for _, g in ipairs(Players:GetPlayers()) do
                    if g.UserId == uid then usunOznaczenia(g) end
                end
            end
        end
        for uid in pairs(nowi) do
            if not starzy[uid] then
                for _, g in ipairs(Players:GetPlayers()) do
                    if g.UserId == uid and g.Character then dodajOznaczenia(g) end
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
--  MONITOROWANIE GRACZY
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
    Author        = "v5.2",
    Folder        = "KonfidentHunter",
    NewElements   = true,
    HideSearchBar = true,
    ToggleKey     = Enum.KeyCode[DOMYSLNY_KLUCZ],
    Topbar = {
        Height      = 44,
        ButtonsType = "Mac",
    },
})

-- ===================================================
--  ZAKLADKA: MAIN
-- ===================================================

MainTab = Window:Tab({ Title = "Main", Icon = "home" })
MainTab:Select()

-- --------------------------------------------------
-- SEKCJA 1: Mój profil (nick + avatar w jednym)
-- --------------------------------------------------

local ProfilSekcja = MainTab:Section({
    Title  = "Mój profil",
    Icon   = "user-circle",
    Opened = true,
})

local nick    = LocalPlayer.Name
local display = LocalPlayer.DisplayName
local userId  = LocalPlayer.UserId

local nickTekst = (display ~= nick)
    and (display .. " (@" .. nick .. ")")
    or  ("@" .. nick)

ProfilSekcja:Paragraph({
    Title   = nickTekst,
    Content = "UserID: " .. tostring(userId),
})

-- Avatar pobieramy asynchronicznie i dopisujemy
task.spawn(function()
    local avatarUrl = ""
    pcall(function()
        avatarUrl = Players:GetUserThumbnailAsync(
            userId,
            Enum.ThumbnailType.AvatarBust,
            Enum.ThumbnailSize.Size100x100
        ) or ""
    end)
    if avatarUrl ~= "" then
        pcall(function()
            ProfilSekcja:Paragraph({
                Title   = "Avatar",
                Content = avatarUrl,
            })
        end)
    end
end)

-- --------------------------------------------------
-- SEKCJA 2: Statystyki (budowana dynamicznie)
-- Zostanie wypełniona przez rebuildMainStats()
-- --------------------------------------------------

-- (sekcja tworzona w rebuildMainStats po załadowaniu configu)

-- --------------------------------------------------
-- SEKCJA 3: Serwer – tylko kopiowanie
-- --------------------------------------------------

local SerwSekcja = MainTab:Section({
    Title  = "Serwer",
    Icon   = "server",
    Opened = true,
})

SerwSekcja:Button({
    Title    = "Kopiuj Job ID",
    Desc     = "Skopiuj ID instancji serwera",
    Icon     = "copy",
    Justify  = "Between",
    Callback = function()
        local id = pobierzJobId()
        if id ~= "" then
            local ok = kopiujDo(id)
            WindUI:Notify({
                Title    = ok and "Skopiowano!" or "Błąd",
                Content  = ok and id:sub(1, 30) .. "..." or "Nie udalo sie skopiowac",
                Icon     = ok and "check-circle" or "alert-circle",
                Duration = 3,
            })
        else
            WindUI:Notify({ Title = "Błąd", Content = "Brak Job ID", Icon = "alert-circle", Duration = 3 })
        end
    end,
})

SerwSekcja:Button({
    Title    = "Kopiuj Game ID",
    Desc     = "Skopiuj Place ID gry",
    Icon     = "copy",
    Justify  = "Between",
    Callback = function()
        local id = pobierzGameId()
        if id ~= "" then
            local ok = kopiujDo(id)
            WindUI:Notify({
                Title    = ok and "Skopiowano!" or "Błąd",
                Content  = ok and ("Place ID: " .. id) or "Nie udalo sie skopiowac",
                Icon     = ok and "check-circle" or "alert-circle",
                Duration = 3,
            })
        end
    end,
})

SerwSekcja:Button({
    Title    = "Kopiuj link do serwera",
    Desc     = "roblox://experiences/start?...",
    Icon     = "link",
    Justify  = "Between",
    Callback = function()
        local gid = pobierzGameId()
        local jid = pobierzJobId()
        if gid ~= "" and jid ~= "" then
            local link = ("roblox://experiences/start?placeId=%s&gameInstanceId=%s"):format(gid, jid)
            local ok   = kopiujDo(link)
            WindUI:Notify({
                Title    = ok and "Skopiowano!" or "Błąd",
                Content  = ok and "Link do serwera w schowku" or "Nie udalo sie skopiowac",
                Icon     = ok and "check-circle" or "alert-circle",
                Duration = 3,
            })
        else
            WindUI:Notify({ Title = "Błąd", Content = "Brak Game ID lub Job ID", Icon = "alert-circle", Duration = 3 })
        end
    end,
})

-- ===================================================
--  ZAKLADKA: LISTA
-- ===================================================

ListaTab = Window:Tab({ Title = "Lista", Icon = "users" })

local AkcjeSekcja = ListaTab:Section({ Title = "Akcje", Icon = "zap", Opened = true })

AkcjeSekcja:Toggle({
    Title    = "Pokaz oznaczenia",
    Desc     = "Highlight i tekst nad głową konfidentów",
    Icon     = "eye",
    Value    = true,
    Callback = function(v)
        pokazOznaczenia = v
        odswiezWszystkieOznaczenia()
    end,
})

AkcjeSekcja:Space()

AkcjeSekcja:Button({
    Title    = "Odswież listę",
    Desc     = "Pobiera aktualną listę konfidentów",
    Icon     = "refresh-cw",
    Justify  = "Between",
    Callback = function() aktualizujListe() end,
})

ListaTab:Space()

-- ===================================================
--  ZAKLADKA: TELEPORT
-- ===================================================

TeleportTab = Window:Tab({ Title = "Teleport", Icon = "map-pin" })

TeleportTab:Section({ Title = "Szukaj", Icon = "search", Opened = true }):Input({
    Title       = "Nick konfidenta",
    Placeholder = "np. bartos_GTKM",
    Callback    = function(v)
        teleportFilter = v or ""
        scheduleRebuild()
    end,
})

TeleportTab:Space()

-- ===================================================
--  ZAKLADKA: DISCORD
-- ===================================================

local DiscordTab    = Window:Tab({ Title = "Discord", Icon = "message-circle" })
local DiscordSekcja = DiscordTab:Section({ Title = "Dołącz do nas", Icon = "link", Opened = true })

DiscordSekcja:Button({
    Title    = "Kopiuj link do Discorda",
    Desc     = DISCORD_URL,
    Icon     = "copy",
    Justify  = "Between",
    Callback = function()
        local ok = kopiujDo(DISCORD_URL)
        WindUI:Notify({
            Title    = "Discord",
            Content  = ok and "Link skopiowany!" or DISCORD_URL,
            Icon     = ok and "check-circle" or "message-circle",
            Duration = ok and 3 or 6,
        })
    end,
})

-- ===================================================
--  ZAKLADKA: USTAWIENIA
-- ===================================================

local UstawTab = Window:Tab({ Title = "Ustawienia", Icon = "settings" })

UstawTab:Section({ Title = "Klawisz GUI", Icon = "keyboard", Opened = true }):Keybind({
    Title    = "Otwórz / zamknij GUI",
    Desc     = "Naciśnij klawisz który chcesz przypisać",
    Icon     = "command",
    Value    = DOMYSLNY_KLUCZ,
    Callback = function(v)
        if not v or v == "" then return end
        currentKeybind = v
        pcall(function() Window:SetToggleKey(Enum.KeyCode[v]) end)
        WindUI:Notify({ Title = "Keybind", Content = "Klawisz GUI: " .. v, Icon = "keyboard", Duration = 3 })
    end,
})

UstawTab:Space()

local WizualneSekcja = UstawTab:Section({ Title = "Wizualne", Icon = "palette", Opened = true })

WizualneSekcja:Slider({
    Title    = "Przezroczystość podświetlenia",
    Desc     = "0 = pełny kolor, 10 = niewidoczny",
    Step     = 1,
    Value    = { Min = 0, Max = 10, Default = 4 },
    Callback = function(v)
        if not currentConfig.ustawienia then currentConfig.ustawienia = {} end
        currentConfig.ustawienia.przezroczystosc = v / 10
        for _, folder in pairs(activeMarkers) do
            local hl = folder:FindFirstChildOfClass("Highlight")
            if hl then pcall(function() hl.FillTransparency = v / 10 end) end
        end
    end,
})

WizualneSekcja:Space()

WizualneSekcja:Input({
    Title       = "Tekst nad głową",
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
                        if lbl then
                            pcall(function() lbl.Text = currentConfig.ustawienia.tekstNadGlowa end)
                        end
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

    task.spawn(function()
        local config = pobierzKonfiguracje()
        if config then
            local slownik = {}
            for _, uid in ipairs(config.konfidenci or {}) do slownik[uid] = true end
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
                ustawienia = {
                    kolorPodswietlenia = {255, 170, 0},
                    przezroczystosc    = 0.4,
                    tekstNadGlowa      = "Konfident",
                },
            }
            warn("[KH] Pusta konfiguracja!")
        end

        local bazaLiczba = liczbaKonfidentow()
        print(("[KH] Start. Konfidenci w bazie: %d"):format(bazaLiczba))

        -- Oznaczenia dla graczy już obecnych
        for _, g in ipairs(Players:GetPlayers()) do
            if g ~= LocalPlayer and czyKonfident(g) and g.Character then
                dodajOznaczenia(g)
            end
        end

        -- Jednorazowy rebuild na start
        scheduleRebuild()

        -- Powiadomienie startowe (z opóźnieniem, żeby GUI WindUI zdążyło się otworzyć)
        task.delay(1.0, function()
            local naSerwerze = #konfidenciNaSerwerzeLista()
            WindUI:Notify({
                Title    = "KonfidentHunter",
                Content  = ("Baza: %d kont | Klawisz: %s"):format(bazaLiczba, currentKeybind),
                Icon     = "shield-alert",
                Duration = 5,
            })

            -- Alert o konfidentach pojawia się po powiadomieniu startowym
            task.delay(1.5, function()
                if naSerwerze == 0 then
                    if bazaLiczba > 0 then
                        pokazAlert("KonfidentHunter", ("Załadowano %d kont. Brak konfidentów na serwerze."):format(bazaLiczba), Color3.fromRGB(255, 170, 0))
                    end
                else
                    pokazAlert("KonfidentHunter!", ("%d konfident(ów) JEST NA TYM SERWERZE!"):format(naSerwerze), Color3.fromRGB(255, 60, 60))
                end
            end)
        end)

        -- Monitorowanie graczy
        for _, g in ipairs(Players:GetPlayers()) do
            monitorujGracza(g)
        end

        Players.PlayerAdded:Connect(function(gracz)
            if gracz == LocalPlayer then return end
            monitorujGracza(gracz)
            task.wait(0.5)
            if czyKonfident(gracz) then
                -- Najpierw alert (duży widoczny), potem Notify z opóźnieniem
                pokazAlert("Konfident dołączył!", gracz.Name .. " wbił na serwer!", Color3.fromRGB(255, 60, 60))
                task.delay(0.8, function()
                    WindUI:Notify({
                        Title    = "Konfident na serwerze!",
                        Content  = gracz.Name .. " jest na tym serwerze!",
                        Icon     = "alert-triangle",
                        Duration = 6,
                    })
                end)
                if gracz.Character then dodajOznaczenia(gracz) end
            end
            scheduleRebuild()
        end)

        Players.PlayerRemoving:Connect(function(gracz)
            task.wait(0.15)
            monitorowani[gracz] = nil
            if spectateTarget == gracz then stopSpectate() end
            if czyKonfident(gracz) then
                pokazAlert("Konfident opuścił serwer", gracz.Name .. " wyszedł.", Color3.fromRGB(100, 180, 100))
            end
            scheduleRebuild()
        end)

        task.spawn(startAutoRefresh)
    end)
end

inicjuj()
