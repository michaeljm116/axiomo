So the main question is should everything be wrapped under axiomo ?   
      * you should figure out hotreloading also  
      * because then you can wrap all memory under that and make updates easily on the fly  
        * ...maybe im curious how that actually works...  
        * like if you start game... and you have initial variables... like... what?  
        * is hot reloading the same as basically having a play and pause button or what?  
        * but yeah regardless, one thing to keep in mind about wrapping everything under axiomo is then you'd need to alloc all memory up front  
          * i think and use a consistent allocator for that  
          * also does this all work with vulkan?  
      * so if so then axiomo would be an api that you call in to for everything  
        * if thats the case... you'll need to think of the api design from like a high-level  
        * like... welll first... think about not wrapping axiomo...  
          * everything will just be under gameplay.odin  
          * i guess it just depends on folder structure  
          * but i think another thing to consider is git...  
          * like you can make the game have a git reference to axiomo that gets updated asneeded  
          * so its like no matter what you're always thinking axiomo  
          * if you leave t  
          * question is what is the fastest approach  
          * would doing all this lead to faster developoment for halloween?  
          * no... you have till saturday oct 18th, just merge for now  
    * okay so lets then plan what to do...   
      * alot of art like first make a scene that's a grid thats 7x5ish divisible there should be a repeatable texture for the floor but the walls would have like a singular or maybe just a wall  
      * Set the camera if necessary just make 3 walls  
      * Set the light maybe write a script to make it move or stay in a particular locale  
      * 3d Generate player assets and Bee assets if possible get them divided by parts  
      * use your chest asset to get a weap  
      * you need easy grid placing functions  
      * Once you have all the assets and you have those functions..  
      * you need function for moving from 1 grid piece to another  
      *
* Okay so plan:
	* THe plan might be to just go ahead and design the level 
	* set the camera
	* pretty much do everything you said above
	* you need to set up a scale system
	* that takes the floor size and divides it by the games grid size
	* hmm... decide on physics or nah...
	* so you'lre gonna need some just like... straight up grid forcing options
		* Set Player on Tile (x,y)
		* SetGrid 
* Okay so I think its time to get hte UI System working
	* if there's a library for like vulkan texts being shown on like things that'd be great


Okay now lets talk UI
* each ui elemennt will have its own entity with its own cmp gui you'll also have a texture that and tbh its a megatexture that has many different gui components like start game end game etc that you can then click on and etc etc
* instead of it being the singleton entity it'll be its own thing