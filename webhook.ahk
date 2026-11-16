; Discord webhook (10.11, player idea: "see the macro from Discord when you are at school").
; raid.ini [raid] webhook = the channel's webhook link (Discord: channel settings > Integrations > Webhooks > Copy URL).
; It is private (anyone with it can post to that channel) - never in the public build, it lives only in raid.ini.
; webhookMin = minutes between status posts with a game screenshot (0 = only start / stop / problems).
; Problems, Roblox restarts and errors go out at once (at most one post a minute for the same kind of line).
; curl.exe (Windows 10 1803+) runs in the background: the bot never waits for Discord, a failed post is only lost.

WebhookUrl() => Trim(IniRead(INI, "raid", "webhook", ""))
WebhookOk(url) => RegExMatch(url, "i)^https://(\w+\.)?discord(app)?\.com/api/webhooks/\d+/[\w-]+$")

WebhookPost(text, file := "") => WebhookSend('{"username":"AD Bot","content":"' JsonEsc(SubStr(text, 1, 1900)) '"}', file)

; json = the whole payload; file goes out as "shot.jpg" (an embed shows it with attachment://shot.jpg)
WebhookSend(json, file := "") {
    url := WebhookUrl()
    if !WebhookOk(url)
        return false
    jf := A_Temp "\adbot_hook_" A_TickCount "_" Random(1000, 9999) ".json"
    try FileAppend json, jf, "UTF-8-RAW"
    catch
        return false
    att := file != "" && FileExist(file) ? ' -F "file1=@' file ';filename=shot.jpg"' : ""
    ; payload_json=<file: curl reads the JSON from the file, so no quoting trouble on the command line
    try Run(A_ComSpec ' /c "curl.exe -s -m 60 -F "payload_json=<' jf '"' att ' "' url '" & del "' jf '""', , "Hide")
    catch
        return false
    return true
}

JsonEsc(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "")
    s := StrReplace(s, "`n", "\n")
    return StrReplace(s, "`t", " ")
}

WebhookStatus() => "**AD Bot** " FormatTime(, "HH:mm") " - " lastStatus
    . "`nThis run: raids " sess["raids"] ", Speed " sess["speedRuns"] ", Infinity " sess["infRuns"] ", Dimensions " sess["dimRuns"]
    . ", gems " SessSum(GEM_KEYS) ", tokens " SessSum(TOKEN_KEYS) ", restarts " sess["restarts"]

; every minute while the bot runs: a status post with a game screenshot every webhookMin minutes
WebhookTick() {
    static last := 0
    if !running || !WebhookOk(WebhookUrl())
        return
    m := IsInteger(v := Trim(IniRead(INI, "raid", "webhookMin", "30"))) ? Integer(v) : 30
    if m <= 0 || last && A_TickCount - last < m * 60000
        return
    if !last {                                           ; the first post comes webhookMin after Start (Start posts its own line)
        last := A_TickCount
        return
    }
    last := A_TickCount
    WebhookPost(WebhookStatus(), Screenshot("discord"))
}
SetTimer(WebhookTick, 60000)

; 16.11 (players asked, raids only): a card with the rewards and the results screenshot after every raid win
WebhookRaidWin(title, gems, tokens, force := false) {   ; force: Send test shows the card even with the switch off
    if !force && cfg["hookWins"] != "1" || !WebhookOk(WebhookUrl())
        return
    shot := Screenshot("raid_win")
    ; look of the Update screen: small "AD BOT" above, big caps title, numbers in mono, the theme's accent bar
    col := 0xB0449A
    try col := Integer("0x" C.acc)
    f := (n, v) => '{"name":"' n '","value":"``' JsonEsc(v) '``","inline":true}'
    fight := fightSince ? (s := (A_TickCount - fightSince) // 1000) // 60 ":" Format("{:02}", Mod(s, 60)) : "?"
    json := '{"username":"AD Bot","embeds":[{"author":{"name":"AD BOT"},"title":"RAID WON","color":' col
        . ',"description":"**' JsonEsc(title) '**","fields":['
        . f("GEMS", gems ? gems : "?") "," f("TOKENS", tokens ? tokens : "?") "," f("FIGHT", fight) ","
        . '{"name":"THIS SESSION","value":"``' JsonEsc("raids " sess["raids"] "  ·  gems " SessSum(GEM_KEYS) "  ·  tokens " SessSum(TOKEN_KEYS)) '``","inline":false}]'
        . (shot != "" ? ',"image":{"url":"attachment://shot.jpg"}' : "")
        . ',"footer":{"text":"AD Bot v' APP_VERSION '"},"timestamp":"' FormatTime(A_NowUTC, "yyyy-MM-dd'T'HH:mm:ss'Z'") '"}]}'
    WebhookSend(json, shot)
}

; called from Log(): lines worth a ping on the phone
WebhookLog(text) {
    static sent := Map()
    if !RegExMatch(text, "^(PROBLEM: |ERROR|WARNING: Roblox|WARNING: No recorded run|WARNING: There is no recorded run|restarting Roblox: )", &m)
        return
    k := m[1]
    if sent.Has(k) && A_TickCount - sent[k] < 60000
        return
    if !WebhookOk(WebhookUrl())
        return
    sent[k] := A_TickCount
    WebhookPost("**AD Bot** " FormatTime(, "HH:mm") " - " text)
}
