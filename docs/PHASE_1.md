# Phase 1

This slice implements the first playable layer of `Diorama Descent`.

## What Is In

- A fresh `scenes/main.tscn` entry point.
- A landscape 3D board built from simple grid tiles.
- Diorama background art placed in the scene.
- A left-side joystick built from the Diorama control art.
- Player grid movement at one tile per second while the stick is held.
- Direction filtering that rejects ambiguous diagonals.
- A goblin enemy that previews its next move with a highlight tile.
- Basic sprite facing swaps for player and goblin card sprites.

## What Is Not Yet In

- Close-combat slash attacks.
- Clash damage resolution.
- Full procedural dungeon generation.
- Multiple enemies or combat AI groups.
