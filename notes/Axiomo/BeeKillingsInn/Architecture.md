So you need something that like... starts...  with like....
* Title menu etc...
* Game Overworld....
* If in game then do this
* so there'd be different kind of scenes
* Room Scenes
* Overworld scenes
* Maybe make a world of like a few ... lol doors and be able to go inside blah blah

# Ultimately:
* right now all the game is in the single bks.odin file
* But this couples the begin,middle,end of the game aka the menu system with the battle system
* It's all a single game
* what you want is a system that's decoupled from all this mess
* also should there be a separation between axiomo and something else?
* that's a goal but ultimately... not neccesary
* but making everything like... axiom.entity... axiom.gui etc... makes things clear where any coupling could occur
* blhe regardless... there should be 3 secitons now
* ## 3 SECTIONS: 
* #### MAIN
	* Menus
* #### OVERWORLD
	* Freeflowing wasd movement
	* level selection
	* talking to npcs etc
	* goals, journals, maps
* #### BATTLE
	* loading the level
	* playing the battle 
	* BKS basically
* Main Should work every where
* Overworld should call battle
* Battle should update status and affect overworld in someway too
* Both battle and overworld load a scene with an ecs

Major question to answer:
* Perfect the battle system before doing the overworld?!?
* I think there should be a scaffolding of basic overworlding features since:
	* You already discovered the lack of scalabliity via ecs
	* You want from  the start to design a begin, middle, end of a battle
* But if you do the other way... 
	* it keeps you gameplay focused
	* you..... idk
	* i think the scaffold is the 