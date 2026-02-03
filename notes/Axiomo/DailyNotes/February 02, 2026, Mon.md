# Priority
 * looking at all these features, it seems like line of sight will be a major aspect of everything going forward
 * It affects literally every thing, including the current run option thus it might need to be worked on first?
 * Lets think actually...
	 * You'll either need to update everything to include line of sight
	 * or line of sight its own separate feature thats modular and can intercept anything?
 * If LOS was a simple raycast that runs constantly through the scene... it'd be easy
	 * er
	 * maybe
## Bee: Grounded vs Flying
* #### Simple
	* if bee.grounded, do weapon grounded damage
* #### Medium/Complex?
	* If bee.flying, can fly over obstacles
	* if bee.flying, can see over obstacles
	* If bee.stunned, bee can't fly

### Priority w/ goals
* Line of sight should technically be more important since that's more closer to the emotion you want
* yeah sneaking up to bee is literally the first dynamic
* I mean yeah its higher priority but i reaaally want players to be SCARED of a FLYING bee
	* and its a tested and proven mechanic 
* honestly you also need a weapons mechanic on your kb board
* so as it stands right now.... flying and grounded are just weapon modifications...
* and it can be done easily right now
* Right now the issue is multiple mechnics each with their own dependency
	* Both LOS and Ground/Flying rely on Obstacles (atlest simplified?)
	* Maybe simple obstacle is first. which would just be an aditional flag
	* but issue is... obstacle doesn't seem like its own feature its like just a flag you can add to things
	* atleast for simplified
* So there's actually with grounded vs flying yeah a simple and medium and complex
* Priority then might be...
	* Simple Obstacle
		* Add an obstacle flag
		* maybe have a data driven obstacle visible object
	* Simple Ground/Fly
		* Make sure the flags exist and are set via cards
		* Make sure player weapons respond to them
	* MediumObstacle
		* alll about visibility?
	* Medium Ground/Fly
	* idk lets laptop switch
* 

