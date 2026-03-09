# Texture
* ## CPU Side
	* Use STBI to load the texture file into a buffer of pixels
		* The width, height and channels (RGBA) will be auto set when doing this
		* also this is only for like... texture files... you can also generate your own
			* aka datatextures
	* It's dynamic so must be defer freed
	* So now that its in RAM it needs to go to the video device
* ## CPU Still but GPU Prep
	* #### Stage
		* creates a staging buffer to get sent to the GPU
			* remember staging buffers are temp in betweens for when you just want to store in the gpu and get rid of the cpu side of it
		* uses vma to allocate etc...
			* so also destroy since its staging via defer dest
			* since it's a staging buffer it's only `usage` is to transfer
		* copy memory from pixels to staging buffer (CPU still)
		* Set up GPU info this is like the main set up
		* This is the actual image
		* `usage`is both transfer and sampled 
			* gussing transfer is due to staging etc...
			* sampled cause its the actuall thing its a siampler
		* Then you create that image on the GPU
	* #### GPU MAP VIEW OF IMAGE
		* okay so now that you have a Physical? image now you need a view of that image
		* im guessing a similar idea of a database view?
			* 1. The image starts off in an undefined state and goes to a transfer state
			* 2. The staging buffer gets copied to the image? (confused because i thougth thats what the mapping does? or just the map just draw out a map but its like blank data until this occurs?)
			* 3. now that the actual staging buffer has occured and the transfer happened, now you want to make this image a read_only shader aka its in teh gpu its read only it stays there can't be written to here
			* 4. then finally you create a view of that image
		* I'm guesisng this is the actual GPU side of it where you're sending command to the gpu
	* #### SAMPLER
		* I'm not sure what the sampler is here for lets think about it...
		* you have a texture thats fully in the gpu and you have a view of that texture too...
			* im assuming a view is just like... a more filtered version of the exact thing you wanna look for?
		* so then the sampler is.... idk just more configurations about how you want to sample that texture?
* ## Back to CPU side
	* save all that info in the texture, its read-only so you're basically just sitting idle with that texture until you tell the gpu to destroy it
* # Note:
	* Image = raw data on the GPU
	* Image View = tells the GPU yo this is like RGB with 4 channels etc..
	* Sampler = Tells the gpu hwo to sample the data
	* It goes.. use stbi to get pixels, map pixels to staging buffer, copy staging buffer to gpu
