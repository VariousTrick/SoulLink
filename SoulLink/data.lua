-- data.lua
-- 【归魂碑 - 数据阶段】
-- 功能：注册快捷栏按钮 (Shortcut)

-- 定义快捷按钮
data:extend({
    {
        type = "shortcut",
        name = "soullink-shortcut", -- 必须与 Config.lua 中的 Names.shortcut 一致
        order = "a[soullink]",      -- 排序权重
        action = "lua",             -- 触发 on_lua_shortcut 事件，由脚本完全接管逻辑
        icon = "__SoulLink__/graphics/icon/shortcut.png",
        icon_size = 64,             -- 请确认你的图片尺寸
        small_icon = "__SoulLink__/graphics/icon/shortcut.png",
        small_icon_size = 64
    }
})
