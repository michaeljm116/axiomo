* Add an obstacle flag to tile
* Possibly rename obstacle
* Update player walk, runable to account for obstacality
* at this time... it think flag adding is about all you can do for now. 
	* or doing the ves but yeah.... 

## Player Attack
* Flying/crawling mostly affects player attack right now which you plan on revamping anyways
* getting rid of dice most likely and sticking with some kind of action system
* Accuracy should be based on legit percentages or dials on a pad

## VES
* Soo I have a feeling there's not gonna be much to do with any of this unless you start adding visual elements
* Specifically just with ves system and making sure that like... flying makes bee fly etc...
* so like there should be a set flying set crawling f unction for each thing and make sure dey work
* For obstacles. there should be data driven obstacle objects  so when they're decorated they just plop right in also good for testing when not decorated
* same for things like x became visible
* #### VES - Fly/Crawl
	* So right now there' s just ves animate bee and player not much else
	* they both seem dedicated only on moving the character to a block
	* the code is so similar it can possibly be reduced
	* its not robust though so idk the best wya to add flycrawl
	* do i update prevuious functions or add a new f unction
	* What other kind of ves's are you expecting?
	* ves are not animations sooooo
	* What would be your dream api for this?
	* ves_animate_bee(bee, flags){
		* if fly then blah if not then blah}
	* nah thats ugly
	* question also is... oh i just realized, there's only 2 states flying or crawling no in between
	* it can ONLY either be flying or crawling it should almost be asserted as such
	* the quick n dirty method would be... just a simple if flying check
	* you can only add .Fflying and it's
	* actually... this is a bool not a flag
	* oh... thats probably why there's no .crawling flag before
	* I think ultimately you'll need a more robust ves system 
	* think of a beautiful api....
	* ves_animate_bee(bee, animation_proc)
	* question of interpolated y or baked in

## VES ECS?
* Right now, if not for the fact that froku uses actual animations... ves_animate bee or player are identical
* So you can possibly get away with.... just having the character component
* So another question
* ves_update_animations can basically be like... on .Start call "added"
	* end call "ended"
* ves_process_animations_ecs = Cmp_VESAnim, + Cmp_grid or something idk
	* depending on the character flags you do things
	* but yeah look at like animate player...  start = walk, end = player
	* honestly... if there's ONLY going to be player and bees...
		* ECS could be overkill

## Grid revamp
* On level start up there should be a grid creation which takes the floor and the size of the grid and creates squares based off it
* g.floor should never be called anymore except on the creation
* no more recalculating the diffreent things every time just cache the grid and do the things
* Then simplify the things on battle