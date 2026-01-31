# Overworld
* So thinking about the overworld vs the Battle structure
	* The battle already has a struct that has like errthang you need
		* player, all enemies, weapons, grid etc... just everything in a struct
	* So the overworld should also have all that stuff
	* there should also be a `Shared` struct that passes data between the two
	* As well as a save file type thing that keeps the players data etc for upgrades etc
	* but that might be fore later but you can plan for it
* So the overworld will have it's own player
	* the and yeah same entity even
	* Maybe rooms, similar to what you did previously, you might use that same structure actually
	* So yeah previously you had this structure of like... each room has its own thing 
		* was it wasd?
		* I remember you named things like dungeon 1r etc...
		* Data think about the data you need
* So Overworld struct will have:
	* Player
		* Entity
		* Transform
		* PhysicsCmp
		* CharacterController
	* Rooms
		* Triggers
			* Pos, Scale
		* Names
		* CanEnter
		* IsBattle
* Actually thats another thing to consider is... should all rooms be a battle or no and what if its not?
	* Well there may be locks and keys soo
		* CanEnter is good not just for battles
		* Also yeah whats the diff between a battle and a room
		* Do we need a room or just a battle
		* This is sounding like Scope creep
		* Ultimately, you just want CanEnter to see if you can enter it
		* and assume that all rooms are battles for now
		* Maybe for now just think of this like mario
		* Yeah better focus on tight game  play and dope uiux 
* So yeah just Make a quick veritcal slice of 10 levels and have that be DEMO-able by.... ac ertain date
	* Demo will be 4 Rooms main floor 
		* Escalator 6 rooms 2nd floor
		* aka 2 overworlds so plan fo dat
		* well if thats the case then you can't call it an overworld
		* more like... a... Level?
		* so a level can have multiple rooms
		* then who controls the levels I mean if thats the case then an overworld struct would be super simple
		* Overworld = array of levels
		* Levels = what overworld is now
		* but then you'd also need the same like trigger or something like how do you know when you go to a new level?
		* So yeah you'd need a player... array of levels... each with their own name... etc....
* also consider data persisting after you leave a battle if you can leave a battle


# Hotel
* ## Level
	* ### Room
		* #### Battle
		* EverythingElse
		* HasWon
	* Pos
	* Player
	* Triggers
	* CanEnter
	* IsBattle
* Player
* Triggers
* CanEnter
* Pos

# Level/Room
*  Start
	* Move player to default position
	* If Battle, start battle
	* Battle should be same as room
	* But that also means... No going back to overworld?
	* So yeah thats a good question....
	* DestroyLevel1 would need to change to like... not destroy
	* And also when you're in the thing you need to immediately change your char to be the position you're currently at and start things like physics etc...
	* So overworld would be swapped
	* this would make things easier
	* The thing is... overworld gameplay will be exactly the same between hotel level and room
[[HotelOverworld.excalidraw]]

* So if this is the case....
	* Should we keep overworld? 
	* Might as well. or maybe call it like... sandbox or freeroam *
Okay so more thoughts:
1. renamed from level to Floor
2. just using g.player for players
3. tirggers = areaentrys
	1. which gets at the main point here which is...
	2. area entrys should have exits
	3. higher layers should do a continuous loop to see if player = in area.exit
		1. if so go to that area
		2. on area start place player in area.exit
		3. which also begs the quesiton of direction 
			1. yeah just do direction 
			2. then do area.exit. +- depending on direction
		4. 