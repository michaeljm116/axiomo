### Character starts on wall
* this gets in to a deeper discussion of overall level design
* and overall level design also implies a overall graphics design
* do you want to keep all shapes simple for the entirety of your engine?
	* for now yes, maybe hire an artist if game proves fun
* So in that case...
	* whats the overall camera view? do you want it to move with the player?
	* collisino with wall?
* how does any of this solve the problem?!?
* if it collides with wall... its the  fact that the floor and the walls do not allign properly...
* either that or... the calculation of the center of the square is off...
# beginning bee bug
* so its probably a movement card they're picking
* they're going to 0,0 ... meaning its probably some uninitialized value
* seems to only happen with attack...
* bee is moving in an attack? why?