[[VES Diagram]]

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
		* Another thing to consider... should there be a generic VES.BLocked that happens once something is started
			* else large ifthen statements
			* but it also adds another layer of complexity 
			* yoooo what if i added a flag at run battle then only run players turn if not in .ves state


| Time  | Turn Queue (WHO)        | Animation Queue (HOW)        | Communication                                  | State                         |
| ----- | ----------------------- | ---------------------------- | ---------------------------------------------- | ----------------------------- |
| T=0   | Player's turn           | -                            | Battle → VES: start_turn(player)               | ves.global_state = .TurnStart |
| T=0.5 | Player selects "Attack" | -                            | Battle → VES: enqueue_attack_animation(target) | -                             |
| T=1.0 | Waiting...              | Attack animation: START      | VES → Battle: animation_started()              | ves.anim_state = .Start       |
| T=1.5 | Waiting...              | Attack animation: QTE WINDOW | VES shows button prompt                        | -                             |
| T=1.8 | Waiting...              | Attack animation: QTE ACTIVE | Battle detects input, calculates result        | -                             |
| T=2.0 | Waiting...              | Attack animation: UPDATE     | VES shows hit/miss effect                      | ves.anim_state = .Update      |
| T=2.5 | Waiting...              | Attack animation: FINISHED   | VES → Battle: animation_complete(results)      | ves.anim_state = .Finished    |
| T=2.5 | Turn complete           | -                            | Battle processes damage, next turn             | ves.global_state = .None      |
| T=3.0 | Bee1's turn             | -                            | Battle → VES: start_turn(bee1)                 | ves.global_state = .TurnStart |
| T=3.5 | Bee1 auto-attacks       | Dodge animation: START       | Battle → VES: enqueue_dodge_animation()        | -                             |
| T=4.0 | Waiting...              | Dodge animation: QTE WINDOW  | VES shows dodge prompt                         | -                             |
| T=4.3 | Waiting...              | Dodge animation: QTE ACTIVE  | Battle detects dodge input                     | -                             |
| T=4.5 | Waiting...              | Dodge animation: FINISHED    | VES → Battle: dodge_complete(success?)         | ves.anim_state = .Finished    |
| T=5.0 | Turn complete           | -                            | Battle processes dodge result, next turn       | ves.global_state = .None      |

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