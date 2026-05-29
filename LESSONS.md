# Godot 4 Multiplayer — Lesson Track

Each lesson is a runnable scene. Open lesson scene in Godot, run two instances (Debug → Run Second Instance), follow along.

## Lessons

| # | Folder | Concept |
|---|--------|---------|
| 01 | `lesson_01_hello_network` | ENetMultiplayerPeer, create_server/create_client, peer signals |
| 02 | `lesson_02_rpcs` | @rpc decorator, modes (any_peer/authority), reliable/unreliable, sender ID |
| 03 | `lesson_03_synchronizer` | MultiplayerSynchronizer, auto-syncing node properties |
| 04 | `lesson_04_spawner` | MultiplayerSpawner, spawning nodes across all peers |
| 05 | `lesson_05_player_movement` | Input authority, movement with sync, local vs remote players |
| 06 | `lesson_06_lobby` | Lobby system, player registry, ready-up, game start |
| 07 | `lesson_07_server_authority` | Server-side validation, why clients can't be trusted |
| 08 | `lesson_08_scene_switch` | Changing scenes across all peers simultaneously |
| 09 | `lesson_09_interpolation` | Lag, jitter, MultiplayerSynchronizer interpolation settings |
| 10 | `lesson_10_mini_game` | All concepts in one tiny functional multiplayer game |

## How to Run Two Instances

1. Open Godot editor
2. Run the lesson scene once normally (F5 or play button)
3. Go to **Debug → Run Second Instance** (or run `godot --scene res://... &` in terminal)
4. One instance clicks "Host", other clicks "Join"

## Key Godot 4 Multiplayer Classes

- `ENetMultiplayerPeer` — low-level UDP networking (most common transport)
- `multiplayer` — the `MultiplayerAPI` singleton on SceneTree, your main interface
- `multiplayer.multiplayer_peer` — assign your ENet peer here to activate networking
- `multiplayer.get_unique_id()` — returns your peer ID (1 = server, clients get random IDs)
- `@rpc(...)` — decorator that makes a function callable across the network
- `MultiplayerSynchronizer` — node that auto-replicates property values
- `MultiplayerSpawner` — node that auto-spawns/despawns scenes across peers
