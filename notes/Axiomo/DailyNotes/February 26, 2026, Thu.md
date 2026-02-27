LOS WORKS WOO but only for 180deg rn
* so there should be a way for you to do things like make a rand notes section here for when NULS happpen to track how to get rid of themm * 
* done YOU HAVE THE [HELPERS] file
* You finished los and now.... what next?
* So oh wait you need to make sure LOS works over obstacles
* but other than that.... idk
* oh yeah los isn't really done
	* you have to make it like... actually do things...
	* soooo  first there's alertness
	* right now its like if you run then alert else dont
	* instead its like... it should be if bee sees you before you run or after then alert
* so therte's 2 things
* ### Alert
	* If player runs before or after then its alert
	* If bee can't see player.... unalert?
		* after a certain number of turns
* ### Move Towards/away
	* There should be like a "Move Random" 
	* Then move towards, away is only for when you see player
* ## Complexity Analysis:
	* ### Conclusion:
[[Line of sight]]
	* ####  ALERT RUNS
			* instead of alerting all bee's when running only 
			* difficuilty in alerting bee's du to both requiring players only
			* unless from bee perspective you look at  run tag of player
			* should a bee poll for a player run status every frame?
			* well no, but there's yeah a ves thing that should do it right?
			* so alert all bee's should be alert all facing bees just be a flag that has the sees thing
	* #### Bee invisibility
		* is there any way right now for you to not see a thing?
		* Honestly, can't think of much other than deleting the entity
		* depends if the ecs has activity flags
		* ultimately it's just the primitive that needs to be inactive no prim no bvh
		* HA..... hide entity = set scale to 0 lol
		* but it might be better to have visibility tags in the bvh
	* #### Move towards/away can be done in less than an hour imo
		* actually idk... crawl should be easy
		* well so there's path finding
		* hmmm should there be goals?
		* so there's like... a target direction
		* goals might make it  super simple
		* because then its like... move towards goal else move towards player
		* but then... should they only move towards player if alert?
		* so move_towards_goal is like.... the main thing
			* if sees player, goal = player
		* how about... attractions...
			* light
			* flowers
		* okay but if there are attractions, that kills the like... thing about move away
		* so ultimately. there will be a need for randomized movement
		* attractions... might be more difficult
			* they'd be on the grid and if the bee is attracted to them its like... algorithmically how would it work? would it scan for hte nearest attraction?  like how will it "Know" an attraction is there? honestly... just a simple grid scan is not that hard...
			* for each attraction pick the closest one
			* but then its like.... how do you know you've reached it and what to do when you reach it?
				* I guess just go back to random?
				* and then its like is there a timer? do they then go back to the thing
				* do they have goals of like polination?
				* too complex
				* sooo at the start of the game... there can be a stack of attractions generated based on closest and then it goes from one attraction to another
				* also question is how do you decide which one is closer in a maze?
				* for each attraction you'd need to do a shortest path algo
				* can still be done easily tho you already have it
				* okay so actually.... yeah you'll just have a stack of goals.... and if its like a goooood goal then it's top of stack. 
					* and once you see a player... they go to top of stack.
					* if they lose sight of player.... remove from stack
					* so their goal will actually just be like... the last place they see the player
					* so in all this... ultimately there's no need for random
					* just make random goals if stack is empty
					* stack or queue?
					* stack duh
						* lifo means see player push else pop
						* at the bottom of no attractions then do w/e 
						* also pathfinding for attractions don't have to be done tbh no one rly cares
					* sooo at the start of bee turn... .. actually noo its just whenever it moves toward... it just always checks that thing. if its on the thing... then pop oh actually good edge case
					* what happens when youre on a player? yeah that's a vimportant edge case
					* do you pop? you should never pop a player that you see and esp alerted
					* what to do you if you fly x2 to a target and 1 spot away/ samesies?
						* sure
					* pop_if_not_player
					* so then what does... move away mean?
					* ooo good point... maybe target is a better name than goal since its more about what youre focused on than whats like... yeah
					* 
			* bee's are attracted to light and puzzles
			* 
* ## Overall strategies:
	* A bee that's unaware should be easy to kill
	* A bee that's crawling should be easier to kill than a bee flying
	* A bee that's alert will easily kill you
	* A bee that sees you will be hard to kill
	* A bee that is alert is very hard to kill
	* Especially when it's flying
		* wait so... should each bee have their own deck of cards? 
			* or same deck but has priority in choice?
	* Using your hand to kill be is generally not good
	* Some weapons make killing bee a lot easier
	* Some weapons require hit n run 
	* 