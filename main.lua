--[[
    Konfident Hunter v5 - WindUI Edition
    
    Nowe w v5:
    - Keybind do otwierania/zamykania GUI (w Ustawienia)
    - Własny alert GUI (prawy dolny róg) - toast-style
      • przy starcie: "X konfidentów na serwerze"
      • gdy konfident wchodzi: "⚠ [nick] wbił na serwer!"
    - Wszystko wcześniejsze z v4
]]

-- ===== KONFIGURACJA =====
local REFRESH_TIME = 5
local CONFIG_URL   = "https://raw.githubusercontent.com/b99517747-cell/KonfidentHunter/main/config.lua"
local DOMYSLNY_KLUCZ = "K"  -- domyślny keybind do otwierania GUI
-- ========================

local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

local Players         = game:GetService("Players")
local TweenService    = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer     = Players.LocalPlayer
local Camera          = workspace.CurrentCamera

-- ===== STAN GLOBALNY =====
local currentConfig   = { konfidenci = {}, ustawienia = {} }
local activeMarkers   = {}
local spectateTarget  = nil
local pokazOznaczenia = true
local currentKeybind  = DOMYSLNY_KLUCZ  -- aktualny klawisz (string)

local ListaTab        = nil
local TeleportTab     = nil
local kartyRefs       = {}

local teleportDropSection  = nil
local teleportInputSection = nil
local konfidenciSection    = nil

-- ═══════════════════════════════════════════
--  SYSTEM ALERTÓW (prawy dolny róg)
-- ═══════════════════════════════════════════

local alertGui    = nil
local alertQueue  = {}  -- kolejka oczekujących alertów
local alertActive = false

local function stworzAlertGui()
    -- Usuń stary jeśli istnieje
    if alertGui then pcall(function() alertGui:Destroy() end) end

    local gui = Instance.new("ScreenGui")
    gui.Name            = "KH_AlertGui"
    gui.ResetOnSpawn    = false
    gui.DisplayOrder    = 999
    gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling

    -- Próbuj gethui(), fallback CoreGui, fallback PlayerGui
    local ok = pcall(function() gui.Parent = gethui() end)
    if not ok then
        ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
        if not ok then gui.Parent = LocalPlayer.PlayerGui end
    end

    alertGui = gui
end

local ALERT_W      = 320
local ALERT_H      = 72
local ALERT_PAD    = 12
local ALERT_MARGIN = 16  -- margines od krawędzi ekranu

local function pokazAlert(tytul, tresc, ikonaTekst, kolorAkcentu)
    kolorAkcentu = kolorAkcentu or Color3.fromRGB(255, 170, 0)
    ikonaTekst   = ikonaTekst   or "⚠"

    if not alertGui or not alertGui.Parent then stworzAlertGui() end

    -- Ramka alertu
    local ramka = Instance.new("Frame")
    ramka.Name              = "Alert"
    ramka.Size              = UDim2.new(0, ALERT_W, 0, ALERT_H)
    -- start poza ekranem (z prawej)
    ramka.Position          = UDim2.new(1, ALERT_MARGIN, 1, -(ALERT_H + ALERT_MARGIN))
    ramka.BackgroundColor3  = Color3.fromRGB(20, 20, 24)
    ramka.BorderSizePixel   = 0
    ramka.ClipsDescendants  = true
    ramka.ZIndex            = 10
    ramka.Parent            = alertGui

    -- Zaokrąglenie
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent       = ramka

    -- Lewa kolorowa kreska akcentu
    local pasek = Instance.new("Frame")
    pasek.Name             = "Akcent"
    pasek.Size             = UDim2.new(0, 4, 1, 0)
    pasek.Position         = UDim2.new(0, 0, 0, 0)
    pasek.BackgroundColor3 = kolorAkcentu
    pasek.BorderSizePixel  = 0
    pasek.ZIndex           = 11
    pasek.Parent           = ramka
    Instance.new("UICorner", pasek).CornerRadius = UDim.new(0, 4)

    -- Obramowanie
    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(50, 50, 58)
    stroke.Thickness = 1
    stroke.Parent    = ramka

    -- Ikona/emoji
    local ikona = Instance.new("TextLabel")
    ikona.Size                   = UDim2.new(0, 36, 0, 36)
    ikona.Position               = UDim2.new(0, 16, 0.5, -18)
    ikona.BackgroundTransparency = 1
    ikona.Text                   = ikonaTekst
    ikona.TextSize               = 22
    ikona.Font                   = Enum.Font.GothamBold
    ikona.TextColor3             = kolorAkcentu
    ikona.ZIndex                 = 11
    ikona.Parent                 = ramka

    -- Tytuł
    local tytulLabel = Instance.new("TextLabel")
    tytulLabel.Size                   = UDim2.new(1, -64, 0, 20)
    tytulLabel.Position               = UDim2.new(0, 58, 0, 12)
    tytulLabel.BackgroundTransparency = 1
    tytulLabel.Text                   = tytul
    tytulLabel.TextColor3             = Color3.fromRGB(240, 240, 240)
    tytulLabel.Font                   = Enum.Font.GothamBold
    tytulLabel.TextSize               = 13
    tytulLabel.TextXAlignment         = Enum.TextXAlignment.Left
    tytulLabel.TextTruncate           = Enum.TextTruncate.AtEnd
    tytulLabel.ZIndex                 = 11
    tytulLabel.Parent                 = ramka

    -- Treść
    local trescLabel = Instance.new("TextLabel")
    trescLabel.Size                   = UDim2.new(1, -64, 0, 30)
    trescLabel.Position               = UDim2.new(0, 58, 0, 32)
    trescLabel.BackgroundTransparency = 1
    trescLabel.Text                   = tresc
    trescLabel.TextColor3             = Color3.fromRGB(175, 175, 190)
    trescLabel.Font                   = Enum.Font.Gotham
    trescLabel.TextSize               = 11
    trescLabel.TextXAlignment         = Enum.TextXAlignment.Left
    trescLabel.TextWrapped            = true
    trescLabel.ZIndex                 = 11
    trescLabel.Parent                 = ramka

    -- Pasek postępu (dolny)
    local progress = Instance.new("Frame")
    progress.Name             = "Progress"
    progress.Size             = UDim2.new(1, 0, 0, 3)
    progress.Position         = UDim2.new(0, 0, 1, -3)
    progress.BackgroundColor3 = kolorAkcentu
    progress.BorderSizePixel  = 0
    progress.ZIndex           = 12
    progress.Parent           = ramka

    -- Animacja: wjazd z prawej
    local targetX = 1 - (ALERT_W / workspace.CurrentCamera.ViewportSize.X) - (ALERT_MARGIN / workspace.CurrentCamera.ViewportSize.X)
    -- Uproszczone: offset od prawej
    local wjazdPos = UDim2.new(1, -(ALERT_W + ALERT_MARGIN), 1, -(ALERT_H + ALERT_MARGIN))
    ramka.Position = UDim2.new(1, ALERT_MARGIN, 1, -(ALERT_H + ALERT_MARGIN))

    local tweenIn = TweenService:Create(ramka, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = wjazdPos
    })
    tweenIn:Play()

    -- Animacja paska postępu (4 sekundy)
    local CZAS_WYSWIETLANIA = 4
    local tweenProgress = TweenService:Create(progress, TweenInfo.new(CZAS_WYSWIETLANIA, Enum.EasingStyle.Linear), {
        Size = UDim2.new(0, 0, 0, 3)
    })

    tweenIn.Completed:Connect(function()
        tweenProgress:Play()
    end)

    -- Wyjazd po czasie
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

-- ═══════════════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════════════

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

-- ═══════════════════════════════════════════
--  OZNACZENIA (highlight + billboard)
-- ═══════════════════════════════════════════

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
    hl.Name                = "Podswietlenie"
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

-- ═══════════════════════════════════════════
--  SPECTATE
-- ═══════════════════════════════════════════

local function spectateGracza(gracz)
    if not gracz or not gracz.Character then return end
    local h = gracz.Character:FindFirstChild("Humanoid")
    if not h then return end
    spectateTarget = gracz
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

-- ═══════════════════════════════════════════
--  TELEPORT
-- ═══════════════════════════════════════════

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

-- ═══════════════════════════════════════════
--  POBIERANIE CONFIGU
-- ═══════════════════════════════════════════

local function pobierzKonfiguracje()
    local ok, result = pcall(function() return game:HttpGet(CONFIG_URL) end)
    if not ok then warn("[KH] HttpGet: " .. tostring(result)); return nil end
    local func, err = loadstring(result)
    if not func then warn("[KH] loadstring: " .. tostring(err)); return nil end
    local ok2, config = pcall(func)
    if not ok2 then warn("[KH] pcall: " .. tostring(config)); return nil end
    return config
end

-- ═══════════════════════════════════════════
--  REBUILD LISTY I TELEPORTU
-- ═══════════════════════════════════════════

local function rebuildListaSekcje()
    if not ListaTab then return end
    if konfidenciSection then
        pcall(function() konfidenciSection:Destroy() end)
        konfidenciSection = nil
    end
    kartyRefs = {}

    local obecni = konfidenciNaSerwerzeLista()

    konfidenciSection = ListaTab:Section({
        Title  = ("Konfidenci na serwerze (%d)"):format(#obecni),
        Icon   = "users",
        Opened = true,
    })

    if #obecni == 0 then
        konfidenciSection:Button({ Title = "Brak konfidentów na serwerze", Icon = "user-x", Locked = true })
        return
    end

    for _, gracz in ipairs(obecni) do
        local isSpect = (spectateTarget == gracz)
        konfidenciSection:Button({
            Title    = gracz.Name,
            Desc     = isSpect and "👁  Obserwujesz — kliknij aby stop" or "Kliknij aby spectate",
            Icon     = avatarUrl(gracz.UserId),
            Color    = isSpect and Color3.fromRGB(255, 170, 0) or nil,
            Callback = function()
                if spectateTarget == gracz then
                    stopSpectate()
                else
                    if spectateTarget then stopSpectate() end
                    spectateGracza(gracz)
                end
                task.wait(0.05)
                rebuildListaSekcje()
            end,
        })
    end
end

local function rebuildTeleportSekcje()
    if not TeleportTab then return end
    if teleportDropSection then
        pcall(function() teleportDropSection:Destroy() end)
        teleportDropSection = nil
    end
    if teleportInputSection then
        pcall(function() teleportInputSection:Destroy() end)
        teleportInputSection = nil
    end

    local obecni = konfidenciNaSerwerzeLista()

    -- ── Sekcja: Szukaj po nicku ──
    teleportInputSection = TeleportTab:Section({ Title = "Szukaj konfidenta", Icon = "search", Opened = true })

    local filterInput = ""
    teleportInputSection:Input({
        Title       = "Wpisz nick",
        Placeholder = "np. bartos_GTKM",
        Callback    = function(v)
            filterInput = v
            -- rebuild sekcji wynikow po wpisaniu
            rebuildTeleportSekcje()
        end,
    })

    -- ── Sekcja: Lista konfidentów (filtrowana) ──
    teleportDropSection = TeleportTab:Section({
        Title  = "Konfidenci na serwerze",
        Icon   = "map-pin",
        Opened = true,
    })

    if #obecni == 0 then
        teleportDropSection:Button({ Title = "Brak konfidentów na serwerze", Icon = "user-x", Locked = true })
        return
    end

    -- Filtrowanie po nicku jeśli coś wpisano
    local filtered = {}
    if filterInput ~= "" then
        local szukaj = filterInput:lower()
        for _, g in ipairs(obecni) do
            if g.Name:lower():find(szukaj, 1, true) then
                table.insert(filtered, g)
            end
        end
    else
        filtered = obecni
    end

    if #filtered == 0 then
        teleportDropSection:Button({ Title = "Nie znaleziono: " .. filterInput, Icon = "user-x", Locked = true })
        return
    end

    for _, gracz in ipairs(filtered) do
        teleportDropSection:Button({
            Title    = gracz.Name,
            Desc     = "Kliknij aby teleportować",
            Icon     = avatarUrl(gracz.UserId),
            Justify  = "Between",
            Callback = function()
                teleportDo(gracz)
            end,
        })
    end
end

local function rebuildWszystko()
    rebuildListaSekcje()
    rebuildTeleportSekcje()
end

-- ═══════════════════════════════════════════
--  AKTUALIZACJA KONFIG
-- ═══════════════════════════════════════════

local function aktualizujListe()
    local nowaKonfig = pobierzKonfiguracje()
    if not nowaKonfig then return end

    local nowi = {}
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

    currentConfig = nowaKonfig
    currentConfig.konfidenci = nowi
    currentConfig.ustawienia = currentConfig.ustawienia or {
        kolorPodswietlenia = {255, 170, 0},
        przezroczystosc    = 0.4,
        tekstNadGlowa      = "Konfident",
    }

    print(("[KH] ✅ Odświeżono. Konfidenci w bazie: %d"):format(liczbaKonfidentow()))
    rebuildWszystko()
end

-- ═══════════════════════════════════════════
--  MONITOROWANIE GRACZY
-- ═══════════════════════════════════════════

local function monitorujGracza(gracz)
    if gracz == LocalPlayer then return end

    gracz.CharacterAdded:Connect(function()
        task.wait(0.3)
        if czyKonfident(gracz) then
            dodajOznaczenia(gracz)
            rebuildWszystko()
        end
    end)

    gracz.CharacterRemoving:Connect(function()
        usunOznaczenia(gracz)
        if spectateTarget == gracz then stopSpectate() end
        rebuildWszystko()
    end)
end

-- ═══════════════════════════════════════════
--  AUTO-ODŚWIEŻANIE
-- ═══════════════════════════════════════════

local function startAutoRefresh()
    while true do
        task.wait(REFRESH_TIME)
        aktualizujListe()
        for _, g in ipairs(Players:GetPlayers()) do
            if g ~= LocalPlayer then
                local jestKonf = czyKonfident(g)
                if jestKonf and g.Character then
                    if pokazOznaczenia and not activeMarkers[g] then dodajOznaczenia(g)
                    elseif not pokazOznaczenia and activeMarkers[g] then usunOznaczenia(g) end
                elseif not jestKonf and activeMarkers[g] then
                    usunOznaczenia(g)
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════
--  WIND UI - TWORZENIE OKNA
-- ═══════════════════════════════════════════

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

-- ══════════════════════════════════════════
--  ZAKŁADKA: LISTA
-- ══════════════════════════════════════════
ListaTab = Window:Tab({ Title = "Lista", Icon = "users" })

local AkcjeSekcja = ListaTab:Section({ Title = "Akcje", Icon = "zap", Opened = true })

AkcjeSekcja:Toggle({
    Title = "Pokaż oznaczenia",
    Desc  = "Highlight i tekst nad głową konfidentów",
    Icon  = "eye",
    Value = true,
    Callback = function(v)
        pokazOznaczenia = v
        odswiezWszystkieOznaczenia()
    end,
})

AkcjeSekcja:Space()

AkcjeSekcja:Button({
    Title    = "Odśwież listę",
    Desc     = "Pobiera aktualną listę konfidentów",
    Icon     = "refresh-cw",
    Justify  = "Between",
    Callback = function() task.spawn(aktualizujListe) end,
})

ListaTab:Space()
-- konfidenciSection budowana przez rebuildListaSekcje()

-- ══════════════════════════════════════════
--  ZAKŁADKA: TELEPORT
-- ══════════════════════════════════════════
TeleportTab = Window:Tab({ Title = "Teleport", Icon = "map-pin" })
-- teleportDropSection i teleportInputSection budowane przez rebuildTeleportSekcje()

-- ══════════════════════════════════════════
--  ZAKŁADKA: DISCORD
-- ══════════════════════════════════════════
local DiscordTab = Window:Tab({ Title = "Discord", Icon = "message-circle" })

local DiscordSekcja = DiscordTab:Section({ Title = "Dołącz do nas", Icon = "link", Opened = true })

local DISCORD_URL = "https://discord.gg/YjTWGZYD"

DiscordSekcja:Button({
    Title    = "Skopiuj link do Discorda",
    Desc     = DISCORD_URL,
    Icon     = "copy",
    Justify  = "Between",
    Callback = function()
        local ok = pcall(function() setclipboard(DISCORD_URL) end)
        if ok then
            WindUI:Notify({
                Title    = "Discord",
                Content  = "Link skopiowany do schowka!",
                Icon     = "check-circle",
                Duration = 3,
            })
        else
            WindUI:Notify({
                Title    = "Discord",
                Content  = DISCORD_URL,
                Icon     = "message-circle",
                Duration = 5,
            })
        end
    end,
})

-- ══════════════════════════════════════════
--  ZAKŁADKA: USTAWIENIA
-- ══════════════════════════════════════════
local UstawTab = Window:Tab({ Title = "Ustawienia", Icon = "settings" })

-- ── Sekcja: Klawisz GUI ──
local KeybindSekcja = UstawTab:Section({ Title = "Klawisz GUI", Icon = "keyboard", Opened = true })

KeybindSekcja:Keybind({
    Title    = "Otwórz / zamknij GUI",
    Desc     = "Naciśnij klawisz, który chcesz przypisać",
    Icon     = "command",
    Value    = DOMYSLNY_KLUCZ,
    Callback = function(v)
        if not v or v == "" then return end
        currentKeybind = v
        -- Ustaw nowy klawisz w WindUI
        local ok = pcall(function()
            Window:SetToggleKey(Enum.KeyCode[v])
        end)
        if ok then
            WindUI:Notify({
                Title   = "Keybind",
                Content = "Klawisz GUI ustawiony na: " .. v,
                Icon    = "keyboard",
                Duration = 3,
            })
        end
    end,
})

UstawTab:Space()

-- ── Sekcja: Wizualne ──
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
            local hl = folder:FindFirstChild("Podswietlenie")
            if hl then hl.FillTransparency = v / 10 end
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
                        if lbl then lbl.Text = currentConfig.ustawienia.tekstNadGlowa end
                    end
                end
            end
        end
    end,
})

-- ══════════════════════════════════════════
--  INICJALIZACJA
-- ══════════════════════════════════════════

local function inicjuj()
    -- Stwórz GUI alertów
    stworzAlertGui()

    -- Pobierz konfig
    local config = pobierzKonfiguracje()
    if config then
        local slownik = {}
        for _, userId in ipairs(config.konfidenci or {}) do slownik[userId] = true end
        currentConfig = config
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
        warn("[KH] ⚠️ Pusta konfiguracja!")
    end

    local bazaLiczba = liczbaKonfidentow()
    print(("[KH] 🟢 Start. Konfidenci w bazie: %d"):format(bazaLiczba))

    -- Oznacz obecnych
    for _, g in ipairs(Players:GetPlayers()) do
        if g ~= LocalPlayer and czyKonfident(g) and g.Character then
            dodajOznaczenia(g)
        end
    end

    -- Zbuduj obie zakładki
    rebuildWszystko()

    -- === ALERT STARTOWY ===
    local naSerwerze = #konfidenciNaSerwerzeLista()
    task.delay(1.5, function()
        if bazaLiczba == 0 then
            pokazAlert(
                "KonfidentHunter",
                "Baza jest pusta. Brak konfidentów.",
                "🛡",
                Color3.fromRGB(100, 100, 120)
            )
        elseif naSerwerze == 0 then
            pokazAlert(
                "KonfidentHunter",
                ("Załadowano %d konfidentów. Brak na serwerze."):format(bazaLiczba),
                "🛡",
                Color3.fromRGB(255, 170, 0)
            )
        else
            pokazAlert(
                "KonfidentHunter",
                ("⚠ %d konfident(ów) NA SERWERZE!"):format(naSerwerze),
                "🚨",
                Color3.fromRGB(255, 60, 60)
            )
        end
    end)

    -- WindUI notif
    WindUI:Notify({
        Title    = "KonfidentHunter",
        Content  = ("Baza: %d ID | Naciśnij %s"):format(bazaLiczba, currentKeybind),
        Icon     = "shield-alert",
        Duration = 5,
    })

    -- Monitorowanie aktualnych
    for _, g in ipairs(Players:GetPlayers()) do
        if g ~= LocalPlayer then monitorujGracza(g) end
    end

    -- Nowi gracze
    Players.PlayerAdded:Connect(function(gracz)
        if gracz == LocalPlayer then return end
        monitorujGracza(gracz)

        -- Czekaj aż gracz załaduje dane
        task.wait(0.5)

        if czyKonfident(gracz) then
            -- === ALERT: KONFIDENT WBIŁ ===
            pokazAlert(
                "⚠  Konfident na serwerze!",
                ("\"" .. gracz.Name .. "\" wbił na serwer!"),
                "🚨",
                Color3.fromRGB(255, 60, 60)
            )
            WindUI:Notify({
                Title   = "Konfident wbił!",
                Content = gracz.Name .. " jest na serwerze!",
                Icon    = "alert-triangle",
                Duration = 6,
            })
            if gracz.Character then dodajOznaczenia(gracz) end
        end

        task.wait(0.1)
        rebuildWszystko()
    end)

    -- Gracze opuszczający
    Players.PlayerRemoving:Connect(function(gracz)
        task.wait(0.15)
        if spectateTarget == gracz then stopSpectate() end

        if czyKonfident(gracz) then
            pokazAlert(
                "Konfident opuścił serwer",
                ("\"" .. gracz.Name .. "\" wyszedł."),
                "🛡",
                Color3.fromRGB(100, 180, 100)
            )
        end

        rebuildWszystko()
    end)

    task.spawn(startAutoRefresh)
end

inicjuj()
