There seems to be architectural problems between the VES and Battle still... 
* YO WHAT why is anim_state = .Start on select Character?
* move player adds animate to the player which is good
	* but it doesn't trigger anim_state = .Start because its started at select char
* on movement. it checks for ves.anim_state == finished as it should
	* but does not set .removed on player which means...
	* oh wow... so finished is only triggered when .animate is removed
	* actually that's another consideration, the diff between animation and movement
		* usually .Start starts the loop animation then it just continues ad inf
		* so .finish should be finished
		* so ves_animate_player triggers .removed
		* So maybe it should be something like...
			* Battle -> Start
			* Battle -> Update... check ves_animate == true if false remove
		* instead ves_update_anims handles that whole thing
			* well you should be able to keep that
			* theres a .Update flag for the animstate
			* wait.... update animations is kinda bad like what if
				* oh nvm actually yeah it possibly is
		* So ultimately i do like the idea of the ves being a self-contained system that goes from start, update, finish...
		* and the constant communication is like... overly complicated
		* i feel like there's a problem that can have a simple solution
		* the purpose of ves is a block between the battle statemachine and the animation statemachine
		* what if you let ves control update?
		* So ultimately you want like.... 
			* Battle.start -> VES.start,update,finish -> Battle.end
			* battle_request_ves() battle_respond_ves()
			* This way you can decouple the ves and allow for easy testing
			*  idk but w/e it is... you need to decide quickly maybe ask ai


# Event queue:
* Thoughts: the grok example makes more sense
* battle just enqueues
* while the event queue is empty... run gameplay logic
	* once there is something in teh event queue the queue auto handles itself until it finishes
		* instant fear about inf loop but thats no problem its also easy to drop in an empty queue at anytime if necessary
* enqueing involves setting up the event type and data for the event
	* this would mean having a huge struct of event types possibly
	* with variants
	* tbh i like the idea of a callback better i wonder what grok thinks


# THOUGHT
* should mulitple bees move at the same time?
* multiple bee attacks?
* multi QTES?
* *