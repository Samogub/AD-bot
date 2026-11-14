#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"
SendMode "Event"
SetKeyDelay 30, 30
try DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")   ; щоб координати не з'їжджали при масштабі Windows != 100%

; ======================= НАЛАШТУВАННЯ =======================
GAME     := "ahk_exe RobloxPlayerBeta.exe"
INI      := A_ScriptDir "\raid.ini"
LOGFILE  := A_ScriptDir "\raid.log"                  ; "" = без логу

; Точка на кожному ромбі скіла (під текстом). Готовий скіл = кольоровий, перезарядка = сірий.
; Координати для вікна Roblox на весь екран 1920x1080.
SKILL_POS := Map(
    "1", [739, 1010],
    "2", [887, 1010],
    "3", [1035, 1010],
    "4", [1184, 1010],
    "5", [960, 920],
    "e", [1348, 975],
    "r", [1400, 1025],
    "z", [1456, 958],      ; ближче до центру ромба: у RDP (дрібніший інтерфейс) точка 975 вилазила за ромб
    "x", [1512, 1025])
SKILL_KEYS := ["1", "2", "3", "4", "5", "e", "r", "z", "x"]
SKILL_BAR := [730, 900, 800, 135]        ; ділянка панелі скілів (x, y, w, h) - усі точки SKILL_POS всередині (див. SkillColor)
IMGDIR    := A_ScriptDir "\img\"
TOLERANCE := 40
; Roblox scales its interface with the window, and the images only match at the size they were captured at
; (1.11 on another PC: client 1920x1009 and 1920x1057 - PLAY was "not recognised" for minutes). So the bot sizes the window itself.
; 1.11 22:00 raid at client height 1027: the "Respawn in N" countdown was not seen at all and BossAhead scored 0.13 instead of 0.00 -
; the detectors were calibrated at 1017 (taskbar 40 px), so that is the one size we use, +-2 px.
GAME_W := 1920, GAME_H := 1017
; the game area on screen: title bar 23 + client 1017 + 40 = the top-left 1920x1080 of any screen >= 1920x1080
; (5.11: bigger screens and Windows scale > 100% are allowed - the window keeps this size, all coordinates stay the same)
SCR_W := 1920, SCR_H := 1080
ENEMIES_BOX := [1700, 780, 1920, 900]    ; де шукати напис ENEMIES LEFT (є лише в бою)
; де напис стоїть зазвичай (лівий верхній кут). Спершу шукаємо лише тут: у широкій рамці ImageSearch
; бере перший збіг, а рожева стіна (178,106,94) з допуском *80 теж "схожа" на літери - її відкидає
; BorderOk, і до справжнього напису правіше пошук так і не доходить (бот вирішує, що бою немає)
ENEMIES_HOME := [1840, 819]
; рейди на вибір: еталон напису в списку, зсув від його лівого верхнього кута до кнопки Create, назва,
; шаблон назви для OCR. Без еталона ("") рейд шукається в списку за назвою (OCR, з прокручуванням) -
; так новий рейд додається одним рядком. Порядок у вікні бота - за ключем.
RAIDS := Map(
    "halloween", ["halloween.png", [113, 95], "Halloween Raid", "i)Hallow"],
    "divine",    ["divine.png",    [107, 92], "Divine Guardian Raid", "i)Divine"],
    "shiro",     ["", 0, "Infinity Shiro Raid", "i)Shiro"],
    "saiya",     ["", 0, "Saiya Ultra Instinct Raid", "i)Saiya|Instinct"],
    "sungomi",   ["", 0, "Sun Gomi Raid", "i)Gomi"],
    "tiger",     ["", 0, "Tiger Raid", "i)Tiger"],
    "dual",      ["", 0, "Dual Wielder Raid", "i)Wielder"],
    "monke",     ["", 0, "Monke Raid", "i)Monke"],
    "cursed",    ["", 0, "Cursed Sage Raid", "i)Cursed|Sage"])
; dungeon (experimental): found in the Create list by name, like a raid without a picture
DUNGEON := ["", 0, "Giant Dimension", "i)Giant"]
; the plain Dimensions to pick (11.11, cards read from the Create list): title, OCR pattern. Only Giant has a built-in run; every other one
; plays the player's own recording in dimension\<name>\ (no recording = skipped, the player is told). UI order = DIM_ORDER.
DIM_ORDER := ["giant", "halloween", "demon", "curse", "villain", "sword", "ghoul", "fate", "gel", "devil", "pirate", "alien", "level", "death"]
DIMS := Map("giant", ["Giant Dimension", "i)Giant"], "halloween", ["Halloween Dimension", "i)Halloween\s*Dim"]
    , "demon", ["Demon Dimension", "i)Demon\s*Dim"], "curse", ["Curse Dimension", "i)Curse\s*Dim"]
    , "villain", ["Villain Dimension", "i)Villain\s*Dim"], "sword", ["Sword Dimension", "i)Sword\s*Dim"]
    , "ghoul", ["Ghoul Dimension", "i)Ghoul\s*Dim"], "fate", ["Fate Dimension", "i)Fate\s*Dim"]
    , "gel", ["Gel Dimension", "i)Gel\s*Dim"], "devil", ["Devil Dimension", "i)Devil\s*Dim"]
    , "pirate", ["Pirate Dimension", "i)Pirate\s*Dim"], "alien", ["Alien Dimension", "i)Alien\s*Dim"]
    , "level", ["Level Dimension", "i)Level\s*Dim"], "death", ["Death Dimension", "i)Death\s*Dim"])
; Giant mode: leave for the raid this many seconds before createFrom (last run <= 52.4 s + LEAVE-to-Create <= 42 s)
DIM_LEAD := 100
SAFE_MODE := true                        ; 10.11: Safe mode on again with the softer scheme (restart only on problems 1-2, pause on the 3rd in 2 h); false = off
#Include dungeon_giant.ahk               ; DUNGEON_ROUTE: the recorded run (built in), played by RunRoute()
DIM_DIR := A_ScriptDir "\dimension\giant\"   ; the editable copy of the run: log.txt (Recorder format) + screenshots
; the dungeon being played: Extreme (own switch, wins over Dimension) or the one chosen on the Dimension page
; 10.11: Extreme only while today's map has a run (or an Extreme run is being played); else the plain Dimension when it is on
DimKind() => cfg["xdim"] = "1" && (xdimMapNow != "" || cfg["dungeon"] != "1" || XdimReady()) ? "xdim"
    : DIMS.Has(cfg["dimName"]) ? cfg["dimName"] : "giant"
XdimReady() {                                              ; DimKind is called many times a tick: checked again every 5 s
    static at := 0, ok := false
    if !at || A_TickCount - at > 5000
        at := A_TickCount, ok := !XdimNearReset() && FileExist(DimDir("xdim", true) "log.txt")
    return ok
}
; recordings: Giant = dimension\giant, giant2..5; Halloween / Death the same with their own name; Extreme = dimension\extreme (one run)
DimDir(kind := "", today := false) {
    k := kind != "" ? kind : DimKind()
    if k = "xdim"                                          ; today's map (or the map of the run being played, for RETRY replays)
        return A_ScriptDir "\dimension\extreme_" (xdimMapNow != "" && !today ? xdimMapNow : XdimMap()) "\"
    if k = "giant"
        return cfg["dimMethod"] = "1" ? DIM_DIR : A_ScriptDir "\dimension\giant" cfg["dimMethod"] "\"
    return A_ScriptDir "\dimension\" k (cfg["dimMethod"] = "1" ? "" : cfg["dimMethod"]) "\"
}   ; Method 1 = giant, Method 2 / Slot 3-5 = giant2 / giant3-5: each keeps its own recording

; Extreme Dimension (10.11, player idea): the game plays one map a day in a fixed 13-day cycle (Sword really comes twice).
; The bot counts game days from an anchor (game day + place in the list; 10.11 = Curse, 6th) that the player fixes with
; < > on the Extreme page. Every map keeps its own run in dimension\extreme_<map>\ (both Sword days share extreme_sword).
; raid.ini: xdimCycle (the list), xdimAnchorPos / xdimAnchorDay, xdimResetUtc (hour the map changes, UTC), xdimResetGuard (min).
XDIM_CYCLE := "alien,pirate,slime,sword,sword,curse,level,fate,devil,titan,ghoul,death,demon"
XdimCycle() {
    l := []
    for s in StrSplit(IniRead(INI, "raid", "xdimCycle", XDIM_CYCLE), ",")
        if (s := RegExReplace(StrLower(s), "[^a-z0-9]")) != ""
            l.Push(s)
    return l.Length >= 2 ? l : StrSplit(XDIM_CYCLE, ",")
}
XdimIni(key, def) => IsInteger(v := Trim(IniRead(INI, "raid", key, def))) ? Integer(v) : Integer(def)
XdimGameDay() => FormatTime(DateAdd(A_NowUTC, -Mod(XdimIni("xdimResetUtc", "0"), 24), "Hours"), "yyyyMMdd")
XdimPos(dayOff := 0) {                                     ; place of the day's map in the list, 1..N (dayOff 1 = tomorrow)
    n := XdimCycle().Length, ad := Trim(IniRead(INI, "raid", "xdimAnchorDay", "20261110"))
    d := RegExMatch(ad, "^\d{8}$") ? DateDiff(XdimGameDay(), ad, "Days") : 0
    return Mod(Mod(XdimIni("xdimAnchorPos", "6") - 1 + d + dayOff, n) + n, n) + 1   ; Mod can be negative in AHK
}
XdimMap(dayOff := 0) => XdimCycle()[XdimPos(dayOff)]
XdimName(id) => StrUpper(SubStr(id, 1, 1)) SubStr(id, 2)
; around the map change it is not sure which map the game has: Extreme is not entered then (reset hour unknown yet: +-60 min)
XdimNearReset() {
    m := Integer(FormatTime(A_NowUTC, "H")) * 60 + Integer(FormatTime(A_NowUTC, "m")), d := Abs(m - Mod(XdimIni("xdimResetUtc", "0"), 24) * 60)
    return Min(d, 1440 - d) <= XdimIni("xdimResetGuard", "60")
}
DIM_MOBS := [820, 260, 280, 170]         ; where the first group (3 orange giants) stands at the Giant Dimension spawn
KNOCKBACK_RAIDS := " divine "            ; лише тут бос відкидає: пошук боса й поворот камери після смерті
RAID_LIST     := [1040, 340, 220, 570]   ; стовпчик назв і кнопок Create in the list рейдів (x, y, w, h)
RAID_CREATE_X := 1175                    ; x кнопки Create in the list (the Easy button of the Group Finder list covers it too)
GF_TAB_DX     := 145                     ; Group Finder tab: centre is this far right of the Create tab centre
; loadout: рейд - 1, Infinity або dungeon - 2. Bag -> кнопка "Loadout N" угорі -> рядок списку. Поточний читаємо OCR з кнопки.
BAG_BTN      := [1850, 700]              ; BAG праворуч (у лобі і в світі рейду)
LOADOUT_BOX  := [880, 192, 230, 50]      ; кнопка "Loadout N ▼" у вікні Bag
LOADOUT_ROWS := [[1085, 290], [1085, 394], [1085, 497]]
BAG_CLOSE    := [1455, 219]
; Speed Raid (28.10): меню режимів -> картка SPEED RAID -> вікно з Start -> вибір персонажа -> Start.
; Кожен персонаж - раз на тиждень (використані затемнені), режим - раз на 30 min.
SPEED_LAST_MIN  := 52                    ; після цієї minилини не починаємо (рейд о :00; бос гине за 1-2 min)
SPEED_EVERY     := 30 * 60               ; с між забігами
SPEED_READY_BOX := [920, 872, 200, 32]   ; "Ready to enter" / "Ready in 00:01:13" над карткою в меню режимів
MODES_CLOSE     := [1490, 200]           ; хрестик меню режимів
SPEED_TITLE_BOX := [400, 200, 520, 65]   ; заголовок вікна: "Speed Raid" / "Select a Character"
SPEED_RESET_BOX := [400, 264, 640, 40]       ; "Weekly Reset in: 8 Hours 26 Minutes" під заголовком вікна Speed Raid
SPEED_START     := [1319, 684]           ; Start у вікні Speed Raid
SPEED_GO        := [951, 847]            ; Start під списком персонажів
SPEED_CLOSE     := [1451, 235]           ; хрестик вікон Speed Raid
SPEED_GRID      := [422, 313, 1028, 462] ; список персонажів (x, y, w, h)
SPEED_COLS      := [521, 728, 935, 1143, 1350]
SPEED_BAR_X     := 1477                  ; смуга прокрутки списку (орієнтир: точний X бот шукає сам, FindBarX)
speedBarX       := SPEED_BAR_X           ; знайдений X повзунка
SPEED_ORDER     := "5 4 3 2 1"           ; порядок скілів у Speed Raid (комбо немає; 5 є не в усіх - порожній слот не готовий, пропуск)
INF_OFFSET    := [109, 95]               ; те саме для напису "Infinite Mode"
RAID_WINDOW   := 10                      ; перші N minилин години пробуємо зайти в рейд (якщо цієї години ще не були; пізніше рейд не створити)
RESET_EVERY   := 5000                    ; як часто робити Esc-R-Enter, коли виходимо з Infinity
CREATE_RETRY  := 5000                    ; як часто тиснути Create, поки рейд закритий
; Еталони з самих літер (решта прозора) збігаються з будь-якою суцільною плямою кольору літер
; (білий спалах, червоний ефект). Тому після збігу дивимось на точки довкола літер: на справжній
; кнопці там фон, на плямі - той самий колір. Точки пораховані з еталонів (зсув від лівого верхнього кута).
BORDER := Map(
    "play.png", ["white", [[5,5],[53,5],[125,5],[173,5],[5,11],[44,14],[95,17],[92,20],[5,26],[65,29],[140,32],[35,38],[158,41],[5,47],[47,50],[83,50]]],
    ; raid_mode.png = letter cores of raid_mode_2.png (same box): the cards pulse, the full letters matched only at one size (3.11 23:57)
    "raid_mode.png", ["white", [[2,2],[131,2],[50,5],[5,8],[5,11],[8,14],[80,17],[119,20],[143,23],[8,29],[2,35],[2,38],[137,38],[23,41],[56,41],[89,41]]],
    ; the modes cards pulse: dimension_2 / speed_mode_2 = letter cores (2 px of every edge cut), same box as the full template (4.11)
    "speed_mode.png", ["white", [[2,2],[86,2],[170,2],[254,2],[56,5],[140,5],[224,5],[158,8],[281,11],[161,20],[257,26],[278,35],[140,41],[32,44],[116,44],[200,44]]],
    "dimension.png", ["white", [[5,8],[86,8],[152,8],[221,8],[95,11],[125,14],[188,17],[188,20],[26,26],[116,29],[140,32],[236,35],[209,38],[56,41],[128,41],[197,41]]],
    "enemies_left.png", ["red", [[12,2],[51,11],[14,12],[27,12],[40,12],[3,13],[16,13],[29,13],[42,13],[17,14],[16,16],[11,18],[16,19],[34,20],[32,22],[18,23]]])
; хрестики відомих вікон гри: Update Logs, вікно Join/Create, меню режимів (PLAY)
CLOSE_XS := [[1506, 321], [1227, 261], [1496, 201], [BAG_CLOSE[1], BAG_CLOSE[2]]]
UPDATE_LOGS_X := [1114, 13]              ; від лівого верхнього кута напису "UPDATE LOGS" до хрестика вікна
; вікно Roblox "Disconnected / Leave / Reconnect": читаємо текст у центрі екрана (OCR), бо фон під вікном будь-який
DISCONNECT_BOX := [560, 280, 800, 520]
; no bare "retry": the RETRY button of Dimension / Infinity results is inside DISCONNECT_BOX (planner 5.11)
DISCONNECT_RE  := "i)disconnect|reconnect|lost connection|error code|connection"
; браузер зі сторінкою гри на roblox.com (вкладка Servers): перезаходимо кнопкою Join першого приватного сервера
BROWSER    := "Anime Dimensions ahk_class Chrome_WidgetWin_1"
JOIN_COLOR := 0x1D3570          ; темно-синя кнопка Join (сіра Create поруч не підходить)
JOIN_BOX   := [1370, 130, 1400, 1040]   ; вузька смуга всередині кнопок Join - перший збіг згори = перша кнопка
RESTART_GAP    := 600000   ; перезапускати Roblox не частіше, ніж раз на 10 min
SERVER_LINK    := ""   ; no private server by default (raid.ini [raid] serverLink = your own share link)
RESTART_GAP_DC := 60000    ; а при обриві з'єднання (Error 279) - одразу, лише не частіше раз на minилину
UNKNOWN_ESC := 90000    ; якщо screen not recognised for стільки ms - раз тиснемо Esc (закрити застряглі меню)
LOG_MAX     := 20000000  ; якщо за день лог виріс понад 20 МБ - відкладаємо його в logs\ і починаємо новий
LOGDIR      := A_ScriptDir "\logs\"   ; логи минулих днів: raid_РРРРММДД.log
LOG_DAYS    := 14        ; скільки днів їх тримати
SHOTDIR     := A_ScriptDir "\shots\"   ; скріншоти, коли бій в Infinity обривається сам
SHOT_MAX    := 40      ; скільки останніх скріншотів тримати (старіші видаляються)
READY_SAT := 50       ; насиченість кольору, вище якої скіл вважається готовим (земля під порожнім слотом 5 ~45, готові скіли 55+)
; У персонажа без скіла (наприклад, без 5) слот порожній, і крізь нього видно мапу - на кольоровій землі
; він "готовий" завжди, бот тисне його кожен тік і до інших скілів черга не доходить.
; Тому скіл, що SKILL_FAILS разів поспіль не пішов на перезарядку, пропускаємо SKILL_SKIP ms.
SKILL_FAILS := 3
SKILL_SKIP  := 20000
SKILL_SKIP_SHORT := 3000                 ; для 1-4 (порожнім буває лише слот 5)
; ============================================================

running    := false
busy       := false
comboUntil := 0          ; до якого моменту спамимо скіл комбо
partySince := 0          ; коли з'явився екран PARTY (0 = не видно)
lastCreate := 0          ; коли востаннє тиснули Create на екрані налаштувань
lastFight  := 0          ; коли востаннє бачили напис ENEMIES LEFT
fightSince := 0          ; коли почався поточний бій (0 = не в бою)
infDrop    := false      ; бій в Infinity ended сам - чекаємо лобі, щоб його теж зняти
; лічильник нагород праворуч ("Rewards: 24") читаємо вбудованим OCR Windows (ocr.ps1) у фоні, раз на 5 с
REWARD_BOX := [1560, 640, 360, 120]       ; ділянка з лічильником (з запасом - в RDP інтерфейс дрібніший)
OCR_IN     := A_Temp "\adbot031_ocr.png"
OCR_OUT    := A_Temp "\adbot031_ocr.txt"
ocrPending := 0          ; коли запущено розпізнавання (0 = не чекаємо)
lastOcr    := 0
runTokens  := 0          ; найбільше прочитане значення лічильника за поточний забіг
runKind    := ""         ; "raid" / "infinity" - до чого додати runTokens, коли забіг скінчиться
infLootDone := true      ; токени з екрана результатів Infinity вже прочитані (скидається на Start)
raidShotDone := true     ; екран нагород рейду вже знято (скидається на Start)
lastDmg    := ""         ; останнє прочитане "Damage Until Next Reward"
dmgChanged := A_TickCount ; коли це число востаннє змінилось (= удари влучають у боса)
lastSearch := 0          ; коли востаннє повертали камеру в пошуках боса
farPress   := 0          ; Divine: коли спрацював скіл 1 чи 2 - за 2.5 с має з'явитись Combo, інакше бос далеко
searchTurns := 0         ; скільки поворотів поспіль без влучань
xdimMapNow := ""          ; Extreme Dimension: the map of the run being played (set at Start, kept for RETRY replays)
xdimStartAt := 0         ; Extreme Dimension: when Start was pressed (or the run was retried): the run starts xdimWait s later
routeDone := false       ; dungeon: the recorded route of this run is already played
dimRunAt := 0            ; when the recorded run of this dungeon started (0 - none waiting for RETRY)
dimRetryAt := 0          ; when RETRY was pressed: the next ~15 s are the game reloading the run, not the lobby
retryPending := false    ; RETRY clicked, the results screen not seen gone yet (DimRetry then arms the route)
friendsDone := false     ; Friends Only на цьому екрані налаштувань уже перевірено
sameReads  := 0          ; скільки свіжих читань поспіль показали ту саму шкоду (доказ, що не влучаємо)
; лише для діагностики (на runTokens і статистику не впливають); скидаються на Start
rewardRaw    := ""       ; останнє сире читання лічильника Rewards (до 3 цифр)
rewardReads  := 0        ; скільки таких читань за забіг
rewardRepeat := 0        ; останнє значення, що повторилось двічі поспіль
charIdx      := 1        ; який по порядку персонаж зараз у рейді (1 після старту й ресету, +1 на кожну смерть)
rdChanges    := 0        ; зміни портрета (смерті разом з ресетами) за забіг
rdResetNo5   := 0        ; ресетів без скіла 5 за забіг
rdResetCombo := 0        ; ресетів без Combo за забіг
lastNo5Reset := 0        ; коли востаннє ресетили персонажа без скіла 5
no5Pending   := false    ; портрет змінився після респавну, вже обробленого по відліку: скіли нового персонажа ще треба перевірити
lastLoadoutWarn := 0     ; коли востаннє писали УВАГА про рейд без loadout 1
pickFails := 0, pickFailHour := "", pickMissAt := 0   ; PickRaidByName: misses of this hour's raid (reset in Start)
GEM_KEYS := ["raidGems", "speedGems", "dimGems"], TOKEN_KEYS := ["raidTokens", "speedTokens"]   ; Stats page: all modes together
raidCountAt := -99999999   ; when a raid was last counted (Start press or results screen)
sess := Map("raids", 0, "raidGems", 0, "raidTokens", 0, "speedRuns", 0, "speedGems", 0, "speedTokens", 0, "infRuns", 0, "dimRuns", 0, "dimGems", 0, "restarts", 0)   ; підсумок поточного запуску бота
FIGHT_STICKY := 15000    ; скільки ms після цього ще битися, якщо екран не розпізнано
lastReset  := 0          ; коли востаннє робили Esc-R-Enter
unknownSince := 0        ; відколи екран поспіль не розпізнається (0 = розпізнається)
watchStep  := 0          ; скільки разів поспіль спрацював сторож
raidWalkDue := true      ; на початку бою в рейді ще треба підійти до боса
portraitSig := ""        ; "відбиток" портрета персонажа (лівий верхній кут) - змінюється, коли персонаж гине і виходить наступний
portraitNew := ""        ; новий відбиток, що ще перевіряється на стабільність
portraitSince := 0
lastRestart := 0         ; коли востаннє перезапускали Roblox
noGameSince := 0         ; відколи вікна Roblox немає (0 = є)
wasDead    := false      ; рейд: на екрані відлік "Respawn in N" (персонаж мертвий)
lastRespawnAt := 0       ; коли відлік скінчився (новий персонаж уже на точці появи)
camYaw     := 0          ; на скільки px миші бот повернув камеру від респавну (щоб знати, де знайшовся бос)
afterRespawn := false    ; після респавну Combo ще не було - перший Combo запишемо в лог з кутом
comboSeen  := false      ; у цьому рейді вже бачили напис "N Combo!" (значить, його розпізнавання працює)
lastCombo  := 0          ; коли востаннє бачили "Combo!" (= удари влучають)
lastComboCheck := 0
routeDown := Map()                                       ; keys a recorded run holds now (RouteCleanup releases them on exit too)
routePtrWas := ""                                        ; pointer settings to put back after a recorded run ("" = none changed)
problemNote := "", problemNoted := Map()                 ; ProblemWatch (below Stop): the same trouble again and again
; Safe mode (0.4.0): a mode that keeps failing is paused, the game is restarted, the other modes go on (see SafeRun below)
safePauses := Map(), safePauseAt := Map()                    ; Safe mode: pauses in a row per mode / time of the last pause
safeBan := Map(), safeStrikes := Map(), safeLast := Map()   ; mode -> A_Now until it is paused / strikes in a row / time of the last strike
safePending := "", safeWhy := "", safeWarnKind := ""        ; ProblemWatch asks, Tick does it (never restart the game from inside a log call)
learnLeft  := 0          ; скільки ще навчальних знімків зробити в цьому рейді (raid.ini [raid] learnShots=1)
lastLearn  := 0
walkAt     := 0          ; коли після респавну йти вперед до боса (0 = не треба)
; точки всередині ромба-портрета (підходять і для звичайного екрана, і для дрібнішого RDP-інтерфейсу)
PORTRAIT_PTS := [[74, 115], [86, 127], [98, 139], [86, 108], [86, 146], [74, 139], [98, 115]]
lockUntil  := 0          ; до якого моменту персонаж не може рухатись (анімація скілів 4, 5)
skillFails := Map()      ; скіл -> скільки разів поспіль натиснули без перезарядки
skillSkip  := Map()      ; скіл -> до якого моменту його пропускаємо
castAt     := Map()      ; скіл -> коли пішов на перезарядку (поки знову не готовий)
castExact  := Map()      ; скіл -> castAt точний (натискання бачили), а не оцінка
skillCd    := Map()      ; скіл -> вивчена перезарядка, ms (найменша виміряна)
spreadUsed := Map()      ; Infinity: коли востаннє спрацював кожен скіл зі spread (черга - хто довше чекав)
spreadTry  := 0          ; Infinity: скільки разів поспіль помічник зі spread "не вийшов" (іконка не посіріла)
spreadNext := 0          ; коли можна тиснути наступний скіл зі spread
lastCast   := 0          ; коли востаннє основний скіл справді спрацював (персонаж ще в анімації)
curLoadout := 0          ; який loadout зараз стоїть (0 = невідомо, перевіримо в Bag)
loadoutChecked := false  ; loadout вже прочитано після Start (коли перемикання вимкнене)
OCR2_IN    := A_Temp "\adbot031_ocr2.png"   ; окремі файли для синхронного OCR (асинхронний OCR нагород не заважає)
OCR2_OUT   := A_Temp "\adbot031_ocr2.txt"
OCRQ       := A_Temp "\adbot031_ocrq\"     ; черга запитів до OCR-сервера (див. OcrCall)
ocrPid     := 0                          ; процес OCR-сервера (0 = не запущений)

; ---------------- налаштування з raid.ini (змінюються у вікні й зберігаються одразу) ----------------
cfg := Map(
    "order",      IniRead(INI, "raid", "order", "5 4 3 2 1 e r z x"),   ; спершу баффи (5, 4), потім комбо 3 -> 1
    "comboKey",   IniRead(INI, "raid", "comboKey", "3"),
    "comboSpam",  IniRead(INI, "raid", "comboSpam", "1"),
    "comboMs",    IniRead(INI, "raid", "comboMs", "3000"),
    "combo",      IniRead(INI, "raid", "combo", "1"),
    "m1",         IniRead(INI, "raid", "m1", "1"),
    "raidWalk",   IniRead(INI, "raid", "raidWalk", "3000"), ; на початку рейду пройти вперед до боса, ms
    "lockSkills", IniRead(INI, "raid", "lockSkills", "4 5"),  ; скіли, після яких персонаж якийсь час не рухається
    "lockMs",     IniRead(INI, "raid", "lockMs", "2500"),     ; скільки після них не ходити й не розвертатись
    "assists",    IniRead(INI, "raid", "assists", "e r z x"), ; помічники: тиснуться одразу, як готові
    "spread",     IniRead(INI, "raid", "spread", "5 4 e r x"),  ; Infinity: великі AOE по черзі, з паузою, поки попередній діє (решта - як готові)
    "spreadMs",   IniRead(INI, "raid", "spreadMs", "7000"),       ; скільки діє скіл зі spread - до того не тиснемо наступний, ms
    "spreadDur",  IniRead(INI, "raid", "spreadDur", "5:10"),      ; винятки "клавіша:секунди" (5 діє 10 s left)
    "infBossBurst", IniRead(INI, "raid", "infBossBurst", "0"),    ; Infinity: бос minилі - великі AOE одразу, без пауз
    "infSmall",   IniRead(INI, "raid", "infSmall", "3 z"),        ; Infinity: малі AOE - лише коли великі (spread) на перезарядці і none не діє
    "seekDash",   IniRead(INI, "raid", "seekDash", "1"),          ; Divine: відкинуло -> вперед з Q 3 рази через 0.5 с
    "respawnDash", IniRead(INI, "raid", "respawnDash", "1"),      ; Divine: після респавну до боса теж ривками Q
    "resetThird", IniRead(INI, "raid", "resetThird", "0"),        ; рейд: вийшов 3-й персонаж - ресет (навіть зі скілом 5)
    "resetNo5",   IniRead(INI, "raid", "resetNo5", "0"),        ; рейд: вийшов персонаж без скіла 5 - ресет (Esc-R-Enter)
    ; 29.10 00:00: з ухиленням 3 смерті (як і без), а пауз без влучань 184 с замість ~110 - ухилення вимкнене,
    ; і очі разом з ним (без ухилення їм нема що робити, а в бою з босом вони беруть ~0.8 ядра)
    "raidName",   IniRead(INI, "raid", "raidName", "divine"), ; який рейд створювати: halloween / divine
    "respawnWait", IniRead(INI, "raid", "respawnWait", "3000"), ; після зміни персонажа (смерть) чекати респавн, ms
    ; (29.10 пробував 6000: о 02:02 поворот після респавну вийшов не туди, і бот за 6 с забіг до краю арени -
    ; 161 с без ударів. З 3000 така помилка коштує менше, тож лишаємо 3000)
    "respawnWalk", IniRead(INI, "raid", "respawnWalk", "3000"), ; потім іти вперед до боса, ms (0 = не йти)
    "respawnTurn", IniRead(INI, "raid", "respawnTurn", "95"),   ; якщо бос не прямо попереду - повернути камеру, градусів (+ вправо)
    "infGameAuto", IniRead(INI, "raid", "infGameAuto", "0"),     ; Infinity: the game's Auto fights (like bossAuto); AOE / turn / stuck settings unused
    "bossAuto",   IniRead(INI, "raid", "bossAuto", "1"),         ; Raid / Speed Raid: the game's Auto fights, the bot only keeps it on (0 = old fight logic)
    "speedWalk",  IniRead(INI, "raid", "speedWalk", "2000"),    ; Speed Raid: walk to the boss at the start, ms
    "respawnWalkOther", IniRead(INI, "raid", "respawnWalkOther", "0"),   ; raids without knockback: walk after respawn, ms
    "noComboReset", IniRead(INI, "raid", "noComboReset", "12000"),       ; Divine: no Combo this long -> reset, ms (0 = off)
    "farWalk",    IniRead(INI, "raid", "farWalk", "2500"),      ; Divine: після 1/2 немає Combo -> вперед стільки ms with Q x3 (0 = вимк.)
    "soloRaid",   IniRead(INI, "raid", "soloRaid", "1"),        ; рейд: вмикати Friends Only (соло, без інших гравців)
    "raidCreate", IniRead(INI, "raid", "raidCreate", "0"),      ; рейд: 1 = власна кімната через Create (для рейдів, які мало хто ставить у Group Finder), 0 = Group Finder
    "loadouts",   IniRead(INI, "raid", "loadouts", "1"),     ; міняти loadout: рейд - 1, Infinity або dungeon - 2, Speed Raid - 3
    "dimWait",    IniRead(INI, "raid", "dimWait", "2000"),       ; Dimension: ms to wait after the first enemies are seen, before the run (0 = start at once)
    "dimShift",   IniRead(INI, "raid", "dimShift", "0"),        ; Dimension: start delay, ms - wait this long after the enemies show up
    "dimFight",   IniRead(INI, "raid", "dimFight", "1"),         ; Dimension: normal fight after the run if enemies are left
    "dimMethod",  IniRead(INI, "raid", "dimMethod", "1"),        ; Dimension route: 1 = dimension\giant\log.txt, 2 = built-in route
    "xdim",       IniRead(INI, "raid", "xdim", "0"),             ; Extreme Dimension on/off (0.3.5: only the switch and the 1-4 picker, no run yet)
    "dimName",    IniRead(INI, "raid", "dimName", "giant"),      ; Dimension: giant / halloween / death / demon / ... (DIMS; each keeps its own recordings)
    "xdimWait",   IniRead(INI, "raid", "xdimWait", "15"),        ; Extreme Dimension: seconds to wait after Start before the run (the game loads the map)
    "xdimPick",   IniRead(INI, "raid", "xdimPick", "1"),         ; Extreme Dimension: which of the 4 buttons
    "dimReplayWait", IniRead(INI, "raid", "dimReplayWait", "15"), ; 14.11 (players): Halloween / Death / other recorded Dimensions - seconds after REPLAY before the run (Extreme: xdimWait)
    "dungeon",    IniRead(INI, "raid", "dungeon", "1"),         ; Giant Dimension (Nightmare, Hardcore, Friends Only) instead of Infinity; experimental
    "speed",      IniRead(INI, "raid", "speed", "1"),          ; Speed Raid раз на 30 min (пріоритет: рейд > speed > Infinity)
    "seekAfter",  IniRead(INI, "raid", "seekAfter", "5000"),    ; скільки ms без влучань, щоб почати пошук
    "camSens",    IniRead(INI, "raid", "camSens", "36"),          ; чутливість миші в грі x100 (0.36 -> 36): від неї залежить, на скільки px вести мишу для повороту камери
    "autoAfter",  IniRead(INI, "raid", "autoAfter", "0"),         ; рейд: стільки ms без Combo -> Auto (за замовчуванням вимкнено; детектор Combo бачить і AOE здалека)
    "infAuto",    IniRead(INI, "raid", "infAuto", "15000"),       ; Infinity: число ENEMIES LEFT не змінюється стільки ms -> натиснути Auto (через 5 с ще раз, вимкнути); 0 = вимк.
    "seekWalk",   IniRead(INI, "raid", "seekWalk", "3000"),     ; після повороту пройти вперед, ms
    "skillsOff",  IniRead(INI, "raid", "skillsOff", ""),      ; вимкнені скіли через пробіл
    "interval",   IniRead(INI, "raid", "interval", "120"),
    "startDelay", IniRead(INI, "raid", "startDelay", "10"),
    "startBonus", IniRead(INI, "raid", "startBonus", "110"),    ; PARTY: бонус команди з якого % стартувати, не чекаючи startDelay
    "raid",       IniRead(INI, "raid", "raid", "1"),
    "raidMin",    IniRead(INI, "raid", "raidMin", "0"),           ; minute of the hour when the raid starts (0 = xx:00; 30 for half-hour time zones, see raid_every.ahk)
    "raidEvery",  IniRead(INI, "raid", "raidEvery", "1"),         ; raid only in hours divisible by N (1 = every hour, as before; 3 = 0, 3, 6 ...)
    "infinity",   IniRead(INI, "raid", "infinity", "1"),
    "sfx",        IniRead(INI, "raid", "sfx", "1"),                 ; короткі звуки кнопок
    "music",      IniRead(INI, "raid", "music", "1"),               ; v0.3: music\*.m4a in the compact skin, 1% volume; on/off kept in the ini
    "infStop",    IniRead(INI, "raid", "infStop", "57:30"),      ; о котрій (хв:с) виходити з Infinity
    "infRunMin",  IniRead(INI, "raid", "infRunMin", "0"),        ; Infinity: вийти через стільки хвилин після початку забігу й зайти знову (0 = ні; для швидшого фарму хвиль)
    "createFrom", IniRead(INI, "raid", "createFrom", "59:30"),    ; з котрої (хв:с) тиснути Create у рейді
    "fightOnly",  "0")                                            ; тест: лише скіли (не зберігається)
; що бот востаннє створив ("raid" / "infinity") і в яку годину був рейд - щоб пам'ятати після перезапуску
lastEntered := IniRead(INI, "state", "lastEntered", "")
speedDue := IniRead(INI, "state", "speedDue", "")
try DateDiff(speedDue, A_Now, "Seconds")                  ; a corrupt value would throw on every tick
catch
    speedDue := ""         ; коли Speed Raid знову доступний (yyyyMMddHHmmss)
speedFails := 0                                           ; невдалих спроб Speed Raid поспіль
raidDoneKey := IniRead(INI, "state", "raidDoneKey", "")

if A_Args.Length && A_Args[1] = "fight"                 ; тест бою: лише скіли
    cfg["fightOnly"] := "1"

; ------------------------- Interface (see ui.ahk) -------------------------
#Include update.ahk                 ; 14.11: UPDATE button (new build on GitHub) - before ui.ahk: the HUD reads its variables at once
#Include ui.ahk
#Include auto_boss.ahk
#Include rewards.ahk
#Include raid_every.ahk
#Include summary.ahk
#Include webhook.ahk
#Include watch.ahk

if A_Args.Length                                        ; "start" or "fight" - start at once, without F1
    Start()

#HotIf !updBusy                     ; 14.11: no Start / Stop / Restart while the update copies files (update.ahk)
F1:: Start()
F2:: Stop()
F3:: RestartBot()
#HotIf

SkillOn(key) => true                       ; v0.3: усі скіли завжди активні (skillsOff ігнорується)

RaidTitle() => RAIDS.Has(cfg["raidName"]) ? RAIDS[cfg["raidName"]][3] : "raid"

; чи відкидає бос обраного рейду (тоді потрібні пошук боса і поворот камери після смерті)
Knockback() => lastEntered = "raid" && InStr(KNOCKBACK_RAIDS, " " cfg["raidName"] " ")

; бій з одним босом: рейд або Speed Raid (підхід до боса на старті, Combo, респавн)
BossFight() => lastEntered = "raid" || lastEntered = "speed"

; лічильники в raid.ini [stats]: за сьогодні (обнуляються з новою датою) і за весь час
; a corrupt value in raid.ini must never stop the bot: anything that is not an integer counts as 0
IntOr0(v) => IsInteger(Trim(v)) ? Integer(Trim(v)) : 0

Stat(name, n := 1) {
    m := name = "raids" ? "raid" : name = "dimRuns" ? "dungeon" : name = "speedRuns" ? "speed" : ""
    if m != "" && safeStrikes.Has(m)                        ; Safe mode: a finished run = the mode works again, its problems are forgotten
        safeStrikes.Delete(m)
    today := FormatTime(, "yyyyMMdd")
    if IniRead(INI, "stats", "day", "") != today {
        IniWrite today, INI, "stats", "day"
        for k in ["infRuns", "raids", "raidGems", "raidTokens", "restarts", "speedRuns", "speedGems", "speedTokens", "dimRuns", "dimGems"]
            IniWrite 0, INI, "stats", k
    }
    IniWrite IntOr0(IniRead(INI, "stats", name, "0")) + n, INI, "stats", name
    IniWrite IntOr0(IniRead(INI, "stats", name "Total", "0")) + n, INI, "stats", name "Total"
    if sess.Has(name)
        sess[name] += n
}

StatDay(name) => IniRead(INI, "stats", "day", "") = FormatTime(, "yyyyMMdd") ? IniRead(INI, "stats", name, "0") : "0"

; Stats page and "This run": gems / tokens of all modes together (raid + Speed Raid + Dimension), same as TOTAL in the session summary
SessSum(keys) {
    n := 0
    for k in keys
        n += sess[k]
    return n
}
DaySum(keys) {
    n := 0
    for k in keys
        n += IntOr0(StatDay(k))
    return n
}
TotalSum(keys) {
    n := 0
    for k in keys
        n += IntOr0(IniRead(INI, "stats", k "Total", "0"))
    return n
}


; Читання лічильника нагород: знімаємо ділянку у файл і запускаємо ocr.ps1 у фоні (не чекаючи),
; результат забираємо на наступних тіках. Беремо найбільше правдоподібне значення за забіг.
PollRewards() {
    global ocrPending, lastOcr, runTokens, runKind, lastDmg, dmgChanged, searchTurns, sameReads
    global rewardRaw, rewardReads, rewardRepeat, tokFromScreen
    if runKind = ""
        runKind := lastEntered
    if tokFromScreen {                                   ; tokens already read from the results: a late answer must not set them again
        if ocrPending {
            try FileDelete OCR_OUT
            ocrPending := 0
        }
        return
    }
    if ocrPending {
        if FileExist(OCR_OUT) {
            txt := ""
            try txt := FileRead(OCR_OUT, "UTF-8")
            try FileDelete OCR_OUT
            ocrPending := 0
            if RegExMatch(txt, "i)(?:rewards?|tokens?)\W{0,3}(\d[\d,]*)", &m) {
                v := Integer(StrReplace(m[1], ","))
                ; лічильник росте поступово: відкидаємо явні помилки розпізнавання (стрибок понад 300)
                if v > runTokens && v - runTokens <= 300
                    runTokens := v
            }
            ; діагностика: лише рядок "Rewards N" (до 3 цифр, далі не '.', ',' і не літера); рядки з "Next Reward" відкидаємо окремо
            for ln in StrSplit(txt, "`n", "`r") {
                if RegExMatch(ln, "i)n[e3]xt|until|damage")
                    continue
                if RegExMatch(ln, "i)(?<![a-z])rewards\W{0,3}(\d{1,3})(?![\d.,a-z]|[ \t]+[kmbt]\b)", &r) {
                    if r[1] = rewardRaw
                        rewardRepeat := Integer(r[1])
                    rewardRaw := r[1], rewardReads++
                    break
                }
            }
            ; "Damage Until Next Reward: 225.89M" - якщо це число змінюється, удари влучають у боса
            if RegExMatch(txt, "i)reward:?\s*\R?\s*([\d.,]+\s*[kmbt]?)\s*$", &d) {
                if d[1] != lastDmg
                    lastDmg := d[1], dmgChanged := A_TickCount, searchTurns := 0, sameReads := 0
                else
                    sameReads++
            }
        } else if A_TickCount - ocrPending > 20000 {
            ocrPending := 0                           ; розпізнавання зависло - пробуємо знову
            OcrServerKill()
        }
        return
    }
    if A_TickCount - lastOcr < 1500                     ; у рейді частіше: швидше помічаємо, що не влучаємо
        return
    lastOcr := A_TickCount
    try FileDelete OCR_OUT
    b := REWARD_BOX
    if SaveRegion(OCR_IN, b[1], b[2], b[3], b[4]) = 0 {
        OcrCall(OCR_IN, OCR_OUT, "", false)
        ocrPending := A_TickCount
    }
}

; Які нагороди читати з екрана результатів: [іконка, лічильник у статистиці, назва в лозі]
LOOT := Map(
    "raid", [["raid_gem_icon.png", "raidGems", "gems"], ["raid_token_icon.png", "raidTokens", "tokens"]])

; Екран результатів ("REWARDS"): потрібні нагороди - наприкінці списку. Шукаємо кожну іконку, прокручуючи
; список донизу, і читаємо білу цифру під нею (ocr.ps1 -White лишає тільки білий текст).
ReadLoot(kind) {
    global runTokens, tokFromScreen
    SetStatus("results: reading rewards")
    ParkMouse()
    Sleep 1500                                           ; іконки нагород з'являються по черзі - даємо домалюватись
    todo := []
    for it in LOOT[kind]
        if FileExist(IMGDIR it[1])
            todo.Push(it)
    Loop 4 {                                             ; кілька спроб: іконка ще анімувалась або число не прочиталось
        if A_Index > 1
            Sleep 1200
        i := todo.Length
        while i >= 1 {
            it := todo[i]
            if FindImg(it[1], &tx, &ty, 1200, 300, 1620, 480, "*110") {   ; іконки нагород мерехтять - допуск більший
                n := ReadLootNumber(tx - 18, ty + 62)   ; число - під іконкою зліва
                if n > 0 {
                    Stat(it[2], n)
                    Log(RaidTitle() ": " it[3] " " n)
                    if it[2] = "raidTokens"
                        runTokens := 0, tokFromScreen := true   ; токени рейду вже пораховані з екрана - лічильник з бою не додаємо
                    todo.RemoveAt(i)
                }
            }
            i--
        }
        if !todo.Length
            break
    }
    for it in todo
        Log("  " it[3] ": could not read (icon not found or number not recognised)")
}

; біла цифра під іконкою нагороди (92x30 px від лівого нижнього краю іконки)
; Білий поріг 215; не прочиталось (число трохи сіре чи світиться, 28.10 15:08) - ще раз з м'якшим порогом 175.
; Окремі файли OCR2: асинхронне читання лічильника (OCR_IN/OCR_OUT) може бути ще в черзі.
ReadLootNumber(x, y) {
    if SaveRegion(OCR2_IN, x, y, 92, 32) != 0
        return 0
    for opts in ["-White", "-White -Thresh 175"] {
        OcrCall(OCR2_IN, OCR2_OUT, opts)
        txt := ""
        try txt := FileRead(OCR2_OUT, "UTF-8")
        try FileDelete OCR2_OUT
        if RegExMatch(txt, "\d[\d,]*", &m) && (n := Integer(StrReplace(m[0], ","))) > 0 && n < 1000000 {
            if A_Index > 1
                Log("  number read with a softer threshold: " n)
            return n
        }
    }
    return 0
}

; поворот камери: права кнопка миші затиснута, мишу ведемо на px по горизонталі (мінус - вліво)
RotateCam(px) {
    global camYaw
    camYaw += px
    MouseMove GAME_W // 2, 23 + GAME_H // 2 + 150, 0
    Send "{RButton down}"
    Sleep 60
    n := Max(1, Abs(px) // 60)                           ; дрібними кроками - Roblox краще сприймає
    Loop n {
        DllCall("mouse_event", "uint", 1, "int", px // n, "int", 0, "uint", 0, "ptr", 0)   ; відносний рух
        Sleep 15
    }
    Sleep 60
    Send "{RButton up}"
}

; Friends Only вимкнено: ліва частина перемикача - світлий "повзунок", права - темно-червона доріжка.
; (x, y) - лівий верхній кут кнопки Create; зсуви підходять і для звичайного, і для RDP-масштабу.
FriendsOff(x, y) {
    k := Integer(PixelGetColor(x - 124, y + 25)), t := Integer(PixelGetColor(x - 58, y + 25))
    kr := k >> 16 & 0xFF, kg := k >> 8 & 0xFF, kb := k & 0xFF
    tr := t >> 16 & 0xFF, tg := t >> 8 & 0xFF, tb := t & 0xFF
    return kr > 200 && kg > 110 && kb > 110 && tr > 150 && tg < 110 && tb < 110
}

; Вперед ривками: тримаючи W, Q 3 рази через 0.5 с, решту з ms - звичайним кроком
DashWalk(ms) {
    t0 := A_TickCount
    Send "{w down}"
    Loop 3 {
        if A_Index > 1
            Sleep 500
        Send "{q}"
    }
    Sleep Max(0, ms - (A_TickCount - t0))
    Send "{w up}"
}

; "відбиток" числа під ENEMIES LEFT: кількість, межі й центр червоних пікселів цифри (мерехтіння фону не міняє його);
; "" - число не видно. Число змінилось (вбили ворога) -> відбиток інший.
EnemiesSig() {
    b := ENEMIES_NUM, w := b[3], h := b[4]
    px := GrabPixels(b[1], b[2], w, h)
    n := 0, x0 := w, x1 := -1, sx := 0, sy := 0
    Loop h {
        y := A_Index - 1
        Loop w {
            x := A_Index - 1
            c := NumGet(px, (y * w + x) * 4, "uint")
            if (c >> 16 & 0xFF) > 180 && (c >> 8 & 0xFF) < 130 {
                n++, x0 := Min(x0, x), x1 := Max(x1, x), sx += x, sy += y
            }
        }
    }
    return n < 30 ? "" : (n // 4) "," x0 "," x1 "," (sx // n) "," (sy // n)
}
; Скільки px вести мишу на 45° камери. У грі 0.36 (RDP автора) це 205 px; кут пропорційний чутливості, тож px = 205 * 36 / чутливість x100:
; 0.05 (основний ПК) - 1476 px, 0.52 (тестувальник) - 142 px.
CamPx() => Min(8000, Max(20, Round(205 * 36 / Max(1, Num("camSens", 36)))))

; Напис "N Combo!" (рожеві літери з чорним контуром) - лише поки удари влучають. Точки літер і контуру взяті
; зі знімка 26.10 19:02 (лівий верхній кут слова ~(400, 540)); напис "підстрибує", тому пробуємо зсуви ±12 px.
; На 30 знімках рейду: є Combo - збіг 0.32..1.0, немає - 0 (огляд арени, Infinity - теж 0). Поріг 0.25.
COMBO_ORG := [400, 540]
AUTO_BTN := [738, 852]                                    ; кнопка AUTO над скілами в рейді (автобій гри)
; ENEMIES LEFT: число червоне на темно-червоному, OCR його не читає - порівнюємо відбиток цифри (EnemiesSig)
ENEMIES_NUM := [1842, 846, 48, 36]
lastAuto := 0, autoOffAt := 0                              ; коли тиснули Auto / коли його вимкнути вдруге
COMBO_L := "105,6 100,11 118,12 110,13 108,14 95,15 106,15 49,16 89,16 105,16 43,17 85,17 99,17 110,17 74,18 86,18 96,18 107,18 120,18 66,19 77,19 88,19 98,19 109,19 38,20 56,20 67,20 77,20 88,20 99,20 108,20 32,21 45,21 57,21 69,21 84,21 95,21 102,21 116,21 35,22 46,22 57,22 68,22 79,22 86,22 97,22 104,22 36,23 53,23 65,23 75,23 82,23 9,24 36,24 48,24 64,24 74,24 81,24 21,25 32,25 44,25 55,25 67,25 7,26 25,26 35,26 46,26 57,26 8,27 27,27 34,27 46,27 8,28 15,28 26,28 33,28 7,29 14,29 25,29 9,30"
COMBO_D := "73,0 104,0 83,1 112,1 23,2 93,2 21,3 69,3 21,4 59,4 123,4 44,5 114,5 32,6 104,6 30,7 125,7 83,8 17,9 113,9 42,10 12,11 72,11 14,12 81,12 17,13 92,13 20,14 103,14 16,15 102,15 12,16 72,16 121,16 50,17 115,17 30,18 111,18 17,19 101,19 31,20 122,20 62,21 15,22 92,22 13,23 91,23 119,23 50,24 102,24 121,24 41,25 91,25 110,25 16,26 74,26 93,26 116,26 58,27 77,27 96,27 40,28 63,28 82,28 37,29 56,29 75,29 23,30 42,30 61,30 3,31 30,31 49,31 5,32 24,32 43,32 9,33 28,33 10,34 29,34 19,35"
ComboVisible() {
    static L := ParsePts(COMBO_L), D := ParsePts(COMBO_D)
    w := 160, h := 50
    px := GrabPixels(COMBO_ORG[1] - 14, COMBO_ORG[2] - 6, w, h)
    dy := 0
    while dy <= 10 {                                     ; зсуви -6..+4 від еталона (з запасом ±2 px)
        dx := 2
        while dx <= 26 {                                 ; -12..+12
            if PtsHit(px, w, L, dx, dy, true) && PtsHit(px, w, D, dx, dy, false)
                return true
            dx += 2
        }
        dy += 2
    }
    return false
}

; чи хоча б чверть точок мають колір літер (letter) або контуру; рахуємо з раннім виходом
PtsHit(px, w, pts, ox, oy, letter) {
    need := pts.Length // 4, miss := pts.Length - need
    for p in pts {
        c := NumGet(px, ((p[2] + oy) * w + p[1] + ox) * 4, "uint")
        r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, b := c & 0xFF
        if letter ? (r > 190 && g < 110 && b < 120) : (r < 60 && g < 40 && b < 50) {
            if --need <= 0
                return true
        } else if --miss < 0
            return false
    }
    return false
}

ParsePts(str) {
    pts := []
    for s in StrSplit(str, " ")
        pts.Push(StrSplit(s, ","))
    return pts
}

; ділянка екрана -> пікселі в пам'яті (BGRA, рядки зверху вниз, w*4 байти на рядок) - у рази швидше за PixelGetColor
GrabPixels(sx, sy, w, h) {
    sdc := DllCall("GetDC", "ptr", 0, "ptr")
    mdc := DllCall("CreateCompatibleDC", "ptr", sdc, "ptr")
    hbm := DllCall("CreateCompatibleBitmap", "ptr", sdc, "int", w, "int", h, "ptr")
    old := DllCall("SelectObject", "ptr", mdc, "ptr", hbm, "ptr")
    DllCall("BitBlt", "ptr", mdc, "int", 0, "int", 0, "int", w, "int", h, "ptr", sdc, "int", sx, "int", sy, "uint", 0x00CC0020)
    DllCall("SelectObject", "ptr", mdc, "ptr", old)
    bi := Buffer(40, 0)                                   ; BITMAPINFOHEADER, висота з мінусом = рядки зверху вниз
    NumPut("uint", 40, "int", w, "int", -h, "ushort", 1, "ushort", 32, bi)
    px := Buffer(w * h * 4)
    DllCall("GetDIBits", "ptr", mdc, "ptr", hbm, "uint", 0, "uint", h, "ptr", px, "ptr", bi, "uint", 0)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC", "ptr", mdc)
    DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)
    return px
}

; Бос прямо попереду? Ядро боса (вертикальна золота "капсула") з точки респавну видно рівно по центру
; під смугою HP: x ~955, y 215..265, а обабіч нього - темне. Перевіряємо центри 900..1025: золота в
; смузі 50 px навколо центру > 25%, а в смугах 35..60 px обабіч < 8%. Знімки 26.10: вид з респавну на боса - 0.32,
; ядро зблизька - 1.0, камера повз боса - збігів немає.
; Поріг середини 0.08 (був 0.25): 28-29.10 після респавну "не попереду" було завжди рівно 0.00 (12 разів),
; "попереду" - 0.39..0.63, а 29.10 02:02 бос був попереду з 0.14 - бот повернув камеру і 161 с шукав боса.
; Зблизька ядро широке і заходить на бічні смуги: 29.10 04:08 0.51/0.08 - бос попереду, а бот відвернувся.
; Тож при сильній середині (>= 0.3) бічні смуги можуть бути до чверті від неї.
BossAhead(&score, &cx) {
    x0 := 840, y0 := 215, w := 250, h := 50             ; центри 900..1025 +- 60 px
    px := GrabPixels(x0, y0, w, h)
    col := []                                            ; скільки "золотих" пікселів у кожному стовпчику
    Loop w {
        x := A_Index - 1, n := 0
        Loop h {
            c := NumGet(px, ((A_Index - 1) * w + x) * 4, "uint")
            r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, b := c & 0xFF
            if r > 150 && g > 60 && g < 210 && b < 70 && r - g > 40
                n++
        }
        col.Push(n)
    }
    Sum(a, b) {                                          ; частка золота в стовпчиках [a, b) (from x0)
        t := 0
        Loop b - a
            t += col[a + A_Index]
        return t / ((b - a) * h)
    }
    best := -1, score := 0, cx := 0, ok := false
    c := 900
    while c <= 1025 {
        k := c - x0
        mid := Sum(k - 25, k + 25), side := Max(Sum(k - 60, k - 35), Sum(k + 35, k + 60))
        if mid - 2 * side > best
            best := mid - 2 * side, score := Round(mid, 2) "/" Round(side, 2), cx := c
                , ok := mid > 0.08 && (side < 0.08 || mid >= 0.3 && side <= mid / 4)
        c += 5
    }
    ; the core is a solid upright capsule: some column is gold over most of the strip. 3.11 23:00 the orange hex wall
    ; behind the arena gave 0.15/0.04 (> 0.08) with at most 13 of 50 px per column, the core 39..44 - the bot walked off sideways
    k := cx - x0, top := 0
    Loop 50
        top := Max(top, col[k - 25 + A_Index])
    score .= " col " top
    return ok && top >= 20
}

; забіг скінчився: додаємо прочитані нагороди до сум
FlushRun() {
    global runTokens, runKind, tokFromScreen
    if runKind = "raid" && runTokens > 0 && !tokFromScreen        ; "Rewards: N" counts reward drops, not tokens: log only
        Log("raid: in-fight Rewards counter " runTokens " (not counted as tokens)")
    runTokens := 0, runKind := "", tokFromScreen := false
}

; The setup checks, used by the "Setup check" screen (deep := true also tests the OCR language) and logged at every start.
; Returns [{name, state: "ok"|"warn"|"fail", fix}]. "fail" = the bot cannot work like this; "warn" = may cause trouble.
SetupChecks(deep := false) {
    r := []
    Add := (name, state, fix := "", link := "") => r.Push({name: name, state: state, fix: fix, link: link})
    if deep && !WinExist(GAME)                            ; 8.11: the full check needs the game open: say it first and stop there
        return [{name: "Roblox is not running", state: "fail", fix: "Start Roblox and the game, wait in the lobby (the big PLAY button must be visible), then press Check again."}]
    if A_ScreenWidth = SCR_W && A_ScreenHeight = SCR_H
        Add("Screen resolution " A_ScreenWidth "x" A_ScreenHeight, "ok")
    else if A_ScreenWidth >= SCR_W && A_ScreenHeight >= SCR_H     ; 8.11: the bot is tuned on 1920x1080, other sizes are not tested
        Add("Screen resolution " A_ScreenWidth "x" A_ScreenHeight, "warn", "The bot is tuned for 1920x1080. Should work, but screens may not be recognised. If so: Display settings > Display resolution: 1920 x 1080.", "display")
    else
        Add("Screen resolution is " A_ScreenWidth "x" A_ScreenHeight, "fail", "Right-click the desktop > Display settings > Display resolution: choose 1920 x 1080 or more.", "display")
    MonitorGetWorkArea(MonitorGetPrimary(), &wl, &wt, &wr, &wb)
    cover := 23 + GAME_H - wb                             ; px of the game hidden under a bottom taskbar (scale > 100% on a 1080p screen)
    ; the taskbar decides, not A_ScreenDPI: it is fixed at sign-in, a scale changed inside the session is only seen in the work area
    ; 8.11: the scale of the monitor the game is on, read now (a laptop with a docked monitor: the system DPI said 100%
    ; while the screen was 125%, the bot found no buttons; 100% fixed it for that player)
    dpiNow := 96
    try dpiNow := DllCall("GetDpiForSystem", "uint")
    try {
        gh := WinExist(GAME)
        hm := gh ? DllCall("MonitorFromWindow", "ptr", gh, "uint", 2, "ptr") : DllCall("MonitorFromPoint", "int64", 0, "uint", 1, "ptr")
        if !DllCall("shcore\GetDpiForMonitor", "ptr", hm, "int", 0, "uint*", &mdx := 0, "uint*", &mdy := 0) && mdx
            dpiNow := mdx                                 ; the monitor itself wins over the system value
    }
    scale := Round(dpiNow / 96 * 100) "%"
    if scale = "100%"
        Add("Windows display scale " scale, "ok")
    else
        Add("Windows display scale " scale, "warn", "The bot is tuned for 100%. Set Display settings > Scale to 100%, then sign out and sign in again: with another scale the bot may not find the buttons.", "display")
    ; the taskbar row: a taskbar that hides itself pops up over the bottom of the game when the mouse touches it (ABM_GETSTATE, ABS_AUTOHIDE = 1)
    hidden := false
    try {
        abd := Buffer(48, 0), NumPut("uint", 48, abd)
        hidden := DllCall("shell32\SHAppBarMessage", "uint", 4, "ptr", abd, "uptr") & 1
    }
    if cover > 10                                         ; the r / x skill points are at y 1025: more cover hides them
        Add("The taskbar covers " cover " px of the game", "fail", "Set Display settings > Scale to 100% (then sign out and sign in again), or turn on 'Automatically hide the taskbar'.", "display")
    else if hidden
        Add("Taskbar hides itself (auto-hide is on)", "warn", "It pops up over the game when the mouse touches the bottom edge and can swallow clicks. If the bot misses clicks: Taskbar settings > turn off 'Automatically hide the taskbar'.", "taskbar")
    else if cover > 0
        Add("The taskbar covers " cover " px of the game", "warn", "Should work. If screens are not recognised: Display settings > Scale: 100%, or auto-hide the taskbar.", "taskbar")
    else if wl = 0 && wt = 0 && wr = A_ScreenWidth
        Add("Taskbar at the bottom", "ok")
    else
        Add("Taskbar is not at the bottom", "warn", "Right-click the taskbar > Taskbar settings > Taskbar location on screen: Bottom.", "taskbar")
    if FileExist(A_ScriptDir "\ocr.ps1") && FileExist(IMGDIR "start.png")
        Add("Bot files (ocr.ps1, img folder)", "ok")
    else
        Add("Bot files are missing", "fail", "Unpack the whole archive into one folder: ocr.ps1 and the img folder must lie next to RaidBot.ahk.")
    if deep {
        ; the real ocr.ps1 on a sample image: the same way the bot reads text, so the result is what the bot will get
        out := A_Temp "\adbot031_ocr_test.txt", text := ""
        try FileDelete(out)
        try RunWait('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' A_ScriptDir '\ocr.ps1" "' IMGDIR 'start.png" "' out '" -Scale 1', , "Hide")
        try text := FileRead(out)
        if text != "" && !InStr(text, "ERROR")
            Add("Text recognition (OCR) works", "ok")
        else if text = ""
            Add("Text recognition (OCR) gave no result", "warn", "Add English (United States) in Language & region, restart. Still failing: PowerShell as administrator: Add-WindowsCapability -Online -Name Language.OCR~~~en-US~0.0.1.0", "regionlanguage")
        else
            Add("Text recognition (OCR) failed", "fail", "Add English (United States) in Language & region, restart. Still failing: PowerShell as administrator: Add-WindowsCapability -Online -Name Language.OCR~~~en-US~0.0.1.0", "regionlanguage")
    }
    if hwnd := WinExist(GAME) {
        WinGetClientPos &cx, &cy, &cw, &ch, GAME
        wdpi := 0
        try wdpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
        Log("  setup: Roblox client area " cw "x" ch " at " cx "," cy ", DPI script " A_ScreenDPI " / Roblox window " wdpi ", work area bottom " wb)
        if WinGetMinMax(GAME) = -1
            Add("Roblox is minimised", "fail", "Click the Roblox icon on the taskbar to open it, then maximise the window.")
        else if !(WinGetStyle(GAME) & 0xC00000)
            Add("Roblox is in fullscreen (F11)", "fail", "Press F11 in Roblox to leave fullscreen, then double-click the window title bar to maximise it.")
        else if GameSizeOk(cw, ch)
            Add("Roblox window size is right (" cw "x" ch ")", "ok")
        else if FitGameWindow()                           ; the bot sets the size itself
            Add("Roblox window was set to " GAME_W "x" GAME_H, "ok")
        else
            Add("Roblox window is " cw "x" ch, "fail", "Close Roblox, open it again and press Check again. The bot sets the window size itself.")
        tid := DllCall("GetWindowThreadProcessId", "ptr", hwnd, "uint*", 0, "uint")
        hkl := DllCall("GetKeyboardLayout", "uint", tid, "ptr") & 0xFFFF
        Log("  setup: keyboard layout in Roblox 0x" Format("{:04X}", hkl))
        if (hkl & 0x3FF) != 9 {                           ; ask Roblox to switch to English (US) itself
            PostMessage(0x50, 0, 0x04090409, , "ahk_id " hwnd)
            Sleep 300
            hkl := DllCall("GetKeyboardLayout", "uint", tid, "ptr") & 0xFFFF
            Log("  setup: layout after switch request 0x" Format("{:04X}", hkl))
        }
        if (hkl & 0x3FF) = 9
            Add("Keyboard layout in Roblox is English", "ok")
        else
            Add("Roblox keyboard layout is " Format("{:04X}", hkl), "warn", "Click inside Roblox, press Win+Space until the language shows ENG, then press Check again.")
        if deep {                                         ; 8.11: does the bot really see the game? (the lobby: PLAY button, or the BAG text)
            WinActivate GAME
            try g.Hide()                                  ; the bot window must not cover the game while it looks
            Sleep 600
            seen := SeePlay(&px, &py)
            if !seen {
                Sleep 800
                seen := SeePlay(&px, &py)
            }
            diamond := !seen && PlayDiamond()             ; while the bot window is still hidden
            try g.Show("NA")
            if seen
                Add("The bot sees the game (PLAY button found)", "ok")
            else if diamond {                       ; 9.11: a player had another font / button style: the PLAY picture did not match
                Screenshot("setup_nomatch")
                Add("The PLAY button looks different (another font or button style)", "warn", "The bot finds PLAY by its picture, so a different font, skin or animation can make it miss. After a game restart it presses PLAY at the usual place itself. If it still gets stuck: Send report (the pictures help to add your style) and use the default look of the game.")
            } else {
                Screenshot("setup_nomatch")
                Add("The bot cannot see the game screen", "fail", "Stand in the lobby, close game windows (Esc), Check again. Still failing: Scale 100%, hide the taskbar, lowest graphics, Send report.")
            }
        }
    } else
        Add("Roblox is not running", "fail", "Start Roblox and open the game, wait in the lobby, then press Check again (the full check needs the game open).")
    return r
}

; every start: the same checks go to the log (nothing here stops the bot)
StartupChecks() {
    for it in SetupChecks()
        if it.state != "ok"
            Log("WARNING: " it.name (it.fix != "" ? " - " it.fix : ""))
}

Start() {
    global running, fightSince, infDrop, curLoadout, loadoutChecked, dimRunAt, dimRetryAt, routeDone, dimHandled, pickFails, pickFailHour, pickMissAt, retryPending, xdimStartAt
    global problemNote, problemNoted, safeBan, safeStrikes, safeLast, safePending, safeWarnKind, xdimMapNow, safePauses, safePauseAt
    if IsSet(updBusy) && updBusy                          ; UPDATE is copying the new files: no farming on half-replaced files
        return
    problemNote := "", problemNoted := Map(), xdimMapNow := ""
    safeBan := Map(), safeStrikes := Map(), safeLast := Map(), safePending := "", safeWarnKind := "", safePauses := Map(), safePauseAt := Map()   ; a manual start clears Safe mode
    pickFails := 0, pickFailHour := "", pickMissAt := 0
    xdimStartAt := 0
    dimRunAt := 0, dimRetryAt := 0, routeDone := false, dimHandled := false, retryPending := false   ; 3.11 23:56: a run stopped by F2 left the 2 min timer on - Roblox restart at once on the next start
    if !setupDone {
        Log("Run the Setup check first (press Check in the window)")
        return
    }
    loadoutChecked := false
    fightSince := 0, infDrop := false                 ; бій до зупинки не рахуємо обривом
    curLoadout := 0                                      ; поки бот стояв, loadout могли змінити вручну
    for k in sess                                         ; новий запуск - новий підсумок
        sess[k] := 0
    SessBegin()
    Log("start v" APP_VERSION ", order: " cfg["order"] (cfg["skillsOff"] != "" ? ", disabled: " cfg["skillsOff"] : "")
        . ", loadouts=" cfg["loadouts"] ", raid=" cfg["raid"] ", raidEvery=" RaidEvery() ", infinity=" cfg["infinity"] ", speed=" cfg["speed"]
        . ", soloRaid=" cfg["soloRaid"] ", resetNo5=" cfg["resetNo5"] ", infStop=" cfg["infStop"] (cfg["dungeon"] = "1" ? ", dimStopAt=" Format("{:02}:{:02}", StopSec() // 60, Mod(StopSec(), 60)) : "") ", bossAuto=" cfg["bossAuto"] ", infGameAuto=" cfg["infGameAuto"])
    StartupChecks()
    PlaceId()                                             ; поки гра запущена - запам'ятовуємо, куди перезаходити
    OcrServer()                                         ; OCR-сервер вантажиться заздалегідь
    running := true
    WebhookPost("**AD Bot** " FormatTime(, "HH:mm") " - started")
    WatchdogStart()                                       ; watch.ahk: restarts the bot if it dies or blocks
    PaintRun()
    Layout()
    ; поки бот працює, Windows не засинає і не гасить/не блокує екран (інакше бот бачить чорний екран)
    DllCall("SetThreadExecutionState", "uint", 0x80000003)
    SetTimer(Tick, Max(50, Num("interval", 120)))
    SetTimer(AutoWatch, 150)
}

Stop(showSummary := true) {
    global running
    was := running
    running := false
    Heartbeat()                                           ; "stopped": the watchdog ends instead of starting the bot again
    SetTimer(Tick, 0)
    SetTimer(AutoWatch, 0)
    ReleaseKeys()
    FlushRun()
    if was {
        SessEnd()
        Log(SessLogLine())
        WebhookPost("**AD Bot** " FormatTime(, "HH:mm") " - stopped. " SessLogLine())
    }
    DllCall("SetThreadExecutionState", "uint", 0x80000000)
    PaintRun()
    SetStatus("stopped")
    Layout()
    if was && showSummary {                               ; not after F3 / an error stop
        SummaryShow()
        if problemNote != ""
            ProblemShow()                                 ; the same trouble again and again: the Setup check opens
    }
}

; 8.11: the same trouble again and again is a problem the player should see: it is logged once with a screenshot, and
; after Stop the Setup check opens with a yellow plate (ProblemShow in ui.ahk)
ProblemWatch(text) {
    global problemNote, problemNoted, safePending, safeWhy
    if !IsSet(problemNoted)                               ; a log line during start-up, before the globals exist
        return
    static pats := [["loadout", "i)loadout is not yet|loadout \d failed", 4, "The bot cannot set the loadout: the Bag does not open or the loadout does not change."]
        , ["menu", "i)modes menu: (SPEED RAID|DIMENSION) not visible", 3, "The bot does not find the mode buttons in the PLAY menu."]
        , ["screen", "i)screen not recognised for|screen not recognised, clicking", 2, "The bot does not recognise the game screen."]]
    static hits := Map(), busy := false
    if busy
        return
    if RegExMatch(text, "loadout \d ✓")
        hits["loadout"] := []
    for p in pats {
        if !RegExMatch(text, p[2])
            continue
        list := hits.Get(p[1], [])
        list.Push(A_TickCount)
        while list.Length && A_TickCount - list[1] > 900000        ; (the same trouble counts within 15 min; Safe mode strikes below count within 10 min)
            list.RemoveAt(1)
        hits[p[1]] := list
        if list.Length >= p[3] && !problemNoted.Has(p[1]) {
            problemNoted[p[1]] := true
            problemNote := p[4]
            busy := true
            Log("PROBLEM: " p[4] " (the Setup check opens when you stop the bot)")
            try Screenshot("problem_" p[1])
            if SAFE_MODE && running && safePending = "" {   ; Safe mode: do not wait for the player, Tick closes the game and pauses the mode
                safePending := runGoal != "" ? runGoal : "none", safeWhy := p[4]
                problemNoted.Delete(p[1]), hits[p[1]] := []   ; armed again: the same trouble after the restart counts from zero
            }
            busy := false
        }
        break
    }
}

; ---------------- Safe mode (0.4.0) ----------------
; A problem that shows the yellow plate while the bot is still running (ProblemWatch): the bot does not wait for the player.
; Tick closes the game by itself (RestartRoblox, no minimum gap), pauses the mode that was running (10 min, then 20, 40 ...
; up to 2 h; the count is forgotten after 6 h without a new problem) and goes on with the other modes the player turned on.
; With nothing else left - Infinity with Game AUTO. A manual Start clears everything.
SafeBanned(mode) => safeBan.Has(mode) && DateDiff(safeBan[mode], A_Now, "Seconds") > 0
SafeAny() {
    for m, u in safeBan
        if DateDiff(u, A_Now, "Seconds") > 0
            return true
    return false
}
DimTitle(k := "") {
    k := k != "" ? k : DimKind()
    return k = "xdim" ? "Extreme Dimension" : DIMS.Has(k) ? DIMS[k][1] : "Giant Dimension"
}
SafeName(mode) => mode = "dungeon" ? DimTitle() : mode = "speed" ? "Speed Raid" : mode = "raid" ? "Raid" : mode

SafeRun() {
    global safePending, safeWhy
    mode := safePending, why := safeWhy
    safePending := ""
    ; 14.11: Safe mode closed the game in the middle of a raid (a lobby problem "seen" during the run). The AUTO button exists only
    ; inside a run: a lobby / menu problem cannot be real then - no restart, no strike.
    if RunButtonSeen() {
        Log("SAFE MODE: not restarting - the AUTO button is on screen, a run is going on (" why ")")
        return
    }
    if mode != "" && mode != "none" && mode != "infinity" {     ; Infinity is the way out: it is never paused, only the game is restarted
        ; 10.11 (night log): a ban on the very first problem kept the bot in Infinity all night, though one desync is fixed
        ; by a restart. Now: problems 1 and 2 = only a restart; the 3rd (each within 15 min of the last) = pause 30 / 60 / 120 min.
        ; A finished run of the mode forgets its problems (Stat); the pause count is forgotten after 6 h without one.
        n := safeStrikes.Get(mode, 0)
        if safeLast.Has(mode) && DateDiff(A_Now, safeLast[mode], "Minutes") >= 10   ; 11.11: forgotten after 10 min without a new problem (was 15)
            n := 0
        n++
        safeStrikes[mode] := n, safeLast[mode] := A_Now
        if n < 3 {
            Log("SAFE MODE: " SafeName(mode) " problem " n "/3 - restarting the game only: " why)
        } else {
            b := safePauses.Get(mode, 0)
            if safePauseAt.Has(mode) && DateDiff(A_Now, safePauseAt[mode], "Hours") >= 6
                b := 0
            b++
            safePauses[mode] := b, safePauseAt[mode] := A_Now, safeStrikes[mode] := 0
            mins := Min(30 * (1 << Min(b - 1, 2)), 120)
            safeBan[mode] := DateAdd(A_Now, mins, "Minutes")
            Log("SAFE MODE: " SafeName(mode) " paused for " mins " min (3 problems in a row, pause " b "): " why)
            SetStatus("SAFE MODE: " SafeName(mode) " paused for " mins " min")
        }
    } else
        Log("SAFE MODE: " why " - restarting the game")
    ; 11.11: a raid cut by this restart is not "done": the hour flag (set when the fight began) is cleared so the bot joins the raid again
    ; while the raid window is open (the Safe mode strikes above still pause the mode on the 3rd problem within 10 min)
    global raidDoneKey, fightSince
    if lastEntered = "raid" && fightSince && raidDoneKey != "" {
        raidDoneKey := ""
        IniWrite "", INI, "state", "raidDoneKey"
        Log("SAFE MODE: the raid was cut by the restart - the hour is not marked as done")
    }
    RestartRoblox("safe mode: " why, , 0)
}

; Infinity during Safe mode fights with the game's own Auto (the most simple way, no walking, no skill logic).
; The player's own setting comes back when the pause is over.
SafeAuto(goal) {
    static orig := ""
    want := goal = "infinity" && SafeAny()
    if want && orig = "" {
        orig := cfg["infGameAuto"] = "1" ? "1" : "0"
        cfg["infGameAuto"] := "1"
        Log("SAFE MODE: Infinity with Game AUTO")
    } else if !want && orig != "" {
        cfg["infGameAuto"] := orig
        orig := ""
    }
}

; no recorded run for the chosen Dimension: the bot does not go in - and the player is told (log, Windows toast, yellow plate after Stop)
SafeWarnNoRun(kind := "") {
    global safeWarnKind, problemNote
    kind := kind != "" ? kind : DimKind()
    k := kind = "xdim" ? "xdim_" XdimMap() "_" XdimGameDay() : kind   ; Extreme: once per map and day
    if InStr(safeWarnKind, "|" k "|")                     ; every kind once (Extreme and the plain Dimension can both warn)
        return
    safeWarnKind .= "|" k "|"
    msg := kind = "xdim"
        ? "No recorded run for Extreme: " XdimName(XdimMap()) " (today's map). Extreme is skipped today" (cfg["dungeon"] = "1" ? ", the bot plays " DimTitle() " instead" : "") ". Open Modes > Extreme > Recorder during a " XdimName(XdimMap()) " run to record it."
        : "There is no recorded run for " DimTitle() ", so the bot cannot play it and skips it. Record it on the Dimension page (Edit the run), or turn it off."
    Log("WARNING: " msg)
    problemNote := msg
    try TrayTip(msg, "AD Bot", "Icon!")
}

; відпускаємо клавіші руху (на випадок зупинки посеред патруля чи повороту)
ReleaseKeys() {
    for k in ["w", "a", "s", "d"]
        if GetKeyState(k)
            Send "{" k " up}"
}

; будь-яка помилка - у лог, без вікна помилки (вікно зупинило б бота до ранку)
OnError(LogError)
LogError(e, mode) {
    Log("ERROR: " e.Message " (" e.What ", line " e.Line ")")
    return 1
}

OnExit(BeforeExit)
BeforeExit(*) {
    global running
    running := false
    Heartbeat()                                           ; closed on purpose (window X, F3, a new copy): the watchdog must not start it again
    ReleaseKeys()
    RouteCleanup()                                        ; closed in the middle of a recorded run: mouse buttons, pointer settings
    OcrServerKill()
    DllCall("SetThreadExecutionState", "uint", 0x80000000)
    return 0                                 ; 0 = дозволити вихід (ненульове значення скасувало б вихід)
}

; kind != "" - дрібниця бою (скіл, розворот, патруль...): в Infinity не пишемо в лог по рядку,
; лише рахуємо (див. FightCount); у рейді й Speed Raid пишемо все, як і раніше
SetStatus(text, kind := "") {
    global lastStatus
    quiet := kind != "" && lastEntered = "infinity"
    if quiet
        FightCount(kind)
    if lastStatus = text
        return
    lastStatus := text
    UiSetStatus(text)
    MiniUpdate()
    if !quiet
        Log(text)
}

; Hotbar (the thin strip at the top of the screen while the bot runs): status, time to the hourly raid,
; Speed Raid state and this run's counters. Refreshed on every status change and twice a second.
MiniUpdate() {
    left := RaidLeft()
    sLeft := speedDue ? DateDiff(speedDue, A_Now, "Seconds") : 0
    HotbarDraw(cfg["raid"] = "1" ? ClockTxt(left) : ""      ; Monoline hotbar, both skins
        , cfg["speed"] = "1" ? (sLeft <= 0 ? "ready" : Format("{:02}:{:02}", Min(sLeft, 5999) // 60, Mod(sLeft, 60))) : "", lastStatus)
}

FightLog(kind, text) {
    if lastEntered = "infinity"
        FightCount(kind)
    else
        Log(text)
}

; Infinity: дрібниці бою - раз на minилину одним рядком ("скіл 3 12, розворот 9, ...").
; Без kind - записати накопичене одразу (кінець бою, вихід з Infinity).
FightCount(kind := "") {
    static n := Map(), since := 0
    if kind != "" {
        n[kind] := n.Get(kind, 0) + 1
        if !since
            since := A_TickCount
        if A_TickCount - since < 60000
            return
    }
    s := ""
    for k, v in n
        s .= ", " k " " v
    if s != ""
        Log("Infinity in " (A_TickCount - since) // 1000 " s: " SubStr(s, 3))
    n := Map(), since := 0
}

; Лог за кожен день окремо: щойно настає новий день, учорашній raid.log переїжджає в logs\raid_РРРРММДД.log
; (старші за LOG_DAYS днів видаляються). Якщо за день лог виріс понад LOG_MAX - теж відкладаємо його в logs.
Log(text) {
    static lines := 0, day := ""
    if LOGFILE = ""
        return
    today := FormatTime(, "yyyyMMdd")
    if day != today || Mod(++lines, 2000) = 0 {
        try {
            if FileExist(LOGFILE) {
                fileDay := SubStr(FileGetTime(LOGFILE), 1, 8)
                if fileDay != today || FileGetSize(LOGFILE) > LOG_MAX {
                    DirCreate LOGDIR
                    FileMove LOGFILE, LOGDIR "raid_" fileDay (fileDay = today ? "_" FormatTime(, "HHmm") : "") ".log", 1
                    Loop Files LOGDIR "raid_*.log"
                        if DateDiff(A_Now, A_LoopFileTimeModified, "Days") > LOG_DAYS
                            FileDelete A_LoopFileFullPath
                }
            }
        }
        day := today
    }
    ProblemWatch(text)
    WebhookLog(text)                                      ; Discord webhook (if set): problems / restarts at once
    UiLogPush(text)
    try FileAppend FormatTime(, "dd.MM HH:mm:ss") "." Format("{:03}", A_MSec) "  " text "`n", LOGFILE, "UTF-8"
}

; ----------------------- Головний цикл -----------------------
Tick() {
    global busy, noGameSince, busySince
    if !running || busy
        return
    busy := true, busySince := A_TickCount                ; watch.ahk: one step for 20 min = the bot hung
    try {
        if !WinExist(GAME) {
            if !noGameSince
                noGameSince := A_TickCount
            SetStatus("Roblox not found")
            if A_TickCount - noGameSince > 60000            ; гра закрилась/впала - запускаємо знову
                RestartRoblox("no Roblox window for 60 s")
            return
        }
        noGameSince := 0
        if (frozen := GameFrozen()) != "" {                   ; watch.ahk: Not Responding / the same picture for 3 min
            Log("FREEZE: " frozen)
            RestartRoblox(frozen, , 0)
            return
        }
        if !WinActive(GAME) {
            WinActivate GAME
            Sleep 300
        }
        ; усі координати розраховані на Roblox на весь основний монітор; якщо вікно переїхало
        ; (наприклад, після вимкнення/ввімкнення монітора) - повертаємо його
        WinGetClientPos &cx, &cy, &cw, &ch, GAME
        static fixTries := 0
        if GameSizeOk(cw, ch)
            fixTries := 0
        else if fixTries < 6 {                                ; the same size as the images were captured at
            fixTries++
            SetStatus("fixing the Roblox window size (" cw "x" ch " -> " GAME_W "x" GAME_H ")")
            FixGameWindow()
            return
        } else if fixTries = 6 {
            fixTries++
            Log("WARNING: the Roblox window could not be set to " GAME_W "x" GAME_H " (now " cw "x" ch ") - screens may not be recognised")
        }
        if cx != 0 || Abs(cy - 23) > 2 || cw != GAME_W {     ; on a screen taller than 1080 the window can also slide down
            static badPos := 0, badSince := 0
            if A_TickCount - badSince > 60000
                badPos := 0
            badPos++, badSince := A_TickCount
            if badPos > 4 {                                   ; taskbar on the left/right or a second monitor: moving does not help
                Log("ERROR: the Roblox window cannot be placed at x=0 with width " GAME_W " (client x=" cx ", w=" cw "). Put the taskbar at the bottom.")
                Stop(false)
                MsgBox "Roblox cannot be placed correctly (client x=" cx ", width=" cw ").`n`nPut the Windows taskbar at the bottom of the screen and start the bot again.", "AD Bot", "Icon! T30"
                return
            }
            SetStatus("moving Roblox back to the main monitor")
            FitGameWindow()
            return
        }
        if safePending != "" {                                ; Safe mode asked by ProblemWatch
            SafeRun()
            return
        }
        Step()
    } finally {
        busy := false, busySince := 0
    }
}

; "хв:с" -> секунди від початку години (якщо введено щось не те - def)
MinSec(text, def := 0) {
    try {
        p := StrSplit(Trim(text), ":")
        return Integer(p[1]) * 60 + (p.Length > 1 && p[2] != "" ? Integer(p[2]) : 0)
    } catch
        return def
}

SecOfHour() {
    return RaidMin() * 60 + Integer(A_Sec)
}

; Infinity longer than infRunMin minutes: leave the run (Esc-R-Enter, like for the raid), LEAVE on the results, then Infinity is entered again
InfCycleDue() {
    static loggedFor := 0
    mins := Num("infRunMin", 0)
    if lastEntered != "infinity" || !fightSince || mins <= 0 || A_TickCount - fightSince <= mins * 60000
        return false
    if loggedFor != fightSince {
        loggedFor := fightSince
        Log("Infinity: " mins " min are up - leaving the run, will enter again")
    }
    return true
}

; Second of the hour when the bot leaves Infinity / Giant for the raid
StopSec() {
    return MinSec(cfg["infStop"], 57 * 60 + 30)           ; LEAVE AT: the same for every mode
}

; Куди зараз треба (пріоритет: рейд > Speed Raid > Infinity):
; "raid" (перші minилини години, якщо цієї години рейду ще не було, і з infStop - підготовка),
; "speed" (Speed Raid знову доступний - раз на 30 min), "infinity" (решта часу) або "none" (режими вимкнені - лише бій).
Target() {
    static last := ""
    global runGoal
    static skipKey := ""
    t := PickTarget(&why)
    SafeAuto(t)
    if running
        runGoal := t                                      ; shown by the compact skin
    note := t != "raid" ? RaidSkipNote() : ""             ; raidEvery: this hour has no raid - said once per hour
    hk := RaidKey()
    if note != "" && skipKey != hk {
        skipKey := hk, last := t
        Log("goal: " t " (" note ")")
    } else if t != last {                                 ; every change of the goal is explained in the log
        last := t
        Log("goal: " t " (" why ")")
    }
    return t
}

PickTarget(&why) {
    raidOn := cfg["raid"] = "1" && !SafeBanned("raid")
    infOn := cfg["infinity"] = "1"
    if raidOn && SecOfHour() >= StopSec() && RaidNextOk() {
        why := "the hour is ending, going for the raid" (cfg["dungeon"] = "1" ? " (Giant: last run ends by createFrom-" DIM_LEAD " s)" : "")
        return "raid"
    }
    if raidOn && RaidMin() < RAID_WINDOW && RaidHourOk(RaidHour()) && raidDoneKey != RaidKey() {
        why := "no raid yet this hour"
        return "raid"
    }
    if SpeedReady() {
        why := "Speed Raid is available"
        return "speed"
    }
    speedWhy := cfg["speed"] != "1" ? "Speed Raid is off"
        : speedDue && DateDiff(A_Now, speedDue, "Seconds") < 0 ? "next Speed Raid at " FormatTime(speedDue, "HH:mm")
        : "Speed Raid is not started after minute " SPEED_LAST_MIN " while the raid is on"
    if cfg["xdim"] = "1" && DimKind() != "xdim" && !XdimNearReset()   ; Extreme on, no run for today's map: the plain Dimension plays, the player is told
        SafeWarnNoRun("xdim")
    if (cfg["dungeon"] = "1" || cfg["xdim"] = "1") && !SafeBanned("dungeon") {
        if DimPlayable() {
            why := speedWhy
            return "dungeon"
        }
        ; 9.11 (two players): Halloween / Death / Extreme ship without a run, the HUD there is not recognised and the bot sat in the
        ; dimension for good. No recorded run = not going in (and the player is told); the other modes go on.
        if DimKind() = "xdim" && XdimNearReset()
            speedWhy := "Extreme: near the daily map change (" Mod(XdimIni("xdimResetUtc", "0"), 24) ":00 UTC +-" XdimIni("xdimResetGuard", "60") " min) - skipped"
        else {
            speedWhy := "no recorded run for " DimTitle() " - Dimension skipped, record it on the Dimension page (Edit the run)"
            SafeWarnNoRun()
        }
    }
    if infOn || SafeAny() {                               ; Safe mode: whatever is paused, Infinity is the way out (with Game AUTO, see SafeAuto)
        why := SafeAny() && !infOn ? "Safe mode: the other modes are paused" : speedWhy
        return "infinity"
    }
    why := speedWhy
    if raidOn && !RaidHourOk(RaidHour()) && !RaidNextOk() {
        why := RaidSkipNote()
        return "none"
    }
    return raidOn ? "raid" : "none"
}

; Giant always has a run (built-in); Halloween / Death / Extreme only with the player's own recording
DimPlayable() => DimKind() = "giant" || (DimKind() = "xdim" ? !XdimNearReset() && DimRoute("xdim", true).Length > 0 : DimRoute().Length > 0)

; Speed Raid можна починати: увімкнено, минуло 30 min від минулого, і до рейду встигнемо
; (забіг до 10 min + вхід - після 46-ї minилини не починаємо, якщо рейд увімкнено)
SpeedReady() {
    if cfg["speed"] != "1" || (speedDue && DateDiff(A_Now, speedDue, "Seconds") < 0) || SafeBanned("speed")
        return false
    return cfg["raid"] != "1" || !RaidNextOk() || RaidMin() < SPEED_LAST_MIN
}

; Speed Raid став доступний, а ми в Infinity: вихід з Infinity і повернення коштують ~2.5 min бою.
; Якщо в лобі й так скоро будемо - чекаємо й робимо Speed Raid тоді:
;  - рейд за <= 10 min (з Infinity вийдемо о infStop, Speed Raid - одразу після рейду);
;  - забіг Infinity іде вже 30+ min (сам закінчується на ~38-41 min).
; Довше ніж на 12 min Speed Raid не відкладаємо.
SpeedWait() {
    static noted := "-"
    if speedDue && DateDiff(A_Now, speedDue, "Seconds") > 12 * 60
        return false
    if cfg["raid"] = "1" && RaidNextOk() && StopSec() - SecOfHour() <= 10 * 60
        why := "raid is near - will do it when in the lobby anyway"
    else if fightSince && A_TickCount - fightSince > 30 * 60000
        why := "Infinity ends soon by itself - will do it in the lobby"
    else
        return false
    if noted != speedDue
        noted := speedDue, Log("Speed Raid is available, but " why)
    return true
}

enteredFresh := false      ; true once THIS session entered a mode itself (lastEntered from raid.ini may be old: the bot was started inside something else)
SetEntered(what) {
    global lastEntered, enteredFresh
    lastEntered := what, enteredFresh := true
    IniWrite what, INI, "state", "lastEntered"
}

; Кожен тік визначаємо, що на екрані, і робимо один відповідний крок.
Step() {
    global partySince, lastCreate, lastFight, lastReset, raidDoneKey, unknownSince, watchStep, raidWalkDue, friendsDone, routeDone, dimRunAt, raidCountAt, realFightAt
    global fightSince, infDrop, portraitSig, walkAt, infLootDone, lastDmg, dmgChanged, searchTurns, raidShotDone, sameReads, learnLeft, comboSeen, lastCombo, lastComboCheck, camYaw, afterRespawn, wasDead, lastRespawnAt, farPress, lastSearch, lastAuto, autoOffAt
    global autoOffAt, charIdx, rewardRaw, rewardReads, rewardRepeat, rdChanges, rdResetNo5, rdResetCombo, lastNo5Reset, lastLoadoutWarn, no5Pending
    global dimHandled                        ; was local here: the reset at the route start never reached DimRetry (only the 1st run per Start was counted/read)
    RewardsPoll()                           ; Dimension gem number read in the background
    prevUnknown := unknownSince              ; скидається на кожному тіку, де екран розпізнано
    unknownSince := 0
    if !prevUnknown
        watchStep := 0
    if cfg["fightOnly"] = "1" {
        Fight()
        return
    }
    goal := Target()
    ; Infinity: second fight signal - the red AUTO in the HUD; with the game's Auto on, its AUTO ON look too (a RETRY seen
    ; there on the results is harmless: LeaveInfinity handles the results before any fight code)
    col := lastEntered = "infinity" ? AutoBtnByColour() : ""   ; 14.11: the colours too, so outdated pictures do not cut an Infinity run
    autoOff := lastEntered = "infinity" && (AutoOffVisible() || col = "off" || cfg["infGameAuto"] = "1" && (AutoOnVisible() || col = "on"))
    static autoOffLogged := false, skipLogAt := 0
    if !fightSince && !autoOff
        autoOffLogged := false
    b := ENEMIES_BOX
    ; бій: шукаємо лише червоні літери ENEMIES LEFT (фон ромба напівпрозорий, тому він "прозорий" у картинці)
    ; в еталоні лише насичено-червоні пікселі літер: краї літер змішуються з фоном і різняться від мапи до мапи
    h := ENEMIES_HOME
    inFight := FindImg("enemies_left.png", &x, &y, h[1] - 12, h[2] - 12, h[1] + 66, h[2] + 38, "*80 *TransFF00FF")
        || FindImg("enemies_left.png", &x, &y, b[1], b[2], b[3], b[4], "*80 *TransFF00FF")
    ; виходимо з Infinity на рейд, а ми вже в лобі (видно PLAY): це не бій. 29.10 22:00 і 23:00 бот після LEAVE
    ; у лобі 12 min тиснув Esc-R-Enter - на меню Esc хибно "бачив" ENEMIES LEFT, "липкий" бій не закінчувався
    ; 4.11: also after a dungeon - F3 in the lobby with lastEntered=dungeon "saw" ENEMIES LEFT and waited for the giants there
    lobbyChk := (lastEntered = "infinity" && goal != "infinity" || lastEntered = "dungeon" || cfg["bossAuto"] = "1" && BossFight()) && (inFight || A_TickCount - lastFight < FIGHT_STICKY)
    ; 11.11 17:05 and 14:08: PLAY / the mode cards were "seen" in the middle of a raid (AUTO ON, boss alive), the raid was cut in pieces,
    ; the bot went for Dimension, found no menu and Safe mode closed the game. The AUTO button exists only inside a run: it is never the lobby.
    autoRun := cfg["bossAuto"] = "1" && BossFight() && RunButtonSeen()
    if lobbyChk && (autoOff || autoRun) {
        if A_TickCount - skipLogAt > 60000
            skipLogAt := A_TickCount, Log("lobby check skipped: AUTO button visible (" (autoRun ? "raid" : "Infinity") ")")
    } else if lobbyChk && SeePlay(&px, &py) {
        if inFight || A_TickCount - lastFight < FIGHT_STICKY - 1000
            SetStatus("lobby (PLAY visible) - not a fight, not pressing Esc-R-Enter")
        inFight := false
        lastFight := A_TickCount - FIGHT_STICKY
    }
    if inFight
        realFightAt := A_TickCount                        ; the raw ENEMIES LEFT match (RunButtonSeen trusts the AUTO colours while fights are seen)
    inFight := AutoRunOn(inFight)                         ; bossAuto: the raid / Speed Raid run stays one fight
    if !inFight && autoOff {
        inFight := true
        if !autoOffLogged
            autoOffLogged := true, Log("fight: AUTO-off visible, ENEMIES LEFT not matched (Infinity)")
    }
    if inFight {
        partySince := 0
        lastFight := A_TickCount
        if !fightSince {
            fightSince := A_TickCount
            AutoReset()                                       ; Auto is off again after a teleport / new run
        }
        infDrop := false
        if lastEntered = "raid" && raidDoneKey != RaidKey() {
            raidDoneKey := RaidKey()             ; цієї години рейд уже є
            IniWrite raidDoneKey, INI, "state", "raidDoneKey"
        }
    }
    ; екран результатів Infinity ("REWARDS"): токени - останній пункт списку, читаємо їх один раз
    ; inFight can still be true here: the dim "ENEMIES LEFT" HUD shows under the results (1.11 22:08: gems and tokens were
    ; not read, the bot took 83 tokens from the in-fight counter instead of 274), so the results are searched during the fight too, once a second
    static lastRes := 0
    if !infLootDone && lastEntered = "raid" && A_TickCount - lastRes >= (inFight ? 1000 : 0) {
        lastRes := A_TickCount
        if FindImg("raid_results.png", &x, &y, 300, 120, 900, 260) {
            infLootDone := true
            ; 12.11: since 10:00 this title is seen before the bossAuto card check - the old ReadLoot found nothing and the raid was not counted
            if !RewardCards("raid")
                ReadLoot("raid")
            return
        }
    }
    ; ще до "липкого" бою (FIGHT_STICKY 15 s left): гра сама телепортує саме через ~15 с, тож пізніше LEAVE вже не встигнути
    ; і навіть коли ENEMIES LEFT "видно" (тьмяний HUD під екраном результатів): інакше Esc-R-Enter виходу на рейд
    ; тисне Enter = RETRY (29.10 21:57: після LEAVE новий забіг, 12 min у Infinity і пропущений рейд 22:00)
    ; no RETRY 2 min after the run started (a run takes ~47 s to the results): stuck somewhere - join again
    if lastEntered = "dungeon" && dimRunAt && A_TickCount - dimRunAt > (DimKind() = "xdim" ? 600000 : 120000) {
        dimRunAt := 0
        Screenshot("dim_noretry")
        RestartRoblox("Dimension: no RETRY 2 min after the run started", , 60000)
        return
    }
    ; results first: the dim ENEMIES LEFT HUD shows under them too, and the route must not start there
    ; 10.11 20:33: RETRY pressed, the game froze on results with only LEAVE (routeDone was cleared by then) - the screen was
    ; not recognised for 20 s: look at the results again (DimRetry restarts the game; 12.11: no LEAVE press, it never helped)
    if lastEntered = "dungeon" && (routeDone || prevUnknown && A_TickCount - prevUnknown > 20000) && DimRetry()
        return
    if (lastEntered = "infinity" || lastEntered = "dungeon") && LeaveInfinity()
        return
    ; dungeon: the first fight frame starts the recorded route (blocks until it is played); after it the normal fight
    ; goes on if anything is left. Every results screen re-arms it, so a retried run (by the bot or the game) walks again
    if (xdimStartAt || DimKind() != "xdim" && inFight) && lastEntered = "dungeon" && !routeDone {   ; Extreme / a replayed Halloween-Death run: the timer, not the HUD
        routeDone := true, dimRunAt := A_TickCount, dimHandled := false
        RunRoute(DimRoute())
        return
    }
    ; big "TELEPORT" in the middle for 10+ s after the run: a mob was missed and the way on stays shut - a reset does
    ; not help there, only joining Roblox again
    if inFight && lastEntered = "dungeon" && routeDone && DimStuck()
        return
    if inFight && lastEntered = "dungeon" && cfg["dimFight"] != "1" {
        SetStatus("Dimension: run done, no fight after it (Dimension settings)")
        return
    }
    if inFight || A_TickCount - lastFight < FIGHT_STICKY {
        if inFight && BossFight() {
            if lastEntered = "raid"
                PollRewards()                        ; лічильник праворуч: нагороди й шкода по босу
            ; "N Combo!" зліва від центру - миттєвий знак, що удари влучають (OCR шкоди повільний, 5+ с на читання)
            if A_TickCount - lastComboCheck >= 500 && cfg["bossAuto"] != "1" {
                lastComboCheck := A_TickCount
                if ComboVisible() {
                    if A_TickCount - lastCombo > 3000
                        Log("  Combo: hitting" (lastCombo ? " (none for " (A_TickCount - lastCombo) // 1000 " s left)" : ""))
                    if afterRespawn {                            ; для підбору respawnTurn: де після респавну був бос
                        afterRespawn := false
                        Log("  boss found after respawn: camera " Round(camYaw / CamPx() * 45) "° from respawn")
                    }
                    comboSeen := true, lastCombo := A_TickCount
                    dmgChanged := A_TickCount, searchTurns := 0, sameReads := 0
                }
            }
        }
        ; рейд скінчився (ENEMIES LEFT зник на 3+ s left) - знімаємо екран нагород у папку shots
        if !inFight && !raidShotDone && BossFight() && fightSince && A_TickCount - lastFight > 3000 {
            raidShotDone := true
        }
        ; bossAuto: the game's Auto fights; no skills, combo, walks, turns, resets - only keep Auto on and wait for the end
        if cfg["bossAuto"] = "1" && BossFight() {
            static lastCard := 0, lastDc := 0
            if A_TickCount - autoSeen > 10000 && A_TickCount - lastDc >= 10000 {    ; no sign of the run for 10 s: lost connection?
                lastDc := A_TickCount
                if Disconnected() {
                    RestartRoblox("connection lost", , RESTART_GAP_DC)
                    return
                }
            }
            if !infLootDone && A_TickCount - lastCard >= 1000 {       ; REWARDS panel: gems and tokens
                lastCard := A_TickCount
                if RewardCards(lastEntered) {
                    infLootDone := true
                    return
                }
            }
            if lastEntered = "speed" && SpeedLeave()        ; 14.11: LEAVE at once instead of the ~15 s teleport countdown
                return
            if !raidShotDone && autoBtnAt && A_TickCount - autoBtnAt > 3000 {    ; the Auto button is gone: the end screen is up
                raidShotDone := true
            }
            if inFight && autoOnLogged && RespawnScreen()      ; 14.11: the countdown at the start of a raid looks the same - before Auto is on, keep pressing it
                SetStatus("death: waiting for respawn (Auto stays on)")
            else {
                if A_TickCount - fightSince > 500                 ; 14.11 (player: "~15 s until Auto is pressed"): was 2 s
                    AutoEnsure()
                SetStatus((lastEntered = "speed" ? "Speed Raid" : "raid") ": Auto, waiting for the end")
            }
            return
        }
        ; час іти в рейд (чи в Speed Raid), а ми в Infinity -> скидаємо персонажів (Esc, R, Enter), поки данж не закінчиться
        infCycle := InfCycleDue()
        if lastEntered = "infinity" && (goal = "raid" || goal = "speed" && !SpeedWait() || infCycle) {
            FightCount()
            if A_TickCount - lastReset >= RESET_EVERY {
                SetStatus("leaving Infinity (" (infCycle && goal = "infinity" ? "run time is up" : goal = "speed" ? "Speed Raid" : "raid") "): Esc-R-Enter")
                ; Roblox пропускає надто короткі натискання, поки меню анімується -> тримаємо кожну клавішу довше
                HoldKey("Esc")
                Sleep 1000
                HoldKey("r")
                Sleep 800
                HoldKey("Enter")
                lastReset := A_TickCount
            }
            return
        }
        ; Infinity with the game's Auto: no skills, AOE, turns or walks - only keep Auto on (as in the raid)
        if lastEntered = "infinity" && cfg["infGameAuto"] = "1" {
            if inFight && autoOnLogged && RespawnScreen()      ; 14.11: the countdown at the start of a raid looks the same - before Auto is on, keep pressing it
                SetStatus("death: waiting for respawn (Auto stays on)")
            else {
                if inFight && A_TickCount - fightSince > 500             ; 14.11: was 2 s (players: Auto pressed late)
                    AutoEnsure()
                SetStatus("Infinity: Auto, game fights")
            }
            return
        }
        ; Відлік "Respawn in N": персонаж мертвий - Combo немає, але це не промах. Камеру не крутимо, скілів не тиснемо.
        ; Відлік скінчився -> новий персонаж на точці появи: одразу перевірка напрямку й підхід до боса.
        if BossFight() {
            if RespawnScreen() {
                if !wasDead {
                    Log("death: Respawn countdown")
                    charIdx++                       ; 02.11 06:05: дві смерті за 5 с дали одну зміну портрета - 3-й персонаж бився без ресету
                }
                wasDead := true, dmgChanged := A_TickCount, sameReads := 0, walkAt := 0
                SetStatus("death: waiting for respawn, not pressing skills")
                return
            }
            if wasDead {
                wasDead := false, lastRespawnAt := A_TickCount
                walkAt := A_TickCount + 1500                ; дати персонажу з'явитись
            }
        }
        ; смерть: гра виводить наступного персонажа на точку появи -> після респавну знову йдемо до боса
        if inFight
            CheckRespawn()
        ; 31.10 16:03: перевірка після відліку Respawn йде через 1.5 с, а панель скілів ще від попереднього персонажа
        ; (скіл 5 є) - третій без скіла 5 не ресетився і бився до кінця. Портрет змінюється через ~4 с - тоді перевіряємо ще раз.
        if no5Pending {
            no5Pending := false
            if inFight && lastEntered = "raid" && NeedReset() {
                ResetNo5()
                return
            }
        }
        ; після смерті скілів не тиснемо, поки не повернулись до боса й не підійшли (інакше б'ємо в порожнечу)
        if inFight && walkAt && A_TickCount < walkAt {
            SetStatus("death: waiting for respawn, not pressing skills")
            return
        }
        if inFight && walkAt && A_TickCount >= walkAt {
            walkAt := 0
            ; третій персонаж (без скіла 5) у рейді б'є слабко - одразу ресет (Esc-R-Enter), знову вийде перший
            ; (кожен ресет коштує ~23 с без шкоди: відлік смерті + шлях до боса; resetNo5=0 - не ресетити)
            if lastEntered = "raid" && NeedReset() {   ; у Speed Raid персонаж один - ресет не допоможе
                ResetNo5()
                return
            }
            ; Divine (відкидає) - поворот і respawnWalk. Інші: гра після смерті розвертає камеру від боса,
            ; тож не ходимо - стоїмо й б'ємо скілами (28.10, Shiro)
            ms := Min(Knockback() ? Num("respawnWalk", 3000) : Num("respawnWalkOther", 0), 10000)
            if ms > 0 {
                camYaw := 0, afterRespawn := true
                ; після респавну камера або дивиться прямо на боса, або ~95° лівіше (26.10) - перевіряємо по ядру боса
                if !Knockback() {                           ; інші рейди: бос прямо перед точкою появи
                    deg := 0
                } else if BossAhead(&sc, &cx) {
                    deg := 0
                    Log("  boss straight ahead after respawn (core x=" cx ", " sc ")")
                } else if deg := Num("respawnTurn", 95) {
                    Log("  boss not ahead after respawn (best " sc ") - turning camera")
                    RotateCam(Round(deg / 45 * CamPx()))
                }
                SetStatus("after respawn: camera " (deg > 0 ? "+" : "") deg "°, walking to the boss " ms " ms")
                ; Divine: від точки появи до боса далеко - звичайним кроком перший Combo був лише через ~11 с
                ; після респавну (29.10 00:00), тож теж ривками Q, як після відкидання
                if Knockback() && cfg["respawnDash"] = "1"
                    DashWalk(ms)
                else
                    HoldKey("w", ms)
                return
            }
        }
        ; бос у рейді стоїть за кілька метрів попереду -> на початку бою підходимо до нього
        if inFight && raidWalkDue && BossFight() {
            raidWalkDue := false
            ms := Min(lastEntered = "speed" ? Num("speedWalk", 2000) : Num("raidWalk", 3000), 10000)
            if ms > 0 {
                SetStatus((lastEntered = "speed" ? "Speed Raid" : "raid") ": walking to the boss " ms " ms")
                HoldKey("w", ms)
            }
            if lastEntered = "speed" {                       ; Speed Raid: одразу після підходу - уся серія
                SpeedOpener()
                return
            }
            return
        }
        ; Divine: скіл 1 чи 2 спрацював, а Combo за 2.5 с так і не з'явився (до 0.8 с після натискання - ще
        ; старий напис) -> відкинуло від боса: вперед з Q x3 (користувач, 29.10). Коротко (farWalk 1500): 3 с з ривками
        ; проносили крізь боса (29.10 16:04). Давніше 4 с (смерть) - не рахуємо.
        if inFight && farPress && A_TickCount - farPress >= 2500 {
            p := farPress, farPress := 0
            if lastEntered = "raid" && Knockback() && (ms := Num("farWalk", 1500)) > 0 && A_TickCount - p < 4000
                    && lastCombo < p + 800 && A_TickCount - lastSearch > 3000 {
                SetStatus("skill 1/2 without Combo - knocked back, forward with Q")
                Log("  skill 1/2 without Combo - forward " ms " ms with Q x3")
                DashWalk(Min(ms, 10000))
                lastSearch := A_TickCount
                return
            }
        }
        ; Auto (the game's own auto-battle): no Combo for autoAfter ms (knocked away from the boss) -> press AUTO,
        ; 5 s later press it again to turn it off. The screenshot shows where the boss was.
        if inFight && autoOffAt && A_TickCount >= autoOffAt {
            autoOffAt := 0
            Log("  Auto: off")
            ClickXY(AUTO_BTN[1], AUTO_BTN[2])
            ParkMouse()
        }
        if inFight && lastEntered = "raid" && Knockback() && comboSeen && !autoOffAt && (ms := Num("autoAfter", 20000)) > 0
                && A_TickCount - Max(lastCombo, fightSince, lastRespawnAt) > ms && A_TickCount - lastAuto > ms {
            lastAuto := A_TickCount, autoOffAt := A_TickCount + 5000
            Log("  no Combo for " (A_TickCount - Max(lastCombo, fightSince, lastRespawnAt)) // 1000 " s - Auto on for 5 s")
            SetStatus("no Combo - Auto for 5 s")
            Screenshot("no_combo")
            ClickXY(AUTO_BTN[1], AUTO_BTN[2])
            ParkMouse()
            return
        }
        ; Infinity: a far enemy stands still, so the ENEMIES LEFT number does not change for infAuto ms (any count) ->
        ; press AUTO (the game walks to the enemies), 5 s later press AUTO again to turn it off.
        static lastEn := 0, sameSince := 0, lastSig := ""
        if !inFight || lastEntered != "infinity"
            sameSince := 0, lastSig := ""
        else if (ms := Num("infAuto", 15000)) > 0 && !autoOffAt {
            if A_TickCount - lastEn >= 1000 {
                lastEn := A_TickCount
                sig := EnemiesSig()
                if sig != "" && sig != lastSig
                    lastSig := sig, sameSince := A_TickCount
            }
            if sameSince && A_TickCount - sameSince >= ms && A_TickCount - lastAuto > ms {
                lastAuto := A_TickCount, autoOffAt := A_TickCount + 5000, sameSince := 0, lastSig := ""
                Log("  Infinity: ENEMIES LEFT did not change for " ms // 1000 " s - Auto on for 5 s")
                SetStatus("enemies are not dying - Auto for 5 s")
                ClickXY(AUTO_BTN[1], AUTO_BTN[2])
                ParkMouse()
                return
            }
        }
        ; Divine: Combo немає noComboReset ms (from останнього Combo, старту бою чи респавну) - бос загубився.
        ; Не шукаємо (біг уперед і повороти камери проносили крізь боса і до краю арени, 29.10 16:04 - 100 с
        ; без шкоди), а ресет (Esc-R-Enter): після респавну бот сам іде до боса (користувач, 29.10)
        if inFight && lastEntered = "raid" && Knockback() && comboSeen && (ms := Num("noComboReset", 12000)) > 0
                && A_TickCount - Max(lastCombo, fightSince, lastRespawnAt) > ms {
            Log("  no Combo for " (A_TickCount - Max(lastCombo, fightSince, lastRespawnAt)) // 1000 " s - resetting character")
            SetStatus("no Combo - reset: Esc-R-Enter")
            Screenshot("no_combo_reset")                  ; where the character was when it lost the boss
            rdResetCombo++, charIdx := 0
            HoldKey("Esc")
            Sleep 1000
            HoldKey("r")
            Sleep 800
            HoldKey("Enter")
            lastRespawnAt := A_TickCount                  ; поки гра покаже відлік - не ресетити вдруге
            return
        }
        ; у бою (або щойно, поки спалах ховає напис) меню не шукаємо: на спалахах можливі хибні збіги кнопок
        Fight()
        return
    }
    ; бій щойно скінчився. В Infinity сам він не закінчується, тож якщо ми не виходили через
    ; Esc-R-Enter - команда загинула або гра викинула: пишемо в лог і знімаємо екран (поразка, дисконект)
    if fightSince {
        if lastEntered = "infinity" && A_TickCount - lastReset > 60000 {
            s := (lastFight - fightSince) // 1000
            Log("Infinity ended by itself: fight lasted " s // 60 ":" Format("{:02}", Mod(s, 60))
                . ", ENEMIES LEFT gone " (A_TickCount - lastFight) // 1000 " s ago")
            Screenshot("inf_end")
            infDrop := true
        }
        if BossFight() && lastFight > fightSince {            ; скільки тривав бій з босом - видно, чи зміни допомагають
            s := (lastFight - fightSince) // 1000
            Log((lastEntered = "speed" ? "Speed Raid" : RaidTitle()) ": fight lasted " s // 60 ":" Format("{:02}", Mod(s, 60)))
            ; 12.11: Group Finder raids have no Start press and the results icon is not matched any more - count the raid at the fight end (once per 20 min)
            if lastEntered = "raid" && A_TickCount - raidCountAt > 20 * 60000
                Stat("raids"), raidCountAt := A_TickCount
            if lastEntered = "raid"
                Log("  Rewards " (rewardRepeat ? rewardRepeat : "?") " (raw " (rewardRaw != "" ? rewardRaw : "?") ", reads " rewardReads "), loadout " curLoadout
                    . ", deaths+resets " rdChanges ", resets " (rdResetNo5 + rdResetCombo) " (no 5: " rdResetNo5 ", no Combo: " rdResetCombo ")")
            ; відлік наступного Speed Raid гра починає з перемоги (lastFight - останній кадр бою), а не зі старту
            if lastEntered = "speed" {
                SpeedLater(SPEED_EVERY + 15 - SinceFight() // 1000)
                Log("  next Speed Raid at " FormatTime(speedDue, "HH:mm:ss"))
            }
        }
        FlushRun()
        FightCount()
        fightSince := 0
    }
    ; after RETRY the screen changes for a few seconds; lobby / menu pictures seen then must not send the bot to the
    ; Bag or the modes menu (3.11 20:33 and 20:36: "loadout 2" and "closing the menu" right after RETRY)
    if lastEntered = "dungeon" && A_TickCount - dimRetryAt < 15000 {
        SetStatus("Dimension: RETRY pressed, waiting for the run")
        return
    }
    if goal = "none" {                                                    ; режими вимкнені: меню не чіпаємо
        SetStatus("modes disabled, waiting for a fight")
        return
    }
    ; 14.11 (a raid closed by the bot): everything below acts on lobby / menu / party pictures - loadout, Bag, PLAY, the modes menu,
    ; Create, Halloween, blind clicks, restarts. The AUTO button exists only inside a run, so with it on screen any such picture is a
    ; false hit: wait. (RunButtonSeen stops trusting the colours after 10 min with no fight seen - the bot cannot get stuck here.)
    if RunButtonSeen() {
        static inRunLogAt := 0
        if A_TickCount - inRunLogAt > 60000
            inRunLogAt := A_TickCount, Log("in a run (AUTO button on screen) - no lobby / menu actions, waiting")
        SetStatus("in a run (AUTO button visible) - waiting")
        return
    }
    if FindImg("update_logs.png", &x, &y, 200, 150, 900, 520) {                               ; вікно "UPDATE LOGS" після оновлення гри
        SetStatus("closing UPDATE LOGS window")
        ClickXY(x + UPDATE_LOGS_X[1], y + UPDATE_LOGS_X[2])
        ParkMouse()
        Sleep 1000
        return
    }
    if FindImg("start.png", &x, &y) {                                     ; екран PARTY
        if !partySince
            partySince := A_TickCount
        delay := lastEntered = "raid" && cfg["soloRaid"] != "1" ? Num("startDelay", 10) * 1000 : 0    ; solo mode (Friends Only on): nobody can join - start at once
        left := delay - (A_TickCount - partySince)
        ; гравці вже набрались ("Team Damage Bonus: + 110%" - максимум) - далі чекати нема чого
        if left > 0 && PartyBonus() >= Num("startBonus", 110) {
            Log("  PARTY: team bonus +" PartyBonus() "% - Start now (" Ceil(left / 1000) " s left)")
            left := 0
        }
        if left > 0 {
            SetStatus("PARTY, Start in " Ceil(left / 1000) " s")
            return
        }
        SetStatus("pressing Start")
        FlushRun()                                                        ; попередній забіг - у суми
        infLootDone := false, raidShotDone := false
        lastDmg := "", dmgChanged := A_TickCount, searchTurns := 0, sameReads := 0   ; новий бій - шкоду рахуємо заново
        Stat(lastEntered = "raid" ? "raids" : lastEntered = "dungeon" ? "dimRuns" : "infRuns")                ; ще один забіг у статистику
        if lastEntered = "raid"
            raidCountAt := A_TickCount                                    ; counted here: the results screen must not count it again
        raidWalkDue := true                                              ; у новому бою знову підійдемо до боса
        AutoReset()
        learnLeft := 30, comboSeen := false, lastCombo := 0
        portraitSig := "", walkAt := 0                                    ; новий бій - портрет запам'ятаємо заново
        rewardRaw := "", rewardReads := 0, rewardRepeat := 0              ; діагностичні лічильники рейду - заново
        charIdx := 1, autoOffAt := 0, rdChanges := 0, rdResetNo5 := 0, rdResetCombo := 0, lastNo5Reset := 0, no5Pending := false
        routeDone := false
        ClickImg("start.png", x, y)
        ParkMouse()
        partySince := 0
        Sleep 3000
        return
    }
    partySince := 0
    if FindImg("create_final.png", &x, &y) {                              ; налаштування рейду / данжу
        if lastEntered = "dungeon" && goal = "dungeon" && !friendsDone {  ; set the options first, never press Create with wrong ones
            friendsDone := DungeonSetup(x, y)
            return
        }
        ; соло-рейд: toggle Friends Only - ліворуч від кнопки Create, у тому ж рядку
        if lastEntered = "raid" && cfg["soloRaid"] = "1" && !friendsDone {
            friendsDone := true
            if FriendsOff(x, y) {
                SetStatus("enabling Friends Only (solo)")
                ClickXY(x - 90, y + 25)
                ParkMouse()
                Sleep 700
                Log(FriendsOff(x, y) ? "  Friends Only: could not enable" : "  Friends Only enabled")
            } else
                Log("  Friends Only already enabled")
            return
        }
        ; час рейду минув (рейд можна створити лише 10 min після початку години, 29.10 18:12 бот
        ; тиснув Create до 18:30 і чекав до 59:30) - з світу рейду в лобі шляху нема, перезапуск гри
        if lastEntered = "raid" && goal != "raid" {
            if RestartRoblox("raid time is over and the bot is in the Create window", , 60000)
                Log("  cannot create this hour's raid - going to " goal)
            return
        }
        ; рейд відкривається на початку години: до createFrom (наприклад 59:30) Create не тиснемо
        s := SecOfHour()
        if lastEntered = "raid" && s >= 30 * 60 && s < MinSec(cfg["createFrom"], 59 * 60 + 30) {
            SetStatus("waiting until " cfg["createFrom"] ", then Create")
            return
        }
        ; останні 5 с перед відкриттям і перші 30 с години тиснемо щосекунди - щоб створити рейд одним з перших
        rush := s >= 3595 || s < 30
        if A_TickCount - lastCreate < (rush ? 1000 : CREATE_RETRY) {
            SetStatus("raid still closed, waiting")
            return
        }
        SetStatus("pressing Create (" lastEntered ")")
        ClickImg("create_final.png", x, y)
        ParkMouse()
        lastCreate := A_TickCount
        Sleep 1000
        return
    }
    ; списки данжів і рейдів. Після оновлення Halloween Raid є і в списку данжів головного лобі,
    ; тож спершу обираємо те, що треба зараз, і лише потім вирішуємо, що робити з іншим
    rd := RAIDS.Has(cfg["raidName"]) ? RAIDS[cfg["raidName"]] : RAIDS["halloween"]   ; обраний рейд
    if goal = "raid" && cfg["raidCreate"] != "1" && FindImg("create_tab.png", &gx, &gy) {   ; the Join/Create window: raids go through Group Finder (raidCreate=1: own room through Create, below)
        if EnterRaidGF(rd, gx, gy) {
            SetEntered("raid")
            friendsDone := false
        }
        return
    }
    hasRaid := rd[1] != "" && FindImg(rd[1], &rx, &ry)
    hasHal := hasRaid || FindImg("halloween.png", &hx, &hy)               ; Halloween є в усіх списках рейдів
    hasInf := FindImg("infinite.png", &ix, &iy)
    if hasRaid && goal = "raid" {
        SetStatus("selecting " rd[3])
        SetEntered("raid")
        friendsDone := false                                              ; новий екран налаштувань
        ClickXY(rx + rd[2][1], ry + rd[2][2])
        ParkMouse()
        Sleep 1500
        return
    }
    if hasHal && goal = "raid" && !hasRaid {                            ; рейд без еталона - шукаємо за назвою
        if PickRaidByName(rd) {
            SetEntered("raid")
            friendsDone := false
            Sleep 1500
        }
        return
    }
    if hasInf && goal = "dungeon" && DimKind() != "xdim" {                                       ; dungeon list: find Giant Dimension by name
        if PickDungeon() {
            SetEntered("dungeon")
            friendsDone := false
            Sleep 1500
        }
        return
    }
    if hasInf && goal = "infinity" {
        SetStatus("selecting Infinite Mode")
        SetEntered("infinity")
        ClickXY(ix + INF_OFFSET[1], iy + INF_OFFSET[2])
        ParkMouse()
        Sleep 1500
        return
    }
    if hasInf {                                                           ; список данжів, але час рейду
        SetStatus("closing the dungeon list (raid time)")
        ClickXY(1227, 261)                                                ; хрестик вікна
        ParkMouse()
        Sleep 1000
        return
    }
    if hasHal {                                                           ; світ рейду, але рейд уже був
        static halIdle := 0
        if !halIdle || A_TickCount - halIdle > 600000
            halIdle := A_TickCount
        SetStatus("in the raid world, this hour's raid is already done")
        ; з світу рейду в лобі шляху нема - не чекаємо кіка за AFK (20 min), перезапускаємо гру
        if A_TickCount - halIdle > 90000 && RestartRoblox("in the raid world without a raid", , 60000)
            halIdle := 0
        return
    }
    if FindImg("create_tab.png", &x, &y) {                                ; вікно Join/Create
        ; 4.11 00:04: Create tab pressed for 2 min and the raid was never found in the list - no shot of it
        static tabSince := 0, tabLast := 0, tabShot := 0
        if A_TickCount - tabLast > 15000
            tabSince := A_TickCount
        tabLast := A_TickCount
        if A_TickCount - tabSince > 20000 && A_TickCount - tabShot > 300000 {
            tabShot := A_TickCount
            Log("  Create tab for 20 s: the " (goal = "dungeon" ? "dungeon" : rd[3]) " card is not found in the list")
            Screenshot("list_nomatch")
        }
        SetStatus("Create tab")
        ClickImg("create_tab.png", x, y)
        ParkMouse()
        Sleep 2000                                                        ; список підвантажується
        ; рейд без еталона: Halloween колись зникне зі списку, тож не чекаємо його - шукаємо одразу
        ; 4.11 15:03: after the game update divine.png no longer matched its card - the name (OCR) is the fallback for every raid
        if goal = "raid" && PickRaidByName(rd) {
            SetEntered("raid")
            friendsDone := false
            Sleep 1500
        }
        if goal = "dungeon" && DimKind() != "xdim" && PickDungeon() {
            SetEntered("dungeon")
            friendsDone := false
            Sleep 1500
        }
        ; 4.11: the Halloween Dimension event card pushed Infinite Mode down and infinite.png stopped matching - pick it by name
        if goal = "infinity" && PickInfinity() {
            SetEntered("infinity")
            friendsDone := false
            Sleep 1500
        }
        return
    }
    if (goal = "infinity" || goal = "dungeon") && FindImg("dimension.png", &x, &y, 260, 880, 620, 990) {   ; меню режимів: у данжі (лише білі літери DIMENSION)
        if MenuLoadoutWrong(2)
            return
        if goal = "dungeon" && DimKind() = "xdim" {
            EnterExtreme()
            return
        }
        SetStatus("entering Dimension")
        ClickImg("dimension.png", x, y)
        ParkMouse()
        Sleep 1500
        return
    }
    if goal = "speed" && FindImg("speed_mode.png", &x, &y, 700, 860, 1300, 1000) {  ; меню режимів: Speed Raid
        if MenuLoadoutWrong(3)
            return
        SpeedEnter(x, y)
        return
    }
    if FindImg("raid_mode.png", &x, &y, 0, 860, SCR_W, 1000) {                                 ; меню режимів: у світ рейду
        if RunButtonSeen() {   ; 11.11: the skill bar of a running raid looked like the card - the AUTO button is only in a run
            SetStatus("raid: Auto, waiting for the end")
            return
        }
        if goal = "speed" {                                               ; картки SPEED RAID не впізнали
            Log("  modes menu: SPEED RAID not visible - postponing 10 min")
            Screenshot("speed_menu")
            SpeedLater(600)
            return
        }
        if goal != "raid" {                                               ; поза часом рейду у світ рейду не йдемо
            SetStatus("modes menu: DIMENSION not visible, waiting")
            ; player 9.11 21:26: the bot stood here 6 min (the DIMENSION card was not matched) - after 30 s close the menu and look again
            static menuSince := 0, menuLast := 0
            if A_TickCount - menuLast > 5000
                menuSince := A_TickCount
            menuLast := A_TickCount
            if A_TickCount - menuSince > 30000 {
                menuSince := A_TickCount
                Log("  modes menu: DIMENSION card not found for 30 s - closing the menu")
                Screenshot("modes_menu")
                Send "{Esc}"
            }
            return
        }
        if MenuLoadoutWrong(1)
            return
        SetStatus("teleporting to the raid world")
        ClickImg("raid_mode.png", x, y)
        ParkMouse()
        ; 14.11 11:00: the game answered "Failed to teleport. Exit the teleporter and try again" - the window stayed open, and WaitLoaded took the
        ; PLAY letters behind it for the lobby. Menu still there 6 s after the click = no teleport: close it, the loop reopens it from PLAY.
        Sleep 6000
        if running && FindImg("raid_mode.png", &x, &y, 0, 860, SCR_W, 1000) && !RunButtonSeen() {
            Log("  teleport failed (the modes window is still open) - closing it and trying again")
            Screenshot("tele_failed")
            Send "{Esc}"
            Sleep 1500
            return
        }
        WaitLoaded()
        return
    }
    if SeePlay(&x, &y) {               ; лише білі літери PLAY праворуч унизу (фон анімований)
        ; 14.11: a false PLAY in the middle of a raid sent the bot to the Bag (loadout) and Safe mode closed the game. The AUTO button
        ; exists only inside a run: with it on screen this is never the lobby - no loadout, no PLAY.
        if RunButtonSeen() {
            static falsePlayAt := 0
            if A_TickCount - falsePlayAt > 60000
                falsePlayAt := A_TickCount, Log("PLAY seen, but the AUTO button is on screen - still in a run, not acting as in the lobby")
            SetStatus("in a run (AUTO button visible) - waiting")
            return
        }
        if infDrop {
            infDrop := false
            Log("lobby after Infinity was cut off")
            Screenshot("inf_lobby")
        }
        if goal = "raid" || goal = "infinity" || goal = "dungeon" || goal = "speed" {   ; перед входом - потрібний loadout (Infinity / dungeon - 2)
            if cfg["loadouts"] != "1"
                CheckLoadoutOnce()                                        ; перемикання вимкнене - лише читаємо, що стоїть
            EnsureLoadout(goal = "raid" ? 1 : goal = "speed" ? 3 : 2)
            if !running
                return
            ; рейд з чужим loadout - не частіше разу на годину
            if goal = "raid" && (cfg["loadouts"] != "1" || curLoadout != 1) && (!lastLoadoutWarn || A_TickCount - lastLoadoutWarn > 3600000) {
                lastLoadoutWarn := A_TickCount
                Log("WARNING: raid without loadout 1 (current " curLoadout ", toggle " cfg["loadouts"] ")")
                SetStatus("WARNING: raid without loadout 1")
            }
        }
        SetStatus("pressing PLAY")
        ClickImg("play.png", x, y)
        ParkMouse()
        Sleep 1500
        return
    }
    ; сторож: екран довго не розпізнається (застрягле меню Esc, невідоме вікно гри).
    ; Перші 2 рази тиснемо Esc, далі по черзі хрестики відомих вікон гри (Esc їх не закриває).
    unknownSince := prevUnknown ? prevUnknown : A_TickCount
    ; 9.11 (player report "screen recognizing problem when the bot restarts Roblox"): in his lobby the PLAY button is tilted / outlined
    ; (pulse, event skin) and matches neither play.png nor the BAG text. A freshly restarted game is always in the lobby: after 30 s
    ; of "not recognised" press PLAY at its usual place (every 20 s, for 5 min after the restart).
    static blindAt := 0
    if lastRestart && A_TickCount - lastRestart < 300000 && A_TickCount - unknownSince > 30000 && A_TickCount - blindAt > 20000 {
        blindAt := A_TickCount
        Log("  after the restart the screen is not recognised for " (A_TickCount - unknownSince) // 1000 " s - pressing PLAY at its usual place")
        SetStatus("pressing PLAY at its usual place")
        ClickXY(1760, 942)
        ParkMouse()
        return
    }
    ; 14.11: the AUTO button exists only inside a run - an "unknown" screen with it is a run the pictures missed: no Esc, no window
    ; close clicks, no restart (they would break the run)
    if A_TickCount - unknownSince > UNKNOWN_ESC && RunButtonSeen() {
        unknownSince := A_TickCount, watchStep := 0
        Log("  screen not recognised, but the AUTO button is on screen - a run is going on, not pressing Esc")
        return
    }
    if A_TickCount - unknownSince > UNKNOWN_ESC {
        watchStep += 1
        if watchStep = 1 {
            ; щоб потім знати, на чому застрягли, - знімок і перевірка на чорний екран
            Screenshot("stuck")
            if BlackScreen()
                Log("  screen is black: the game window may be minimised or the screen locked")
        }
        ; connection lost (25.10 бот так простояв 6 год: Retry не допомагає) - лише перезапуск гри.
        ; Якщо ж screen not recognised for 12+ min - теж перезапуск, як крайній захід.
        dc := Disconnected()
        ; результати Infinity з "Teleporting in 0": телепорт гри завис (29.10 17:58 - 14 min і пропущений рейд).
        ; Раз тиснемо LEAVE, не допомогло - одразу перезапуск гри, не чекаючи 12 min
        if !dc && InStr(OcrRegion([860, 840, 340, 70]), "Teleport") {
            if watchStep = 1 {
                Log("  teleport stuck (Teleporting in 0) - pressing LEAVE")
                ClickXY(1215, 762)
                ParkMouse()
                unknownSince := A_TickCount
                return
            }
            unknownSince := A_TickCount
            if RestartRoblox("teleport stuck after Infinity", , 60000)
                watchStep := 0
            return
        }
        if dc || watchStep >= 8 {
            unknownSince := A_TickCount
            if RestartRoblox(dc ? "connection lost" : "screen not recognised for " watchStep * UNKNOWN_ESC // 60000 " min", , dc ? RESTART_GAP_DC : RESTART_GAP)
                watchStep := 0
            return
        }
        if watchStep <= 2 {
            SetStatus("screen not recognised for " UNKNOWN_ESC // 1000 " s, pressing Esc")
            HoldKey("Esc")
        } else {
            p := CLOSE_XS[Mod(watchStep - 3, CLOSE_XS.Length) + 1]
            SetStatus("screen not recognised, clicking window close (" p[1] ", " p[2] ")")
            ClickXY(p[1], p[2])
            ParkMouse()
        }
        unknownSince := A_TickCount
        return
    }
    SetStatus("waiting (screen not recognised), goal: " goal)
}

; Результати Infinity (RETRY / LEAVE): одразу LEAVE, не чекаючи відліку телепорту (29.10 17:58 він завис
; на "Teleporting in 0"). Шаблон перевірено на 3310 кадрах: збіги лише на екранах результатів.
; 3 натискання не допомогли - перезапуск гри
LeaveInfinity() {
    global lastReset, lastFight, routeDone, dimRetryAt, dimRunAt, dimHandled, xdimStartAt
    static leaveAt := 0, leaveN := 0, resSeen := false
    if !FindImg("leave.png", &x, &y, 1000, 680, 1450, 840) && !FindImg("leave.png", &x, &y, 1000, 680, 1450, 840, "*110 *TransFF00FF") {
        ; the button is translucent, so its colour depends on the scene behind (3.11: the template missed it and the game's
        ; AUTO RETRY looped Infinity for hours). Fallback: the light REWARDS panel, confirmed by OCR, then click the fixed LEAVE spot
        static panelAt := 0
        ; 8.11: the game's own AUTO RETRY presses RETRY 3-5 s after the results show (the run also ends by death, not only
        ; when the bot wants out), so look every 0.8 s; the OCR below runs only when the light panel is there
        if A_TickCount - panelAt < 800
            return false
        panelAt := A_TickCount
        light := 0
        for p in [[1200, 330], [1400, 400], [1100, 650], [900, 430]] {
            c := PixelGetColor(p[1], p[2])
            if Min((c >> 16) & 255, (c >> 8) & 255, c & 255) > 200
                light++
        }
        if light < 4 {                                    ; no bright panel: skip the OCR (it costs ~0.3 s, this runs every 2.5 s in fights)
            resSeen := false
            return false
        }
        ocrTxt := OcrRegion([560, 230, 1000, 700])
        if !RegExMatch(ocrTxt, "i)rewards|auto retry|retry|leave") {
            resSeen := false                              ; no results screen: the next one is read again
            return false
        }
        kind := RegExMatch(ocrTxt, "i)PITY|ACCESSORY") ? "Dimension" : (lastEntered = "dungeon" ? "Dimension" : "Infinity")
        Log("  " kind " results found by OCR (LEAVE picture did not match)")
        Screenshot("leave_nomatch")
        x := 1260, y := 771
    }
    routeDone := false, dimRunAt := 0                     ; results seen: the next run plays the route again
    ; поки йде телепорт - ні "липкого" бою, ні Esc-R-Enter (30 s left)
    lastFight := A_TickCount - FIGHT_STICKY
    lastReset := A_TickCount + 30000 - RESET_EVERY
    if A_TickCount - leaveAt > 60000
        leaveN := 0
    if A_TickCount - leaveAt > 4000 {
        if ++leaveN > 3 {
            leaveN := 0
            RestartRoblox("LEAVE after Infinity does not work", , 60000)
            return true
        }
        leaveAt := A_TickCount
        ReleaseKeys()
        ; Dimension: no counting, just RETRY at once - the same run again, the recorded route plays when the enemies show.
        ; RETRY is 593 px left of LEAVE (results screen 3.11). At raid time (goal is no longer the dungeon) - LEAVE.
        first := lastEntered = "dungeon" && !dimHandled
        if first {
            dimHandled := true
            DimCardsStart()
        }
        if lastEntered = "dungeon" && Target() = "dungeon" {
            SetStatus("Dimension results: pressing RETRY")
            routeDone := false, dimRetryAt := A_TickCount, xdimStartAt := A_TickCount
            if first
                Stat("dimRuns")
            ClickXY(x + 90 - 593, y + 24)
            ParkMouse()
            Sleep 800
            return true
        }
        if lastEntered != "dungeon" && !resSeen {
            resSeen := true
            ResultLineStart("infinity")                   ; Time / Wave line, read in the background before LEAVE
        }
        SetStatus("Infinity results: pressing LEAVE")
        ClickXY(x + 90, y + 24)
        ParkMouse()
        Sleep 1500
    }
    return true
}

; Speed Raid results (the REWARDS panel with LEAVE at the same place as in Infinity, shot 8.11 12:30): press LEAVE as soon as the
; rewards are read (or 3 s after the button shows) instead of waiting ~15 s for "Teleporting in N". The raid results have no LEAVE.
; Only the LEAVE picture triggers it; a wrong hit clicks an empty spot of the fight. 14.11: leave.png never matched here (1509 of 8640 px off,
; 08:09 the bot waited for the teleport) - img\leave_2.png (letters + light button, from 2 real shots) is the fallback FindImg tries.
SpeedLeave() {
    static seenAt := 0, pressAt := 0
    if !FindImg("leave.png", &x, &y, 1000, 680, 1450, 840) && !FindImg("leave.png", &x, &y, 1000, 680, 1450, 840, "*110 *TransFF00FF") {
        seenAt := 0
        return false
    }
    if !seenAt
        seenAt := A_TickCount
    if !infLootDone && A_TickCount - seenAt < 3000 || A_TickCount - pressAt < 4000
        return true                                       ; rewards are still being read / the click needs time to show
    pressAt := A_TickCount
    Log("Speed Raid results: pressing LEAVE")
    SetStatus("Speed Raid results: pressing LEAVE")
    ClickXY(x + 90, y + 24)
    ParkMouse()
    return true
}

; ------------------------ Допоміжні функції ------------------------
; знімок основного екрана в SHOTDIR (PNG через GDI+); понад SHOT_MAX найстаріші знімки видаляємо
Screenshot(tag, sx := 0, sy := 0, w := 1920, h := 1080) {            ; = SCR_W x SCR_H (defaults must be literals)
    try {
        DirCreate SHOTDIR
        file := SHOTDIR FormatTime(, "yyyyMMdd_HHmmss") "_" tag ".jpg"       ; 9.11: JPEG ~300 KB instead of PNG 2-3 MB - the Report zip must fit into Discord
        res := SaveRegion(file, sx, sy, w, h)
        Log(res = 0 ? "  screenshot: " file : "  screenshot not saved (GDI+ code " res ")")
        list := ""
        Loop Files SHOTDIR "*.*"
            list .= A_LoopFileFullPath "`n"
        arr := StrSplit(Sort(RTrim(list, "`n")), "`n")        ; імена з датою -> за алфавітом = за часом
        Loop arr.Length - SHOT_MAX
            FileDelete arr[A_Index]
        return file
    } catch as e
        Log("  screenshot failed: " e.Message)
    return ""
}

; ділянка екрана -> PNG-файл (GDI + GDI+); повертає 0, якщо збережено
SaveRegion(file, sx, sy, w, h) {
    try {
        sdc := DllCall("GetDC", "ptr", 0, "ptr")
        mdc := DllCall("CreateCompatibleDC", "ptr", sdc, "ptr")
        hbm := DllCall("CreateCompatibleBitmap", "ptr", sdc, "int", w, "int", h, "ptr")
        old := DllCall("SelectObject", "ptr", mdc, "ptr", hbm, "ptr")
        DllCall("BitBlt", "ptr", mdc, "int", 0, "int", 0, "int", w, "int", h, "ptr", sdc, "int", sx, "int", sy, "uint", 0x40CC0020)  ; SRCCOPY | CAPTUREBLT
        DllCall("SelectObject", "ptr", mdc, "ptr", old)
        DllCall("DeleteDC", "ptr", mdc)
        DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)
        if !DllCall("GetModuleHandle", "str", "gdiplus", "ptr")
            DllCall("LoadLibrary", "str", "gdiplus")
        si := Buffer(24, 0)
        NumPut("uint", 1, si)                                 ; GdiplusStartupInput.GdiplusVersion
        DllCall("gdiplus\GdiplusStartup", "ptr*", &token := 0, "ptr", si, "ptr", 0)
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &bmp := 0)
        clsid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "wstr", file ~= "i)\.jpe?g$" ? "{557CF401-1A04-11D3-9A73-0000F81EF32E}" : "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsid)   ; JPEG for screenshots (small), PNG for OCR (lossless)
        res := DllCall("gdiplus\GdipSaveImageToFile", "ptr", bmp, "wstr", file, "ptr", clsid, "ptr", 0)
        DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
        DllCall("gdiplus\GdiplusShutdown", "ptr", token)
        DllCall("DeleteObject", "ptr", hbm)
        return res
    }
    return -1
}

FindImg(name, &x, &y, x1 := 0, y1 := 0, x2 := 1920, y2 := 1080, opts := "") {   ; = SCR_W x SCR_H
    x := 0
    y := 0
    file := IMGDIR name
    if !FileExist(file)
        return false
    if opts = ""
        opts := "*" TOLERANCE " *TransFF00FF"          ; FF00FF у еталоні = прозорий фон (play.png, enemies_left.png)
    try
        found := ImageSearch(&x, &y, x1, y1, x2, y2, opts " " file)
    catch
        return false
    ; запасний еталон "назва_2.png" - той самий напис у дещо іншому масштабі (наприклад, гра в RDP-сесії)
    ; play_2.png: only the letter cores (2 px of every edge cut) - PLAY pulses, and 3.11 the full letters matched only at one size
    ; enemies_left_2.png: the same letters on a bright map (Giant Dimension sand, 4.11) - lighter red, 31 of 350 px were off at *80
    alt := IMGDIR StrReplace(name, ".png", "_2.png")
    if !found && FileExist(alt)
        try found := ImageSearch(&x, &y, x1, y1, x2, y2, opts " " alt)
    if found && BORDER.Has(name) && !BorderOk(name, x, y) {
        Log("  " name ": matched a blob of letter colour, ignoring")
        return false
    }
    return found
}

; true, якщо довкола літер справді фон, а не той самий колір (менше 12 з 16 точок кольору літер).
; З великим допуском ImageSearch може знайти збіг на 1-2 px зміщеним, тож пробуємо і зсуви до ±2 px:
; справжній напис пройде хоча б з одним, а суцільна пляма - ні з жодним.
BorderOk(name, x, y) {
    kind := BORDER[name][1]
    for off in [[0,0],[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,-1],[1,-1],[-1,1],[2,0],[-2,0],[0,2],[0,-2]] {
        same := 0
        for p in BORDER[name][2] {
            c := Integer(PixelGetColor(x + off[1] + p[1], y + off[2] + p[2]))
            r := c >> 16 & 0xFF, gg := c >> 8 & 0xFF, b := c & 0xFF
            if kind = "white" ? (r > 200 && gg > 200 && b > 200) : (r > 170 && gg < 110 && b < 120)
                same += 1
        }
        if same < 12
            return true
    }
    return false
}

; число з налаштувань; якщо там щось не те (порожньо, букви) - значення за замовчуванням
Num(key, def) {
    try
        return Integer(cfg[key])
    catch
        return def
}

; PLAY in the lobby; when the image does not match, the BAG text (OCR) says it is the lobby and PLAY is at its usual place.
; 06.11: a user's "Activate Windows" watermark lies over PLAY - play.png never matched, the bot waited for hours.
; With a menu open the screen is dimmed and BAG is not read, so this does not fire over menus.
; The orange-red PLAY diamond (bottom right) is on screen: 6+ % of its area has the button colour (lobby 12 %, other screens 0-1 %).
; Only a hint for the Setup check - a colour alone is not enough to press anything.
PlayDiamond() {
    b := [1670, 830, 180, 200]
    px := GrabPixels(b[1], b[2], b[3], b[4]), n := 0, tot := 0
    y := 0
    while y < b[4] {
        x := 0
        while x < b[3] {
            c := NumGet(px, (y * b[3] + x) * 4, "uint")
            r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, bl := c & 0xFF
            tot++
            if r > 190 && g > 70 && g < 150 && bl > 60 && bl < 140 && r - g > 70
                n++
            x += 4
        }
        y += 4
    }
    return n / tot >= 0.06
}

SeePlay(&x, &y) {
    if FindImg("play.png", &x, &y, 1500, 800, 1920, 1060)
        return true
    if !InStr(OcrRegion([1790, 712, 110, 56]), "BAG")
        return false
    x := 1760 - 90, y := 942 - 28                         ; top-left of play.png (180x56) around the PLAY centre 1760,942
    Log("  PLAY not matched, BAG text seen - lobby, PLAY at its usual place")
    return true
}

ClickImg(name, x, y) {
    size := PngSize(IMGDIR name)
    ClickXY(x + size[1] // 2, y + size[2] // 2)
}

ClickXY(cx, cy) {
    if !running                                           ; після F2 кліків більше нема
        return
    MouseMove cx + 3, cy + 3, 0
    Sleep 60
    MouseMove cx, cy, 0
    Sleep 80
    if !running                                           ; за ці 140 ms могли зупинити
        return
    Click
}

; Після телепорту чекаємо не фіксований час, а поки лобі справді завантажиться: з'явиться кнопка PLAY
; (перші 3 с не дивимось - старе лобі ще може бути на екрані). Найдовше 60 с.
WaitLoaded() {
    t0 := A_TickCount
    Sleep 3000
    while A_TickCount - t0 < 60000 && running {
        if SeePlay(&x, &y) {
            Log("  lobby loaded in " Round((A_TickCount - t0) / 1000, 1) " s")
            Sleep 500                            ; дати інтерфейсу домалюватись
            return
        }
        ; 3.11 23:00: raid_mode.png matched in the raid itself and the bot stood here 60 s while the fight went on
        h := ENEMIES_HOME
        if FindImg("enemies_left.png", &x, &y, h[1] - 12, h[2] - 12, h[1] + 66, h[2] + 38, "*80 *TransFF00FF") {
            Log("  already in a fight (ENEMIES LEFT) after " Round((A_TickCount - t0) / 1000, 1) " s - not waiting for the lobby")
            return
        }
        Sleep 500
    }
    Log("  lobby did not load in 60 s")
    Screenshot("no_lobby")
}

; вікно обриву з'єднання Roblox: текст у центрі екрана містить Disconnected / Reconnect / Retry / Error Code
Disconnected() {
    txt := OcrRegion(DISCONNECT_BOX)
    if RegExMatch(txt, DISCONNECT_RE) {
        Log("  connection lost, on screen: " StrReplace(Trim(txt), "`n", " | "))
        return true
    }
    return false
}

; синхронний OCR ділянки екрана (x, y, w, h); lines - кожен рядок як [y від верху ділянки, текст]
OcrRegion(b, lines := false) {
    txt := ""
    try FileDelete OCR2_OUT
    if SaveRegion(OCR2_IN, b[1], b[2], b[3], b[4]) = 0 {
        OcrCall(OCR2_IN, OCR2_OUT, "-Scale 2" (lines ? " -Lines" : ""))
        try txt := FileRead(OCR2_OUT, "UTF-8")
        try FileDelete OCR2_OUT
    }
    if !lines
        return txt
    out := []
    for ln in StrSplit(txt, "`n", "`r")
        if RegExMatch(ln, "^(\d+)\t(.*)$", &m)
            out.Push([Integer(m[1]), m[2]])
    return out
}

; OCR через сервер (ocr.ps1 -Serve): PowerShell запущений один раз, читання ~0.15 с замість ~1 с (28.10).
; Сервер не запущений або не відповів за 8 с - старий спосіб (окремий PowerShell на це читання).
; wait = false - лише поставити в чергу (результат забирає PollRewards на наступних тіках).
OcrCall(img, out, opts := "", wait := true) {
    try FileDelete out
    if OcrServer() {
        req := OCRQ A_TickCount "_" Random(1000, 9999)
        try {
            FileAppend img "`n" out "`n" opts, req ".tmp", "UTF-8-RAW"
            FileMove req ".tmp", req ".req"              ; сервер бере лише готові *.req
            if !wait
                return
            t0 := A_TickCount
            while A_TickCount - t0 < 8000 {
                if FileExist(out)
                    return
                Sleep 30
            }
            try FileDelete req ".req"
        }
        Log("  OCR server did not answer - restarting it, this read uses the old way")
        OcrServerKill()
    }
    cmd := 'powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' A_ScriptDir '\ocr.ps1" "' img '" "' out '" ' opts
    try wait ? RunWait(cmd, , "Hide") : Run(cmd, , "Hide")
}

; true - сервер працює. Не працює - запускаємо (не частіше раз на minилину); щойно запущений ще
; вантажиться ~1 с, тож цього разу false. Сервер сам закривається, коли закривається бот (-Parent).
OcrServer() {
    global ocrPid
    static lastTry := 0
    if ocrPid && ProcessExist(ocrPid)
        return true
    ocrPid := 0
    if lastTry && A_TickCount - lastTry < 60000
        return false
    lastTry := A_TickCount
    try {
        DirCreate OCRQ
        Loop Files OCRQ "*.*"
            try FileDelete A_LoopFileFullPath
        Run('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' A_ScriptDir '\ocr.ps1" -Serve "'
            RTrim(OCRQ, "\") '" -Parent ' DllCall("GetCurrentProcessId"), , "Hide", &pid)
        ocrPid := pid
        Log("  OCR server started")
    }
    return false
}

OcrServerKill() {
    global ocrPid
    if ocrPid
        try ProcessClose ocrPid
    ocrPid := 0
}

; Екран PARTY рейду: "Team Damage Bonus: + N%" праворуч від списку гравців (кадри 29.10: "+ 0%", "+ 110%").
; Читаємо OCR не частіше раз на секунду; -1 - не прочитали.
PartyBonus() {
    static at := 0, val := -1, box := [1060, 585, 200, 65]
    if A_TickCount - at < 1000
        return val
    at := A_TickCount
    val := -1
    ; Windows OCR то читає "+ 110%", то "+ 1100/0" (% -> 0/0) і зовсім по-різному на різних масштабах (31.10: за все
    ; життя жодного "Start одразу" - читання не збігалось із шаблоном), тож пробуємо масштаби 2, 1, 3
    for sc in [2, 1, 3] {
        try FileDelete OCR2_OUT
        if SaveRegion(OCR2_IN, box[1], box[2], box[3], box[4]) != 0
            continue
        OcrCall(OCR2_IN, OCR2_OUT, "-Scale " sc)
        txt := ""
        try txt := FileRead(OCR2_OUT, "UTF-8")
        try FileDelete OCR2_OUT
        if RegExMatch(txt, "\+\s*(\d{1,3})\s*%", &m) || RegExMatch(txt, "\+\s*(\d{1,3}?)\s*0\s*/\s*0", &m) {
            val := Integer(m[1])
            break
        }
        static lastRaw := 0
        if A_TickCount - lastRaw > 15000 {
            lastRaw := A_TickCount
            Log("  PARTY: bonus not read (scale " sc "): '" Trim(StrReplace(txt, "`n", " | ")) "'")
        }
    }
    return val
}

; Рейд без еталона: шукаємо його назву в списку рейдів (OCR), гортаючи колесом від початку,
; і тиснемо Create під назвою. true - натиснули.
PickRaidByName(rd, isRaid := true, btn := "i)reate") {
    global raidDoneKey, pickFails, pickFailHour, pickMissAt
    b := RAID_LIST
    SetStatus("looking for " rd[3] " in the list")
    ListWheel("Up", 80)                                   ; на початок списку (private server: more raids above the dungeons)
    Sleep 1500                                            ; 4.11: the list keeps sliding after the wheel - OCR read an empty moving list
    prev := "-", empty := 0, same := 0
    Loop 80 {
        lines := OcrRegion(b, true)
        if !lines.Length && ++empty <= 4 {                 ; nothing read: the list is still moving - read again, do not scroll
            Sleep 700
            continue
        }
        all := "", titleY := 0
        for ln in lines {
            all .= ln[1] ":" ln[2] "|"                   ; with y: small steps may show the same rows, only shifted
            if !titleY && RegExMatch(ln[2], rd[4])
                titleY := ln[1]
            else if titleY && RegExMatch(ln[2], btn) && ln[1] > titleY && ln[1] - titleY < 130 {
                SetStatus("selecting " rd[3])
                ClickXY(RAID_CREATE_X, b[2] + ln[1])
                ParkMouse()
                if isRaid
                    pickFails := 0
                return true
            }
        }
        ; 12.11: on a slow PC the list may not move between two reads - the end only after 3 same reads in a row
        same := all = prev ? same + 1 : 0
        if same >= 2                                      ; список уже не гортається - кінець
            break
        if same
            Sleep 800                                     ; same rows once: give the slow game time, then scroll again
        prev := all
        ; 4 notches (~half a row): with 10 the title at the bottom edge (its Create still hidden) jumped off the top
        ; on the next step - 4.11 Giant Dimension on the private server was skipped this way
        ListWheel("Down", 2, 200)                         ; 4.11 user: down slowly and a little at a time
        Sleep 500                                         ; let the list stop before the next read
    }
    hour := RaidKey()
    if isRaid {                                           ; a miss within 60 s of the last counted one does not count (list still scrolling)
        if pickFailHour != hour
            pickFails := 0, pickMissAt := 0
        pickFailHour := hour
        if !pickMissAt || A_TickCount - pickMissAt > 60000
            pickFails++, pickMissAt := A_TickCount
        Log("  " rd[3] ": not found in the raid list (" pickFails "/3)")
    } else
        Log("  " rd[3] ": not found in the list")
    Screenshot("raid_list")
    ListWheel("Up", 80)                                   ; do not stay at the bottom of the list
    if !isRaid
        return false
    if pickFails >= 3 {                                       ; рейд зник з гри (limited) - не шукаємо до кінця години
        Log("  skipping this hour's raid: " rd[3] " is not in the list, pick another raid")
        raidDoneKey := hour
        IniWrite raidDoneKey, INI, "state", "raidDoneKey"
        ClickXY(1227, 261)                                ; хрестик вікна
        ParkMouse()
    }
    return false
}

; Raid entry through Group Finder (7.11): open its tab, find the raid by name, press Easy - the bot queues and the game
; teleports into the raid when it opens. While queued the window is not touched (a second click would leave the queue).
EnterRaidGF(rd, x, y) {
    static queuedAt := 0, chkAt := 0, shown := true, queueUntil := 0
    ; after Easy a banner hangs at the top ("Raid opens in 0:17", CANCEL, 7.11 13:59): it is the proof of the queue.
    ; Gone for 15+ s after the click (cancelled, or the raid failed) - queue again.
    if queuedAt {
        if A_TickCount - chkAt > 1500 {
            chkAt := A_TickCount
            shown := RegExMatch(OcrRegion([810, 90, 300, 70]), "i)opens|cancel|Time")
        }
        ; 7.11 17:03: the banner is also gone when the raid opens (teleport starts) - the bot then scrolled the list with the
        ; mouse wheel in the loading raid = camera zoomed in. So wait 90 s after the click before queueing again.
        ; 11.11 18:00: queued at 17:58:42, the raid opens at the full hour and teleports ~15 s later: the 90 s ended at 18:00:12, the bot opened the list
        ; and scrolled it in the loading raid - the camera zoomed to the maximum and looked up. A queue made before the hour waits until 75 s after it.
        if shown || A_TickCount - queuedAt < 90000 || A_TickCount < queueUntil {
            SetStatus("Group Finder: queued, waiting for the raid")
            return false
        }
        Log("  Group Finder: the queue banner is gone - queueing again")
        queuedAt := 0
    }
    SetStatus("Group Finder tab")
    size := PngSize(IMGDIR "create_tab.png")
    ClickXY(x + size[1] // 2 + GF_TAB_DX, y + size[2] // 2)
    ParkMouse()
    Sleep 2000                                            ; the list loads
    if PickRaidByName(rd, true, "i)Eas|Ea.y|E.sy") {
        queuedAt := A_TickCount
        queueUntil := 0
        if RaidMin() >= 50                              ; before the full hour: the raid opens at the hour, not earlier
            queueUntil := A_TickCount + ((60 - RaidMin()) * 60 - Integer(A_Sec) + 75) * 1000
        Log("  Group Finder: queued for " rd[3])
        return true
    }
    return false
}

; Infinite Mode in the Create list by name; after a miss, waits a minute before searching again
PickInfinity() {
    static retryAt := 0
    if A_TickCount < retryAt
        return false
    if PickRaidByName(["", 0, "Infinite Mode", "i)Infinite"], false)
        return true
    retryAt := A_TickCount + 60000
    return false
}

; the card of the chosen dungeon in the Create list: the name read by OCR (Halloween raid cards are told apart by "Dim")
DungeonRd() {
    k := DimKind()
    return k != "giant" && DIMS.Has(k) ? ["", 0, DIMS[k][1], DIMS[k][2]] : DUNGEON
}

; the dungeon in the Create list; after a miss, waits a minute before searching again
PickDungeon() {
    global xdimMapNow
    static retryAt := 0
    xdimMapNow := ""                                      ; the plain Dimension now: the Extreme map of an earlier run is done
    if A_TickCount < retryAt
        return false
    if PickRaidByName(DungeonRd(), false)
        return true
    retryAt := A_TickCount + 60000
    return false
}

; Dungeon Create window: Nightmare, Hardcore on, Friends Only on. (x, y) - top-left of the Create button picture.
; Offsets are read from a 1920x1080 screenshot of the window (toggles left of Create, difficulty list above them).
; The chosen options are listed top right ("Nightmare / Hardcore / Friends Only") - read with OCR as a check.
DungeonSetup(x, y) {
    static fails := 0
    box := [x - 29, y - 493, 200, 160]
    hcNeed := DimKind() != "halloween"                        ; the Halloween Hardcore button cannot be pressed: never click it
    Loop 3 {
        SetStatus("dungeon: Nightmare, Hardcore, Friends Only")
        if !InStr(OcrRegion(box), "ightmare") {
            MouseMove x - 290, y - 190, 0                    ; list to the top: Easy, Hard, Nightmare (partly visible)
            Sleep 100
            MouseMove x - 299, y - 190, 0
            Sleep 100
            Loop 5 {
                Send "{WheelUp}"
                Sleep 25
            }
            Sleep 300
            ClickXY(x - 299, y - 136)
            ParkMouse()
            Sleep 600
        }
        if hcNeed && !ToggleGreen(x - 122, y - 58) {         ; Hardcore
            ClickXY(x - 92, y - 58)
            ParkMouse()
            Sleep 500
        }
        if !ToggleGreen(x - 122, y + 22) {                   ; Friends Only
            ClickXY(x - 92, y + 22)
            ParkMouse()
            Sleep 500
        }
        nm := InStr(OcrRegion(box), "ightmare"), hc := !hcNeed || ToggleGreen(x - 122, y - 58), fo := ToggleGreen(x - 122, y + 22)
        if nm && hc && fo {
            Log("  dungeon options set: Nightmare, Hardcore, Friends Only")
            fails := 0
            return true
        }
        Log("  dungeon options: Nightmare " (nm ? "ok" : "NOT set") ", Hardcore " (hc ? "ok" : "NOT set") ", Friends Only " (fo ? "ok" : "NOT set"))
    }
    if ++fails = 1
        Screenshot("dungeon_setup")
    return false
}

; the left part of an ON toggle is green; OFF has the light knob there
ToggleGreen(px, py) {
    c := Integer(PixelGetColor(px, py))
    r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, b := c & 0xFF
    return g > 130 && g > r + 40 && g > b + 20
}

; Plays a recorded route: [ms, "kd"/"ku", key code] from the start. Starts when the first enemies are seen ahead,
; as when it was recorded (not played if they are not seen in 20 s), every step shifted by dimShift ms. Each step is timed against the start with a 1 ms timer,
; so nothing adds up (Sleep alone is 15.6 ms coarse). SendInput: no key delay, exactly like the recording.
RunRoute(route) {
    global xdimStartAt, dimRetryAt
    shift := Num("dimShift", 0)
    if !route.Length {
        Log("  dungeon route not started: no recorded run for " DimKind() " (Edit the run on the Dimension page)")
        xdimStartAt := 0
        return
    }
    kind := DimKind()
    SetStatus("Dimension: waiting for the first enemies")
    t0 := A_TickCount
    ; orange things in the lobby or the modes menu are not the giants (3.11 20:36 the run started in the menu)
    h := ENEMIES_HOME
    seen := false, strong := 0, timed := false   ; 14.11: Giant after RETRY also waits dimReplayWait s (no enemy detection)
    if kind = "xdim" || xdimStartAt {                     ; Extreme: the map is different every day - the run starts a set time after Start
        wait := Num(kind = "xdim" ? "xdimWait" : "dimReplayWait", 15) * 1000   ; 8.11: also after REPLAY in Halloween / Death (the HUD start missed the replayed run); 14.11 own setting
        xdimStartAt := xdimStartAt || A_TickCount
        while running && A_TickCount - xdimStartAt < wait {
            SetStatus((kind = "xdim" ? "Extreme" : kind) " Dimension: the run starts in " Ceil((wait - (A_TickCount - xdimStartAt)) / 1000) " s")
            ; 8.11 13:18:24: right after REPLAY the reload showed PLAY and cancelled the run - not the lobby yet
            if A_TickCount - dimRetryAt > 30000 && FindImg("play.png", &px, &py, 1500, 800, 1920, 1060) && !RunButtonSeen() {   ; 14.11: not with the AUTO button on screen (a false PLAY)
                Log("  Extreme Dimension: lobby seen while waiting - run cancelled")
                xdimStartAt := 0
                return
            }
            Sleep 400
        }
        xdimStartAt := 0
        seen := running, timed := true
    }
    while running && !seen && A_TickCount - t0 < 20000 {
        n := MobsCount()
        hud := (n >= 500 || kind != "giant") && FindImg("enemies_left.png", &px, &py, h[1] - 12, h[2] - 12, h[1] + 66, h[2] + 38, "*80 *TransFF00FF")
        strong := kind = "giant" && enteredFresh && n >= 800 ? strong + 1 : 0   ; 11.11: bot started inside a raid (old lastEntered=dungeon) took the raid boss for the giants and played the run
        ok := (hud || strong >= 3) && (!FindImg("play.png", &px, &py, 1500, 800, 1920, 1060) || RunButtonSeen())
            && !FindImg("dimension.png", &px, &py, 260, 880, 620, 990)
        if ok && hud
            seen := true
        else if ok {                             ; 05.11: the giants stood in the dark for seconds before the HUD showed - the clear look of them is enough
            seen := true
            Log("  giants seen without the ENEMIES LEFT HUD (" n " px)")
        } else
            Sleep 30
    }
    if !seen {                                            ; not at the spawn (or another view): walking blind would go wrong
        Log("  dungeon route not started: the first enemies were not seen in 20 s - normal fight")
        Screenshot("route_nostart")
        return
    }
    if kind != "xdim" && !(timed && kind = "giant") && running && Num("dimWait", 2000) > 0 {   ; 8.11 (Discord report): the character did not walk, only the skills worked - the game was not ready for movement yet
        wait := Num("dimWait", 2000)
        ; 11.11 (player report, log 09:12): after RETRY the giants are seen after ~5 s but the character cannot move yet - the route was played
        ; on the spot (the first run after a restart, which has a longer wait, walked fine). The run of a RETRY starts no earlier than
        ; dimRetryWait (default 10 s) after the RETRY press; the cooldowns are reset in every round, so nothing else has to be waited for.
        if dimRetryAt
            wait := Max(wait, Num("dimRetryWait", 10000) - (A_TickCount - dimRetryAt))
        if wait > 0 {
            SetStatus("Dimension: first enemies seen, starting the run in " Round(wait / 1000, 1) " s")
            Sleep wait
        }
    }
    Log("  dungeon route started (method " cfg["dimMethod"] ", " (route == DUNGEON_ROUTE ? "built-in" : kind = "xdim" ? DimDir() "log.txt" : "log.txt") ", " route.Length " steps)")
    SetStatus("dungeon: playing the recorded route")
    DllCall("winmm\timeBeginPeriod", "uint", 1)
    global routePtrWas, routeDown
    t0 := NowMs(), down := routeDown := Map()                          ; 13.11: QPC ms (A_TickCount moves in 15.6 ms steps)
    for st in route {
        due := st[1] + shift
        while running && NowMs() - t0 < due
            Sleep Min(10, Max(1, Floor(due - (NowMs() - t0)) - 1))
        if !running
            break
        if st[2] = "ptr" {                                ; the recording PC's pointer settings for the replay (back below)
            routePtrWas := PtrNow()
            if st[3] != routePtrWas
                SetPtr(st[3])
            continue
        }
        if st[2] = "mm" {
            DllCall("mouse_event", "uint", 1, "int", Integer(st[3]), "int", Integer(st[4]), "uint", 0, "ptr", 0)
            continue
        }
        if (st[2] = "up" || st[2] = "dn") {                   ; wheel: a tiny move there and back (net 0); an absolute MouseMove turned the camera
            DllCall("mouse_event", "uint", 1, "int", 3, "int", 0, "uint", 0, "ptr", 0)
            Sleep 8
            DllCall("mouse_event", "uint", 1, "int", -3, "int", 0, "uint", 0, "ptr", 0)
            Sleep 16
            Send st[2] = "up" ? "{WheelUp}" : "{WheelDown}"
            continue
        }
        if RouteBtn().Has(b := SubStr(st[2], 1, -1)) {          ; buttons from the Recorder: ld lu rd ru md mu x1d x1u x2d x2u at x, y (3, 4)
            d := SubStr(st[2], -1) = "d"
            if d && IsInteger(st[3]) && IsInteger(st[4])      ; 13.11: not before a release (it turned the held camera)
                PressAt(Integer(st[3]), Integer(st[4]))
            Click RouteBtn()[b] (d ? " Down" : " Up")
            continue
        }
        SendInput "{" st[3] (st[2] = "kd" ? " down}" : " up}")
        if st[2] = "kd"
            down[st[3]] := true
        else if down.Has(st[3])
            down.Delete(st[3])
    }
    RouteCleanup()
    DllCall("winmm\timeEndPeriod", "uint", 1)
    Log("  dungeon route " (running ? "done in " Round((NowMs() - t0) / 1000, 1) " s" : "stopped"))
}

; The run to play: dimension\giant\log.txt when it is there (edited in the Recorder from the Dimension page; read
; again whenever the file changes, so edits work without a restart), else the built-in DUNGEON_ROUTE.
; Steps: [ms from the start, "kd"/"ku", key code] or [ms, "mm", dx, dy]; "wait" rows of the Recorder only add time.
; dimMethod 2 = always the built-in route; 1 = log.txt (built-in with a warning when the file is missing).
; Row "kp" (key press, col 5 = hold ms) becomes kd at t and ku at t + hold; the route is then sorted by time (stable).
DimRoute(kind := "", today := false) {
    static at := "", route := 0, atMethod := "", atSens := "", warned := false
    if kind = ""
        kind := DimKind()
    method := kind (InStr("12345", cfg["dimMethod"]) ? cfg["dimMethod"] : "1")
    fb := kind = "giant" ? DUNGEON_ROUTE : []             ; the built-in walk is the Giant map only: elsewhere no recording = no run
    file := DimDir(kind, today) "log.txt"
    if kind = "giant" && cfg["dimMethod"] != "1" && !FileExist(file)   ; Slot 2-5: own recording in dimension\giant<N>, else the built-in route
        return fb
    if !FileExist(file) {
        if !warned {
            warned := true
            Log("  WARNING: " file " is missing - " (kind = "giant" ? "built-in route" : "no recorded run, normal fight"))
        }
        return fb
    }
    warned := false
    t := file "|" FileGetTime(file)                       ; the path too: another Extreme map's run can have the same file time
    sens := IniRead(INI, "raid", "camSens", "36")         ; the Recorder can change camSens while the bot runs (not the INI time: raid.ini is written all the time)
    if t = at && atMethod = method && atSens = sens
        return route
    f := RunMoveFactor(file)                              ; 1 unless the run was recorded with another mouse sensitivity (header "; sens N / ; ptr N")
    r := []
    try txt := FileRead(file)
    catch
        txt := ""
    cx := 0, cy := 0                                      ; rounding left over, so the total turn stays right
    if Abs(f - 1) > 0.005
        Log("  run scaled x" Round(f, 2) " for your mouse sensitivity (" file ")")
    for line in StrSplit(txt, "`n", "`r") {
        p := StrSplit(line, ",")
        if p.Length < 3 || SubStr(line, 1, 1) = ";" || !(p[2] = "kd" || p[2] = "ku" || p[2] = "mm" || p[2] = "kp" || InStr(" up dn ld lu rd ru md mu x1d x1u x2d x2u ", " " p[2] " "))
            continue
        if !IsNumber(Trim(p[1])) {                        ; one bad line is skipped, not the rest of the run
            Log("  WARNING: log.txt line skipped (bad time): " line)
            continue
        }
        ms := Round(Number(Trim(p[1])) * 1000)
        if p[2] = "kp" {
            hold := p.Length > 4 && IsNumber(Trim(p[5])) ? Max(0, Round(Number(Trim(p[5])))) : 0
            r.Push([ms, "kd", p[3], ""], [ms + hold, "ku", p[3], ""])
        } else if p[2] = "mm" && Abs(f - 1) > 0.005 && p.Length > 3 && IsInteger(Trim(p[3])) && IsInteger(Trim(p[4])) {
            fx := Integer(Trim(p[3])) * f + cx, fy := Integer(Trim(p[4])) * f + cy
            dx := Round(fx), dy := Round(fy)
            cx := fx - dx, cy := fy - dy
            r.Push([ms, "mm", dx, dy])
        } else
            r.Push([ms, p[2], p[3], p.Length > 3 ? p[4] : ""])
    }
    i := 2                                                ; stable insertion sort by ms
    while i <= r.Length {
        x := r[i], j := i - 1
        while j >= 1 && r[j][1] > x[1] {
            r[j + 1] := r[j]
            j--
        }
        r[j + 1] := x
        i++
    }
    if r.Length && RegExMatch(txt, "m)^; ptr (-?\d+ -?\d+ -?\d+ \d+)", &pm)
        r.InsertAt(1, [0, "ptr", pm[1], ""])              ; RunRoute: Windows pointer settings of the recording PC
    at := t, atMethod := method, atSens := sens, route := r.Length ? r : fb
    return route
}

; after a recorded run (and on exit in the middle of one): 13.11 a held right button kept turning the camera at every menu move;
; the pointer settings of the run go back to yours
RouteCleanup() {
    global routePtrWas, routeDown
    for k in routeDown                                    ; stopped in the middle: release what is still held
        SendInput "{" k " up}"
    routeDown := Map()
    for b in ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
        if GetKeyState(b)
            SendInput "{" b " up}"
    if routePtrWas != "" && PtrNow() != routePtrWas
        SetPtr(routePtrWas)
    routePtrWas := ""
}

; ms with sub-ms precision (QueryPerformanceCounter)
NowMs() {
    static f := 0
    if !f
        DllCall("QueryPerformanceFrequency", "int64*", &f)
    DllCall("QueryPerformanceCounter", "int64*", &c := 0)
    return c * 1000 / f
}

RouteBtn() {
    static m := Map("l", "Left", "r", "Right", "m", "Middle", "x1", "X1", "x2", "X2")
    return m
}

; Windows pointer settings "t1 t2 accel speed" (Enhance pointer precision = accel 1). A run holds raw mouse counts, a replayed move
; goes through this scaling: the run is played with the recording PC's settings (header "; ptr"), so a turn is the same angle.
PtrNow() {
    m := Buffer(12, 0), s := 10
    DllCall("SystemParametersInfo", "uint", 0x03, "uint", 0, "ptr", m, "uint", 0)         ; SPI_GETMOUSE
    DllCall("SystemParametersInfo", "uint", 0x70, "uint", 0, "int*", &s, "uint", 0)       ; SPI_GETMOUSESPEED
    return NumGet(m, 0, "int") " " NumGet(m, 4, "int") " " NumGet(m, 8, "int") " " s
}
; for this session only (fWinIni 0: not written to the profile - a crash leaves it until the next sign-in at most)
SetPtr(v) {
    p := StrSplit(v, " ")
    if p.Length != 4
        return
    m := Buffer(12, 0)
    NumPut("int", Integer(p[1]), "int", Integer(p[2]), "int", Integer(p[3]), m)
    DllCall("SystemParametersInfo", "uint", 0x04, "uint", 0, "ptr", m, "uint", 0)         ; SPI_SETMOUSE
    DllCall("SystemParametersInfo", "uint", 0x71, "uint", 0, "ptr", Integer(p[4]), "uint", 0)   ; SPI_SETMOUSESPEED
}

; a button press of a run at x, y; Roblox needs a mouse move just before it. 13.11 ("the mouse flies up"): with the cursor locked
; in the middle (shift-lock / right button) every jump to the recorded x, y, a few px off the centre, turned the camera -
; there a move of 2 px and back (net 0). The pauses were 100 ms (every click came late), now one game frame.
PressAt(x, y) {
    near := false
    try {
        WinGetClientPos &cx, &cy, &cw, &ch, GAME
        near := Abs(x - (cx + cw // 2)) <= 40 && Abs(y - (cy + ch // 2)) <= 40
    }
    try {
        MouseGetPos &mx, &my
        near := near && Abs(mx - (cx + cw // 2)) <= 40 && Abs(my - (cy + ch // 2)) <= 40   ; the cursor is held in the middle NOW
    }
    if near {
        DllCall("mouse_event", "uint", 1, "int", 2, "int", 0, "uint", 0, "ptr", 0)
        Sleep 8
        DllCall("mouse_event", "uint", 1, "int", -2, "int", 0, "uint", 0, "ptr", 0)
    } else {
        MouseMove x + 6, y + 6, 0
        Sleep 8
        MouseMove x, y, 0
    }
    Sleep 16
}

; header of a run file: "; sens N" = the Roblox mouse sensitivity (x100, like camSens) of the PC that recorded it. No header (an old file) =
; unknown = played as it is. The camera turn is counts x sensitivity, so counts are multiplied by recorded / yours.
RunMoveFactor(file) {
    try txt := FileRead(file)
    catch
        return 1
    if !RegExMatch(txt, "m)^; sens (\d+)", &m)
        return 1
    v := Trim(IniRead(INI, "raid", "camSens", ""))
    if !IsInteger(v) || v < 1                             ; your sensitivity is not set: 36 is the author's, not yours - play as it is
        return 1
    return Integer(m[1]) / Integer(v)
}

; first line of the region whose text matches rx: its y on the screen, else 0
OcrLineY(box, rx) {
    for ln in OcrRegion(box, true)
        if RegExMatch(ln[2], rx)
            return box[2] + ln[1]
    return 0
}

; Extreme Dimension from the modes menu: open its card, pick the difficulty (checked on the "Difficulty:" line, Start is never
; pressed on "None"), press Start and play the recorded run xdimWait s later. Click spots are estimated from a 1920x1080
; picture of the menu and window; the lines are found by OCR first, the estimates are the fallback.
EnterExtreme() {
    global xdimStartAt, routeDone, dimRunAt, dimHandled, xdimMapNow
    static fails := 0
    names := ["Easy", "Normal", "Nightmare", "Extreme"]
    pick := Min(4, Max(1, Integer(cfg["xdimPick"]))), nm := names[pick], nm4 := SubStr(nm, 1, 4)
    SetStatus("Extreme Dimension: " nm)
    if !OcrLineY([1100, 270, 450, 100], "i)Select|Diffic") {         ; the window is not open yet: open the card
        cy := OcrLineY([1250, 150, 600, 900], "i)EXTREME\s*DIM")
        ClickXY(1416, cy ? cy - 45 : 722)
        ParkMouse()
        Sleep 1500
    }
    win := false
    Loop 4 {
        if OcrLineY([1100, 270, 450, 100], "i)Select|Diffic") {
            win := true
            break
        }
        Sleep 700
    }
    static winDay := ""
    if win && winDay != XdimGameDay() {                    ; once a day: what the window says (does it name the map?) - for checking the list
        winDay := XdimGameDay()
        Log("  Extreme window text: " RegExReplace(OcrRegion([1100, 150, 600, 800]), "\s+", " "))
        Screenshot("xdim_win")
    }
    if !win {
        Log("  Extreme Dimension: the difficulty window did not open")
        if ++fails = 1
            Screenshot("xdim_nowin")
        return
    }
    ok := false
    Loop 3 {
        y := OcrLineY([1166, 340, 320, 330], "i)" nm4)
        ClickXY(1323, y ? y : [395, 475, 556, 637][pick])
        ParkMouse()
        Sleep 600
        txt := OcrRegion([1100, 690, 450, 90])
        if RegExMatch(txt, "i)" nm4) && !RegExMatch(txt, "i)None") {
            ok := true
            break
        }
    }
    if !ok {
        Log("  Extreme Dimension: difficulty " nm " not set")
        if ++fails = 1
            Screenshot("xdim_diff")
        return
    }
    fails := 0
    xdimMapNow := XdimMap()                                ; fixed for this run and its RETRY replays (DimDir)
    Log("  Extreme: today = " XdimName(xdimMapNow) " (" XdimPos() "/" XdimCycle().Length ", game day " XdimGameDay() ", map change " Mod(XdimIni("xdimResetUtc", "0"), 24) ":00 UTC)")
    sy := OcrLineY([1100, 780, 450, 100], "i)Star")
    ClickXY(1323, sy ? sy : 836)
    ParkMouse()
    Log("  Extreme Dimension: " nm " started, the run begins in " Num("xdimWait", 15) " s")
    SetEntered("dungeon")
    routeDone := true, dimRunAt := A_TickCount, dimHandled := false
    xdimStartAt := A_TickCount
    RunRoute(DimRoute())
}

; "TELEPORT" (big white word, middle of the screen) read every 2 s; seen for 10 s in a row -> restart Roblox
DimStuck() {
    static since := 0, at := 0
    if A_TickCount - at < 2000
        return false
    at := A_TickCount
    if !RegExMatch(OcrRegion([300, 150, 1320, 500]), "i)TELEPORT") {
        since := 0
        return false
    }
    if !since {
        since := A_TickCount
        Log("  Dimension: TELEPORT on screen - a mob was missed?")
    }
    if A_TickCount - since < 10000
        return false
    since := 0
    Screenshot("dim_teleport")
    RestartRoblox("Dimension: TELEPORT on screen for 10 s (a mob was missed)", , 60000)
    return true
}
; Dimension results (S rank, RETRY / LEAVE): both words in the button row, read with OCR every 0.3 s. Nothing is
; counted - RETRY at once, so the same run starts again (LEAVE at raid time). The leave.png picture does not match
; here (the buttons are translucent over another scene), and Infinity's light-panel points fall on the reward cards.
; Click points from the results screen 3.11 (1920x1080): RETRY 757,795, LEAVE 1350,795.
DimRetry() {
    global routeDone, lastFight, lastReset, dimRetryAt, dimRunAt, dimHandled, retryPending, xdimStartAt
    static at := 0, pressAt := 0
    if A_TickCount - at < 300
        return false
    at := A_TickCount
    txt := OcrRegion([450, 730, 1150, 120])
    ; only LEAVE, no RETRY, "Teleporting in 0": the game's teleport hung (player 9.11 22:52, Extreme: the bot waited
    ; 10 min). Seen for 5 s (one OCR miss of RETRY must not trigger a restart). LEAVE never helped
    ; (11.11: 0 of 32), so restart the game at once after the 5 s
    static onlyLeave := 0
    if RegExMatch(txt, "i)leave") && !RegExMatch(txt, "i)retry") {
        onlyLeave := onlyLeave || A_TickCount
        if A_TickCount - onlyLeave < 5000
            return true
        lastFight := A_TickCount - FIGHT_STICKY, dimRunAt := 0
        if !dimHandled
            dimHandled := true, Stat("dimRuns")
        onlyLeave := 0
        Log("Dimension results without RETRY (the game's teleport hung) - restarting Roblox")
        Screenshot("dim_onlyleave")
        RestartRoblox("Dimension: results without RETRY (teleport hung)", , 60000)
        return true
    }
    onlyLeave := 0
    if !RegExMatch(txt, "i)retry") || !RegExMatch(txt, "i)leave") {
        if retryPending                                   ; the results are gone: RETRY worked, arm the route for the new run
            retryPending := false, routeDone := false, xdimStartAt := A_TickCount   ; Extreme / Halloween / Death: the wait starts again
        return false
    }
    lastFight := A_TickCount - FIGHT_STICKY                ; not a fight any more
    lastReset := A_TickCount + 30000 - RESET_EVERY
    if A_TickCount - pressAt < 2500                       ; just pressed - give the game a moment
        return true
    pressAt := A_TickCount, dimRunAt := 0                ; results reached: the 2 min watch is over
    ReleaseKeys()
    first := !dimHandled                                  ; one results screen: count and read it once, even if RETRY is pressed again
    dimHandled := true
    if first
        DimCardsStart()
    if Target() = "dungeon" {
        SetStatus("Dimension results: pressing RETRY")
        ; routeDone stays true until the results are gone (below): a click the game ignored ("0 Players want to retry") is pressed again
        retryPending := true, dimRetryAt := A_TickCount
        if first
            Stat("dimRuns")
        else
            Log("  RETRY still on screen - pressing again")
        ClickXY(757, 795)
    } else {
        SetStatus("Dimension results: raid time, pressing LEAVE")
        ClickXY(1350, 795)
    }
    ParkMouse()
    return true
}

; The first enemies (the giants) ahead at the spawn: giant-coloured pixels in DIM_MOBS, every 4th px. Two looks:
; lit orange (3.11 recording: 915 of 3010) and dark red-brown in the shade at the start (3.11 screenshot: 868).
; Frames later in the run give up to ~290, the lobby is held off by the PLAY / menu checks in RunRoute.

MobsCount() {
    b := DIM_MOBS, px := GrabPixels(b[1], b[2], b[3], b[4]), n := 0
    y := 0
    while y < b[4] {
        x := 0
        while x < b[3] {
            c := NumGet(px, (y * b[3] + x) * 4, "uint")
            r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, bl := c & 0xFF
            if r > 135 && r < 240 && g > 60 && g < 150 && bl < 70 && r - g > 50        ; lit
                n++
            else if r >= 20 && r <= 90 && g * 2 <= r && bl * 3 <= r                  ; in the shade
                n++
            x += 4
        }
        y += 4
    }
    return n
}

; Гортає список рейдів колесом. Roblox ловить колесо лише над списком після руху миші,
; тому спершу ворушимо мишу, а оберти шлемо по одному.
ListWheel(dir, n, gap := 25) {
    b := RAID_LIST
    cx := b[1] + 60, cy := b[2] + b[4] // 2
    MouseMove cx + 8, cy + 8, 0
    Sleep 80
    MouseMove cx, cy, 0
    Sleep 150
    Loop n {
        Send "{Wheel" dir "}"
        Sleep gap
    }
    Sleep 700
}

; поточний loadout з кнопки "Loadout N" у відкритому Bag (0 - не прочитали: Bag не відкритий)
; 12.11 (player "Loudout 1"): OCR glued the 1 to the word ("Loudoutl V") - l / I / | / ! right after the word are read as 1
ReadLoadout() => RegExMatch(OcrRegion(LOADOUT_BOX), "i)Lo[au]?d\w*?\s*([\dlI|!])(?!\w)", &m) ? (IsDigit(m[1]) ? Integer(m[1]) : 1) : 0

; Поставити loadout n (Bag -> список угорі -> рядок). Стан пам'ятаємо, тож Bag відкриваємо лише при зміні;
; якщо не вийшло - пауза (щоб не застрягти в лобі): Bag did not open (телепорт, вікно гри) - 1 min,
; Bag відкрився, але loadout не перемкнувся - 10 min.
; Loadout switching is off: read once after Start which loadout is active, so the log, the Dashboard and the
; "raid without loadout 1" warning show the real number.
CheckLoadoutOnce() {
    global curLoadout, loadoutChecked
    if loadoutChecked
        return
    loadoutChecked := true
    SetStatus("checking the current loadout")
    cur := 0
    Loop 2 {
        if !running
            return
        ClickXY(BAG_BTN[1], BAG_BTN[2])
        Sleep 1800
        if cur := ReadLoadout()
            break
        Sleep 1000
        if cur := ReadLoadout()
            break
    }
    if cur {
        curLoadout := cur
        ClickXY(BAG_CLOSE[1], BAG_CLOSE[2])
    }
    ParkMouse()
    Sleep 800
    Log("  current loadout: " (cur ? cur : "could not be read"))
}

EnsureLoadout(n, onlyCheck := false) {
    global curLoadout
    static failAt := 0, failWait := 0, failN := 0
    ; пауза після невдачі - лише для того самого loadout (28.10 21:40: невдача з 3 не має блокувати повернення на 2)
    if cfg["loadouts"] != "1" || curLoadout = n || (failAt && failN = n && A_TickCount - failAt < failWait)
        return false
    if onlyCheck                                          ; лише питаємо: чи треба міняти loadout
        return true
    SetStatus("loadout " n ": opening Bag")
    ; одразу після телепорту лобі ще довантажується і клік по Bag губиться (28.10 16:03: рейд пішов
    ; з loadout 2) - до 3 спроб; перш ніж клікати знову, ще раз читаємо (Bag міг відкритись пізніше)
    cur := 0
    Loop 3 {
        if !running
            return false
        if A_Index > 1 {
            Log("  loadout " n ": Bag did not open - attempt " A_Index)
            ClickXY(MODES_CLOSE[1], MODES_CLOSE[2])           ; 07.11: меню режимів лишилось відкритим після LEAVE і закриває Bag
            Sleep 1500
        }
        ClickXY(BAG_BTN[1], BAG_BTN[2])
        Sleep 1800
        if cur := ReadLoadout()
            break
        Sleep 1000
        if cur := ReadLoadout()
            break
    }
    bagOpen := cur != 0
    if !running
        return false
    ; 11.11 (player log 14:00, 14:57): "loadout 1 failed (read: 2)" right after a restart/teleport, the same switch worked a minute later -
    ; the list opens slowly there and the row click lands on nothing. Now: a longer wait for the list and one more try at once.
    Loop 2 {
        if !(cur && cur != n)
            break
        SetStatus("loadout " cur " -> " n (A_Index > 1 ? " (again)" : ""))
        ClickXY(LOADOUT_BOX[1] + LOADOUT_BOX[3] // 2, LOADOUT_BOX[2] + LOADOUT_BOX[4] // 2)
        Sleep A_Index = 1 ? 1400 : 2000
        if !running
            return false
        if failAt || A_Index > 1                          ; a retry: also the picture of the opened list (where the rows really are)
            Screenshot("loadout_list")
        ClickXY(LOADOUT_ROWS[n][1], LOADOUT_ROWS[n][2])
        Sleep 1500
        ; одразу після перемикання кнопка часом не читається (28.10 21:40: "Switched to Loadout 3" був,
        ; а OCR - порожньо) - ще кілька спроб
        Loop 4 {
            if cur := ReadLoadout()
                break
            Sleep 700
        }
    }
    ; 11.11 (player report): the picture of a failed switch was taken after the Bag was closed and showed nothing. Now it is taken
    ; right here, with the Bag as the bot sees it (open or not), before it is closed.
    if cur != n
        Screenshot("loadout_bag")
    if bagOpen                                            ; Bag відкритий - закриваємо (навіть якщо не прочитали)
        ClickXY(BAG_CLOSE[1], BAG_CLOSE[2])
    ParkMouse()
    Sleep 800
    if cur = n {
        curLoadout := n, failAt := 0
        Log("  loadout " n " ✓")
    } else {
        ; перемикали, а що стоїть - не знаємо: наступного разу перевіримо в Bag, а не повіримо старому
        if bagOpen
            curLoadout := cur
        failAt := A_TickCount, failWait := cur && n != 1 ? 600000 : 60000, failN := n   ; для рейду (1) і з прочитаним номером - теж 1 min
        Log("  loadout " n " failed (read: " (cur ? cur : bagOpen ? "nothing after switching" : "Bag did not open") ") - retrying in " failWait // 60000 " min")
    }
}

; Меню режимів відкрите, а loadout ще не той (бота перезапустили з відкритим меню - 28.10 19:12 Speed Raid
; пішов з loadout 2; або меню лишилось після невдалого Speed Raid) - закриваємо меню: у лобі EnsureLoadout
; поставить потрібний, а тоді знову PLAY.
MenuLoadoutWrong(n) {
    static lastLog := 0
    if !EnsureLoadout(n, true)
        return false
    SetStatus("modes menu: loadout first " n " - closing the menu")
    if A_TickCount - lastLog > 60000 {
        lastLog := A_TickCount
        Log("modes menu: loadout is not yet " n " - closing menu, will set it in the lobby")
    }
    ClickXY(MODES_CLOSE[1], MODES_CLOSE[2])
    ParkMouse()
    Sleep 800
    ; 8.11 01:11-01:15: dimension.png matched in a plain lobby (no menu: PLAY visible), so this branch ran again and again and the
    ; lobby branch with EnsureLoadout never got its turn. The lobby is visible now - set the loadout right here.
    if SeePlay(&px, &py)
        EnsureLoadout(n)
    return true
}

; секунд до тижневого скидання Speed Raid з рядка "Weekly Reset in: 1 Day 3 Hours 5 Minutes" (0 - не прочитали):
; після нього використані персонажі знову вільні
SpeedResetSec() {
    txt := OcrRegion(SPEED_RESET_BOX)
    if !InStr(txt, "eset")
        return 0
    s := 0
    if RegExMatch(txt, "i)(\d+)\s*d", &m)
        s += m[1] * 86400
    if RegExMatch(txt, "i)(\d+)\s*h", &m)
        s += m[1] * 3600
    if RegExMatch(txt, "i)(\d+)\s*m", &m)
        s += m[1] * 60
    return s
}

; наступна спроба Speed Raid - через sec секунд (пам'ятаємо в raid.ini, щоб пережити перезапуск бота)
SpeedLater(sec) {
    global speedDue
    speedDue := DateAdd(A_Now, sec, "Seconds")
    IniWrite speedDue, INI, "state", "speedDue"
}

; Меню режимів -> Speed Raid: картка -> Start -> найнижчий вільний персонаж -> Start.
; Будь-яка невдача - закриваємо вікно і пробуємо через 2 min (щоб не застрягти в лобі).
SpeedEnter(x, y) {
    global raidWalkDue, infLootDone, raidShotDone, lastDmg, dmgChanged, searchTurns, sameReads
    global learnLeft, comboSeen, lastCombo, portraitSig, walkAt, speedFails
    ready := Trim(OcrRegion(SPEED_READY_BOX), " `r`n")
    ; на картці таймер замість "Ready to enter": "Ready in 00:01:13" (год:хв:с) - теж "Ready", тож дивимось на
    ; час (28.10 19:09: бот прийняв таймер за готовність, Start у вікні вибору не спрацював, меню зависло)
    timer := RegExMatch(ready, "(\d+)\s*[:.]\s*(\d\d)(?:\s*[:.]\s*(\d\d))?", &m)
    if timer || ready != "" && (!InStr(ready, "Ready") || RegExMatch(ready, "i)Ready\s*in")) {
        wait := !timer ? 120 : m[3] != "" ? m[1] * 3600 + m[2] * 60 + m[3] + 10 : m[1] * 60 + m[2] + 10
        Log("  Speed Raid not available yet (" ready ") - trying again in " Ceil(wait / 60) " min")
        SpeedLater(wait)
        ; закриваємо меню режимів: у лобі бот знову поставить loadout для Infinity (а не піде в неї з loadout 3)
        ClickXY(MODES_CLOSE[1], MODES_CLOSE[2])
        ParkMouse()
        Sleep 800
        return
    }
    SetStatus("Speed Raid: opening")
    ; меню режимів ще виїжджає - клік по картці в цей момент гра ігнорує (28.10 09:40: вікно не відкрилось,
    ; і Speed Raid зсунувся на 12 min). Чекаємо, клікаємо, а якщо вікна нема 3 с - ще раз.
    Sleep 700
    opened := false
    Loop 2 {
        if FindImg("speed_mode.png", &x, &y, 700, 860, 1300, 1000)
            ClickImg("speed_mode.png", x, y)
        ParkMouse()
        t0 := A_TickCount
        while !(opened := InStr(OcrRegion(SPEED_TITLE_BOX), "Speed")) && A_TickCount - t0 < 3000
            Sleep 300
        if opened
            break
        Log("  Speed Raid: window did not open - pressing the card again")
    }
    if !opened
        return SpeedFail("Speed Raid window did not open")
    resetSec := SpeedResetSec()                          ; the weekly reset is shown under the title
    Log("  Speed Raid: weekly reset in " (resetSec ? resetSec // 3600 " h " Mod(resetSec // 60, 60) " min" : "? (not read)"))
    ClickXY(SPEED_START[1], SPEED_START[2])
    ParkMouse()
    Sleep 2000
    if !InStr(OcrRegion(SPEED_TITLE_BOX), "Select")
        return SpeedFail("character list did not open")
    SetStatus("Speed Raid: looking for a free character")
    if !PickSpeedChar(&cx, &cy) {
        wait := resetSec ? resetSec + 180 : 6 * 3600           ; until the weekly reset (+3 min), 6 h if it was not read
        Log("  Speed Raid: no free characters (all played this week) - next try after the weekly reset in " Ceil(wait / 3600) " h")
        Screenshot("speed_chars")
        ClickXY(SPEED_CLOSE[1], SPEED_CLOSE[2])
        Sleep 1000
        if InStr(OcrRegion(SPEED_TITLE_BOX), "Speed")      ; під списком ще вікно Speed Raid (див. SpeedFail)
            ClickXY(SPEED_CLOSE[1], SPEED_CLOSE[2])
        ParkMouse()
        SpeedLater(wait)
        return
    }
    ; персонаж -> Start; якщо вікно вибору не закрилось (28.10 14:09: Start "не спрацював", вікно висіло
    ; 12 min і бот перезапустив Roblox) - ще раз персонаж і Start, а тоді закриваємо й пробуємо пізніше
    Loop 2 {
        ClickXY(cx, cy)
        ParkMouse()
        Sleep 700
        ClickXY(SPEED_GO[1], SPEED_GO[2])
        ParkMouse()
        Sleep 2500
        if !InStr(OcrRegion(SPEED_TITLE_BOX), "Select")
            break
        if A_Index = 2 {
            Screenshot("speed_nogo")
            return SpeedFail("Start did not work (character window did not close)")
        }
        Log("  Speed Raid: character window still open after Start - selecting again")
    }
    SetEntered("speed")
    SpeedLater(SPEED_EVERY)               ; запас, якщо кінець бою не побачимо; точний час - після перемоги (Step)
    speedFails := 0
    FlushRun()
    infLootDone := false, raidShotDone := false
    lastDmg := "", dmgChanged := A_TickCount, searchTurns := 0, sameReads := 0
    raidWalkDue := true, learnLeft := 0, comboSeen := false, lastCombo := 0
    AutoReset()
    portraitSig := "", walkAt := 0
    Stat("speedRuns")
    Log("Speed Raid: start (character x=" cx " y=" cy ")")
    ; телепорт: кілька секунд ще видно лобі з PLAY - чекаємо, поки воно зникне, інакше бот
    ; знову тисне Bag/PLAY посеред телепорту (28.10: loadout 2 "не вдалося" і 10 min без зміни)
    t0 := A_TickCount
    Sleep 3000
    while A_TickCount - t0 < 40000 && running && FindImg("play.png", &px, &py, 1500, 800, 1920, 1060)
        Sleep 500
    Sleep 2000
}

; Speed Raid, щойно підійшли до боса: E і R майже разом, X, Z, через 1 с - 5 4 3 2 1 по черзі.
; Зазвичай бос гине вже від цієї серії; далі - звичайний бій (скіли й помічники по готовності).
; Скіл під час анімації попереднього "з'їдається" - тиснемо, поки не піде на перезарядку (до 3 s left).
SpeedOpener() {
    global lastCast
    SetStatus("Speed Raid: E R X Z, then " SPEED_ORDER)
    Send "{e}"
    Sleep 60
    Send "{r}"
    Sleep 200
    Send "{x}"
    Sleep 200
    Send "{z}"
    Sleep 1000
    done := ""
    for k in StrSplit(SPEED_ORDER, " ") {
        if !SkillReady(k)                                 ; порожній слот 5 (не в усіх персонажів) - далі
            continue
        t0 := A_TickCount
        Loop {
            Send "{" k "}"
            Sleep 250
            if !SkillReady(k) {
                done .= k " "
                break
            }
        } until A_TickCount - t0 > 3000 || !running
    }
    lastCast := A_TickCount
    Log("Speed Raid: opening series E R X Z, skills fired: " (done = "" ? "none" : Trim(done)))
}

; перша невдача - повтор через 2 min (зазвичай випадковість); якщо знову - через 10 min,
; щоб не виходити з Infinity щокілька minилин, коли щось зламалось надовго
SpeedFail(why) {
    global speedFails
    ; 3 невдачі поспіль - найімовірніше, вільних персонажів уже нема (обрали затемненого, Start не йде):
    ; не виходимо з Infinity щодесять minилин, а відкладаємо Speed Raid на 6 год
    wait := ++speedFails >= 3 ? 6 * 3600 : speedFails > 1 ? 600 : 120
    Log("  Speed Raid: " why " - trying again in " wait // 60 " min" (wait > 3600 ? " (" speedFails " failures in a row, then Infinity)" : ""))
    Screenshot("speed_fail")
    ClickXY(SPEED_CLOSE[1], SPEED_CLOSE[2])
    ; хрестик списку персонажів повертає у вікно Speed Raid - закриваємо і його (29.10 16:21: бот лишився
    ; у вікні Speed Raid і чекав, "екран не розпізнано")
    Sleep 1000
    if InStr(OcrRegion(SPEED_TITLE_BOX), "Speed")
        ClickXY(SPEED_CLOSE[1], SPEED_CLOSE[2])
    ParkMouse()
    SpeedLater(wait)
}

; Найнижчий вільний персонаж (у кінці списку - найслабші). Використані цього тижня - затемнені.
; Гортаємо повзунком у самий низ; якщо там усі темні - піднімаємось по 120 px.
PickSpeedChar(&cx, &cy) {
    global speedBarX
    b := SPEED_GRID
    speedBarX := FindBarX()
    Log("  Speed Raid: scroll bar " (speedBarX ? "found at x=" speedBarX : "not found - scrolling with the mouse wheel"))
    if !speedBarX
        return PickSpeedCharWheel(&cx, &cy)
    DragBar(b[2] + 45, b[2] + b[4] + 80)                  ; повзунок на початку списку -> униз до упору
    Sleep 800
    thumb := b[2] + b[4] - 45
    Loop 8 {
        ; обрізаний верхній ряд (видно лише край) не беремо: клік туди влучав у затемнену клітинку нижче
        ; (29.10 16:18) - його покаже прокрутка колесом нижче
        if SpeedScan(&cx, &cy) && cy > b[2] + 70
            return true
        if thumb - 120 < b[2]
            break
        DragBar(thumb, thumb - 120)
        thumb -= 120
        Sleep 700
    }
    ; кроки по 120 px не доходять до самого верху - верхній ряд лишався обрізаним, і вільних там не бачили
    ; (29.10 15:09 "вільних нема", а вгорі було ще 5) - насамкінець повзунок до упору вгору
    DragBar(thumb, b[2] - 80)
    Sleep 500
    ; і повзунок до упору не догортає (29.10 16:18: перший ряд видно лише краєм) - догортаємо колесом
    MouseMove b[1] + b[3] // 2 + 8, b[2] + b[4] // 2 + 8, 0
    Sleep 80
    MouseMove b[1] + b[3] // 2, b[2] + b[4] // 2, 0
    Sleep 150
    Loop 15 {
        Send "{WheelUp}"
        Sleep 30
    }
    Sleep 800
    return SpeedScan(&cx, &cy)
}

; Не затемнені клітинки в кожному стовпчику: у вікні 120 px заввишки > 5% світлих точок (> 100).
; Затемнений персонаж - максимум ~55, порожньо ~27; вільний темний (чорне волосся й одяг) у середньому лише ~72
; (29.10 13:08: середнє > 100 його не бачило - "вільних нема", хоча він був). Перевірено на 6 знімках списку.
; Беремо найнижчу, при рівних - праву.
SpeedScan(&cx, &cy) {
    b := SPEED_GRID, win := 120
    px := GrabPixels(b[1], b[2], b[3], b[4])
    best := 0, cx := 0, cy := 0
    for col in SPEED_COLS {
        x0 := col - b[1] - 50
        rows := []
        Loop b[4] {                                       ; скільки світлих точок у кожному рядку смуги 100 px
            y := A_Index - 1, s := 0
            Loop 25 {
                c := NumGet(px, (y * b[3] + x0 + (A_Index - 1) * 4) * 4, "uint")
                s += Max(c >> 16 & 0xFF, c >> 8 & 0xFF, c & 0xFF) > 100
            }
            rows.Push(s)
        }
        sum := 0
        Loop win
            sum += rows[A_Index]
        start := 0
        Loop b[4] - win {                                 ; ковзне вікно, запам'ятовуємо найнижче не затемнене
            if sum / (win * 25) > 0.05
                start := A_Index
            sum += rows[A_Index + win] - rows[A_Index]
        }
        if !start
            continue
        ; клік - у середину клітинки: низ світлої частини (рядки рамки, де світле все, не рахуємо) мінус 80 px
        ; (клітинка ~190 px). Раніше центр вікна падав на нижній край клітинки - клік влучав у затемнену
        ; нижче, "Character has already been used" (29.10 16:23)
        bottom := start
        Loop win
            if (n := rows[start + A_Index - 1]) >= 3 && n < 20
                bottom := start + A_Index - 1
        found := Max(20, bottom - 80)
        if found >= best - 60 {                           ; нижче або той самий ряд (стовпчики йдуть зліва направо)
            best := Max(best, found)
            cx := col, cy := b[2] + found
        }
    }
    return cx != 0
}

; X of the list's scroll thumb: the only light grey vertical strip right of the character cards.
; The window is narrow on purpose (the cards' light borders must stay out); 0 - not found (other UI scale).
FindBarX() {
    b := SPEED_GRID
    x0 := SPEED_BAR_X - 15, w := 45
    px := GrabPixels(x0, b[2], w, b[4])
    col := []
    best := 0
    Loop w {
        x := A_Index - 1, n := 0
        Loop b[4] {
            c := NumGet(px, ((A_Index - 1) * w + x) * 4, "uint")
            r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, bl := c & 0xFF
            if Min(r, g, bl) > 140 && Max(r, g, bl) - Min(r, g, bl) < 40
                n++
        }
        col.Push(n)
        best := Max(best, n)
    }
    if best < 25
        return 0
    first := 0, last := 0
    for i, n in col
        if n >= best * 0.7 {
            first := first ? first : i
            last := i
        }
    return x0 + (first + last) // 2 - 1
}

; no scroll bar found: bottom of the list with the wheel, then up in small steps (the whole list is scanned each time)
PickSpeedCharWheel(&cx, &cy) {
    b := SPEED_GRID
    SpeedWheel("Down", 60)
    Loop 25 {
        if SpeedScan(&cx, &cy) && cy > b[2] + 70
            return true
        SpeedWheel("Up", 3)
    }
    SpeedWheel("Up", 40)
    return SpeedScan(&cx, &cy)
}

SpeedWheel(dir, n) {
    b := SPEED_GRID
    MouseMove b[1] + b[3] // 2 + 8, b[2] + b[4] // 2 + 8, 0
    Sleep 80
    MouseMove b[1] + b[3] // 2, b[2] + b[4] // 2, 0
    Sleep 150
    Loop n {
        Send "{Wheel" dir "}"
        Sleep 30
    }
    Sleep 700
}

; тягне повзунок списку персонажів від y1 до y2 (Roblox рахує клік лише після наведення)
DragBar(y1, y2) {
    x := speedBarX
    MouseMove x + 3, y1 + 3, 0
    Sleep 80
    MouseMove x, y1, 0
    Sleep 150
    Click "Down"
    Sleep 120
    Loop 10 {
        MouseMove x, y1 + (y2 - y1) * A_Index // 10, 0
        Sleep 30
    }
    Sleep 120
    Click "Up"
}

; посилання на приватний сервер: raid.ini [raid] serverLink (порожнє значення - без сервера), інакше сервер автора
PrivateLink() => Trim(IniRead(INI, "raid", "serverLink", SERVER_LINK))

; share link -> the same server via roblox:// straight in the Roblox client, no browser (05.11: user has no logged-in browser)
; shortcut: only roblox.com/share?code= links are converted, other link types still open the browser
ProtoLink(link) {
    if RegExMatch(link, "i)roblox\.com/share\?code=(\w+)", &m)
        return "roblox://navigation/share_links?code=" m[1] "&type=Server"
    ; 06.11: an old games/<id>?privateServerLinkCode= link could not be opened (no default browser) - Roblox client straight away
    if RegExMatch(link, "i)roblox\.com/games/(\d+).*[?&]privateServerLinkCode=(\w+)", &m)
        return "roblox://experiences/start?placeId=" m[1] "&linkCode=" m[2]
    return link
}

; ID гри для перезапуску: raid.ini [raid] placeId (можна вписати і посилання на гру), інакше Anime Dimensions Simulator
PlaceId() {
    id := IniRead(INI, "raid", "placeId", "6938803436")
    return RegExMatch(id, "\d{5,}", &m) ? m[0] : "6938803436"
}

; the Windows session the bot runs in (RDP: not the PC's own session 1)
MySession() {
    static s := -1
    if s < 0 {
        v := 0
        DllCall("ProcessIdToSessionId", "uint", DllCall("GetCurrentProcessId", "uint"), "uint*", &v)
        s := v
    }
    return s
}
; RobloxPlayerBeta.exe of this session only, 0 = none
MyRobloxPid() {
    try {
        for p in ComObjGet("winmgmts:").ExecQuery("SELECT ProcessId, SessionId FROM Win32_Process WHERE Name = 'RobloxPlayerBeta.exe'")
            if p.SessionId = MySession()
                return p.ProcessId
    } catch
        return ProcessExist("RobloxPlayerBeta.exe")       ; no WMI: the old way
    return 0
}

; Закрити Roblox і зайти в гру знову (протокол roblox://). Повертає true, якщо вікно гри з'явилось.
; mode: "auto" - спершу браузер, потім roblox://; "browser" / "proto" - лише цей спосіб (тест, без паузи 10 min)
RestartRoblox(why, mode := "auto", gap := RESTART_GAP) {
    global lastRestart, fightSince, portraitSig, walkAt, noGameSince, lastFight, dimRunAt, dimRetryAt, routeDone, retryPending, xdimStartAt, problemNote
    if mode = "auto" && A_TickCount - lastRestart < gap && lastRestart
        return false
    lastRestart := A_TickCount
    ; 05.11 18:58: the run watch (no RETRY 2 min) outlived the restart and restarted Roblox again while the raid loadout was being chosen
    dimRunAt := 0, dimRetryAt := 0, routeDone := false, retryPending := false, xdimStartAt := 0
    SetStatus("restarting Roblox: " why)
    Stat("restarts")
    Screenshot("restart")
    ReleaseKeys()
    ; як у WaitGame: перервати, якщо бота зупинили (F2); режими тесту (не auto) не перериваємо
    stopped := () => !(running || mode != "auto")
    if stopped() {
        Log("restart interrupted: bot stopped")
        return false
    }
    ; закриваємо гру, як хрестиком вікна; якщо не закрилась за 10 с - знімаємо процес
    if WinExist(GAME) {
        WinClose GAME
        WinWaitClose GAME, , 10
    }
    ; 10.11 (RDP test): only Roblox of THIS Windows session - in RDP the PC's own user may have Roblox open in session 1;
    ; ProcessExist saw it, the bot waited 30 s for nothing and then would not start the game
    while (pid := MyRobloxPid()) && A_TickCount - lastRestart < 30000 {
        ProcessClose pid
        Sleep 1000
    }
    ; guaranteed close: still alive -> taskkill /F /T (with children), then crash handler; log the outcome
    if pid := MyRobloxPid() {
        Log("WARNING: Roblox did not close in 30 s, taskkill /F /T")
        loop 3 {
            try RunWait("taskkill /F /T /PID " pid, , "Hide")
            Sleep 1000
            if !(pid := MyRobloxPid())
                break
        }
        if MyRobloxPid() {
            Log("WARNING: Roblox STILL running after taskkill - not starting a second copy, the next restart tries again")
            problemNote := "Roblox does not close"
            return false
        } else
            Log("Roblox closed by taskkill")
    }
    try RunWait('taskkill /F /IM RobloxCrashHandler.exe /FI "SESSION eq ' MySession() '"', , "Hide")
    Sleep 3000
    ; спершу браузер (Join приватного сервера); не відкрилась гра за 60 с - запасний шлях roblox:// (публічний сервер)
    ok := false
    if stopped() {
        Log("restart interrupted: bot stopped")
        return false
    }
    if mode != "proto" && PrivateLink() = "" && JoinFromBrowser() {
        ok := WaitGame(mode = "browser" ? 120000 : 60000, mode)
        if stopped() {
            Log("restart interrupted: bot stopped")
            return false
        }
        if !ok {
            Log("  game did not open after Join")
            Screenshot("join_fail")                       ; що показує браузер (запит "Відкрити Roblox?", помилка)
        }
    }
    if !ok && mode != "browser" {
        id := PlaceId()
        if id = "" {
            Log("RESTART IMPOSSIBLE: game ID unknown (raid.ini [raid] placeId)")
            return false
        }
        if stopped() {
            Log("restart interrupted: bot stopped")
            return false
        }
        link := PrivateLink()
        Log("  launching " (link != "" ? "private server link" : "via roblox://, game " id))
        launched := true
        try Run link != "" ? ProtoLink(link) : "roblox://experiences/start?placeId=" id
        catch as e {
            Log("  could not launch Roblox: " e.Message)
            launched := false                             ; 06.11: was "return false" - 5 h of the same failure; now plain roblox:// below
        }
        ok := launched && WaitGame(link != "" ? 60000 : 120000, mode)
        if stopped() {
            Log("restart interrupted: bot stopped")
            return false
        }
        ; 02.11 12:17: the share link only opened a roblox.com tab ("Download Roblox") and the game never started for 9 h -> plain roblox:// next
        if !ok && link != "" {
            Log("  private server link did not start the game - trying roblox://, game " id)
            Screenshot("join_fail")
            try Run "roblox://experiences/start?placeId=" id
            ok := WaitGame(120000, mode)
            if stopped() {
                Log("restart interrupted: bot stopped")
                return false
            }
        }
    }
    ; 13.11: on players' PCs the Roblox app keeps logging itself out, so roblox:// lands on its Sign In page and the bot
    ; waited there forever. The browser stays signed in: close the app and start the game through a roblox.com link instead.
    if ok && mode != "browser" && SignInScreen() {
        Log("  Roblox app shows its Sign In page (app logged out) - starting the game through the browser")
        Screenshot("signin")
        WinClose GAME
        WinWaitClose GAME, , 10
        if pid := MyRobloxPid()
            ProcessClose pid
        Sleep 3000
        link := PrivateLink()
        web := RegExMatch(link, "i)^https?://(www\.)?roblox\.com/") ? link : "https://www.roblox.com/games/start?placeId=" PlaceId()
        try Run web
        ok := WaitGame(120000, mode) && !SignInScreen()
        if !ok {
            Log("WARNING: the game did not start through the browser either - sign in at roblox.com in your default browser")
            problemNote := "Roblox app logged out - sign in at roblox.com in your browser"
        }
    }
    if !ok {
        Log("  Roblox window never appeared")
        return false
    }
    if stopped() {
        Log("restart interrupted: bot stopped")
        return false
    }
    Sleep 15000                                          ; гра вантажиться
    FixGameWindow()
    Log("  Roblox started again in " (A_TickCount - lastRestart) // 1000 " s")
    fightSince := 0, lastFight := 0, portraitSig := "", walkAt := 0, noGameSince := 0
    return true
}

; the logged-out Roblox app: "Sign In" / "Create Account" in the middle of its window (looks for up to 20 s while it loads)
SignInScreen() {
    t0 := A_TickCount
    while A_TickCount - t0 < 20000 && WinExist(GAME) {
        try {
            WinActivate GAME
            WinGetClientPos &cx, &cy, &cw, &ch, GAME
            if RegExMatch(OcrRegion([cx + cw // 2 - 300, cy + ch // 3, 600, ch // 2]), "i)sign\s*in|create\s*account")
                return true
        }
        Sleep 3000
    }
    return false
}

; чекаємо вікно гри до ms ms (під час роботи бота - лише поки його не зупинили)
WaitGame(ms, mode) {
    t0 := A_TickCount
    while !WinExist(GAME) && A_TickCount - t0 < ms && (running || mode != "auto")
        Sleep 1000
    return WinExist(GAME) != 0
}

; Гра має бути розгорнутим вікном (з рамкою, над панеллю задач) - на це розраховані всі координати.
; Повний екран (F11) і мале вікно виправляємо.
FixGameWindow() {
    static lastFix := 0
    if !WinExist(GAME) || A_TickCount - lastFix < 10000   ; не смикати вікно частіше, ніж раз на 10 с
        return
    lastFix := A_TickCount
    WinActivate GAME
    Sleep 300
    WinGetClientPos , , , &ch, GAME
    if ch >= A_ScreenHeight {                             ; повний екран без рамки - вимикаємо його
        Log("  game opened fullscreen - F11")
        Send "{F11}"
        Sleep 2000
    }
    FitGameWindow()
}

GameSizeOk(cw, ch) => cw = GAME_W && Abs(ch - GAME_H) <= 2

; a normal (not maximised) window with the client area of exactly GAME_W x GAME_H at the top left of the screen
FitGameWindow() {
    if WinGetMinMax(GAME) != 0 {
        WinRestore GAME
        Sleep 600
    }
    Loop 3 {                                              ; borders and the title bar are different on every Windows: measure and correct
        WinGetPos &wx, &wy, &ww, &wh, GAME
        WinGetClientPos &cx, &cy, &cw, &ch, GAME
        WinMove wx + (0 - cx), wy + (23 - cy), ww + (GAME_W - cw), wh + (GAME_H - ch), GAME
        Sleep 600
    }
    WinGetClientPos &cx, &cy, &cw, &ch, GAME
    Log("  Roblox window set: client " cw "x" ch " at " cx "," cy)
    return GameSizeOk(cw, ch)
}

; Сторінка гри в браузері -> перша кнопка Join (приватний сервер). true, якщо натиснули.
JoinFromBrowser() {
    if !WinExist(BROWSER) {
        Log("  browser with the Anime Dimensions page not found")
        return false
    }
    WinActivate BROWSER
    if WinGetMinMax(BROWSER) != 1
        WinMaximize BROWSER
    Sleep 1500
    if PlayFromPage()                                     ; main way; Join on the Servers tab and roblox:// are the backups
        return true
    b := JOIN_BOX
    Loop 2 {
        ; перший темно-синій піксель згори, але лише якщо це кнопка (200x32): той самий колір і правіше, і нижче
        y := b[2], found := false
        while y < b[4] && PixelSearch(&jx, &jy, b[1], y, b[3], b[4], JOIN_COLOR, 12) {
            if SameColor(jx + 150, jy + 4, JOIN_COLOR, 20) && SameColor(jx + 2, jy + 26, JOIN_COLOR, 20) {
                found := true
                break
            }
            y := jy + 1
        }
        if found {
            ClickXY(jx + 80, jy + 15)
            ParkMouse()
            Log("  pressed Join in the browser (" jx + 80 ", " jy + 15 ")")
            return true
        }
        if A_Index = 1 {                                  ; сторінка могла застаріти - оновлюємо і пробуємо ще раз
            Send "{F5}"
            Sleep 10000
        }
    }
    Log("  Join button not found in the browser (is the Servers tab open?)")
    Screenshot("no_join")
    return false
}

; The big blue Play button of the game page (0x335FFF, 300x60): starts the game through the signed-in browser.
; 7.11: a plain roblox:// start showed the client's sign-in page and never got past it (and trusting the device did not help).
PlayFromPage() {
    y := 380
    while y < 620 && PixelSearch(&jx, &jy, 1240, y, 1700, 620, 0x335FFF, 8) {
        if SameColor(jx + 120, jy + 10, 0x335FFF, 12) && SameColor(jx + 120, jy + 45, 0x335FFF, 12) && SameColor(jx + 200, jy + 25, 0x335FFF, 12) {
            ClickXY(jx + 100, jy + 25)
            ParkMouse()
            Log("  pressed Play on the game page (" jx + 100 ", " jy + 25 ")")
            return true
        }
        y := jy + 1
    }
    return false
}

SameColor(x, y, color, tol) {
    c := Integer(PixelGetColor(x, y))
    return Abs((c >> 16 & 0xFF) - (color >> 16 & 0xFF)) <= tol && Abs((c >> 8 & 0xFF) - (color >> 8 & 0xFF)) <= tol
        && Abs((c & 0xFF) - (color & 0xFF)) <= tol
}

; відлік "Respawn in N" угорі по центру: обабіч напису дві тонкі білі лінії на висоті y=85..86
; (x 632..840 і 1117..1329; ліва буває на рядок вище за праву). На знімках рейдів 26.10 - лише на кадрах з відліком.
RespawnScreen() {
    px := GrabPixels(660, 84, 640, 5)                     ; рядки 84..88
    lineL := false, lineR := false
    Loop 5 {
        row := (A_Index - 1) * 640 * 4, l := 0, r := 0
        x := 0
        while x < 160 {                                   ; ліва лінія 660..820 і права 1140..1300, кожен 8-й піксель
            c := NumGet(px, row + x * 4, "uint")
            l += (c >> 16 & 0xFF) > 200 && (c >> 8 & 0xFF) > 200 && (c & 0xFF) > 200
            c := NumGet(px, row + (x + 480) * 4, "uint")
            r += (c >> 16 & 0xFF) > 200 && (c >> 8 & 0xFF) > 200 && (c & 0xFF) > 200
            x += 8
        }
        lineL := lineL || l >= 18, lineR := lineR || r >= 18   ; з 20 точок кожної лінії
    }
    return lineL && lineR
}

; ресет потрібен: персонаж без скіла 5 (resetNo5) або третій персонаж (resetThird)
NeedReset() => cfg["resetNo5"] = "1" && NoSkill5() || cfg["resetThird"] = "1" && charIdx >= 3

; Esc-R-Enter: персонаж вмирає, знову виходить перший
ResetNo5() {
    global rdResetNo5, lastNo5Reset, charIdx
    charIdx := 0                                          ; після ресету Respawn дасть першого -> стане 1
    Log("  unwanted character after respawn - resetting to get the first one again")
    Screenshot("unwanted_char")
    SetStatus("character reset: Esc-R-Enter")
    rdResetNo5++
    if lastNo5Reset && A_TickCount - lastNo5Reset < 20000
        Log("WARNING: two characters without skill 5 in a row - check the loadout")
    lastNo5Reset := A_TickCount
    if rdResetNo5 > 3
        Log("WARNING: too many resets without skill 5 (" rdResetNo5 " per raid)")
    HoldKey("Esc")
    Sleep 1000
    HoldKey("r")
    Sleep 800
    HoldKey("Enter")
}

; У персонажа немає скіла 5: замість ромба (готовий - рожевий/фіолетовий, перезарядка - сірий) крізь слот
; видно підлогу рейду - яскраву помаранчеву/червону без синього або жовту лаву (див. SkillReady)
NoSkill5() {
    c := SkillColor("5")
    r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, b := c & 0xFF
    return Max(r, g, b) - Min(r, g, b) > READY_SAT && (b < 40 || g > 110)
}

; майже весь екран чорний (сітка 5x5 точок темніша за 12)
BlackScreen() {
    Loop 5 {
        x := GAME_W * A_Index // 6
        Loop 5 {
            c := Integer(PixelGetColor(x, 23 + GAME_H * A_Index // 6))
            if (c >> 16 & 0xFF) > 12 || (c >> 8 & 0xFF) > 12 || (c & 0xFF) > 12
                return false
        }
    }
    return true
}

; відводимо курсор у порожнє місце, щоб кнопки меню не підсвічувались від наведення
ParkMouse() {
    MouseMove 300, 23 + GAME_H // 2, 0
}

PngSize(file) {
    f := FileOpen(file, "r")
    f.Pos := 16
    w := DllCall("ws2_32\ntohl", "UInt", f.ReadUInt(), "UInt")
    h := DllCall("ws2_32\ntohl", "UInt", f.ReadUInt(), "UInt")
    f.Close()
    return [w, h]
}

; Бій: одна дія за тік. Під час комбо спамимо скіл комбо,
; інакше тиснемо перший готовий увімкнений скіл за порядком, а якщо готових немає - M1.
Fight() {
    global comboUntil, lockUntil, lastCast, farPress, spreadNext, spreadTry
    ; рухатись можна лише поза комбо і поза анімацією скілів, що блокують рух (4, 5):
    ; інакше крок "з'їдається", і персонаж збивається з маршруту
    canMove := A_TickCount >= comboUntil && A_TickCount >= lockUntil
    ; v0.3: в Infinity завжди стоїмо на місці (Patrol і Turn прибрані) - вороги самі йдуть під великі AOE
    ; помічники (E R Z X) не залежать від основних скілів і працюють навіть під час анімацій,
    ; тож тиснемо кожен, щойно він готовий - на кожному тіку, окремо від порядку 1-5
    ; В Infinity великі AOE (spread: 5 4 E R X) не тиснемо всі разом, а по одному: наступний - коли попередній
    ; відпрацював (spreadMs, для 5 - 10 с зі spreadDur), щоб AOE було весь час. Скіли поза списком (3 Z 2 1, M1) -
    ; як завжди, щойно готові - ними б'ємо, поки великий AOE діє.
    ; spreadKey - чия черга зараз ("" = нікого зі списку зараз не тиснемо).
    spreadKey := ""
    ; бос minилі в Infinity (смуга HP угорі) - паузи між AOE лише шкодять: усе одразу, як готове
    spread := !BossFight() && !InfBoss() ? " " cfg["spread"] " " : "  "
    if spread != "  " && A_TickCount >= spreadNext
        spreadKey := NextSpread()
    ; малі AOE (infSmall: 3 Z) не чіпаємо, поки великий AOE діє або якийсь великий готовий - лише коли всі на перезарядці
    hold := spread != "  " && (A_TickCount < spreadNext || spreadKey != "") ? " " cfg["infSmall"] " " : "  "
    assists := " " cfg["assists"] " "
    for key in StrSplit(cfg["assists"], " ")
        if key != "" && SKILL_POS.Has(key) && SkillOn(key) && (!InStr(spread, " " key " ") || key = spreadKey)
                && !InStr(hold, " " key " ")
                && SkillReady(key) {
            Send "{" key "}"
            FightLog("assist", "  assist " key)
            if key = spreadKey {
                ; чекаємо, поки AOE діє, лише якщо помічник справді вийшов. Іконка помічника сіріє повільніше
                ; за скіли 1-5 (28.10: за 0.45 с E жодного разу не зарахувався, і одразу йшов R) - дивимось до 1.5 с.
                ; Не посіріла - повтор за 1.5 с; 3 рази поспіль - вважаємо, що вийшов (щоб не застрягти на ньому).
                t0 := A_TickCount
                while SkillReady(key) && A_TickCount - t0 < 1500
                    Sleep 150
                if !SkillReady(key) || ++spreadTry >= 3 {
                    if spreadTry >= 3
                        FightLog("AOE not greyed", "  AOE " key ": icon did not grey out 3 times - assuming it fired")
                    spreadTry := 0
                    SpreadDone(key)
                } else {
                    FightLog("AOE " key " failed", "  AOE " key " failed - again in 1.5 s")
                    spreadNext := A_TickCount + 1500
                }
                spreadKey := ""
            }
        }
    comboOn := false                                                  ; v0.3: комбо прибране
    if A_TickCount < comboUntil && comboOn && cfg["comboSpam"] != "" {
        ; комбо: тримаємо клавішу затиснутою до кінця комбо (весь час, без перерв на інші перевірки)
        ; і кожні 50 ms шлемо повтор "натиснуто" - як фізична клавіша при утриманні
        k := cfg["comboSpam"]
        SetStatus("combo: holding " k, "combo")
        SetKeyDelay -1, -1
        Send "{" k " down}"
        while A_TickCount < comboUntil && running {
            Sleep 50
            Send "{" k " down}"
        }
        Send "{" k " up}"
        SetKeyDelay 30, 30
        return
    }
    LearnCooldowns()
    order := lastEntered = "speed" ? SPEED_ORDER : cfg["order"]
    for key in StrSplit(order, " ") {
        if key = "" || !SKILL_POS.Has(key) || !SkillOn(key) || InStr(assists, " " key " ")
            continue
        if skillSkip.Get(key, 0) > A_TickCount
            continue
        if InStr(spread, " " key " ") && key != spreadKey          ; Infinity: не його черга
            continue
        if InStr(hold, " " key " ")                                ; Infinity: малий AOE, а великий діє/готовий
            continue
        if SkillReady(key) {
            SetStatus("skill " key, "skill " key)
            ; персонаж зайнятий (анімація скіла 4/5 або щойно спрацював інший скіл) - натискання може "з'їстись",
            ; такий промах не рахуємо як порожній слот (інакше готовий скіл пропускався б 20 s left)
            ; (+2 с запасу: анімація 4 і комбо довші за lockMs - 28.10 у логах "1/2 не спрацював" майже завжди
            ; одразу після 4 чи комбо, і робочий скіл пропускався на 20 с; порожній слот не спрацьовує й поза цим)
            busyNow := A_TickCount < lockUntil + 2000 || A_TickCount - lastCast < 2500 || A_TickCount < comboUntil + 1500
            tSend := A_TickCount
            Send "{" key "}"
            if InStr(" " cfg["lockSkills"] " ", " " key " ")
                lockUntil := A_TickCount + Num("lockMs", 2500)
            ; комбо (затиснути 1 після 3) - завжди одразу після натискання: перевірка іконки в RDP запізнюється,
            ; і через неї комбо раніше часто не запускалось (28.10: ~600 разів на 2000 натискань 3)
            if comboOn && key = cfg["comboKey"]
                comboUntil := A_TickCount + Num("comboMs", 3000)
            ; чи скіл справді спрацював (пішов на перезарядку); у RDP іконка часом сіріє повільніше - ще одна перевірка
            Sleep 150
            if SkillReady(key)
                Sleep 300
            if !SkillReady(key) {
                lastCast := A_TickCount
                castAt[key] := tSend, castExact[key] := true      ; від цього моменту рахуємо перезарядку
                if Knockback() && (key = "1" || key = "2")
                    farPress := tSend                             ; перевірка "чи влучили" - у Step
                if key = spreadKey
                    SpreadDone(key)
                skillFails[key] := 0
            } else if !busyNow {
                skillFails[key] := skillFails.Get(key, 0) + 1
                FightLog("failed " key, "  " key " did not fire")
                if skillFails[key] >= SKILL_FAILS {
                    ; порожнім буває лише слот 5 (персонаж без пробудження); 1-4 є завжди, а "не спрацював" у них -
                    ; відкинуло, оглушило чи анімація (28.10: 1/2 пропускались на 20 с ~2 рази на minилину) - коротка пауза
                    skip := key = "5" ? SKILL_SKIP : SKILL_SKIP_SHORT
                    skillFails[key] := 0
                    skillSkip[key] := A_TickCount + skip
                    Log("  " key " " SKILL_FAILS " times in a row did not fire" (key = "5" ? " (empty slot?)" : "") " - skipping " skip // 1000 " s")
                }
            }
            return
        }
    }
    ; готових нема: скіл, якому до кінця перезарядки <= 2 с (як "2" на іконці), тиснемо щотіку -
    ; гра запустить його в ту ж мить, як він звільниться
    if PrimeSkill(order, assists, spread SubStr(hold, 2))
        return
    if cfg["m1"] = "1" {
        SetStatus("M1", "M1")
        MouseMove GAME_W // 2, 23 + GAME_H // 2, 0             ; щоб не клікнути по вікну бота (centre of the game, not of a bigger screen)
        Click
    } else
        SetStatus("all skills on cooldown")
}

; Перезарядка кожного скіла вчиться сама: від натискання до того, як іконка знову стала кольоровою
; (беремо найменше з виміряного - тік бота може запізнитись). Вимірюємо лише від точного моменту натискання.
LearnCooldowns() {
    for key, t in castAt.Clone() {
        if !SkillReady(key)
            continue
        if castExact[key] {
            ms := A_TickCount - t
            if ms > 1500 && ms < 120000 && (!skillCd.Has(key) || ms < skillCd[key]) {
                if !skillCd.Has(key) || skillCd[key] - ms > 500
                    Log("  cooldown " key ": " Round(ms / 1000, 1) " s")
                skillCd[key] := ms
            }
        }
        castAt.Delete(key)
    }
}

PrimeSkill(order, assists, spread) {
    global comboUntil, lastCast
    static comboFor := 0                                  ; для якого натискання 3 комбо вже запущено
    for key in StrSplit(order, " ") {
        if key = "" || !castAt.Has(key) || !skillCd.Has(key) || !SkillOn(key) || InStr(assists, " " key " ")
                || InStr(spread, " " key " ") || skillSkip.Get(key, 0) > A_TickCount
            continue
        left := castAt[key] + skillCd[key] - A_TickCount
        if left > 2000
            continue
        if left < -1500 {                                 ; вікно минуло, а скіл сірий - спрацював від нашого натискання
            castAt[key] += skillCd[key], castExact[key] := false
            continue
        }
        SetStatus("skill " key ": pressing early (" Round(Max(0, left) / 1000, 1) " s left)", "early")
        Send "{" key "}"
        ; перезарядка скінчилась - натиснутий наперед скіл саме зараз спрацьовує. Для 3 одразу комбо (затиснути 1),
        ; як після звичайного натискання: інакше комбо після 3 "наперед" не запускалось, а 1 тиснувся посеред
        ; анімації 3 і "не спрацьовував" (28.10 23:01)
        if left <= 0 {
            lastCast := A_TickCount
            if false && key = cfg["comboKey"] && comboFor != castAt[key] {   ; v0.3: комбо прибране
                comboFor := castAt[key]
                comboUntil := A_TickCount + Num("comboMs", 3000)
            }
        }
        return true
    }
    return false
}

; Infinity: на екрані смуга HP боса minилі (та сама, що в рейді: фіолетова, line y=188, лівий край x~785).
; 29.10: забіги закінчувались на minилях 150-160 - бос за 30 с двічі вбивав персонажа, а сам лишався з 25% HP,
; поки великі AOE чекали своєї черги по 7-10 с. Перевірка - 3 точки біля лівого краю, раз на 0.5 с.
InfBoss() {
    static at := 0, was := false
    if lastEntered != "infinity" || cfg["infBossBurst"] != "1"
        return false
    if A_TickCount - at < 500
        return was
    at := A_TickCount
    n := 0
    for x in [792, 800, 808] {
        c := PixelGetColor(x, 188)
        r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, b := c & 0xFF
        if b >= 200 && r >= 140 && r <= 235 && g >= 60 && g <= 160 && b - g > 80
            n++
    }
    now := n >= 3
    if now && !was
        FightLog("wave boss", "  Infinity: wave boss - all AOE at once")
    return was := now
}

; з готових скілів spread - той, що найдовше не спрацьовував (на початку - за порядком списку: 5 4 E R X).
; Раніше черга йшла строго по колу, і скіл, не готовий саме у свою чергу (E після 4), чекав ціле коло.
NextSpread() {
    best := "", bestAt := 0
    for key in StrSplit(Trim(cfg["spread"]), " ")
        if key != "" && SKILL_POS.Has(key) && SkillOn(key) && skillSkip.Get(key, 0) <= A_TickCount && SkillReady(key) {
            at := spreadUsed.Get(key, 0)
            if best = "" || at < bestAt
                best := key, bestAt := at
        }
    return best
}

; скіл зі spread спрацював: у кінець черги, а поки він діє (spreadMs або spreadDur) - пауза
SpreadDone(key) {
    global spreadNext
    spreadUsed[key] := A_TickCount
    ms := Num("spreadMs", 7000)
    for pair in StrSplit(cfg["spreadDur"], " ")
        if (kv := StrSplit(pair, ":")).Length = 2 && kv[1] = key && IsNumber(kv[2])
            ms := Round(kv[2] * 1000)
    spreadNext := A_TickCount + Min(ms, 30000)
    FightLog("AOE " key, "  AOE " key ": next in " ms // 1000 " s")
}

HoldKey(k, ms := 120) {
    Send "{" k " down}"
    Sleep ms
    Send "{" k " up}"
}

; "Відбиток" портрета: колір кожної точки, огрублений до 4 рівнів на канал (щоб легке світіння рамки
; не заважало), рядком "rgb,rgb,...".
ReadPortrait() {
    sig := ""
    for p in PORTRAIT_PTS {
        c := Integer(PixelGetColor(p[1], p[2]))
        sig .= ((c >> 22) & 3) "" ((c >> 14) & 3) "" ((c >> 6) & 3) ","
    }
    return sig
}

; Смерть/респавн: портрет змінився (4+ з 7 точок) і новий тримається 1.5 с -> вийшов наступний персонаж.
; У рейді через respawnWait підемо вперед до боса, в Infinity маршрут патруля почнеться знову з центру.
CheckRespawn() {
    global portraitSig, portraitNew, portraitSince, walkAt, rdChanges, no5Pending, charIdx
    s := ReadPortrait()
    if portraitSig = "" {
        portraitSig := s
        return
    }
    a := StrSplit(s, ","), b := StrSplit(portraitSig, ",")
    diff := 0
    for i, v in a
        if v != b[i]
            diff++
    if diff < 4 {
        portraitNew := ""
        return
    }
    if portraitNew != s {                    ; новий відбиток - перевіряємо, чи він стабільний
        portraitNew := s, portraitSince := A_TickCount
        return
    }
    if A_TickCount - portraitSince < 1500
        return
    portraitSig := s, portraitNew := ""
    ; на початку бою відбиток ще з лобі/завантаження - це не смерть (29.10 17:01: "змінився персонаж" через 4 с
    ; після старту -> поворот камери на 95° від боса). Справжня смерть у перші 15 с - побачимо по відліку Respawn
    if fightSince && A_TickCount - fightSince < 15000 {
        Log("  portrait at fight start - remembered (not a death)")
        return
    }
    Log("character changed (death/respawn)")
    rdChanges++
    ; поки персонаж був мертвий, скіли "не спрацьовували" - у нового персонажа всі скіли знову доступні
    skillFails.Clear(), skillSkip.Clear()
    if lastEntered = "raid" {
        if A_TickCount - lastRespawnAt > 8000            ; респавн уже оброблено по відліку Respawn - вдруге не йдемо
            walkAt := A_TickCount + Min(Num("respawnWait", 3000), 20000)
        else
            no5Pending := true                           ; але скіл 5 нового персонажа перевіримо
    }
}

; колір точки скіла. Панель скілів знімаємо одним знімком (GrabPixels) і тримаємо 40 ms - у межах тіку:
; PixelGetColor на кожну з 9 точок окремо в RDP повільний. Після натискання бот чекає 150+ ms - знімок свіжий.
SkillColor(key, dx := 0, dy := 0) {
    static px := 0, at := 0
    b := SKILL_BAR, p := SKILL_POS[key]
    if !px || A_TickCount - at > 40
        px := GrabPixels(b[1], b[2], b[3], b[4]), at := A_TickCount
    return NumGet(px, ((p[2] + dy - b[2]) * b[3] + p[1] + dx - b[1]) * 4, "uint") & 0xFFFFFF
}

; Помічники (E R Z X): перезарядка - сірий ромб (~55-77, без кольору) з білим числом, готовий - портрет.
; Портрет буває майже весь темний (28.10: E в loadout 2 - чорний одяг і темно-червоне, насиченість <= 26,
; і бот жодного разу не тиснув E в Infinity), тому шукаємо не "кольорове", а "не сіре": точка кольорова
; (насиченість > 20) або темна (усі канали < 40). Таких 3+ з 5 - готовий. На 40 знімках: перезарядка 0 з 5, готовий 5 з 5.
SkillReady(key) {
    static ASSIST_PTS := [[0, 0], [0, -20], [-12, -12], [12, -12], [0, -30]]
    if !IsDigit(key) {
        n := 0
        for d in ASSIST_PTS {
            c := SkillColor(key, d[1], d[2])
            r := c >> 16 & 0xFF, gg := c >> 8 & 0xFF, b := c & 0xFF
            if Max(r, gg, b) - Min(r, gg, b) > 20 || Max(r, gg, b) < 40
                n++
        }
        return n >= 3
    }
    c := SkillColor(key)
    r := c >> 16 & 0xFF, gg := c >> 8 & 0xFF, b := c & 0xFF
    ; ромби скілів 1-5: готовий - рожево-коричневий (122,67,59) або фіолетовий (128,78,140), перезарядка - сірий.
    ; У персонажа без скіла 5 крізь порожній слот видно підлогу рейду - помаранчеву/червону, майже без синього
    ; (108,34,0), (255,54,0), або жовту лаву (255,230,125). Таку "готовність" не рахуємо.
    if b < 40 || gg > 110
        return false
    return Max(r, gg, b) - Min(r, gg, b) > READY_SAT
}
