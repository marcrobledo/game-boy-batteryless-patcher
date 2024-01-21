; Game Boy battery-less patching for bootleg cartridges
; by Marc Robledo 2024
; based on BennVennElectronic's tutorial (https://www.youtube.com/watch?v=l2bx-udTN84)
; ------------------------------------------------------------------------------------
; see README file

INCLUDE "hardware.inc" ;https://github.com/gbdev/hardware.inc
INCLUDE "settings.asm"



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
ELSE
	SECTION "RAM - original game's bank switch backup", WRAM0[GAME_ENGINE_CURRENT_BANK_OFFSET]
ENDC

_current_game_bank:
	DB



; ----------------- ROM -----------------
; hook game's boot and execute our initial_restore_sram_from_flash subroutine beforehand
SECTION "ROM - Entry point", ROM0[$0100]
nop
;jp		original_boot
jp		initial_restore_sram_from_flash



SECTION "ROM - Original game boot", ROM0[GAME_BOOT_OFFSET]
original_boot:

SECTION "ROM - Bank 0 free space", ROM0[BANK0_FREE_SPACE]
initial_restore_sram_from_flash:
	;this will be run during boot, will copy savegame from Flash ROM to SRAM
	push	af
	ld		a, BANK(load_save_flash_to_sram)
	ld		[$2000], a
	call	load_save_flash_to_sram
	ld		a, 1
	ld		[$2000], a
	pop		af
	jp		original_boot


save_sram_to_flash:
	;this will redirect
	di
	push	af
	push	bc
	push	de
	push	hl
	ld		a, BANK(erase_and_write_ram_banks)
	ld		[$2000], a
	call	erase_and_write_ram_banks
	ld		a, [_current_game_bank]
	ld		[$2000], a
	pop		hl
	pop		de
	pop		bc
	pop		af
	;ei
	;ret
	reti ;optimization? to-do: test if it's not breaking anything

bank_switch_and_copy:
	;this subroutine is called by load_save_flash_to_sram
	;we store it in bank 0 to make bank switching easier while copying from Flash ROM to SRAM
	ld		[$2000], a
.loop:
	ld		a, [hli]
	ld		[de], a
	inc		de
	dec		bc
	ld		a, c
	or		b
	jr		nz, .loop
	ld		a, BANK(load_save_flash_to_sram)
	ld		[$2000], a
	ret




SECTION "ROM - Free space", ROMX[BATTERYLESS_CODE_OFFSET], BANK[BATTERYLESS_CODE_BANK]
load_save_flash_to_sram:
	;copy code from Flash ROM to SRAM, this is executed while the flashcart is erasing or writing
	ld		a, $0a
	ld		[$0000], a ;enable SRAM

	xor		a
	ld		[$4000], a ;set RAM bank 0
	ld		hl, $4000 ;source (Flash ROM)
	ld		de, _SRAM ;target (SRAM)
	ld		bc, $2000 ;size
	ld		a, BANK_FLASH_DATA
	call	bank_switch_and_copy

	IF SRAM_SIZE_32KB
		;to-do: test if this works!

		;8kb-16kb
		ld		a, 1
		ld		[$4000], a ;set RAM bank 1
		;ld		hl, $6000 ;source (Flash ROM) ;no need to set hl, it should be $6000 already
		ld		de, _SRAM ;target (SRAM)
		ld		bc, $2000 ;size
		ld		a, BANK_FLASH_DATA
		call	bank_switch_and_copy

		;16kb-32kb
		ld		a, 2
		ld		[$4000], a ;set RAM bank 2
		ld		hl, $4000 ;source (Flash ROM)
		ld		de, _SRAM ;target (SRAM)
		ld		bc, $2000 ;size
		ld		a, BANK_FLASH_DATA + 1
		call	bank_switch_and_copy
		ld		a, 3
		ld		[$4000], a ;set RAM bank 3
		;ld		hl, $6000 ;source (Flash ROM) ;no need to set hl, it should be $6000 already
		ld		de, _SRAM ;target (SRAM)
		ld		bc, $2000 ;size
		ld		a, BANK_FLASH_DATA + 1
		call	bank_switch_and_copy
	ENDC
	
	ret

copy_save_subroutine_to_ram:
	ld		a, [hli]
	ld		[de], a
	inc		de
	dec		bc
	ld		a, c
	or		b
	jr		nz, copy_save_subroutine_to_ram
	ret


erase_and_write_ram_banks:
	;can be run from RAM or ROM
	ld		hl, erase_one_flash_erase_block
	ld		de, WRAM0_FREE_SPACE
	ld		bc, erase_one_flash_erase_block_end - erase_one_flash_erase_block
	call	copy_save_subroutine_to_ram
	call	WRAM0_FREE_SPACE
	nop
	ld		hl, write_sram_to_flash_rom
	ld		de, WRAM0_FREE_SPACE
	ld		bc, write_sram_to_flash_rom_end - write_sram_to_flash_rom
	call	copy_save_subroutine_to_ram
	call	WRAM0_FREE_SPACE
	nop

	IF SRAM_SIZE_32KB
		;to-do: repeat three times?
	ENDC

	ret

erase_one_flash_erase_block:
	ld		a, BANK_FLASH_DATA
	ld		[$2000], a
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
	ld		[$4000], a
	ld		a, BATTERYLESS_CODE_BANK
	ld		[$2000], a
	ret
erase_one_flash_erase_block_end:




write_sram_to_flash_rom:
	ld		a, BANK_FLASH_DATA
	ld		[$2000], a
	ld		hl, _SRAM
	ld		de, $4000
.loop:
	ld		a, $0a
	ld		[$0000], a

	xor		a
	ld		[$4000], a
	ld		a, [hl]
	ld		b, a

	xor		a
	ld		[$0000], a
	ld		a, $f0
	ld		[$4000], a
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
	ld		[$4000], a
	ld		a, BATTERYLESS_CODE_BANK
	ld		[$2000], a

	ret
write_sram_to_flash_rom_end:





; ----------- Embed savegame ------------
IF EMBED_SAVEGAME
	SECTION "Flash ROM - Embed savegame (first 16kb)", ROMX[$4000], BANK[BANK_FLASH_DATA]
	INCBIN "embed_savegame.sav", 0, 8192
	IF SRAM_SIZE_32KB
		INCBIN "embed_savegame.sav", 8192, 8192
		SECTION "Flash ROM - Embed savegame (last 16kb)", ROMX[$4000], BANK[BANK_FLASH_DATA + 1]
		INCBIN "embed_savegame.sav", 16384, 16384
	ENDC
ENDC