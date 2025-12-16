* So physics system will possibly be similar to bvh?
* question will be about the memory structure...
* actually how is bvh mem
	* bvh = created using core mem
	* bvh = updated using frame_mem
	* which btw is unnessary and should just be temp_a
* So it seems to be working but now you need to think about how to structure it within hlevels...
* one option is to search for everything that has... "wall" in the name
* Another option is to just add a colider to the engine flags blah blah
	* let it be possible to switch to 3d just incase you do make the change
	* to jolt
* Plan:
	* 1. Get player movement
	* 2. get floor
	* 3. do a single wall
	* 4. after validation, do the files