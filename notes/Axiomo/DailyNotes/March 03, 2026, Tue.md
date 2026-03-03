# Persistence.odin
* There needs to be a way for the game to persist from one section to another
* Another thing to consider is the fact that you may not need to complete every level sooo to unlock otehr levels you may need to have like... maybe a stars system like mario?
* how do you sum up a bitset?  actually that algo could be quite qute and clever based on like...  bit shifts
* ``` go
  bit_set_sum :: proc(val : u64)
  {
	  sum := 0
	  for i in 0..<sizeof(u64)
	  {
		 sum += 0 << i & val 
	  }
  }
  ```
* idk somethin like that
* Any thing else tho? like can the character get power ups etc/???
	* how about randomized singular persisting weapons?
	* weapons that can break but exist throughout levels?
	* so you do have this month left to develop features so feel free to do it
* So think about this... what will motivate players to keep playing?
	* is it the fun?
	* the story?
	* what will addict people and want them to keep going on and on
	* this is a necessary part of game dev
	* progression is a must
	* unless the game is inherently deep enough
	* there's no reason to assume it'll get better which can lead players uninspired to finish
	* You can have a series of main weapons but also side-lvl only weapons
	* honestly... right now you're all about coding features this is a major design decision that you'll discover in testing right now you just need to have the ability to go from 1 level to aknother and that's it
	* once you have it in place im sure coding weapon persistance is ieasy
* but for level persistence... its like....
	* okay just do the things
	* so how will the flow go?
* So there's gonna be a save file a menu an app.odin and you can choose things... but also cheats also how will pause work? also is there like a new game continue game multiple saves situation?
* can hitting new make you lose all progress? what if multiple ppl wanna play n stuff?
* SO MANY DESIGN QUESTIONS BUT RIGHT NOW YOU JUST WANT TO GO FROM 1 LVL TO ANOTHER
* but actually you need to first analyze the difficulty of adding all these other things it miight not be too difficult
* so lets say you have a directory of save files you can choose from okay kool
* you alwys start in the overworld? yeah you can't save mid battle
* weapon persistance can exist maybe just 1
	* player stats... may be able to upgrade their dodging and focusing and accuracy
	* or new abilities like counter
	* may be able to persist scores
* So ultimately all you really need for app.odin is like..... a flow that instead of just straight overworld.odin its like... load file -> read file -> overworld.odin based on file and let overowlrd decide?
* load_overworld :: proc(savefile)
	* then overworld loads the level
* well see thats the thing too... like how do u do this testing phase eventually you want the lelevs to have positions right?
* and then there's also going to be like levels, areas, positions etc... like an array of all these
* but that shouldn't be based on a save file let that be hardcoded the save file just tells you which things are locked or unlocked
* 