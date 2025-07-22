#include "game-scene-system.h"


void spawnHeart(glm::vec3 pos);
void spawnSpring(glm::vec3 pos, artemis::Entity* f);
artemis::Entity* spawnChest(glm::vec3 pos, bool* global);
artemis::Entity* spawnDropChest(glm::vec3 pos, Cmp_Interactable* button, bool* global, bool* global2);
artemis::Entity* spawnButton(glm::vec3 pos);
artemis::Entity* spawnBatteryHolder(glm::vec3 pos, bool withBattery);
artemis::Entity* spawnRockFallButton(glm::vec3 pos, glm::vec3 areaCenter, glm::vec3 areaExtents);
artemis::Entity* spawnShinyBlock(glm::vec3 pos);
artemis::Entity* spawnPowerUp(glm::vec3 pos);
artemis::Entity* spawnSword(glm::vec3 pos);
artemis::Entity* spawnSwitch(glm::vec3 pos);