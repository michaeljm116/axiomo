package main
import "core:fmt"
import "core:math/linalg"
import "core:bufio"
import "core:os"
import "core:strings"
import "core:slice"
import "core:math/rand"
import "core:container/queue"
import "core:mem"
import "base:intrinsics"

display_player :: proc(p : Player)
{
    fmt.println("Player", p.name, "Position: ", p.pos, " Health: ", p.health)
}

display_deck :: proc(deck: ^BeeDeck)
{
    for i in 0..<36
    {
        if i > 0 && i % 6 == 0
        {
            fmt.println()
        }
        fmt.printf("%-12v ", queue.get(&deck.deck,i))
    }
    fmt.println()
}

display_temp_deck :: proc(deck: [dynamic]BeeAction)
{
    fmt.printfln("Temp Deck: ")
    for i in 0..<len(deck)
    {
        if i > 0 && i % 6 == 0
        {
            fmt.println()
        }
        fmt.printf("%-12v ", deck[i])
    }
    fmt.println()
}

display_bee :: proc (b : Bee)
{
    fmt.println("Bee ",b.name, ":  Position: ", b.pos)
}

display_level :: proc(lvl : Level)
{
    display_player(lvl.player)
    for bee in lvl.bees do display_bee(bee)

    // Create a simple character grid representation based on Tile and overlay entities (player + bees)
    chars : [GRID_WIDTH][GRID_HEIGHT]rune

    // Initialize chars from tiles
    for x in 0..<GRID_WIDTH do for y in 0..<GRID_HEIGHT
    {
        switch lvl.grid[x][y] {
        case Tile.Blank:
            chars[x][y] = '.'
        case Tile.Wall:
            chars[x][y] = '#'
        case Tile.Weapon:
            chars[x][y] = '!'
        case Tile.Entity:
            chars[x][y] = '.'
        }
    }

    // Overlay player rune if in bounds
    if in_bounds(lvl.player.pos) {
        chars[lvl.player.pos[0]][lvl.player.pos[1]] = lvl.player.name
    }

    // Overlay bees (supporting the two global bees)
    // If more bees are added as globals, add them here similarly or change this function to accept a slice.
    for bee in lvl.bees
    {
        if in_bounds(bee.pos) {
            chars[bee.pos[0]][bee.pos[1]] = bee.name
        }
    }

    // Print header with coordinates (optional)
    fmt.println("Grid:")
    // Print rows: y from HEIGHT-1 down to 0 so increasing Y appears upward
    for y := GRID_HEIGHT - 1; y >= 0; y -= 1
    {
        for x in 0..<GRID_WIDTH
        {
            // Use %-3v for spacing so rune/emojis align reasonably
            fmt.printf("%-3v", chars[x][y])
        }
        fmt.println()
    }
}
