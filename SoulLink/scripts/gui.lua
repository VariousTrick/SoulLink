-- scripts/gui.lua
-- 【归魂碑 - 界面模块】
-- 功能：处理所有 GUI 的构建、交互和销毁。

local Config = require("scripts.config")

local GUI = {}

-- 切换主窗口的显示/隐藏
-- @param player LuaPlayer
function GUI.toggle_main_window(player)
	-- 目前仅打印日志用于测试
	Config.log("GUI: toggle_main_window 被调用。玩家: " .. player.name)

	-- 下一步我们将在这里编写真正的窗口创建逻辑
	-- if window_exists then destroy else create end
end --ok

return GUI
