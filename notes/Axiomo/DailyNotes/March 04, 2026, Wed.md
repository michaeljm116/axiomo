* More on persist....
* It should obvs be global?
* So just think again... outside of completion of levels... what exactly do you want to save?
	* num bee's killed?
	* kind of bee's killed
	* sure but not rly
	* weapons found
	* idk...
* So question then is about the levels
* you want to save well overworld already has like... everything?
* Oh yeah  so ther'es a single Inn which has levels aka floors which have rooms and they're all maps except levels are number maps and rooms are named string rooms and rooms have their own battle?!?
* bro that changes things like a LOT
* Okay if thats the case then.. on start you have an inn
* which is  
* well first... you need to think about whether this is a good idea or not lets just consider it
* at the start of the game... 
* so like ultimately, instead of having a single global battle now you have like every single battle of the game loaded in memory at once
* it still wont be that much memory tbh but....
* So you'd hardcode a hashmap of wait shouldn't batgtle also have the name of the file?
* so lets think bout dis right quick
* do you really wanna load all this data at the start?
* you can always just keep a file with all the data ant load them as is
* So i like everything up until like... the battle itself
* why does the battle need to be there?
* is battle? i guess for like once you finish the battle you can explore the room
* So right now youre overwhelmed with a bunch of different decisions it seems like there's so much to do so break it down piece by piece
* First, Inn will be in
* curr_battle := Inn.levels(0)("first_encounter").Battle
* run_battle(&curr_battle)
* oh looks like g.battle is just a Battle not a ^Battle 
* so yeah it'll just be g.Inn.levels(0)("first_encounter").Battle
* lex has all the level names
* i think the scene name and battle name should be the same
* and the level number etc... should be the same
* ### App flow:
	* ##### App_start -> Called once, init err thang
		* Load File
		* Set Curr Level_num
		* Set is_battles based on room flags
	* ##### App_Run -> 
		* OverworldStart(Level_num)
		* .OverworldRun -> .Battle
			* .BattleWon/Lost -> OverWorldStart(level_num)
			* ^ -> Win = Set Room Flag, isBattle = false
	* ##### Overworld_Run ->
		* if area_trigged, if  is_battle
			* Start battle
			* else just load scene no battle
	* #### Load File
		* takes a file and put it in global mem
		* main file will just be a single number that can be decompressed into a bitstring
		* put in assets config
		* So in order to load file you must first save file
		* how do parse?
		* Will there be separate like... #'s for easy access?
		* can i make a quick odin program that creates a save file?
