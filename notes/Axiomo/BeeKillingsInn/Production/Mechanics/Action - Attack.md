* Description : When player attacks bee...
	* if not facing bee, face bee
		* if bee not facing player, make bee face player?
		* Actually a discussion will be needed on how facing relates to alert
	* Camera switches to first-person mode
	* A Timer of some sort then starts
	* If player Presses button within timer zone, attack = success
		* else Miss 
	* Timer zone is based on weapon
* To do this, something will need to appear in the UI 
	* and that thing will need to dynamically update
* Camera work is lower priority for now

## UI 
* First design a meter in the UI which will have
	* Picture of weapon
	* Picture of Bee
	* Meter the Bee slides down
	* This is one spot where hot-reloading would be helpful
	* but yeah in the middle of the meter is a box that depending on the weapon will adjust the width
	* there might also be a bee-speed
	* line would be simplest
	* Zigzag would be dope
	* or maybe like the entire screen idk
* A single quick QTE with out much time to adjust
	* but the start up time can be a bit random as well
* ### QTE
	* LINE
	* BOX
	* BEE
	* HAND
* Soooo You have a Bee, a bar and now you need to get the bee's X to be along side the bar
	* and also the size, everything needs perfectionish but for now its okay
	* simple box to point collision if box.x lower is < than point but > then box.x + len then do stuff
	* but also keep box position in mind
	* Sooo there's actually several ways you can do this... it could be like.... 
		1. bar moves bee dont
		2. bee moves bar dont
		3. both move
	* I like the idea of bee moving and focus controls the speed of the move
	* another control could be the type of bee
		* a dodgy bee vs a slow lazy bee
	* so in general... bee's moving does sound like a necessity
	* question is bar also moving or static 
		* idk but lets get that bar up and that bee moving
		* Ne