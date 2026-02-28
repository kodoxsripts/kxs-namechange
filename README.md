# kxs-namechange

A FiveM resource that lets players change their character's first and last name in-game through a sleek black and blue NUI interface.

## Features

- Clean black and blue themed UI (Name Change Document)
- Multi-framework support: QBCore, QBox, ESX, and standalone
- ox_inventory auto-detection and compatibility
- Bad word / profanity filter (configurable)
- Job-restricted access (optional)
- Cooldown between name changes (optional)
- Item-based or command-based usage
- Server-side validation and logging
- Name preview before confirming

## Supported Frameworks & Inventory

| Framework | Status |
|-----------|--------|
| QBCore | Supported |
| QBox (qbx_core) | Supported |
| ESX | Supported |
| Standalone | Supported |
| ox_inventory | Auto-detected |

When `Config.Framework` is set to `'auto'`, the resource detects the framework in this order: QBox > QBCore > ESX > Standalone.

ox_inventory is detected separately and works alongside any framework. When present, it handles item removal automatically.

## Installation

1. Place the `kxs-namechange` folder in your server's `resources` directory
2. Add `ensure kxs-namechange` to your `server.cfg`
3. Make sure `oxmysql` is running if you use QBCore, QBox, or ESX
4. Edit `data/config.lua` to match your server setup
5. If using item mode, add `namechangedocument` to your inventory system (see below)
6. Restart your server

## Configuration

All settings are in `data/config.lua`:

```lua
Config.UseItem            = true                  -- Use an item to open (true) or a command (false)
Config.ItemName           = "namechangedocument"  -- Item name in your inventory system
Config.Command            = "changename"          -- Command when UseItem is false
Config.RemoveItemOnUse    = true                  -- Remove the item after use
Config.Framework          = 'qbox'               -- 'qbcore', 'qbox', 'esx', or 'auto'
Config.JobLocked          = false                -- Restrict to certain jobs
Config.AllowedJobs        = { "police", "doj", "ems" }
Config.MinNameLength      = 2                    -- Minimum characters per name
Config.MaxNameLength      = 20                   -- Maximum characters per name
Config.Cooldown           = 0                    -- Seconds between changes (0 = none)
Config.LogChanges         = true                 -- Log changes to server console
Config.NotificationType   = 'chat'               -- 'chat', 'framework', or 'custom'
```

### Bad Words

Add or remove words from the `Config.BadWords` table in `data/config.lua`. Both first and last names are checked against this list on both client and server side.

```lua
Config.BadWords = { "dev", "mod", "staff", "owner" }
```

## Adding the Item

### QBCore / QBox

Add to your shared items (`qb-core/shared/items.lua` or equivalent):

```lua
namechangedocument = { name = "namechangedocument", label = "Name Change Document", weight = 0, type = "item", image = "namechangedocument.png", unique = true, useable = true, shouldClose = true, description = "A document to legally change your name" },
```

### ox_inventory

Add to `ox_inventory/data/items.lua`:

```lua
["namechangedocument"] = {
    label = "Name Change Document",
    weight = 0,
    stack = false,
    close = true,
    description = "A document to legally change your name"
},
```

### ESX

Add the item to your `items` database table:

```sql
INSERT INTO items (name, label, weight) VALUES ('namechangedocument', 'Name Change Document', 0);
```

## Commands

| Command | Description |
|---------|-------------|
| `/changename` | Opens the name change UI (always available) |

If `Config.UseItem = false`, the command defined in `Config.Command` will also open the UI.

## File Structure

```
kxs-namechange/
  fxmanifest.lua        -- Resource manifest
  data/config.lua       -- Configuration
  client/main.lua       -- Client-side logic
  server/main.lua       -- Server-side logic
  html/index.html       -- NUI interface
  html/style.css        -- NUI styling
  html/script.js        -- NUI logic
  locales/en.json       -- English translations
```

## Dependencies

- `oxmysql` (required for QBCore / QBox / ESX database updates)
- `qb-core` or `qbx_core` or `es_extended` (depending on your framework)
- `ox_inventory` (optional, auto-detected)
