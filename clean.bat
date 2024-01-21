@echo off

SET TARGET_FILENAME=output.gbc

del roms\%TARGET_FILENAME%
del roms\*.sym
del src\*.obj