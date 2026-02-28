Config = {}

Config.UseItem            = true
Config.ItemName           = "namechangedocument"
Config.Command            = "changename"
Config.RemoveItemOnUse    = true

-- 'qbcore', 'qbox', 'esx', or 'auto' (auto-detect)
-- ox_inventory is auto-detected and used when available
Config.Framework          = 'qbox'

Config.JobLocked          = false
Config.AllowedJobs        = { "police", "doj", "ems" }

Config.MinNameLength      = 2
Config.MaxNameLength      = 20
Config.Cooldown           = 0

Config.LogChanges         = true

Config.BadWords           = { "dev", "mod", "staff", "owner" }

-- 'chat', 'framework', or 'custom'
Config.NotificationType   = 'chat'
