            .cpu "6502i"
            
            .text "NES",$1a
            .byte (MAINBANK/2)+2 ;16k prg
            .byte 1 ;16k chr
            .byte $70 ;vrc4f
            .byte $10
            
            MAINBANK = $1c
            IRQTIME = 2 ;223 cycles for 8000Hz sample rate
                            ;(2 scanlines is 227.3 cycles, very close!)
            
            
framecounter = $09
rand = $07a7 ;7 random numbers here


cursamp := 0
curcoarsebank := 0
makesamp .segment
S_\2 = cursamp
cursamp += 1
loc := (* * 1) - $10
SP_\2 = (loc & $ff) | (loc & $1f00 | $8000) | (loc / $2000 * $10000) | (curcoarsebank * $80000)
        s := binary(\1)
        .if loc + len(s) >= $10000
            curcoarsebank += 1
        .endif
        .for i = 0, i < len(s), i += 1
            .byte s[i]/2
        .next
        .byte $c0
        .endm
            
            * = $10
            .logical $8000 ;trampoline bank 0
ramcode     .logical $6000
ramcodedest 
irq         pha
            lda #$40
            sta nmiflag
sampbank = *+1
            lda #0
            sta $8000
sampptr = *+1
            lda $ffff
            sta $4011
            bmi lastirq
            sta $f003
            inc sampptr
            bne irqend
            sec
            lda #$a0
            isb sampptr+1
            bne irqend
            inc sampbank
            lda #$80
            sta sampptr+1
irqend      lda #MAINBANK
            sta $8000
            asl nmiflag
            bcs irqtonmi+1
            pla
            rti
            
lastirq     ;lda #$00
            sta $f002
            jmp irqend
            


            ;nmi can happen during irq - so we need to prevent that
nmi         bit nmiflag
            bvs nmitoirq
irqtonmi    pha
            txa
            pha
            tya
            pha
            lda mainloopflag
            bne +
            jmp $8082
+           lda $0779 ;reset scroll if and only if rendering is on
            and #$08
            beq nmiend
            lda #$00
            sta $2005
            sta $2005
            lda $0778
            ora #$80
            and #$fe
            sta $2000
nmiend      cli
            jsr sampcontrol
            
            lda $0722
            beq nmiskipscroll
-           bit $2002
            bvs -
nmictrl = *+1
            lda #0
            ora #$80
            tay
nmiscroll = *+1
            lda #0
            ldx #$00
-           bit $2002
            bvc -
            sei
            .rept 6
                php
                plp
            .next
            sta $2005
            stx $2005
            sty $2000
nmiskipscroll
            inc nmicnt
            pla
            tay
            pla
            tax
            pla
            rti
nmitoirq    asl nmiflag
            rti

nmiflag .byte 0
mainloopflag .byte 0
            
            
            
mainloop    lda $073f
            sta nmiscroll
            lda $0778
            sta nmictrl
            
            lda nmicnt
nmicnt = *+1
-           cmp #0
            beq -
            
            inc mainloopflag
            
            inc $09
            
            jsr $8e5c
            jsr $8182
            jsr $8f97
            
            lda $0776
            lsr
            bcs ++
            jsr $80f6
            lda $0722
            beq +
            jsr $8223
            jsr $81c6
+           jsr $8212
+           jsr $811b

            dec mainloopflag
            
            jmp mainloop
            
            
            
sampcontrol cli
            
            
            ;jumping sfx
jumpflag = *+1
            lda #0
            beq _nojump
            ldy #S_BOING
            lda rand
            beq _setjump
jumpphase = *+1
            ldx #0
            lda jumptimer
            cmp #$0c
            bcc +
            ldx #0
            stx jumpphase
+           cpx #2
            beq _jump2
_jump0      lda rand
            and #3
            clc
            adc #S_YA
            tay
            bne _setjump
_jump2      lda rand
            and #7
            cmp #6
            bcc +
            sbc #6
            clc
+           adc #S_HAHA
            tay
_setjump    sty sampflag
            inc jumpphase
_endjump    lda #0
            sta jumptimer
            sta jumpflag
_nojump     
            
            
            
            ; title screen
            lda $0770
            bne _skiptitle
            lda $0772
            cmp #2
            bne _skiptitle
democnt = *+1
            lda #0
            inc democnt
            ldx #S_ITSAME
            cmp #0
            beq +
            lsr
            ldx #S_HELLO
            bcc +
            ldx #S_PRESSSTART
+           stx sampflag
_skiptitle  
            
            ; game over
            lda $fc
            and #$02
            beq +
            lda #S_GAMEOVER
            sta sampflag
+           
            ; ending
            lda $fc
            and #$04
            beq +
            lda #S_THANKYOU
            sta sampflag
+           
            ;level complete
            lda $fc
            and #$20
            beq +
            lda #S_HEREWEGO
            sta sampflag
+           
            ;starman
            lda $fb
            and #$50
            beq +
            lda #S_HEREWEGO
            sta sampflag
+           
            ;castle complete
            lda $fc
            and #$08
            beq +
            lda #S_SOLONG
            sta sampflag
+           
            
            ;handle death moan
deadtimer = *+1
            lda #$ff
            bmi +
            dec deadtimer
            bpl +
            lda #S_DEAD
            sta sampflag
+           
            
            
            lda $1d ;don't count the counter when player is not grounded
            bne +
jumptimer = *+1
            lda #$ff
            cmp #$ff
            beq +
            inc jumptimer
+           
            
            
            
sampflag = *+1
            ldx #$ff
            bmi +
            lda samptbllo,x
            sta sampptr
            lda samptblhi,x
            sta sampptr+1
            lda samptblbank,x
            sta sampbank
            lda #$ff
            sta sampflag
            lda #$03
            sta $f002
+           
            
            
            jmp $f2d0
            
samptbllo   .byte <samptbl
samptblhi   .byte >samptbl
samptblbank .byte `samptbl
            
            
reset4      stx $8000
            jmp $8001
            
            
            
gamestarthook
            lda #S_LETSAGO
            sta sampflag
            jmp $9c03
            
            
            
fallhook    sty $0712
            pha
            jsr $90f2 ;get level music
            ldy #$00
            sty $fb
            ldy #S_BURNED ;castle
            cmp #$08
            beq +
            ldy #S_DROWN ;underwater
            cmp #$02
            beq +
            ldy #S_FALL
+           sty sampflag
            pla
            jmp $b1a6
            
            
            
hurthook    ldx #S_HURT
            stx sampflag
            ldx $0756 ;small mario?
            beq +
            jmp $d936
+           lda #$48
            sta deadtimer
            jmp $d958
            
            
            
jumphook    inc jumpflag
            ldy $0754
            jmp $b516
            
            .here
            
            
reset3      ldx #$00
            stx $2000
            stx $2001
            dex
            stx $4017
            ; ... set up mapper
            ;chr banks
            ldx #$07
            stx $e002
            dex
            stx $e000
            dex
            stx $d002
            dex
            stx $d000
            dex
            stx $c002
            dex
            stx $c000
            dex
            stx $b002
            dex
            stx $b000
            stx $b001
            stx $b003
            stx $c001
            stx $c003
            stx $d001
            stx $d003
            stx $e001
            stx $e003
            ;vertical mirroring
            lda #$00
            sta $9000
            ;irq
            sta $f002 ;disable irq
            lda #($100 - IRQTIME) ;set latch value
            sta $f000
            lda #($100 - IRQTIME) >> 4
            sta $f001
            cli
            
            ;copy ram code to prg-ram
            ldx #0
-           lda ramcode,x
            sta ramcodedest,x
            lda ramcode + $100,x
            sta ramcodedest + $100,x
            lda ramcode + $200,x
            sta ramcodedest + $200,x
            inx
            bne -
            
            ;now go to game
            ldx #MAINBANK+1
            stx $a000
            dex
            jmp reset4
            
            
            
            
            .here
            
samptbl=[SP_HELLO,SP_PRESSSTART,SP_GAMEOVER,SP_ITSAME,SP_THANKYOU,SP_HEREWEGO,SP_LETSAGO,SP_FALL,SP_DROWN,SP_BURNED,SP_HURT,SP_DEAD,SP_YA,SP_YAH,SP_WOO,SP_WA,SP_HAHA,SP_HOOHOO,SP_WAHA,SP_YAHOO,SP_YIPPEE,SP_BOING,SP_SOLONG
        ]
            
            #makesamp "raw_8000/sm64_mario_hello.raw", HELLO
            #makesamp "raw_8000/sm64_mario_press_start.raw", PRESSSTART
            #makesamp "raw_8000/sm64_mario_game_over.raw", GAMEOVER
            #makesamp "raw_8000/sm64_mario_its_me.raw", ITSAME
            #makesamp "raw_8000/sm64_mario_thank_you.raw", THANKYOU
            #makesamp "raw_8000/sm64_mario_here_we_go.raw", HEREWEGO
            #makesamp "raw_8000/sm64_mario_lets_go.raw", LETSAGO
            #makesamp "raw_8000/sm64_mario_falling.raw", FALL
            #makesamp "raw_8000/sm64_mario_drowning.raw", DROWN
            #makesamp "raw_8000/sm64_mario_burned.raw", BURNED
            #makesamp "raw_8000/sm64_mario_hurt.raw", HURT
            #makesamp "raw_8000/sm64_mario_lost_a_life.raw", DEAD
            #makesamp "raw_8000/mario-ya.raw", YA
            #makesamp "raw_8000/mario-yah.raw", YAH
            #makesamp "raw_8000/mario-woo.raw", WOO
            #makesamp "raw_8000/mario-wa.raw", WA
            #makesamp "raw_8000/sm64_mario_haha.raw", HAHA
            #makesamp "raw_8000/sm64_mario_hoohoo.raw", HOOHOO
            #makesamp "raw_8000/sm64_mario_waha.raw", WAHA
            #makesamp "raw_8000/sm64_mario_yahoo.raw", YAHOO
            #makesamp "raw_8000/sm64_mario_yippee.raw", YIPPEE
            #makesamp "raw_8000/sm64_mario_boing.raw", BOING
            #makesamp "raw_8000/sm64_mario_so_long_bowser.raw", SOLONG
                        
            
            
            
            
            ; ---------------- original prg banks
            * = (MAINBANK*$2000)+$10
            .logical $8000
            .binary "Super Mario Bros. (W) [!].nes",$10,$7ffe
            * = $e392
reset       lda #$00
            sta $9002
            jmp reset2
            * = $f2ca
reset2      sta $8000
            jmp reset3
            
            ;disable write to $4011 in music
            * = $f37d
            rts
            rts
            rts
            
            ;recode nmi to remove all game logic
            * = $8057
            jmp mainloop
            * = $8085
            ora #$80
            * = $808a
            and #$fe
            * = $8119
            rts
            * = $8138
            rts
            * = $80e4
            jmp nmiend
            
            ;play sample on game start
            * = $82e6
            jsr gamestarthook
            
            ;play sample on falling
            * = $b1a3
            jmp fallhook
            
            ;play sample on hurt
            * = $d931
            jmp hurthook
            
            ;play sample on jump
            * = $b513
            jmp jumphook
            
            
            
            * = $fffa
            .word nmi
            .word reset
            .word irq
            .here
            
            
            
            
            
            ; ---------------- chr
            .binary "Super Mario Bros. (W) [!].nes",$8010,$2000
            ;bonus image ^_^
            ;.binary "firsttry/newchr.chr"
        .comment
bitmap = binary("firsttry/firsttry.data")
            .for ytile = 0, ytile < 16, ytile += 1
                .for xtile = 0, xtile < 16, xtile += 1
                    .for plane = 0, plane < 2, plane += 1
                        .for yfine = 0, yfine < 8, yfine += 1
                            val := 0
                            .for xfine = 0, xfine < 8, xfine += 1
                                .if bitmap[ytile*128*8 + xtile*8 + yfine*128 + xfine] & (1 << plane)
                                    val := val | ($80 >> xfine)
                                .endif
                            .next
                            .byte val
                        .next
                    .next
                .next
            .next
            ;to fill in a full $2000 bytes of CHR
            .for ytile = 0, ytile < 16, ytile += 1
                .for xtile = 15, xtile >= 0, xtile -= 1
                    .for plane = 0, plane < 2, plane += 1
                        .for yfine = 0, yfine < 8, yfine += 1
                            val := 0
                            .for xfine = 0, xfine < 8, xfine += 1
                                .if bitmap[ytile*128*8 + xtile*8 + yfine*128 + xfine] & (1 << plane)
                                    val := val | (1 << xfine)
                                .endif
                            .next
                            .byte val
                        .next
                    .next
                .next
            .next
        .endc
            