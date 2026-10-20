; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; IA_Invaders - PurePunch Halloween 2026.;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Fred, the last human developer, fights AI-generated bugs.;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Pure PureBasic: no API, no external library.;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Keys: LEFT / RIGHT = move, SPACE = fire, ESC = quit.;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; --------------------------------------------------------------------------------------------------------------------------------------
; HOW IT WORKS:
; - A Space Invaders clone: Fred (bottom of the screen) shoots the armada of Bugs, Code Knots and Git Commits, which goes down line by line.
; - Two special enemies: CEO Cash $$$ (top: 3 hits, the armada goes up) and MegaCenter (under the armada: lightning, escapes = armada goes down).
; - Fixed time step: Update() (the game logic) runs 60 times per second whatever the screen refresh rate, then Draw() shows the result.
; - No drawing command while playing: texts and shapes are drawn once into sprites (cached), then only sprites are displayed.
; - Resources (images, sounds, music) are embedded in the exe with DataSection and IncludeBinary.
; - States: Boot (fake compilation) > Title > Play > Game Over or Victory. All the tuning constants are at the top of this file.
; --------------------------------------------------------------------------------------------------------------------------------------

EnableExplicit

; ---------- TUNING: change these values to adjust the game ----------
#LIVES = 5                 ; Fred's lives
#MAX_WAVE = 5              ; number of waves to survive
#PLAYER_SPEED = 5          ; Fred speed (pixels per frame)
#FIRE_DELAY = 320          ; ms between two Fred shots (bigger = harder)
#TICK_MS = 16.6667          ; game logic step in ms (60 steps per second)
#MAX_SHOTS = 3             ; Fred bullets on screen at the same time (smaller = harder)
#STEP_PIXELS = 8           ; armada horizontal move per step
#STEP_BASE = 36            ; armada step delay in ms (smaller = faster)
#STEP_PER_ENEMY = 10        ; + ms per living enemy (smaller = less acceleration as the armada empties)
#STEP_MIN = 14             ; fastest possible step delay in ms
#WAVE_SPEEDUP = 10         ; armada gets this % faster at each wave
#DROP = 20                 ; one "line" = 20 pixels
#BOMB_DELAY_MAX = 1200     ; ms between enemy shots: random between MIN and MAX
#BOMB_DELAY_MIN = 500
#BOMB_WAVE_FASTER = 70    ; MAX delay is reduced by this value at each wave
#BOMB_SPEED = 4            ; bomb speed (+1 every 3 waves)
#BURST_EVERY = 3           ; +1 bomb per enemy shot every N waves
#AIM_PERCENT = 30          ; % of bombs dropped in Fred's column
#MERGE_BOOST = 1500        ; ms of armada panic after a Git Commit dies
#CASH_SPEED = 1.4          ; CEO Cash speed (pixels per frame)
#CASH_HITS = 3             ; shots needed to kill the CEO
#CASH_DELAY_MIN = 9000     ; ms before the CEO comes back (random between MIN and MAX)
#CASH_DELAY_MAX = 15000
#MEGA_SPEED = 1.2          ; MegaCenter speed (pixels per frame)
#MEGA_HITS = 2             ; shots needed to kill the MegaCenter
#MEGA_DELAY_MIN = 14000
#MEGA_DELAY_MAX = 22000
#BOLT_WARN = 800           ; ms of warning before the lightning strikes
#BOLT_STRIKE = 220         ; ms the lightning stays on screen
#BOLT_COOLDOWN = 1800      ; ms between two lightnings
#BUG_REBORN = 8            ; 1 chance in N that a dead Bug is "fixed by AI" (a new Bug flies back)
#REBORN_MS = 1800          ; ms for the new Bug to fly back to the armada
#HALLU_CHANCE = 5          ; 1 Git Commit shot in N is a harmless hallucination (cyan)
#SHIELD_MS = 6000          ; rubber duck shield duration in ms
#PTS_BUG = 10
#PTS_KNOT = 30
#PTS_COMMIT = 20
#PTS_CASH = 150
#PTS_MEGA = 250

; ---------- layout ----------
#SW = 800 : #SH = 600
#COLS = 8 : #ROWS = 3
#CELL_W = 64 : #ROW_H = 50
#CASH_Y = 30               ; lane of the CEO Cash (top of the screen)
#AY_START = 84             ; armada start height
#AY_MIN = 76               ; the armada can not go higher than this
#LOSE_Y = 470              ; armada reaching this line = system crash (painted in background.png)
#PLAYER_Y = #SH - 76
#SP_CASH = 0 : #SP_MEGA = 1
#Img_Measure = 0           ; 1x1 image used to measure text
#Spr_Solid = 10            ; 8 solid colour sprites (10 to 17), zoomed to draw rectangles
#Spr_Title = 20            ; pre-rendered title panel
#Spr_Chat = 21             ; pre-rendered chat panel
#Spr_Ring = 22             ; pre-rendered shield ring
#Spr_Cache = 100           ; first sprite number of the text cache
#CACHE_MAX = 250           ; the text cache is flushed beyond this number of entries

Enumeration
  #Spr_BG
  #Spr_Enemies
  #Spr_Player
EndEnumeration

Enumeration
  #Snd_Shoot
  #Snd_Explosion
  #Snd_Music
EndEnumeration

Enumeration
  #St_Boot
  #St_Title
  #St_Play
  #St_Over
  #St_Win
EndEnumeration

Structure TShot
  x.f
  y.f
  act.b
EndStructure

Structure TBoom
  x.l
  y.l
  kind.b
  t.l
EndStructure

Global Dim hp.b(#ROWS - 1, #COLS - 1)
Global Dim shot.TShot(#MAX_SHOTS - 1)
Global Dim bomb.TShot(15)
Global Dim boom.TBoom(31)
Global Dim spOn(1)
Global Dim spX.f(1)
Global Dim spY(1)
Global Dim spHp(1)
Global Dim spHit(1)
Global Dim spNext(1)
Global NewMap tc()

Global state, score, hiscore, lives, wave, ax, ay, dir, frame, alive
Global nextStep, nextBomb, nextShot, boostUntil, hitUntil, invUntil
Global msgUntil, fireUntil, lock, hasSound, gMinC, gMaxC, gMaxR, moving
Global bState, bUntil, bCool, bHit, overAt, bootAt, duckOn, shieldUntil, rbOn, rbCol, rbStart, rbSX, rbSY, rbBend
Global px.f, bX.f, duckX.f, duckY.f, rbX.f, rbY.f
Global msg$, quotes$
Global nextSpr, cGreen, cBlue, cYellow, cWhite, cMsg, cDBlue, cRed, cLilac, cHead

; collision test: 1 if rectangle 1 overlaps rectangle 2
Macro Hit(x1, y1, w1, h1, x2, y2, w2, h2)
  Bool((x1) < (x2) + (w2) And (x1) + (w1) > (x2) And (y1) < (y2) + (h2) And (y1) + (h1) > (y2))
EndMacro

; ---------- helpers ----------
; stops the program with a message when a resource can not be loaded
Procedure Need(ok, file$)
  If ok = 0 : MessageRequester("IA Invaders", "Missing resource: " + file$) : End : EndIf
EndProcedure

; plays a sound effect (if the sound system is available)
Procedure Sfx(n)
  If hasSound : PlaySound(n, #PB_Sound_MultiChannel) : EndIf
EndProcedure

; shows a message at the bottom of the screen for ms milliseconds
Procedure Say(text$, ms = 1600)
  msg$ = text$
  msgUntil = ElapsedMilliseconds() + ms
EndProcedure

; starts an explosion animation at x, y (kind = row of the sprite sheet)
Procedure AddBoom(x, y, kind)
  Protected i, now = ElapsedMilliseconds()
  For i = 0 To 31
    If boom(i)\t < now
      boom(i)\x = x : boom(i)\y = y : boom(i)\kind = kind : boom(i)\t = now + 250
      Break
    EndIf
  Next
EndProcedure

; schedules the next appearance of a special enemy (0 = CEO Cash, 1 = MegaCenter)
Procedure SetNext(k)
  If k = #SP_CASH
    spNext(k) = ElapsedMilliseconds() + Random(#CASH_DELAY_MAX, #CASH_DELAY_MIN)
  Else
    spNext(k) = ElapsedMilliseconds() + Random(#MEGA_DELAY_MAX, #MEGA_DELAY_MIN)
  EndIf
EndProcedure

; occupied area of the armada
Procedure Scan()
  Protected r, c
  gMinC = #COLS : gMaxC = -1 : gMaxR = -1
  For r = 0 To #ROWS - 1
    For c = 0 To #COLS - 1
      If hp(r, c)
        If c < gMinC : gMinC = c : EndIf
        If c > gMaxC : gMaxC = c : EndIf
        If r > gMaxR : gMaxR = r : EndIf
      EndIf
    Next
  Next
EndProcedure

; builds a new armada and resets bullets, bombs and special enemies
Procedure StartWave()
  Protected r, c, now = ElapsedMilliseconds()
  For r = 0 To #ROWS - 1
    For c = 0 To #COLS - 1
      If r = 1 : hp(r, c) = 2 : Else : hp(r, c) = 1 : EndIf
    Next
  Next
  alive = #ROWS * #COLS
  ax = (#SW - #COLS * #CELL_W) / 2 : ay = #AY_START + (wave - 1) * 10 : dir = 1
  For r = 0 To #MAX_SHOTS - 1 : shot(r)\act = 0 : Next
  For r = 0 To 15 : bomb(r)\act = 0 : Next
  For r = 0 To 1 : spOn(r) = #False : SetNext(r) : Next
  bState = 0 : duckOn = #False : rbOn = #False
  nextStep = now + 600 : nextBomb = now + 1500
EndProcedure

; starts a new game: score, lives and the first wave
Procedure NewGame()
  score = 0 : lives = #LIVES : wave = 1 : state = #St_Play
  px = (#SW - #CELL_W) / 2
  hitUntil = 0 : invUntil = 0 : boostUntil = 0
  StartWave()
  Say("WAVE 1 - FIXED BY AI")
EndProcedure

; switches to the Game Over or Victory screen and updates the hi-score
Procedure EndGame(newState)
  state = newState
  If score > hiscore : hiscore = score : EndIf
  lock = ElapsedMilliseconds() + 900 : overAt = ElapsedMilliseconds()
EndProcedure

; ---------- armada ----------
; delay in ms between two armada steps (shorter when the armada is small, and at higher waves)
Procedure StepDelay()
  Protected d = (#STEP_BASE + alive * #STEP_PER_ENEMY) * (100 - (wave - 1) * #WAVE_SPEEDUP) / 100
  If ElapsedMilliseconds() < boostUntil : d = d / 2 : EndIf
  If d < #STEP_MIN : d = #STEP_MIN : EndIf
  ProcedureReturn d
EndProcedure

; moves the armada by one step: sideways, or down one line at the edges
Procedure StepArmada()
  Scan()
  If (dir > 0 And ax + (gMaxC + 1) * #CELL_W + #STEP_PIXELS >= #SW) Or (dir < 0 And ax + gMinC * #CELL_W - #STEP_PIXELS <= 0)
    dir = -dir
    ay = ay + #DROP
  Else
    ax = ax + dir * #STEP_PIXELS
  EndIf
  frame = 1 - frame
EndProcedure

; makes one or more enemies drop a bomb (some aimed at Fred, some fake: hallucinations)
Procedure DropBomb()
  Protected c, r, i, k, n = 1 + (wave - 1) / #BURST_EVERY
  For k = 1 To n
    c = Random(#COLS - 1)
    If Random(99) < #AIM_PERCENT
      c = (px + 32 - ax) / #CELL_W
      If c < 0 : c = 0 : ElseIf c > #COLS - 1 : c = #COLS - 1 : EndIf
    EndIf
    For r = #ROWS - 1 To 0 Step -1
      If hp(r, c) : Break : EndIf
    Next
    If r >= 0
      For i = 0 To 15
        If bomb(i)\act = 0
          bomb(i)\x = ax + c * #CELL_W + #CELL_W / 2 - 3
          bomb(i)\y = ay + r * #ROW_H + 40
          bomb(i)\act = 1 + Bool(r = 2 And Random(#HALLU_CHANCE - 1) = 0)
          Break
        EndIf
      Next
    EndIf
  Next
EndProcedure

; a Fred bullet hit the enemy (r, c): damage, points and special effects
Procedure KillEnemy(r, c)
  Protected k = Random(#COLS - 1)
  hp(r, c) = hp(r, c) - 1
  If hp(r, c) > 0 : score = score + 5 : ProcedureReturn : EndIf
  alive = alive - 1
  AddBoom(ax + c * #CELL_W, ay + r * #ROW_H, r)
  Sfx(#Snd_Explosion)
  Select r
    Case 0 : score = score + #PTS_BUG
      If Random(#BUG_REBORN - 1) = 0 And rbOn = 0 And hp(0, k) = 0 And k <> c       ; fixed by AI: a new Bug comes back
        rbOn = #True : rbCol = k : rbStart = ElapsedMilliseconds() : rbSX = Random(#SW - 64) : rbSY = #SH
        rbBend = 120 - Random(1) * 240 : alive = alive + 1 : Say("FIXED BY AI (+1 NEW BUG)")
      EndIf
    Case 1 : score = score + #PTS_KNOT : Say("CODE KNOT REFACTORED")
    Case 2 : score = score + #PTS_COMMIT : boostUntil = ElapsedMilliseconds() + #MERGE_BOOST : Say("MERGE CONFLICT!")
  EndSelect
EndProcedure

; ---------- special enemies: CEO Cash $$$ (k = 0) and MegaCenter (k = 1) ----------
; a Fred bullet hit CEO Cash (k = 0) or MegaCenter (k = 1)
Procedure HitSpecial(k)
  Protected now = ElapsedMilliseconds()
  spHp(k) = spHp(k) - 1 : spHit(k) = now + 300 : score = score + 25
  If spHp(k) > 0
    If k = #SP_CASH
      Say("BUDGET CUT " + Str(#CASH_HITS - spHp(k)) + "/" + Str(#CASH_HITS), 900)
    Else
      Say("SERVER OVERHEAT " + Str(#MEGA_HITS - spHp(k)) + "/" + Str(#MEGA_HITS), 900)
    EndIf
    ProcedureReturn
  EndIf
  spOn(k) = #False : SetNext(k)
  AddBoom(spX(k), spY(k), 3 + k) : Sfx(#Snd_Explosion)
  If k = #SP_CASH
    score = score + #PTS_CASH
    ay = ay - #DROP                                   ; SPECIAL RULE: the armada goes up one line!
    If ay < #AY_MIN : ay = #AY_MIN : EndIf
    Say("BUDGET APPROVED! ARMADA -1 LINE", 2200)
    duckOn = #True : duckX = spX(k) : duckY = spY(k)
  Else
    score = score + #PTS_MEGA
    If bState = 1 : bState = 0 : EndIf
    Say("DATA CENTER DOWN!", 1800)
  EndIf
EndProcedure

; Fred loses a life (short invulnerability) or the game is over
Procedure HurtPlayer()
  Protected now = ElapsedMilliseconds()
  lives = lives - 1
  hitUntil = now + 600 : invUntil = now + 1800
  Sfx(#Snd_Explosion)
  If lives <= 0 : EndGame(#St_Over) : Else : Say(StringField(quotes$, Random(7) + 1, "|")) : EndIf
EndProcedure

; Fred fires a bullet if one is free
Procedure Fire()
  Protected i
  For i = 0 To #MAX_SHOTS - 1
    If shot(i)\act = 0
      shot(i)\x = px + 45 : shot(i)\y = #PLAYER_Y + 10 : shot(i)\act = 1
      fireUntil = ElapsedMilliseconds() + 90
      Sfx(#Snd_Shoot)
      Break
    EndIf
  Next
EndProcedure

; ---------- game logic (one tick) ----------
; game logic for one step: input, armada, special enemies, lightning, bullets, bombs, end of wave
Procedure Update()
  Protected i, k, r, c, x, y, sp.f, tf.f, now = ElapsedMilliseconds()

  moving = #False
  If KeyboardPushed(#PB_Key_Left)  : px = px - #PLAYER_SPEED : moving = #True : EndIf
  If KeyboardPushed(#PB_Key_Right) : px = px + #PLAYER_SPEED : moving = #True : EndIf
  If px < 0 : px = 0 : EndIf
  If px > #SW - #CELL_W : px = #SW - #CELL_W : EndIf
  If KeyboardPushed(#PB_Key_Space) And now >= nextShot : Fire() : nextShot = now + #FIRE_DELAY : EndIf

  If now >= nextStep : StepArmada() : nextStep = now + StepDelay() : EndIf
  If now >= nextBomb : DropBomb() : nextBomb = now + Random(#BOMB_DELAY_MAX - (wave - 1) * #BOMB_WAVE_FASTER, #BOMB_DELAY_MIN) : EndIf

  ; specials: CEO Cash on the top lane, MegaCenter on the line just below the armada
  Scan()
  spY(#SP_CASH) = #CASH_Y : spY(#SP_MEGA) = ay + (gMaxR + 1) * #ROW_H
  For k = 0 To 1
    If spOn(k)
      If k = #SP_CASH : sp = #CASH_SPEED : Else : sp = #MEGA_SPEED : EndIf
      spX(k) = spX(k) - sp
      If spX(k) < -64
        spOn(k) = #False : SetNext(k)
        If k = #SP_MEGA : ay = ay + #DROP : Say("SERVER OVERLOAD! ARMADA +1 LINE", 2200) : EndIf
      EndIf
    ElseIf now >= spNext(k)
      spOn(k) = #True : spX(k) = #SW
      If k = #SP_CASH : spHp(k) = #CASH_HITS : Else : spHp(k) = #MEGA_HITS : EndIf
    EndIf
  Next

  ; MegaCenter lightning: warning, then strike on the column locked at warning time
  If bState = 0 And spOn(#SP_MEGA) And now >= bCool And Abs(spX(#SP_MEGA) - px) < 20
    bState = 1 : bX = spX(#SP_MEGA) + 32 : bUntil = now + #BOLT_WARN : bHit = #False
  ElseIf bState = 1 And now >= bUntil
    bState = 2 : bUntil = now + #BOLT_STRIKE : Sfx(#Snd_Explosion)
  ElseIf bState = 2
    If bHit = 0 And now > invUntil And now >= shieldUntil And Abs(bX - (px + 32)) < 22 : bHit = #True : HurtPlayer() : EndIf
    If now >= bUntil : bState = 0 : bCool = now + #BOLT_COOLDOWN : EndIf
  EndIf

  ; the new Bug flies back from the bottom of the screen to its place in the armada (curve)
  If rbOn
    tf = (now - rbStart) / (#REBORN_MS * 1.0)
    rbX = rbSX + (ax + rbCol * #CELL_W - rbSX) * tf + Sin(tf * 3.14159) * rbBend
    rbY = rbSY + (ay - rbSY) * tf
    If tf >= 1 : rbOn = #False : hp(0, rbCol) = 1 : EndIf
  EndIf

  ; Fred bullets
  For i = 0 To #MAX_SHOTS - 1
    If shot(i)\act
      shot(i)\y = shot(i)\y - 9
      If shot(i)\y < -20 : shot(i)\act = 0 : EndIf
      For k = 0 To 1
        If shot(i)\act And spOn(k) And Hit(shot(i)\x, shot(i)\y, 4, 14, spX(k) + 1, spY(k) + 8, 62, 30)
          shot(i)\act = 0 : HitSpecial(k)
        EndIf
      Next
      If shot(i)\act And rbOn And Hit(shot(i)\x, shot(i)\y, 4, 14, rbX + 12, rbY + 6, 40, 36)
        shot(i)\act = 0 : rbOn = #False : alive = alive - 1 : score = score + #PTS_BUG
        AddBoom(rbX, rbY, 0) : Sfx(#Snd_Explosion) : Say("BUG SQUASHED... AGAIN")
      EndIf
      For r = 0 To #ROWS - 1
        For c = 0 To #COLS - 1
          If shot(i)\act And hp(r, c)
            x = ax + c * #CELL_W + 12 : y = ay + r * #ROW_H + 6
            If Hit(shot(i)\x, shot(i)\y, 4, 14, x, y, 40, 36) : shot(i)\act = 0 : KillEnemy(r, c) : EndIf
          EndIf
        Next
      Next
    EndIf
  Next

  ; enemy bombs
  For i = 0 To 15
    If bomb(i)\act
      bomb(i)\y = bomb(i)\y + #BOMB_SPEED + wave / 3
      If bomb(i)\y > #SH
        bomb(i)\act = 0
      ElseIf Hit(bomb(i)\x, bomb(i)\y, 6, 14, px + 14, #PLAYER_Y + 10, 36, 58)
        If now < shieldUntil
          bomb(i)\act = 0
        ElseIf now > invUntil
          If bomb(i)\act = 1 : bomb(i)\act = 0 : HurtPlayer() : ElseIf bomb(i)\act = 2 : bomb(i)\act = 3 : Say("HALLUCINATION! (NO DAMAGE)", 1200) : EndIf
        EndIf
      EndIf
    EndIf
  Next

  ; rubber duck falls from the dead CEO: catch it for a shield
  If duckOn
    duckY = duckY + 3
    If duckY > #SH
      duckOn = #False
    ElseIf Hit(duckX + 14, duckY + 10, 36, 28, px + 14, #PLAYER_Y + 10, 36, 58)
      duckOn = #False : shieldUntil = now + #SHIELD_MS : score = score + 50 : Say("RUBBER DUCK! SHIELD ON", 1800)
    EndIf
  EndIf

  ; wave cleared / system crash
  Scan()
  If state = #St_Play
    If alive = 0
      wave = wave + 1
      If wave > #MAX_WAVE : EndGame(#St_Win) : Else : StartWave() : Say("LGTM! WAVE " + Str(wave) + "/" + Str(#MAX_WAVE), 2000) : EndIf
    ElseIf ay + (gMaxR + 1) * #ROW_H >= #LOSE_Y
      EndGame(#St_Over)
    EndIf
  EndIf
EndProcedure

; ---------- rendering: sprites only while playing ----------
; StartDrawing(SpriteOutput()) is used ONCE per text or shape, to fill a sprite. After that, only sprites are displayed.
; builds the solid colour sprites, the title panel, the chat panel and the shield ring
Procedure BuildSprites()
  Protected i, c
  CreateImage(#Img_Measure, 1, 1)
  For i = 0 To 7
    Select i
      Case 0 : c = RGB(120, 255, 90)
      Case 1 : c = RGB(255, 80, 80)
      Case 2 : c = RGB(120, 255, 255)
      Case 3 : c = RGB(50, 50, 80)
      Case 4 : c = RGB(255, 240, 120)
      Case 5 : c = RGB(130, 210, 255)
      Case 6 : c = RGB(255, 255, 255)
      Default : c = RGB(120, 180, 255)
    EndSelect
    CreateSprite(#Spr_Solid + i, 8, 8)
    StartDrawing(SpriteOutput(#Spr_Solid + i)) : Box(0, 0, 8, 8, c) : StopDrawing()
  Next
  CreateSprite(#Spr_Title, 761, 507, #PB_Sprite_AlphaBlending)         ; title screen panel
  StartDrawing(SpriteOutput(#Spr_Title))
  DrawingMode(#PB_2DDrawing_AllChannels)
  Box(0, 0, 761, 507, RGBA(0, 0, 0, 0))
  Box(0, 0, 760, 506, RGBA(4, 6, 28, 205))
  For i = 1 To 4 : Line(10, 46 + 64 * i, 740, 0, RGBA(28, 46, 102, 230)) : Next
  Line(0, 0, 760, 0, RGBA(60, 120, 255, 255)) : Line(0, 506, 760, 0, RGBA(60, 120, 255, 255))
  Line(0, 0, 0, 506, RGBA(60, 120, 255, 255)) : Line(760, 0, 0, 506, RGBA(60, 120, 255, 255))
  StopDrawing()
  CreateSprite(#Spr_Chat, 520, 256, #PB_Sprite_AlphaBlending)          ; chat panel
  StartDrawing(SpriteOutput(#Spr_Chat))
  DrawingMode(#PB_2DDrawing_AllChannels)
  Box(0, 0, 520, 256, RGBA(0, 0, 0, 0))
  RoundBox(0, 0, 520, 256, 10, 10, RGBA(60, 120, 255, 255))
  RoundBox(1, 1, 518, 254, 9, 9, RGBA(8, 10, 34, 255))
  StopDrawing()
  CreateSprite(#Spr_Ring, 92, 92, #PB_Sprite_AlphaBlending)            ; shield ring
  StartDrawing(SpriteOutput(#Spr_Ring))
  DrawingMode(#PB_2DDrawing_AllChannels)
  Box(0, 0, 92, 92, RGBA(0, 0, 0, 0))
  Circle(46, 46, 45, RGBA(200, 235, 255, 255)) : Circle(46, 46, 44, RGBA(120, 200, 255, 255)) : Circle(46, 46, 43, RGBA(0, 0, 0, 0))
  StopDrawing()
EndProcedure

; frees all the cached text sprites
Procedure FlushCache()
  ForEach tc() : FreeSprite(tc()) : Next
  ClearMap(tc())
  nextSpr = #Spr_Cache
EndProcedure

; sprite of a text: rendered the first time it is needed, then reused
Procedure GetText(font, text$, color)
  Protected key$ = text$ + "|" + Str(font) + "|" + Str(color), w, h, spr
  If FindMapElement(tc(), key$) : ProcedureReturn tc() : EndIf
  If MapSize(tc()) >= #CACHE_MAX : FlushCache() : EndIf
  StartDrawing(ImageOutput(#Img_Measure))
  DrawingFont(FontID(font))
  w = TextWidth(text$) : h = TextHeight(text$)
  StopDrawing()
  If w < 1 : w = 1 : EndIf
  spr = nextSpr : nextSpr = nextSpr + 1
  CreateSprite(spr, w, h, #PB_Sprite_AlphaBlending)
  StartDrawing(SpriteOutput(spr))
  DrawingMode(#PB_2DDrawing_AllChannels)
  Box(0, 0, w, h, RGBA(0, 0, 0, 0))
  DrawingFont(FontID(font))
  DrawText(0, 0, text$, RGBA(Red(color), Green(color), Blue(color), 255), RGBA(0, 0, 0, 0))
  StopDrawing()
  tc(key$) = spr
  ProcedureReturn spr
EndProcedure

; displays a text at x, y (its sprite comes from the cache)
Procedure Txt(font, x, y, text$, color)
  DisplayTransparentSprite(GetText(font, text$, color), x, y)
EndProcedure

; displays a text horizontally centered on the screen
Procedure CTxt(font, y, text$, color)
  Protected spr = GetText(font, text$, color)
  DisplayTransparentSprite(spr, (#SW - SpriteWidth(spr)) / 2, y)
EndProcedure

; rectangle: a solid sprite zoomed to the wanted size (cells: 0 shot, 1 red, 2 cyan, 3 dark, 4 spark, 5 bolt, 6 white, 7 warning)
Procedure FillRect(cell, x, y, w, h)
  If w > 0 And h > 0
    ZoomSprite(#Spr_Solid + cell, w, h)
    DisplaySprite(#Spr_Solid + cell, x, y)
  EndIf
EndProcedure

; one line of the enemy list on the title screen
Procedure TitleRow(i, name$, info$, desc$)
  Protected y = 112 + i * 64
  Txt(0, 110, y + 6, name$, cGreen)
  Txt(0, 300, y + 6, info$, cYellow)
  Txt(0, 110, y + 30, desc$, cBlue)
EndProcedure

; sprite of a chat bubble (who: 0 = AI, 1 = Fred): rounded box + text lines, rendered once
Procedure GetBubble(who, text$)
  Protected key$ = "B|" + Str(who) + "|" + text$, i, n = CountString(text$, "|") + 1, w, t, h, lh, spr, bg, fg
  If FindMapElement(tc(), key$) : ProcedureReturn tc() : EndIf
  If MapSize(tc()) >= #CACHE_MAX : FlushCache() : EndIf
  StartDrawing(ImageOutput(#Img_Measure))
  DrawingFont(FontID(2))
  lh = TextHeight("Ag")
  For i = 1 To n
    t = TextWidth(StringField(text$, i, "|"))
    If t > w : w = t : EndIf
  Next
  StopDrawing()
  w = w + 20 : h = n * lh + 10
  If who = 0 : bg = RGB(244, 244, 250) : fg = RGB(25, 25, 45) : Else : bg = RGB(18, 80, 70) : fg = RGB(255, 255, 255) : EndIf
  spr = nextSpr : nextSpr = nextSpr + 1
  CreateSprite(spr, w, h, #PB_Sprite_AlphaBlending)
  StartDrawing(SpriteOutput(spr))
  DrawingMode(#PB_2DDrawing_AllChannels)
  Box(0, 0, w, h, RGBA(0, 0, 0, 0))
  RoundBox(0, 0, w, h, 8, 8, RGBA(Red(bg), Green(bg), Blue(bg), 255))
  DrawingFont(FontID(2))
  For i = 1 To n
    DrawText(10, 5 + (i - 1) * lh, StringField(text$, i, "|"), RGBA(Red(fg), Green(fg), Blue(fg), 255), RGBA(Red(bg), Green(bg), Blue(bg), 255))
  Next
  StopDrawing()
  tc(key$) = spr
  ProcedureReturn spr
EndProcedure

; (the bubble is displayed before the label: GetText may flush the cache, which would free the bubble sprite)
; one chat bubble with its label, returns the y of the next bubble
Procedure Bubble(who, text$, y)
  Protected spr = GetBubble(who, text$), x, h, lab$, lc
  h = SpriteHeight(spr)
  If who = 0 : x = 172 : lab$ = "AI" : lc = cLilac : Else : x = 668 - SpriteWidth(spr) : lab$ = "FRED" : lc = cGreen : EndIf
  DisplayTransparentSprite(spr, x, y + 16)
  Txt(2, x, y, lab$, lc)
  ProcedureReturn y + 16 + h + 8
EndProcedure

; Game Over chat, inspired by the LGTM video: one new message every 1.5 s
Procedure DrawChat(now)
  Protected n, y = 226, t = now - overAt - 700, m$, i, hs, h$ = "Hello, Fred. How can I help you today?"
  DisplayTransparentSprite(#Spr_Chat, 160, 192)
  hs = GetText(2, h$, cHead)
  DisplayTransparentSprite(hs, 160 + (520 - SpriteWidth(hs)) / 2, 198)
  If t >= 0 : n = t / 1500 + 1 : EndIf
  If n > 3 : n = 3 : EndIf
  If state = #St_Over
    m$ = "Sorry Fred, you lost ;)|I'm going to restore from the backup|right before you lost it."
    m$ = m$ + "#We don't have a backup.#You're right. I'm sorry for the confusion.|I'll restore from backup :)"
  Else
    m$ = "I reviewed all 4,200 lines in 0.2 seconds.|LGTM! Ship it."
    m$ = m$ + "#Did you actually read them?#You're absolutely right to ask!|It compiles. It passes. Nobody knows why."
  EndIf
  For i = 1 To n : y = Bubble(Bool(i = 2), StringField(m$, i, "#"), y) : Next
  If n < 3                                         ; typing indicator
    If n = 1 : Txt(2, 638, y + 4, Left("...", 1 + ((now / 250) & 1) * 2), cGreen)
    Else : Txt(2, 182, y + 4, Left("...", 1 + ((now / 250) & 1) * 2), cLilac) : EndIf
  EndIf
EndProcedure

; fake compilation shown at start
Procedure DrawBoot(now)
  Protected t = now - bootAt, p
  p = (t - 500) / 10
  If p < 0 : p = 0 : EndIf
  If p > 100 : p = 100 : EndIf
  ClearScreen(RGB(4, 6, 18))
  Txt(0, 40, 40, "> pbcompiler IA_Invaders.pb", cGreen)
  If t > 400 : Txt(0, 40, 80, "Compiling... " + RSet(Str(p), 3) + "% [" + Left("##########", p / 10) + Left("..........", 10 - p / 10) + "]", cGreen) : EndIf
  If t > 1600 : Txt(0, 40, 120, "0 errors, 0 warnings, 0 tests.", cBlue) : EndIf
  If t > 2200 : Txt(0, 40, 160, "Looks Good to Me!", cYellow) : EndIf
  If t > 2600 : Txt(0, 40, 220, "(Nobody Knows Why!!!)", cDBlue) : EndIf
  If t > 3000 : Txt(0, 40, 260, "_", cGreen) : EndIf
EndProcedure

; draws everything for the current state: only sprites are displayed here
Procedure Draw()
  Protected r, c, i, j, k, f, a, by, y, x0, x1, mx, vis, now = ElapsedMilliseconds()
  ; boot screen: fake compilation, nothing else to draw
  If state = #St_Boot : DrawBoot(now) : ProcedureReturn : EndIf
  ; background
  DisplaySprite(#Spr_BG, 0, 0)

  If state = #St_Title
    ; title screen: panel and enemy icons
    DisplayTransparentSprite(#Spr_Title, 20, 64)
    For i = 0 To 4
      ClipSprite(#Spr_Enemies, i * 64, ((now / 400) & 1) * 48, 64, 48)
      DisplayTransparentSprite(#Spr_Enemies, 34, 120 + i * 64)
    Next
  ElseIf state = #St_Over Or state = #St_Win
    ; game over / victory: Fred, sad or normal
    ClipSprite(#Spr_Player, Bool(state = #St_Over) * 192, 0, 64, 72)
    DisplayTransparentSprite(#Spr_Player, 48, 284)
  ElseIf state = #St_Play
    ; gameplay: armada, special enemies, explosions, Fred, bullets and effects
    ; armada (the damaged Code Knot is semi-transparent)
    For r = 0 To #ROWS - 1
      For c = 0 To #COLS - 1
        If hp(r, c)
          If hp(r, c) = 1 And r = 1 : a = 150 : Else : a = 255 : EndIf
          ClipSprite(#Spr_Enemies, r * 64, frame * 48, 64, 48)
          DisplayTransparentSprite(#Spr_Enemies, ax + c * #CELL_W, ay + r * #ROW_H, a)
        EndIf
      Next
    Next
    ; CEO Cash and MegaCenter (they blink when hit)
    For k = 0 To 1
      If spOn(k)
        vis = Bool(now >= spHit(k) Or ((now / 50) & 1) = 0)
        If vis
          ClipSprite(#Spr_Enemies, (3 + k) * 64, ((now / 150) & 1) * 48, 64, 48)
          DisplayTransparentSprite(#Spr_Enemies, spX(k), spY(k))
        EndIf
      EndIf
    Next
    ; explosions
    For i = 0 To 31
      If boom(i)\t > now
        ClipSprite(#Spr_Enemies, boom(i)\kind * 64, 96, 64, 48)
        DisplayTransparentSprite(#Spr_Enemies, boom(i)\x, boom(i)\y)
      EndIf
    Next
    ; rubber duck, and the Bug flying back to the armada (Fixed by AI)
    If duckOn : ClipSprite(#Spr_Enemies, 320, 0, 64, 48) : DisplayTransparentSprite(#Spr_Enemies, duckX, duckY) : EndIf
    If rbOn : ClipSprite(#Spr_Enemies, 0, ((now / 100) & 1) * 48, 64, 48) : DisplayTransparentSprite(#Spr_Enemies, rbX, rbY) : EndIf
    ; Fred: idle, firing or hit frame, small bounce when moving, blinks while invulnerable
    f = 0 : by = #PLAYER_Y
    If moving And ((now / 90) & 1) = 1 : by = by + 3 : EndIf
    If now < hitUntil : f = 2 : ElseIf now < fireUntil : f = 1 : EndIf
    If now >= invUntil Or ((now / 90) & 1) = 0
      ClipSprite(#Spr_Player, f * 64, 0, 64, 72)
      DisplayTransparentSprite(#Spr_Player, px, by)
    EndIf
    ; Fred bullets and enemy bombs (cyan = hallucination)
    For i = 0 To #MAX_SHOTS - 1 : If shot(i)\act : FillRect(0, shot(i)\x, shot(i)\y, 4, 14) : EndIf : Next
    For i = 0 To 15
      If bomb(i)\act : a = 1 : If bomb(i)\act > 1 : a = 2 : EndIf : FillRect(a, bomb(i)\x, bomb(i)\y, 6, 14) : EndIf
    Next
    ; rubber duck shield
    If now < shieldUntil And (shieldUntil - now > 1200 Or ((now / 100) & 1) = 1) : DisplayTransparentSprite(#Spr_Ring, px - 14, #PLAYER_Y - 6) : EndIf
    ; hit points and impact sparks of the special enemies
    For k = 0 To 1
      If spOn(k)
        If k = #SP_CASH : mx = #CASH_HITS : Else : mx = #MEGA_HITS : EndIf
        For j = 1 To mx                                ; hit points
          If j <= spHp(k) : a = 1 : Else : a = 3 : EndIf
          FillRect(a, spX(k) + 32 - mx * 8 + (j - 1) * 16, spY(k) + 44, 12, 5)
        Next
        If now < spHit(k)                              ; impact sparks
          For j = 1 To 8 : FillRect(4, spX(k) + Random(60), spY(k) + 8 + Random(30), 4, 4) : Next
        EndIf
      EndIf
    Next
    ; MegaCenter lightning: warning line, then the strike
    If bState = 1
      For y = spY(#SP_MEGA) + 44 To #SH Step 20 : FillRect(7, bX, y, 2, 8) : Next
    ElseIf bState = 2
      x0 = bX
      For y = spY(#SP_MEGA) + 44 To #SH Step 22
        x1 = bX + Random(28) - 14
        If x1 < x0 : a = x1 : j = x0 - x1 : Else : a = x0 : j = x1 - x0 : EndIf
        FillRect(5, a - 3, y, j + 7, 7) : FillRect(5, x1 - 3, y, 7, 22)
        FillRect(6, a - 1, y + 2, j + 3, 3) : FillRect(6, x1 - 1, y, 3, 22)
        x0 = x1
      Next
    EndIf
  EndIf

  ; HUD: score, level, hi-score, lives, wave and the message line
  If state <> #St_Title
    Txt(0, 16, 8, "SCORE " + RSet(Str(score), 7, "0"), cGreen)
    Txt(0, 330, 8, "LEVEL " + Str(wave), cBlue)
    Txt(0, 560, 8, "HI-SCORE " + RSet(Str(hiscore), 7, "0"), cYellow)
    Txt(0, 16, #SH - 28, "FRED x " + Str(lives), cWhite)
    Txt(0, #SW - 200, #SH - 28, "WAVE " + Str(wave) + "/" + Str(#MAX_WAVE), cGreen)
    If now < msgUntil : CTxt(0, #SH - 28, msg$, cMsg) : EndIf
  EndIf
  ; big titles
  Select state
    Case #St_Title : CTxt(1, 14, "IA Invaders", cGreen)
    Case #St_Over : CTxt(1, 76, "Game Over dear Developper!", cRed)
    Case #St_Win : CTxt(1, 76, "LGTM!  Shipped to Prod", cGreen)
  EndSelect
  ; texts of the title screen, and of the Game Over / victory screens (with the chat)
  Select state
    Case #St_Title
      CTxt(0, 70, "Looks Good to Me. It compiles. It passes. Nobody knows why!", cBlue)
      TitleRow(0, "BUG", Str(#PTS_BUG) + " pts - 1 hit", "Bug. Squash it. It can reappear due to a fake AI fix")
      TitleRow(1, "CODE KNOT", Str(#PTS_KNOT) + " pts - 2 hits", "Spaghetti code: needs a refactor.")
      TitleRow(2, "GIT COMMIT", Str(#PTS_COMMIT) + " pts - 1 hit", "Merge conflict: armada speeds up! Cyan shots: fake.")
      TitleRow(3, "CEO CASH $$$", Str(#PTS_CASH) + " pts - " + Str(#CASH_HITS) + " hits", "Kill it: armada UP 1 line! Catch the duck for a 6s shield")
      TitleRow(4, "MEGACENTER", Str(#PTS_MEGA) + " pts - " + Str(#MEGA_HITS) + " hits", "Lightning! Escape: armada DOWN 1 line!")
      CTxt(0, 436, "ARROWS = move    SPACE = fire    ESC = quit", cWhite)
      CTxt(0, 484, "Kill the CEO, catch the RUBBER DUCK = shield!", cYellow)
      CTxt(0, 540, "HI-SCORE " + RSet(Str(hiscore), 7, "0"), cYellow)
    Case #St_Over, #St_Win
      CTxt(0, 150, "FINAL SCORE " + RSet(Str(score), 7, "0"), cWhite)
      DrawChat(now)
  EndSelect
  ; blinking PRESS SPACE
  If state <> #St_Play And ((now / 500) & 1) = 1
    by = 516 : If state = #St_Over Or state = #St_Win : by = 512 : EndIf
    CTxt(0, by, "PRESS SPACE", cGreen)
  EndIf
EndProcedure

; ---------- main ----------
Define ev, quit, now, last, ticks, acc.f, wt$ = "IA Invaders - PurePunch Halloween 2026"


UsePNGImageDecoder()
UseOGGSoundDecoder()
If InitSprite() = 0 Or InitKeyboard() = 0
  MessageRequester("IA Invaders", "Cannot initialize the screen.")
  End
EndIf

; DPI aware: the window inner size must be exactly #SW x #SH real pixels
OpenWindow(0, 0, 0, DesktopUnscaledX(#SW), DesktopUnscaledY(#SH), wt$, #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
Need(OpenWindowedScreen(WindowID(0), 0, 0, #SW, #SH, #False, 0, 0), "screen")

Need(CatchSprite(#Spr_BG, ?background), "background.png")
Need(CatchSprite(#Spr_Enemies, ?enemies_sheet, #PB_Sprite_AlphaBlending), "enemies_sheet.png")
Need(CatchSprite(#Spr_Player, ?player, #PB_Sprite_AlphaBlending), "player.png")
LoadFont(0, "Courier New", DesktopUnscaledX(14), #PB_Font_Bold)
LoadFont(1, "Courier New", DesktopUnscaledX(36), #PB_Font_Bold)
LoadFont(2, "Comic Sans MS", DesktopUnscaledX(11))
cGreen = RGB(60, 255, 160) : cBlue = RGB(150, 170, 255) : cYellow = RGB(255, 210, 40) : cWhite = RGB(255, 255, 255)
cMsg = RGB(255, 235, 90) : cDBlue = RGB(80, 114, 255) : cRed = RGB(255, 80, 80) : cLilac = RGB(190, 140, 255) : cHead = RGB(120, 150, 255)
nextSpr = #Spr_Cache
BuildSprites()

hasSound = InitSound()
If hasSound
  CatchSound(#Snd_Shoot, ?snd_shoot, ?Endsnd_shoot - ?snd_shoot) : SoundVolume(#Snd_Shoot, 35)
  CatchSound(#Snd_Explosion, ?snd_explosion, ?Endsnd_explosion - ?snd_explosion) : SoundVolume(#Snd_Explosion, 25)
  If CatchSound(#Snd_Music, ?music_theme, ?Endmusic_theme - ?music_theme)
    SoundVolume(#Snd_Music, 50)
    PlaySound(#Snd_Music, #PB_Sound_Loop)
  EndIf
EndIf

quotes$ = "REGRESSION DETECTED!|WORKS ON MY MACHINE|IT WAS WORKING YESTERDAY|TRY TURNING IT OFF AND ON AGAIN" +
          "|NOT A BUG, IT'S A FEATURE|SEGFAULT (CORE DUMPED)|STACK OVERFLOW... AGAIN|YOU'RE ABSOLUTELY RIGHT!"
state = #St_Boot : bootAt = ElapsedMilliseconds()
last = ElapsedMilliseconds()
Repeat
  now = ElapsedMilliseconds() : acc = acc + (now - last) : last = now        ; time elapsed since the previous loop
  If acc > 250 : acc = 250 : EndIf                                           ; after a long pause (window dragged...) do not catch up
  Repeat
    ev = WindowEvent()
    If ev = #PB_Event_CloseWindow : quit = #True : EndIf
  Until ev = 0
  ExamineKeyboard()
  If KeyboardPushed(#PB_Key_Escape) : quit = #True : EndIf
  If state = #St_Boot
    If ElapsedMilliseconds() - bootAt > 3400 Or KeyboardPushed(#PB_Key_Space) : state = #St_Title : lock = ElapsedMilliseconds() + 300 : EndIf
  ElseIf state <> #St_Play And KeyboardPushed(#PB_Key_Space) And ElapsedMilliseconds() > lock
    NewGame()
  EndIf
  ticks = 0
  While acc >= #TICK_MS                                                      ; fixed time step: the game logic always advances by 1/60 s
    If state = #St_Play : Update() : EndIf
    acc = acc - #TICK_MS : ticks = ticks + 1
  Wend
  Draw()
  FlipBuffers()
  If ticks = 0 : Delay(1) : EndIf                                            ; nothing to compute yet (vsync off): let the CPU rest
Until quit

; resources embedded in the executable (the files must be next to this source when compiling)
DataSection
  background:    : IncludeBinary "background.png"    : Endbackground:
  enemies_sheet: : IncludeBinary "enemies_sheet.png" : Endenemies_sheet:
  player:        : IncludeBinary "player.png"        : Endplayer:
  snd_shoot:     : IncludeBinary "snd_shoot.wav"     : Endsnd_shoot:
  snd_explosion: : IncludeBinary "snd_explosion.wav" : Endsnd_explosion:
  music_theme:   : IncludeBinary "music_theme.ogg"   : Endmusic_theme:
EndDataSection

; IDE Options = PureBasic 6.41 (Windows - x64)
; Folding = ------
; Optimizer
; EnableXP
; DPIAware
; UseIcon = IA_Invaders_icon.ico
; Executable = IA_Invaders.exe
; Compiler = PureBasic 6.41 - C Backend (Windows - x64)
; IncludeVersionInfo
; VersionField0 = 1.2.0.0
; VersionField1 = 12.0.0
; VersionField2 = ChrisR
; VersionField3 = IA Invaders
; VersionField5 = 1.2
; VersionField6 = IA Invaders