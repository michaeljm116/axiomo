so you're still trying to solve the selection issue
you want to be able to select anything in the current battle queue...
wait...
* actually that's a problem because the battle queue is just who's turn is next
* it's not a representation of eveyrone that's alive
* or all creatures
* although there is a separation between teh two
* like for example the queue might be person, bee1, bee2, person, person, bee2, bee1
* in stead what you want is

## Single turn memory arena
*  A new lifetime has been discovered
* memory for things that only exist within a single turn 
* such as.... who are all the alive's 
* who is currently the main actor
* idk if theres anything else, it might not need a new arena if its this small
* but like... at start_turn, init_current_turn_state
* at end_turn, destroy_current_turn_state
* seems like a good thing to have but also.... idk


# Battle vs Battle turn
* For battle turn what you're wanting is things related to a single turn of a battle
* but how is that different from battle itself?
* Battle = global battle state
* Turn = per-turn-battle-state
* but you want them both to interact with each other
* but how do you want this interaction to happen?
* So  forget the memory arena is just a red herring, 
* What you ultimately want is info relative to just the ...
	* current selected entity
	* index of that entity
	* currently alive entitites
	* any other current data
	* current dice roll? 
	* current state ultimately aka battle
* so maybe just scope this to....
	* so ultimately its like...
	* you start the turn and youre a PLAYER
	* you select a thing and then do a thing based off that selection
* okay most simple would be a current selection struct
	* pointer to character (entity?)
	* type
	* index
	* -fin
* wait... is there a thing that's like... eveyrhting tho?
* like right now battle queue is... ya know.. what we discussed earlier
* but we dont have a dynamic list of all characters in scene
* or all living characters, dead characters etc...
* so what do?
* what if there's a character component? and a battle ecs?
* how might an ecs solve our issues?
* would it be its own db? or just use what you already have i mean you do have one in place already and ecs's are known to be useful for gameplay code
* an ecs would legit be so perfect cause then for the VES you can just query the state of all characters
* what are the downsides of an ecs tho?
	* being overly bound to one?
	* interurupting one?
* so right now characters have entities...
* what if you made entities have characters?
* it'd be hard to test 
	* maybe
* there are systems you can put in place, you can make a mini ecs in side if you want
* its jsut an iterator over an array of things
* any time you need to iterate over all of a thing then you can make a system out of it
* but right now you just want to.... BRO JUST FINISH THE THING

### future
* Input state needs to be revamped to be LEFTRIGHT UPD OWN instead of key presses 
* More discussion about the main overall game design
	* The main idea being you must kill something as soon as possible before it kills you
	* do it at a game loop level, but also an overarching level like once you start a game you have a certain time to complete before it becomes harder
	* 



## Implementation
* previously you had select action then select enemy
* now its select character so you have yourself selected
	* movement is just wasd
* enemy is already selected....
	* you should still have the arrow showing
	* you should choose between focus dodge etc...
	* you should check if bee is near
		* if so then you can attack 
* honestly... this seeems so messy i want functions out of them
	* handle_focus(), action, dodge
* [WARNING] for player action when you kill enemies it just destroys from teh curr turn thing
* 