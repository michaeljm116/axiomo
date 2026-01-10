@echo off
glslangvalidator -V raytrace-main.comp -o raytracing.comp.spv
if %errorlevel% neq 0 (
	echo Shader compliation Failed!
	pause
)