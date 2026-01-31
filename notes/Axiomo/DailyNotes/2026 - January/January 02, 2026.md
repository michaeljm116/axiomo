* There needs to be a persistent UI across the whole game
* and u still aint got a pause menu
* you also need to architect it to make ending the battle more seamless
	* and many of the tests are useless
* The rules need to  be so that you end when need

# Escape Battle:
* So there's basically this loop that happens of players turn -> bee's turn and then checking for win loses
* question is... how do we make it so that hm....
	* right now there's run battle that has start, loops, end...   
	* start i guess just makes it so you loop and oh wait there's also a pause
	* Actually hm.... you should diagram out the most important functions
* Run battle should check for win-lose conditions each frame
	* If you check the battle state every frame it'll decide based on that state what's what
	* So basically there should be a check status and condition befor each run blah blah
	* and if so it goes to end state
## VIP (Very Important Procs)

* app_run
	* ...wait should it be battle_run? or run_app?
	* Regardless... this is like... what the main loop actually calls
	* so it decides on the main menus as well as calls the overworld or battle
* ves_update_all
	* This actually isn't that important
	* but the ves itself is super important and should be more multi layered
	* also maybe it should be battle_ves_run and theres an overworld_ves?
* run_battle
	* this is super important since its like... the main battle loop
	* run_players_turn
		* This controls the battle menu of the player so its possibly like.... the most important thing.... this IS the gameplay
		* also it should be a quick and easy ux. try to keep it to like 2/3 buttons at most
		* should it be battle_players_turn?
	* run_bee_turn
		* This is basically enemy ai
		* it requires its own thing to understand

