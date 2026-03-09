* Soooo I think you decided to do away with the font system until later bc honestly... its like... not that biggy
* There is one question about the overworld systme regarding like... rooms n what happens if its well lets check it
* yeah it sbad but for diff reasons prolly stilll mem issues?

[[Texture]]

# Font
* Things it should do:
	* Load texture from stbi
	* create staging buffer
	* map data to staging buffer
	* prepare gpu for staging and sampling
	* copy staging to gpu image
	* set to shaderreadonly
	* tell the gpu what kinda image it is
	* and how to sample it
* What it do do
* 1. Load file
* 2. Get font offset
* 3. Init font based off data and offset
* 4. Create a blank bitmap (no channels mentioned)
* 5. BakeFont bitmap
* 6. Then it creates a texture.... maybe...
	*  wait... so it creates a texture and appends it to bindless textures... but does it ever delete the actual texure? why is it storing it!??!
	* it seems like its creating 2 cpu copies of the same texture...
	* so what happens if you delete 1?
	* 