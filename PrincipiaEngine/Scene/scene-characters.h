#include "game-scene-system.h"
#include <optional>

artemis::Entity* spawnFroku(MainCharacterData* MainCharacterData);
artemis::Entity* spawnEnemy(glm::vec3 pos, glm::vec3 rot, std::string name, std::string prefab);
artemis::Entity* spawnEnemyAnim(glm::vec3 pos, glm::vec3 rot, std::string name, std::string prefab);
artemis::Entity* spawnSnake();
std::vector<artemis::Entity*> FindEnemies();
std::vector<artemis::Entity*> SpawnEnemies();