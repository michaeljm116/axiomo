
okay so you have 2 animations and you want to transition from one to another
What should happen?
* You want to stop the animation and start the new animation
* This would involve getting a list of every peice in teh old animation that is NOT being used in the new one and sending that back to the original transform of the character
* and then also transitioning to the start position of the new transition
* so some body parts will transition to the new animation and others will transition back to the original starting position
* the ones that go to teh starting position then become inactive when the've reached their end
* but the other ones then go from the start of that new post to the end pose
* then if its on loop it does the typical loop of swapping the start from the end