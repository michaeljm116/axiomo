* Memory should remove the g_ it'll be ax. now*
* maybe remove references to other resources n stuff
* should improve engines external 
	* maybe even call it api instead
* g.worlds everywhere you need to deal with these bad globals
* vec2 vec2i ns tuff

* So there's a few things... there's axiom components which are ecs specific stuff etc..
	* but then there's also like... data storage things and you want to separate them how do u do dat

Decision on if you want components to be their on directory
Pros: 
	comp.transform looks cleaner than Cmp_Transform
	what is the odin code style anyways? arent datatypes lowercase?
	so idiomatic odin will be ax.comp.Transform
	ax.sys.RenderBase
	Cmp_ comp. hmmm
	Sys_ sys.do_thing
		ax.Cmp_Thing ax.cmp.Thing  ax.Thing_Cmp ax.comp.thing 
	Cmp_Thing is just best tbh and can be easily automated with ai
* question is now about globals as it relate sto the engine
	* the engine should be its own self-contained thing so no globals basically?
	* but you can have engine globals right?
	* maybe thats the answer!
	* ...a temporary answer lol
	* why temp?
	* okay sure there can be some engine globals like the renderer sure i guess but what about other globals you're using?
	* you still need a clear definition of resources you store in mem
	* resources.materials, resources.prefabs resources..ui-refabs etc...
	* ax.resources. hmmm
	* possible problem is you have a entity resource...
	* but then should that even be a resource?!??*
	* you can literally handle all this so far
	* materials,models,prefabs, uiprefabs, animations, textureindexes....
		* what about texture indexes... that's renderer specific....

a star pathfinding needs to degridify
