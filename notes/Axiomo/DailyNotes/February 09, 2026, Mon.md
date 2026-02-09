# Attack
* So right now youre switching the attack system to be more action based.
* This will involve an attack bar slider that slides based on a multitude of factors
	* Mostly the weapon and the bee
	* You should diagram the actual  system and how it interacts with ves
	* VES rules iirc:
		* Added and removed are cleared at the end of a frame
		* VES otherwise should never change the added or removed, only react to it
		* So the battle code alone should add things
			* but what about remove things?
			* so it goes
				* battle.added -> VES Respond -> endframe.updated -> VES Respond -> ves.finished -> battle.removed -> VES Respond -> endframe kill
	* [[VES Diagram]]
* Based off this
	* Battle:
		* Detect attack button press (if not in ves)
		* On pressed:  
			* player.added = {.Attack}
			* + all the attack info
		* On update:
			* wait for VES
		* On finished:
			* Check final result
			* call .removed
	* VES :
		* Added: start up the attack bar
		* Update: control all attack bar logic
		* Removed: turn off attack bar
* Honestly... this seems wonky... 
	* why can't VES just call .removed
		* because you want to alert the battle that the animation is finished?
	* why do you control the update in ves and not battle?
		* because ves is controlling visuals in the event?
		* should ves also detect button presses though?
			* thats the gooood question
			* wait... why does battle control  button presses and not the ves anyways???!