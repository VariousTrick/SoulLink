-- scripts/main.lua
-- 【归魂碑 - 核心逻辑】
-- 功能：注册事件监听器，并将事件分发给对应的模块 (GUI/Manager)。

local Config = require("scripts.config")
local GUI = require("scripts.gui")

-- ============================================================================
-- 事件处理器映射表 (Handler Tables)
-- 性能优化：使用哈希表查找代替 if-else 判断，复杂度 O(1)
-- ============================================================================

-- 快捷键事件处理器映射
-- Key: shortcut_name (string), Value: function
local shortcut_handlers = {}

-- 注册我们的快捷键处理函数
shortcut_handlers[Config.Names.shortcut] = function(event)
    local player = game.get_player(event.player_index)
    if player then
        GUI.toggle_main_window(player)
    end
end

-- ============================================================================
-- 事件监听注册
-- ============================================================================

-- 监听快捷栏点击事件
script.on_event(defines.events.on_lua_shortcut, function(event)
    -- 直接查表调用，无需遍历
    local handler = shortcut_handlers[event.prototype_name]
    if handler then
        handler(event)
    end
end)

-- (后续我们会在这个文件里注册 on_gui_click, on_built_entity 等事件)
