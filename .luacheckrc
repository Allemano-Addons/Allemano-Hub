std = "lua51"
max_line_length = false
self = false
exclude_files = { "Tests/**" }

-- The only globals AllemanoHub may write.
globals = {
    "AllemanoHubDB",
    "SLASH_ALLEMANOHUB1", "SLASH_ALLEMANOHUB2", "SlashCmdList",
}

-- WoW API used by AllemanoHub (read-only). Extend as new APIs are used.
read_globals = {
    "_G",
    "strjoin", "strtrim", "strlower", "tostringall", "tinsert", "tremove", "wipe", "sort", "min", "date", "time",
    "unpack", "geterrorhandler", "seterrorhandler", "strmatch", "BugGrabber", "strupper", "strfind", "strsplit", "Ambiguate", "CHARACTER_SURNAME_SEPARATOR", "IsInGuild", "GetNumGuildMembers", "GetGuildRosterInfo", "GetGuildInfo", "C_ChatInfo", "C_UIFileAsset", "GetBuildInfo", "GetLocale", "UnitClass", "UnitLevel", "GetAddOnInfo", "IsAddOnLoaded", "GetNumAddOns", "C_Spell", "GetTime", "ItemRefTooltip", "HushDB", "LibStub", "GetCursorPosition", "IsModifiedClick", "IsShiftKeyDown", "ChatEdit_InsertLink", "AuctionFrame", "BrowseName", "ITEM_QUALITY_COLORS", "strsplit", "Ambiguate", "ceil", "floor", "max", "UIParent", "UISpecialFrames", "GetPhysicalScreenSize", "CUSTOM_CLASS_COLORS", "RAID_CLASS_COLORS", "Hush", "ChatFrame_OpenChat", "MailFrame", "MailFrameTab_OnClick", "SendMailNameEditBox", "GetNumGuildMembers", "IsInGuild", "issecretvalue",
    "CreateFrame", "DEFAULT_CHAT_FRAME", "GameTooltip", "TooltipDataProcessor", "Enum",
    "GetBuildInfo", "GetAddOnMetadata", "C_AddOns", "C_Timer", "C_ChatInfo", "C_GuildInfo", "C_TradeSkillUI", "C_TooltipInfo",
    "UnitGUID", "UnitName", "CHARACTERNAME_SURNAME_SEPARATOR",
    "IsInGuild", "GetGuildInfo", "GetNumGuildMembers", "GetGuildRosterInfo", "GuildRoster",
    "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo",
    "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillLine", "GetTradeSkillItemLink", "GetTradeSkillRecipeLink",
    "GetTradeSkillNumMade", "GetTradeSkillNumReagents", "GetTradeSkillReagentInfo", "GetTradeSkillReagentItemLink",
    "GetTradeSkillTools", "GetTradeSkillCooldown", "GetTradeSkillIcon", "GetTradeSkillSelectionIndex",
    "C_Item", "IsInGuild", "UnitClass", "GetProfessions", "GetNumCrafts", "GetCraftInfo", "GetCraftDisplaySkillLine", "GetCraftItemLink", "GetCraftRecipeLink",
    "GetCraftNumReagents", "GetCraftReagentInfo", "GetCraftReagentItemLink", "GetCraftSpellFocus",
}
