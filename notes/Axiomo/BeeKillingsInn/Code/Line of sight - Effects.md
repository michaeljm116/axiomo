#### Movetowards/away will be based on a stack of targets,
*  stack will be based on player, attraction, random
* if stack empty push a random
* if see player, push player to stack top
* if can't see player && far from player, pop from stack top
* if target is reached pop
	* unless target is player

* #### Player can't see bee
	* If player cant see bee, do hide_entity, else sca = 1

* #### Bee alert on player run
	* alert_all_bees() -> for all bees if .CanSeePlayer in flag

## Additional thoughts
* Possible bug of beetarget not being a pointer to player position but a copy
	* Possible feature too
	* because then it only updates if looking at
* LOS soooo transforms this
* 


