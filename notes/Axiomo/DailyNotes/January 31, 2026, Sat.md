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