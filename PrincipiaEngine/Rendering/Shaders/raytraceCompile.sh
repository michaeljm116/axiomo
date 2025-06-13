glslangvalidator -V raytrace-main.comp -o ../../../../Bin/Assets/Shaders/raytracing.comp.spv
glslangvalidator -V raytrace-main.comp -o raytracing.comp.spv
glslangvalidator -V raytrace-main.comp -o ../../../Assets/Shaders/raytracing.comp.spv
glslangvalidator -V raytrace-main.comp -o ../../../../Assets/Shaders/raytracing.comp.spv
if [ $? -ne 0 ]; then
	cmd /k
fi
