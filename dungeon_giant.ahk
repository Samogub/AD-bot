; Giant Dimension (Nightmare, Hardcore, Friends Only): the whole run as recorded by the author on 3.11 (tools\rec\20261103_195649,
; 41.6 s, keyboard only). [ms from the start, kd/ku = key down/up, key code vkXXscYYY (layout independent)].
; Played by RunRoute() from the moment the first enemies are seen at the spawn, exactly as in the recording.
; the character this run was recorded with - shown on the Dimension page. Fill in: name, a short line, more text,
; and a picture img\dim_char.png (square, e.g. 128x128; a "?" is shown while the file is missing)
DIM_CHAR := {
    name: "Speed",
    text: "The main character in loadout 2.",
    more: "Sub stat: Cooldown Reduction +36.10%. The run needs this much (or a bit more) - with less, the skills come back too late and the recorded presses miss.",
    icon: "dim_char.png",
    ; the fruit used with the run (picture img\dim_fruit.png)
    fruitName: "Fruit (Lv. 30)",
    fruitText: "The author uses this fruit. Sub stat: Fruit Cooldown Reduction +22.40% - the run needs at least this much.",
    fruitIcon: "dim_fruit.png"
}
DUNGEON_ROUTE := [
    [546, "kd", "vk57sc011"],   ; W down
    [2531, "kd", "vk32sc003"],   ; 2 down
    [2656, "ku", "vk32sc003"],   ; 2 up
    [3562, "kd", "vk31sc002"],   ; 1 down
    [3687, "ku", "vk31sc002"],   ; 1 up
    [4218, "kd", "vk44sc020"],   ; D down
    [4343, "ku", "vk57sc011"],   ; W up
    [4750, "kd", "vk53sc01F"],   ; S down
    [4921, "ku", "vk53sc01F"],   ; S up
    [5218, "kd", "vk33sc004"],   ; 3 down
    [5328, "ku", "vk33sc004"],   ; 3 up
    [6328, "kd", "vk57sc011"],   ; W down
    [6578, "ku", "vk44sc020"],   ; D up
    [8171, "kd", "vk41sc01E"],   ; A down
    [8406, "ku", "vk57sc011"],   ; W up
    [8875, "kd", "vk53sc01F"],   ; S down
    [8984, "ku", "vk53sc01F"],   ; S up
    [9531, "ku", "vk41sc01E"],   ; A up
    [9875, "kd", "vk32sc003"],   ; 2 down
    [9968, "ku", "vk32sc003"],   ; 2 up
    [10296, "kd", "vk41sc01E"],   ; A down
    [11093, "kd", "vk51sc010"],   ; Q dash down
    [11250, "ku", "vk51sc010"],   ; Q dash up
    [11609, "kd", "vk51sc010"],   ; Q dash down
    [11859, "ku", "vk51sc010"],   ; Q dash up
    [12203, "kd", "vk31sc002"],   ; 1 down
    [12296, "ku", "vk31sc002"],   ; 1 up
    [13203, "kd", "vk51sc010"],   ; Q dash down
    [13359, "ku", "vk51sc010"],   ; Q dash up
    [13671, "kd", "vk51sc010"],   ; Q dash down
    [13796, "ku", "vk51sc010"],   ; Q dash up
    [14031, "kd", "vk5Asc02C"],   ; Z down
    [14203, "ku", "vk5Asc02C"],   ; Z up
    [14984, "kd", "vk51sc010"],   ; Q dash down
    [15140, "ku", "vk51sc010"],   ; Q dash up
    [15828, "kd", "vk20sc039"],   ; Space down
    [15968, "ku", "vk20sc039"],   ; Space up
    [16062, "kd", "vk31sc002"],   ; 1 down
    [16140, "ku", "vk31sc002"],   ; 1 up
    [18156, "kd", "vk32sc003"],   ; 2 down
    [18296, "ku", "vk32sc003"],   ; 2 up
    [20000, "kd", "vk31sc002"],   ; 1 down
    [20109, "ku", "vk31sc002"],   ; 1 up
    [20187, "kd", "vk31sc002"],   ; 1 down
    [20265, "ku", "vk31sc002"],   ; 1 up
    [21250, "kd", "vk57sc011"],   ; W down
    [21375, "ku", "vk57sc011"],   ; W up
    [21875, "kd", "vk51sc010"],   ; Q dash down
    [22062, "ku", "vk51sc010"],   ; Q dash up
    [22312, "kd", "vk51sc010"],   ; Q dash down
    [22453, "ku", "vk51sc010"],   ; Q dash up
    [23859, "kd", "vk33sc004"],   ; 3 down
    [23968, "ku", "vk33sc004"],   ; 3 up
    [24906, "kd", "vk52sc013"],   ; R down
    [25015, "ku", "vk52sc013"],   ; R up
    [25140, "kd", "vk57sc011"],   ; W down
    [25359, "ku", "vk57sc011"],   ; W up
    [25906, "kd", "vk51sc010"],   ; Q dash down
    [26093, "ku", "vk51sc010"],   ; Q dash up
    [27046, "kd", "vk57sc011"],   ; W down
    [27218, "ku", "vk57sc011"],   ; W up
    [27453, "kd", "vk51sc010"],   ; Q dash down
    [27546, "ku", "vk51sc010"],   ; Q dash up
    [28062, "kd", "vk53sc01F"],   ; S down
    [28187, "ku", "vk53sc01F"],   ; S up
    [28328, "kd", "vk32sc003"],   ; 2 down
    [28390, "ku", "vk32sc003"],   ; 2 up
    [29109, "kd", "vk53sc01F"],   ; S down
    [29218, "ku", "vk53sc01F"],   ; S up
    [29546, "kd", "vk45sc012"],   ; E down
    [29640, "ku", "vk45sc012"],   ; E up
    [30640, "kd", "vk57sc011"],   ; W down
    [30765, "ku", "vk57sc011"],   ; W up
    [31171, "kd", "vk53sc01F"],   ; S down
    [31390, "ku", "vk53sc01F"],   ; S up
    [32562, "kd", "vk58sc02D"],   ; X down
    [32718, "ku", "vk58sc02D"],   ; X up
    [33515, "kd", "vk51sc010"],   ; Q dash down
    [33718, "ku", "vk51sc010"],   ; Q dash up
    [34390, "kd", "vk32sc003"],   ; 2 down
    [34500, "ku", "vk32sc003"],   ; 2 up
    [35281, "kd", "vk31sc002"],   ; 1 down
    [35421, "ku", "vk31sc002"],   ; 1 up
    [35625, "ku", "vk41sc01E"],   ; A up
    [35937, "kd", "vk44sc020"],   ; D down
    [36265, "ku", "vk44sc020"],   ; D up
    [36921, "kd", "vk33sc004"],   ; 3 down
    [37031, "ku", "vk33sc004"],   ; 3 up
    [37937, "kd", "vk44sc020"],   ; D down
    [38156, "kd", "vk41sc01E"],   ; A down
    [38171, "ku", "vk44sc020"],   ; D up
    [38437, "kd", "vk44sc020"],   ; D down
    [38468, "ku", "vk41sc01E"],   ; A up
    [38609, "kd", "vk41sc01E"],   ; A down
    [38656, "ku", "vk44sc020"],   ; D up
    [39171, "kd", "vk51sc010"],   ; Q dash down
    [39359, "ku", "vk51sc010"],   ; Q dash up
    [39578, "kd", "vk57sc011"],   ; W down
    [39718, "ku", "vk57sc011"],   ; W up
    [39828, "kd", "vk51sc010"],   ; Q dash down
    [40015, "ku", "vk51sc010"],   ; Q dash up
    [40265, "kd", "vk51sc010"],   ; Q dash down
    [40359, "ku", "vk51sc010"],   ; Q dash up
    [40500, "kd", "vk31sc002"],   ; 1 down
    [40578, "ku", "vk31sc002"],   ; 1 up
    [40734, "ku", "vk41sc01E"],   ; A up
    [41156, "kd", "vk41sc01E"],   ; A down
    [41390, "kd", "vk32sc003"],   ; 2 down
    [41515, "ku", "vk32sc003"],   ; 2 up
    [41609, "ku", "vk41sc01E"]   ; A up
]
