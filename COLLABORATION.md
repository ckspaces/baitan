# Collaboration Guide

## Project Scope

This repository contains a Lua-based street-stall business game. The main code currently lives under `scripts/` and `assets/`.

## Directory Map

- `scripts/main.lua`: game entry point, system init, UI build, scene registration, audio, update loop.
- `scripts/core/`: core gameplay systems such as time, finance, player, events, save, and progression.
- `scripts/ui/`: UI widgets and interaction panels.
- `scripts/scenes/`: rendering logic for different business scenes.
- `scripts/config/`: game config, balance data, text, and event constants.
- `assets/audio/`: current audio assets.

## Confirmed So Far

- The main runtime entry is `scripts/main.lua`.
- Shared runtime state is centered in `scripts/core/GameState.lua`.
- Stall gameplay logic is centered in `scripts/core/StallSystem.lua`.
- Day flow and end-of-month settlement are centered in `scripts/core/TimeSystem.lua`.
- The main UI shell is built by `scripts/ui/UIManager.lua` and `scripts/ui/BottomActions.lua`.
- No standard manifest file is present yet, so this looks like an engine script/resource repo rather than a fully standalone CLI project.

## Collaboration Rules

- Read the target module before editing it.
- Update `CHANGELOG_COLLAB.md` after every code change.
- Each log entry should include date, author, files, purpose, risks, and validation notes.
- Do not revert unknown changes unless explicitly asked.
- Prefer small, trackable changes over wide cross-system edits.

## Change Log Template

Append entries to `CHANGELOG_COLLAB.md` using a structure like this:

```md
## 2026-04-16

### Author
- Codex

### Changes
- File: `scripts/example.lua`
- Purpose: fix a logic issue
- Details: adjust a condition to prevent duplicate settlement
- Risk: may affect old save compatibility
- Validation: manual in-game check pending
```

## Current Phase

- Finish initial codebase mapping.
- Keep a stable collaboration logging workflow.
- Start implementation after the first issue list is clear.
