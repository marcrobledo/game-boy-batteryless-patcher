; Game Boy battery-less patching for bootleg cartridges
; by Marc Robledo 2024
; based on BennVennElectronic's tutorial (https://www.youtube.com/watch?v=l2bx-udTN84)
; ------------------------------------------------------------------------------------
; see README file


INCLUDE "src/hardware.inc" ;https://github.com/gbdev/hardware.inc
INCLUDE "src/bootleg_types.inc"


; -------- BOOTLEG CARTRIDGE TYPE --------
; Define your bootleg cartridge type.
; Valid values (see bootleg_types.inc):
; - WRAAAA9_64KB: WR/AAA/A9 cart type with 64kb (0x00010000) flashable sector size
DEF BOOTLEG_CARTRIDGE_TYPE EQU WRAAAA9_64KB














; ---------------- HEADER ----------------
; modify game header if needed
IF DEF(CHANGE_CART_TYPE)
	SECTION "Cart type", ROM0[$0147]
	DB CHANGE_CART_TYPE
ENDC
IF DEF(CHANGE_CART_SIZE)
	SECTION "Cart size", ROM0[$0148]
	DB CHANGE_CART_SIZE
ENDC



; --------------- RAM/HRAM ---------------
; define section and label for game's current bank byte
IF GAME_ENGINE_CURRENT_BANK_OFFSET >= _HRAM
	SECTION "HRAM - original game's bank switch backup", HRAM[GAME_ENGINE_CURRENT_BANK_OFFSET]
ELIF GAME_ENGINE_CURRENT_BANK_OFFSET >= _RAM
	SECTION "WRAM - original game's bank switch backup", WRAM0[GAME_ENGINE_CURRENT_BANK_OFFSET]
ELSE
	SECTION "SRAM - original game's bank switch backup", SRAM[GAME_ENGINE_CURRENT_BANK_OFFSET], BANK[0]
ENDC

_current_game_bank:
	DB



; ----------------- ROM -----------------
; hook game's boot and execute our boot_hook subroutine beforehand
IF DEF(GAME_BOOT_OFFSET)
	SECTION "ROM - Entry point", ROM0[$0100]
	nop
	;jp		boot_original
	jp		boot_hook

	SECTION "ROM - Original game boot", ROM0[GAME_BOOT_OFFSET]
	boot_original:
ENDC

SECTION "ROM - Bank 0 free space", ROM0[BANK0_FREE_SPACE]
IF DEF(GAME_BOOT_OFFSET)
	boot_hook:
		;this will be run during boot, will copy savegame from Flash ROM to SRAM
		push	af
		ld		a, BANK(copy_save_flash_to_sram)
		ld		[rROMB0], a
		call	copy_save_flash_to_sram
		ld		a, 1
		ld		[rROMB0], a
		pop		af
		jp		boot_original
ENDC


save_sram_to_flash:
	; IF DEF(DISABLE_HW_WHEN_SAVING)
	; 	;disable screen, timer and speaker
	; 	ldh		a, [rIE]
	; 	push	af
	; 	ldh		a, [rIF]
	; 	push	af
	; 	ldh		a, [rTAC]
	; 	push	af
	; 	ldh		a, [rSTAT]
	; 	push	af
	; 	ldh		a, [rNR50]
	; 	push	af
	; 	halt 
	; 	xor  a
	; 	ld   [rIE], a
	; 	ld   [rIF], a
	; 	ld   [rTAC], a
	; 	ld   [rSTAT], a
	; 	ld   [rNR50], a
	; ENDC

	;this will be run when the game saves, will copy savegame from SRAM to Flash ROM
	di
	push	af
	push	bc
	push	de
	push	hl

	ld		a, BANK(erase_and_write_ram_banks)
	ld		[rROMB0], a
	call	erase_and_write_ram_banks
	IF GAME_ENGINE_CURRENT_BANK_OFFSET >= _HRAM
		ldh		a, [_current_game_bank]
	ELSE
		ld		a, [_current_game_bank]
	ENDC
	ld		[rROMB0], a

	pop		hl
	pop		de
	pop		bc
	pop		af


	; IF DEF(DISABLE_HW_WHEN_SAVING)
	; 	;reenable screen, timer and speaker
	; 	pop		af
	; 	ldh		[rNR50], a
	; 	pop		af
	; 	ldh		[rSTAT], a
	; 	pop		af
	; 	ldh		[rTAC], a
	; 	pop		af
	; 	ldh		[rIF], a
	; 	pop		af
	; 	ldh		[rIE], a
	; ENDC

	reti

bank_switch_and_copy_from_flash_to_sram:
	;this subroutine is called by copy_save_flash_to_sram
	;we store it in bank 0 to make bank switching easier while copying from Flash ROM to SRAM
	ld		[rROMB0], a
.loop:
	ld		a, [hli]
	ld		[de], a
	inc		de
	dec		bc
	ld		a, c
	or		b
	jr		nz, .loop
	ld		a, BANK(copy_save_flash_to_sram)
	ld		[rROMB0], a
	ret




SECTION "ROM - Free space", ROMX[BATTERYLESS_CODE_OFFSET], BANK[BATTERYLESS_CODE_BANK]
copy_save_flash_to_sram:
	;copy code from Flash ROM to SRAM, this is executed during game's intercepted boot
	ld		a, CART_SRAM_ENABLE
	ld		[rRAMG], a ;enable SRAM

	xor		a
	ld		[rRAMB], a ;set RAM bank 0
	ld		hl, $4000 ;source (Flash ROM)
	ld		de, _SRAM ;target (SRAM)
	ld		bc, $2000 ;size
	ld		a, BANK_FLASH_DATA ;set source ROM bank
	call	bank_switch_and_copy_from_flash_to_sram

	IF SRAM_SIZE_32KB
		;8kb-16kb
		ld		a, 1
		ld		[rRAMB], a ;set RAM bank 1
		;hl is $6000 here
		ld		de, _SRAM ;target (SRAM)
		ld		bc, $2000 ;size
		ld		a, BANK_FLASH_DATA ;set source ROM bank
		call	bank_switch_and_copy_from_flash_to_sram

		;16kb-24kb
		ld		a, 2
		ld		[rRAMB], a ;set RAM bank 2
		ld		hl, $4000 ;source (Flash ROM)
		ld		de, _SRAM ;target (SRAM)
		ld		bc, $2000 ;size
		ld		a, BANK_FLASH_DATA + 1 ;set source ROM bank
		call	bank_switch_and_copy_from_flash_to_sram

		;24kb-32kb
		ld		a, 3
		ld		[rRAMB], a ;set RAM bank 3
		;hl is $6000 here
		ld		de, _SRAM ;target (SRAM)
		ld		bc, $2000 ;size
		ld		a, BANK_FLASH_DATA + 1 ;set source ROM bank
		call	bank_switch_and_copy_from_flash_to_sram
	ENDC
	
	ret



;parameters:
; - hl: source
; - de: target
; - bc: size
copy_data:
.loop:
	ld		a, [hli]
	ld		[de], a
	inc		de
	dec		bc
	ld		a, c
	or		b
	jr		nz, .loop
	ret


erase_and_write_ram_banks:
	;safe to be run from ROM, since it will copy the needed subroutines to RAM and call them there

	;erase 64kb block
	ld		hl, erase_one_flash_erase_block
	ld		de, WRAM0_FREE_SPACE
	ld		bc, erase_one_flash_erase_block_end - erase_one_flash_erase_block
	call	copy_data
	call	WRAM0_FREE_SPACE
	nop

	;write
	ld		hl, write_sram_to_flash_rom
	ld		de, WRAM0_FREE_SPACE
	ld		bc, write_sram_to_flash_rom_end - write_sram_to_flash_rom
	call	copy_data
	call	WRAM0_FREE_SPACE
	nop

	IF SRAM_SIZE_32KB
		REPT 7 - 1
			nop ;some dummy nops to guarantee correct flashing, might not be needed?
		ENDR

		;8kb-16kb
		;edit subroutine directly in RAM, changing some values
		ld		a, HIGH($6000)
		ld		[WRAM0_FREE_SPACE + (write_sram_to_flash_rom.set_destination_offset - write_sram_to_flash_rom) + 2], a ;destination ROM offset=$6000
		ld		a, 1
		ld		[WRAM0_FREE_SPACE + (write_sram_to_flash_rom.set_source_copy_bank - write_sram_to_flash_rom) + 1], a ;source SRAM bank=1
		call	WRAM0_FREE_SPACE
		nop
		REPT 7 - 1
			nop ;some dummy nops to guarantee correct flashing, might not be needed?
		ENDR

		;16kb-24kb
		;edit subroutine directly in RAM, changing some values
		ld		a, BANK_FLASH_DATA + 1
		ld		[WRAM0_FREE_SPACE + (write_sram_to_flash_rom.set_destination_bank - write_sram_to_flash_rom) + 1], a ;destination ROM bank=BANK_FLASH_DATA + 1
		ld		a, HIGH($4000)
		ld		[WRAM0_FREE_SPACE + (write_sram_to_flash_rom.set_destination_offset - write_sram_to_flash_rom) + 2], a ;destination ROM offset=$4000
		ld		a, 2
		ld		[WRAM0_FREE_SPACE + (write_sram_to_flash_rom.set_source_copy_bank - write_sram_to_flash_rom) + 1], a ;source SRAM bank=2
		call	WRAM0_FREE_SPACE
		nop
		REPT 7 - 1
			nop ;some dummy nops to guarantee correct flashing, might not be needed?
		ENDR

		;24kb-32kb
		;edit subroutine directly in RAM, changing some values
		ld		a, HIGH($6000)
		ld		[WRAM0_FREE_SPACE + (write_sram_to_flash_rom.set_destination_offset - write_sram_to_flash_rom) + 2], a ;destination ROM offset=$6000
		ld		a, 3
		ld		[WRAM0_FREE_SPACE + (write_sram_to_flash_rom.set_source_copy_bank - write_sram_to_flash_rom) + 1], a ;source SRAM bank=3
		call	WRAM0_FREE_SPACE
		nop
	ENDC

	ret

erase_one_flash_erase_block:
	ld		a, BANK_FLASH_DATA
	ld		[rROMB0], a
	nop

	ld		a, $f0
	ld		[$4000], a
	nop

	ld		a, $a9
	ld		[$0aaa], a
	nop

	ld		a, $56
	ld		[$0555], a
	nop

	ld		a, $80
	ld		[$0aaa], a
	nop

	ld		a, $a9
	ld		[$0aaa], a
	nop

	ld		a, $56
	ld		[$0555], a
	nop

	ld		a, $30
	ld		[$4000], a
	nop

.loop:
	ld		a, [$4000]
	cp		a, $ff
	jr		z, .end
	jr		.loop
	;jr		nz, .loop ;possible optimization? to-do: test if it's not breaking anything
.end:
	nop

	ld		a, $f0
	ld		[rRAMB], a
	ld		a, BATTERYLESS_CODE_BANK
	ld		[rROMB0], a
	ret
erase_one_flash_erase_block_end:




write_sram_to_flash_rom:
.set_destination_bank:
	ld		a, BANK_FLASH_DATA
	ld		[rROMB0], a
	ld		hl, _SRAM
.set_destination_offset:
	ld		de, $4000
.loop:
	ld		a, CART_SRAM_ENABLE
	ld		[rRAMG], a ;enable SRAM

	;RTC (not needed?)
	;ld		a, 1
	;ld		[$6000], a
	
.set_source_copy_bank:
	IF SRAM_SIZE_32KB
		ld		a, $00 ;so we can replace $00 with following block indexes later
	ELSE
		xor		a
	ENDC
	ld		[rRAMB], a
	ld		a, [hl]
	ld		b, a

	xor		a

	;RTC (not needed?)
	;ld		[$6000], a

	ld		[rRAMG], a ;disable SRAM
	ld		a, $f0
	ld		[rRAMB], a
	nop

	ld		a, $a9
	ld		[$0aaa], a
	nop

	ld		a, $56
	ld		[$0555], a
	nop

	ld		a, $a0
	ld		[$0aaa], a
	nop

	ld		a, b
	ld		[de], a
.unknown_small_loop:
	ld		a, [de]
	xor		b
	jr		z, .skip
	nop
	jr		.unknown_small_loop
.skip:
	inc		hl
	inc		de
	ld		a, h
	cp		a, $c0
	jr		nz, .loop

	ld		a, $f0
	ld		[rRAMB], a
	ld		a, BATTERYLESS_CODE_BANK
	ld		[rROMB0], a

	ret
write_sram_to_flash_rom_end:





; ----------- Embed savegame ------------
IF EMBED_SAVEGAME
	SECTION "Flash ROM - Embed savegame (first 16kb)", ROMX[$4000], BANK[BANK_FLASH_DATA]
	INCBIN "src/embed_savegame.sav", 0, 8192
	IF SRAM_SIZE_32KB
		INCBIN "src/embed_savegame.sav", 8192, 8192
		SECTION "Flash ROM - Embed savegame (last 16kb)", ROMX[$4000], BANK[BANK_FLASH_DATA + 1]
		INCBIN "src/embed_savegame.sav", 16384, 16384
	ENDC
ENDC
