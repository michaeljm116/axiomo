# Run
* The Api for the controller refactoring is done (for the most part)
* You revamped grid/battle to now just have a walkable, runnable flag in the grid
* so now to walk you just see if you can walk there or to run you see if you can run there
* seems simple, scalable and overall better
* There's a bunch of benefits to everything you've done overall
	* now if you want to ui the grid you have the tiles in place for that
	* there's a "bug" where you dont have blanks set up by default so instead of
		* .Blank in Tile its
		* Tile == {}
		* Idk if I want to do that or not....
			* Pros:
				* not having to constantly init the blanks
				* Is blank used for literally anything else?
					* blank could be a problem actually cause you can have
					* blank | Player in the same tile
					* having it as 0 means it is officially blank and nothings in
					* i wonder if there's an `is nil` ?
			* Cons:
				* Less expressive?
				* Technically Tile == null doesn't have to be a tile?
		* I think removing blank is best
		* DONE
	* Now blanks are fully blank
	* You can have a generic controller interfact that operates on whole game
	* eventually you can map right_axis to the mouse
		* i wonder if thats already in the cpp 
* Ultimately you'd want a game interface for this controller that lets you do things like map multiple keys to the same action
* aaaand now you're seriously considering that
* okay lets think about how much time you have and the pros and cons of that!

## Additional Game Input Layer
* Discription: As a programmer i'd like to have something that maps controller input to a game input so that way I can have selected actions that are mapped
	* It'd let me to something like... if  Pressed(.ActionButton) do action instead of if Pressed(.ActionU) WOW YOU ALREADY NAMED IT ACTION YOU DINGUS
	* This would also let me map multiple buttons like enter and space to the same action
		* but like when you're in the menu you can pick a diff one
		* infact you can have a GameController, MenuController etc....
		* but due to the type of game you're making they are probably gonna be the same
	* Risks:
		* Potential waste of time
		* less efficient
	* Mitigated:
		* 20 min timer
		* not really that much less efficient
		*