glslangvalidator -V raytrace-main.comp -o raytracing.comp.spv
if [ $? -ne 0 ]; then
	cmd /k
fi
