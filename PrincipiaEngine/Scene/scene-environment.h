#include "game-scene-system.h"


void spawnDoor(glm::vec3 pos, artemis::Entity* button, bool* globalOpen);

artemis::Entity* spawnHole(glm::vec3 pos, glm::vec3 extents);


std::pair<artemis::Entity*, artemis::Entity*> findLightCam();
artemis::Entity* findFloor();
void LightControl();