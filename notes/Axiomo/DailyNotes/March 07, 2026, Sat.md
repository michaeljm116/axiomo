* So one thing to keep in mind is you do plan on hardcoding all levels 
* In fact, maybe you should just do it now iwth the inn so you can have an example


## Implementation of Serialize:
* So now that you can save and load....
* load also happens at game start...
* whenever you enter into 
	* well first, by default room 0 should always be open
* a battle you should say visited
* when you win a battle its completed
* losing a battle takes you back to overworld
* you also should set up area things
	* back to overworld is back to area exit
* you should also save the last place you visited
* Lets organize
* ### Battle
	* On Win: 
		* Set flag to .Completed
		* Set .Overworld
* ### App
	* On Won Overowrld :
		* Save maybe num killed bees
		* Go back to overworld
		* area.entrance + direction + epsilon
		* record last visited
		* unlock next level?
	* On Lose overworld
		* Go back to overwrold
		* basically similar except no unlocks
* Overall arch...
	* wow so there's like... multiple places where the battle can be lost this is horribad
	* maybe just do check win/lose condition in the app.odin and do eveyrthing in app.


## Pause
* okay now you have a way to finish a room and set the next one except you need to iterate on curr now except now you realize you can't really do that because curr is like... not curr
* so you need to now take over the overworld so that it starts detecting areas and also make sure its fin*
* you already have a detect area changes but its not used once its used then bam you done right now its just overworld update hardcode to 20
* 