# UI Prefabs
* If you can get your engine to select a texture, and edit and create a ui prefab to save that'd be great
* then load a list of ui prefabs
* which you can make into a map
* and reference except hmmm do you load prefabs already?
* im guessing there'a  reference prefab and then an actual prefab
* right now there's  g_prefabs which is a map of scene nodes
* lets check create texture
# Deck
* So quesiton is how do i handle the "deck" which tbh shouldn't real ly even bee a deck AHAH GET IT BEE A DECK? but real talk it shouldn't even be a deck but an editable group of statistics but for nwo its a deck of cards
* So if its going to be a deck of cards then just think like a human
	1. There's a deck of x # of cards
	2. You shuffle them
	3. in some games you distrubute piece by piece but in thsi case tis 1 by 1
	4. Each turn you draw a card
	5. when card is used, it's putin a discard bpile
* Now think of it in code
	1. You have an array of cards
	2. You shuffle that array
	3. Its turned into a queue
	4. Each turn you pop the queue
	5. Then Push to a stack
* No need to optimize as it happens infrequently

* So now we have a loop going and we have it so that the player can go places,
	* incorrect bounds = a single turn tho soooo idk if i wanna include that or not
* now we need the player to be able to pick up a weapon
* then player should be able to go to a bee
* display bee position
* *

### Bee Actions/AI
* Fly Towards
	* Set bee to .Flying
	* if bee is 2+ away from player, go 2 towards player
	* Else: set to alert
		* if bee is 1+ away from player, go 1 towards player
		* if bee is next to player, do nothing
* Fly Away
	* Set bee to .Flying
	* Find a path thats 2 away from player and go there
* Crawl Towards
	* Set .Flying flag to false
	* if bee is 1+ away from player go 1 towards player
	* else if bee is already next to player, set to alert
* Crawl Away
	* Set .Flying flag to false
	* Find a path thats 1 away from player and go there
* Sting
	* If bee is alert, attack player
		* if bee is next to player, attack

# Where you're at now:
* you have:
	* a grid
	* player and bee
	* bee actions
	* Player to pick up weapon
	* player death = game over
	* killing of bees
	* Deck refresh()
* Still need
* will use with engine
	* weapon engine
	* Other player actions
		* Dodge
		* Focus

## Weapons flow
* Tiles have .Weapon tile
* If player goes to .Weapon tile, go to the .Weapon DB
* Rand weapon based on that
* Player.Current weapon = weapon from db
* On Player attack, check curr weap compare with db based on db stats do things, maybe even have a function pointer in the db?
* okay so there's a weapon db for default weapons but also a player can have their own weapon
	* they copy it by the db
		* So the tile can have the type
		* so there is both a tile type and na
* so then what will there be like... a level with ...
	* yeah there should be a level struct 
	* level struct will have all the bee's and the. ..
	* basically everything?
	* scene?
	* then have a scenedb
	* on load scene you should...
		* also keep in mind that scenes are .json from your scene.json files
			* eventually
		* so there shoould be a
		* wait so then shouold there be both a json scene and a game scene?
		* for now do the game scene
	* game scene:
	  ``` Odin
	  Scene :: struct
	  {
		  bees : [dynamic]Bee 
		  players : [dynamic]Player
		  weapons : [dyanmic]Weapon
		  grid : [][]Tile
	  }
	  ```
		* So the ultimate question you're STILL ASKING IS.... WHAT IS THE WEAPONS FLOW?
		* Tile Weapons -> Rand weapon from -> weapondb from -> scene.weapons? 
			* if so then no pos on weapon
			*  but then the question is where do they go tile wise? shouldn't the weapon db tell you?
			* the tile! seeing as how you'll have walls in teh scenes... the tile should be in the scene itself
			* foro now just create a temp scene and yeah eventually it'll be dynamic but yeha the grid alone has the scene stuff
			* 
* ### Weapon Procs?
	* So each weapon will have their own special features
	* should a weapon carry its.... no, data oriented
	* each weapon should have its own proc but... it should be more like each proc will be ref a weapon
	* and stats etc.. idk but for now just do weap procs
	* okay sooo lets just do it individually
	* 
* ### Weapons
	* Hands : Acc: 10/12, Dmg, Half-Air, Full Ground, Range = on top
	* Swatter: Acc: 8/12, Dmg, Full-air, full Ground, Range = 1
	* Shoe: Acc 7/12, Dmg, half-air, full ground, Range = on top
	* NewsPaper: same
	* Electric Swatter: Acc 7/12 Full Air Full Ground, Range = 1
	* Spray Can: Acc 7/12, Full air & ground, but 2 turns to die, range + 2
* Overall Stats =
* Oops first do a struct of:
	* AttkStruct:
		* Accuracy : float
		* Power : int
	* Flying : AttackStruct
	* Ground : AttackStruct
	* Range : int8
	* Status Effects : enum16
		* TimeToDie
		* Stunned
		* Angered?
* Overall Proc = 
	* Params : Player, Bee, Weapon?
	* Check Range (Player, Bee)
	* CheckFlyingOrGround(Bee)
	* ChooseAttackBasedOnAbove
	* ApplyEffectToBee(Bee)

### Abilities
* What is the architecture behind abilities?
	* If player or bee attack | Then check for specific ability
	* Have an abilities observer that checks for player attack events
		* every kind of entity attack thing registers itself to an ability manager
		* or... ok the architecture of this is super complicated, maybe do l8r
	* Oh yeah... ECS.... u have that lol
		* On player select ability select the bee and then pass the bee a dodge component
		* on bee attack if dodge component then do dodgey 
		* ugh so simple so easy so beautiful
		* i think its time to merge with engine
	* okay so now you have ecs access....
		* problem is... you dont have a way for the player to select bee yet
		* So there should be some kind of menu
		* [[PlayersTUrn.excalidraw]]

## Game SLowdown
* So there's 2 ways to slow it down
	* by making the movements linearly interpolate
	* In general have slowy things so that state transitions are based on timers as well
* there might be a tempation to make state transitions be by area triggers
* pero hin
* okay so what if each thing ha
* so there is a bee actiona nd a player action state
	* each can have a .Animation state too
	* also give each a flag of the thing to animate
	* like movement 
	* so like if a player is just like walk then yeah palyer animation flags and player targets
	* targets = vec2
	* [[AnimationStates.excalidraw]]

### Art
* So question is how to make development not be slow for art assets
* right now you hardcode every texture into the thing
* materials draw from the index of where that hardcoded value is
	* ultimately, the material should just find the texture name and if there's a keyvalue pair then match it up accordingly 
	* its done once at startup so speed isn't that much of a concern
	* oh another issue is there's texture name and theirs filename i guess it doesnt' matter ulitmately
	* okay so question is how to do this in both c++ and odin
		* odin, have a map of... hmmm
			* or enum array?
			* no must be map for dynamism
			* so that way the texture can be ummm
	* So what you basically want is an ordered key-value pair
		* key = texturename
		* value =
		* ...
		* nvm just keys and where they sit in the thing
		* also keep the dyanmicness in mind
		* dyanmic arrays assume expansion
		* but since you dont expand texture nums then...
		* at start up look at the # of textures in a directory
		* reserve
		* and plop
		* set a vector
		* but it can't be a vector it has to be a std set
		* ordered set?
		* you dont care about the order just a ref to it in the gpu
		* so first do std set then shift to std vector for each in the set
		* well first... can you access sets sequentually?
		* 