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