-- scripts/gui.lua
-- 【归魂碑 - 界面模块】
-- 最终修复版 v10：基于 V9 结构修正。修复图标报错，实现右侧纯监控布局。

local Config = require("scripts.config")
local State = require("scripts.state")

local GUI = {}

-- 标记需要刷新的玩家
local players_to_refresh = {}

-- 常量定义
local NAMES = {
    frame = Config.Names.main_frame,
    titlebar = "aetherlink_titlebar",
    close_btn = "aetherlink_close_btn",

    -- [新增] 标题栏新按钮
    pin_btn = "aetherlink_pin_btn",
    search_btn = "aetherlink_search_btn",
    search_textfield = "aetherlink_search_text",

    -- 容器
    left_scroll = "aetherlink_left_scroll",
    right_pane = "aetherlink_right_pane",
    camera = "aetherlink_detail_camera",
    -- info_flow 已删除，不再需要

    -- 改名窗口
    rename_frame = "aetherlink_rename_frame",
    rename_textfield = "aetherlink_rename_text",
    rename_confirm = "aetherlink_rename_confirm",

    -- 动态前缀
    btn_expand = "aetherlink_expand_",
    btn_fav = "aetherlink_fav_",
    btn_select = "aetherlink_sel_",
    btn_edit = "aetherlink_edit_",
    btn_gps = "aetherlink_gps_", -- [新增] GPS 按钮
    btn_teleport = "aetherlink_tp_",
    btn_fold = "aetherlink_fold_", -- [新增] 折叠按钮

    -- [保留] 之前讨论的排序抓手 (如果你之前删了，请加回来)
    btn_move_anchor = "aetherlink_mv_anc_",
    btn_move_surface = "aetherlink_mv_srf_",

    nav_scroll = "aetherlink_nav_scroll", -- 左侧导航栏容器名
    btn_nav_item = "aetherlink_nav_item_", -- 导航按钮前缀
    btn_nav_tp = "aetherlink_nav_tp_", -- 导航传送按钮前缀
}

-- ============================================================================
-- 辅助工具
-- ============================================================================

--- 递归查找 GUI 元素 (最稳健的查找方式)
local function find_element_by_name(parent, name)
    if parent.name == name then
        return parent
    end
    if parent.children then
        for _, child in pairs(parent.children) do
            local found = find_element_by_name(child, name)
            if found then
                return found
            end
        end
    end
    return nil
end

--- 智能排序 (字符串 vs 本地化表)
local function sort_anchors(a, b)
    local ta, tb = type(a.name), type(b.name)
    if ta ~= tb then
        return ta == "string"
    end
    if ta == "string" then
        return a.name < b.name
    end
    return a.name[2] < b.name[2]
end

-- ============================================================================
-- 界面构建与更新
-- ============================================================================

--- [右侧] 更新详情面板 (纯监控，无额外信息)
local function update_detail_pane(frame, anchor_id)
    local anchor = State.get_by_id(anchor_id)
    if not anchor then
        return
    end

    -- 使用递归查找确保找到 camera
    local camera = find_element_by_name(frame, NAMES.camera)

    if camera then
        camera.position = anchor.position
        camera.surface_index = anchor.surface_index
        camera.zoom = 0.2
    end
end

--- [新增] 更新左侧导航栏
local function update_nav_pane(frame, player, p_data)
    local scroll = find_element_by_name(frame, NAMES.nav_scroll)
    if not scroll then
        return
    end
    scroll.clear()

    -- [关键修改] 创建一个内部容器来消除间距
    local inner_flow = scroll.add({ type = "flow", direction = "vertical" })
    inner_flow.style.vertical_spacing = 0 -- 消除元素间的缝隙
    inner_flow.style.horizontally_stretchable = true
    -- inner_flow.style.vertically_stretchable = true -- 可选，如果需要让flow填满高度

    local ROW_HEIGHT = 28
    if not p_data.selected_nav then
        p_data.selected_nav = player.surface.index
    end

    -- 辅助函数
    local function add_nav_row(id, caption, is_special, surface_index_for_tp)
        local is_selected = (p_data.selected_nav == id)

        -- [修改] 改为添加到 inner_flow 中
        local flow = inner_flow.add({ type = "flow", direction = "horizontal" })
        flow.style.vertical_align = "center"
        flow.style.bottom_margin = 0
        -- [关键] 让 flow 水平拉伸，确保按钮填满宽度
        flow.style.horizontally_stretchable = true

        -- 左侧按钮
        local btn = flow.add({
            type = "button",
            name = NAMES.btn_nav_item .. tostring(id),
            caption = caption,
            style = "list_box_item",
            tags = { nav_id = id }, -- id 可能是数字或字符串
            mouse_button_filter = { "left" },
            -- [修复] 启用 toggled 属性，实现持久高亮
            toggled = is_selected,
        })

        -- 样式修正
        btn.style.height = ROW_HEIGHT
        btn.style.horizontally_stretchable = true
        btn.style.horizontal_align = "left"
        btn.style.font = "default-bold"

        -- [修复] 颜色调整
        if is_selected then
            btn.style.font_color = { 0, 0, 0 }
        else
            btn.style.font_color = { 0.8, 0.8, 0.8 }
        end

        -- 右侧传送按钮 (主塔)
        if surface_index_for_tp then
            local anchors = State.get_list_by_surface(surface_index_for_tp)
            local main_anchor = nil
            for _, a in pairs(anchors) do
                if a.type == "aetherlink-obelisk" then
                    main_anchor = a
                    break
                end
            end

            if main_anchor then
                flow.add({
                    type = "sprite-button",
                    name = NAMES.btn_nav_tp .. main_anchor.id,
                    sprite = "aetherlink-icon-teleport",
                    style = "frame_action_button",
                    style_mods = { width = 24, height = 24, margin = 0 },
                    tooltip = { "gui.aetherlink-tooltip-teleport-main" },
                    tags = { anchor_id = main_anchor.id },
                })
            else
                flow.add({ type = "empty-widget", style_mods = { width = 24 } })
            end
        end
    end

    -- 1. 特殊分类
    add_nav_row("__all__", { "gui.aetherlink-nav-all" }, true)
    add_nav_row("__fav__", { "gui.aetherlink-nav-favorites" }, true)

    -- 2. 地表列表
    local active_surfaces = State.get_active_surfaces()
    local s_idxs = {}
    for k in pairs(active_surfaces) do
        table.insert(s_idxs, k)
    end
    table.sort(s_idxs)

    for _, s_idx in ipairs(s_idxs) do
        local s_name = game.surfaces[s_idx] and game.surfaces[s_idx].name or ("Surface #" .. s_idx)
        add_nav_row(s_idx, s_name, false, s_idx)
    end
end

-- [重写] 添加表格行 (原生工具栏风格: 20px)
local function add_table_row(table_elem, anchor, player_data)
    local ROW_SIZE = 28

    -- 图标按钮样式：使用原生 frame_action_button，它是专门为 20px 设计的
    local icon_style = "frame_action_button"
    local icon_mods = { width = ROW_SIZE, height = ROW_SIZE, padding = 0, margin = 0 }

    -- 名字栏样式：保持深色背景，但压扁高度
    local name_mods = { height = ROW_SIZE, top_padding = 0, bottom_padding = 0, margin = 0 }

    -- [新增] 第0列：排序抓手 (用字符模拟)
    local is_moving = (player_data.moving_anchor_id == anchor.id)
    local move_style = is_moving and "flib_selected_frame_action_button" or "frame_action_button"

    table_elem.add({
        type = "button", -- 改用 button
        name = NAMES.btn_move_anchor .. anchor.id,
        caption = "::", -- 字符模拟
        style = move_style,
        style_mods = { width = 24, height = ROW_SIZE, padding = 0, margin = 0, font = "default-bold" },
        tags = { anchor_id = anchor.id, surface_index = anchor.surface_index },
        tooltip = { "gui.aetherlink-tooltip-sort" },
    })

    -- 1. 第一列：收藏按钮 (Star)
    local is_fav = player_data.favorites and player_data.favorites[anchor.id]
    local fav_sprite = is_fav and "aetherlink-icon-star" or "aetherlink-icon-notstar"

    table_elem.add({
        type = "sprite-button",
        name = NAMES.btn_fav .. anchor.id,
        sprite = fav_sprite,
        style = icon_style, -- [修改] 使用原生小按钮样式
        style_mods = icon_mods,
        tags = { anchor_id = anchor.id },
        tooltip = is_fav and { "gui.aetherlink-tooltip-unfavorite" } or { "gui.aetherlink-tooltip-favorite" },
    })

    -- 2. 第二列：名字 (Name)
    local is_editing = player_data.editing_anchor_id == anchor.id

    if is_editing then
        -- 编辑框
        local current_text = (type(anchor.name) == "string") and anchor.name or ""
        local textfield = table_elem.add({
            type = "textfield",
            name = NAMES.rename_textfield .. anchor.id,
            text = current_text,
            icon_selector = true,
            tags = { anchor_id = anchor.id },
        })
        textfield.style.horizontally_stretchable = true
        textfield.style.height = ROW_SIZE
        textfield.style.margin = 0
        textfield.focus()
    else
        -- 名字按钮 (统一为原生工具栏按钮样式)
        local name_btn = table_elem.add({
            type = "button",
            name = NAMES.btn_select .. anchor.id,
            caption = anchor.name,
            style = "list_box_item",
            tags = { anchor_id = anchor.id },
            mouse_button_filter = { "left" },
        })
        name_btn.style.horizontally_stretchable = true
        name_btn.style.horizontal_align = "left" -- 保持左对齐
        name_btn.style.font_color = { 1, 1, 1 }

        -- 应用高度修正
        for k, v in pairs(name_mods) do
            name_btn.style[k] = v
        end

        -- [新增] 增加一点左内边距，让文字不要紧贴边缘
        name_btn.style.left_padding = 4
    end

    -- 3. 第三列：改名/确认
    if is_editing then
        table_elem.add({
            type = "sprite-button",
            name = NAMES.rename_confirm .. anchor.id,
            sprite = "utility/check_mark",
            style = icon_style, -- [修改] 原生小按钮
            style_mods = icon_mods,
            tags = { anchor_id = anchor.id },
            tooltip = { "gui.aetherlink-confirm-rename" },
        })
    else
        table_elem.add({
            type = "sprite-button",
            name = NAMES.btn_edit .. anchor.id,
            sprite = "aetherlink-icon-rename",
            style = icon_style, -- [修改] 原生小按钮
            style_mods = icon_mods,
            tags = { anchor_id = anchor.id },
            tooltip = { "gui.aetherlink-rename" },
        })
    end

    -- 4. 第四列：GPS
    local surface_name = "Unknown"
    if game.surfaces[anchor.surface_index] then
        surface_name = game.surfaces[anchor.surface_index].name
    end
    local gps_tag = string.format("[gps=%d,%d,%s]", anchor.position.x, anchor.position.y, surface_name)

    table_elem.add({
        type = "sprite-button",
        name = NAMES.btn_gps .. anchor.id,
        sprite = "utility/center",
        style = icon_style, -- [修改] 原生小按钮
        style_mods = icon_mods,
        tags = { gps_string = gps_tag },
        tooltip = { "gui.aetherlink-tooltip-gps" },
    })

    -- 5. 第五列：传送
    table_elem.add({
        type = "sprite-button",
        name = NAMES.btn_teleport .. anchor.id,
        sprite = "aetherlink-icon-teleport",
        style = icon_style, -- [修改] 原生小按钮
        style_mods = icon_mods,
        tags = { anchor_id = anchor.id },
        tooltip = { "gui.aetherlink-teleport" },
    })
end
local function update_list_view(frame, player)
    local p_data = State.get_player_data(player.index)

    update_nav_pane(frame, player, p_data)

    local scroll = find_element_by_name(frame, NAMES.left_scroll)
    if not scroll then
        return
    end
    scroll.clear()

    -- 获取搜索文本
    local search_text = ""
    local titlebar = find_element_by_name(frame, NAMES.titlebar)
    if titlebar and titlebar[NAMES.search_textfield] then
        search_text = string.lower(titlebar[NAMES.search_textfield].text)
    end

    local is_search_mode = (search_text ~= "")
    local nav_selection = p_data.selected_nav

    local all_anchors = State.get_all()
    local grouped_data = {}

    -- 数据筛选逻辑 (保持不变)
    for _, anchor in pairs(all_anchors) do
        local keep = false
        if is_search_mode then
            if type(anchor.name) == "string" and string.find(string.lower(anchor.name), search_text, 1, true) then
                keep = true
            end
        elseif nav_selection == "__fav__" then
            if p_data.favorites and p_data.favorites[anchor.id] then
                keep = true
            end
        elseif nav_selection == "__all__" then
            keep = true
        elseif type(nav_selection) == "number" then
            if anchor.surface_index == nav_selection then
                if anchor.type ~= "aetherlink-obelisk" then
                    keep = true
                end
            end
        end

        if keep then
            local s_idx = anchor.surface_index
            if not grouped_data[s_idx] then
                local s_name = game.surfaces[s_idx] and game.surfaces[s_idx].name or ("Surface #" .. s_idx)
                grouped_data[s_idx] = { name = s_name, anchors = {} }
            end
            table.insert(grouped_data[s_idx].anchors, anchor)
        end
    end

    local s_idxs = {}
    for k in pairs(grouped_data) do
        table.insert(s_idxs, k)
    end
    table.sort(s_idxs)

    -- 空数据提示
    if #s_idxs == 0 then
        scroll.add({ type = "label", caption = { "gui.aetherlink-no-anchors" }, style_mods = { font_color = { 0.5, 0.5, 0.5 } } })
        return
    end

    -- 渲染列表
    for _, s_idx in ipairs(s_idxs) do
        local group = grouped_data[s_idx]
        local show_header = (type(nav_selection) ~= "number") or is_search_mode

        -- [改动 1] 外层容器改用 Frame，样式为 inside_shallow_frame (浅灰色)
        -- 这就是你想要的"灰色边框向外扩散"的效果
        local group_frame = scroll.add({ type = "frame", style = "inside_shallow_frame", direction = "vertical" })
        group_frame.style.horizontally_stretchable = true
        group_frame.style.bottom_margin = 10
        -- 稍微调整内边距，让里面的深坑看起来被灰色包围
        group_frame.style.padding = 6

        -- [改动 2] 标题栏
        -- 因为外层已经是灰色的了，标题栏不需要额外的 Frame，直接放 Label 即可
        if show_header then
            local header_flow = group_frame.add({ type = "flow", direction = "horizontal" })
            header_flow.style.vertical_align = "center"
            header_flow.style.bottom_margin = 4 -- 标题和列表之间的间距
            header_flow.style.left_padding = 2

            -- 这里可以加图标，增加质感
            -- header_flow.add({type="sprite", sprite="utility/surface_editor_icon"})

            local caption = group.name
            if group.name == "★ 特别关注" then
                caption = { "gui.aetherlink-header-favorites" }
            end

            header_flow.add({ type = "label", caption = caption, style = "caption_label" }).style.font = "default-bold"
            header_flow.add({ type = "empty-widget", style = "flib_horizontal_pusher" })
        end

        -- [改动 3] 内容深坑 (Deep Frame)
        -- 这个深色框放在浅灰色框内部，形成"被包围"的视觉效果
        local content_frame = group_frame.add({ type = "frame", style = "inside_deep_frame", direction = "vertical" })
        content_frame.style.horizontally_stretchable = true
        content_frame.style.padding = 0

        -- 列表 Table
        local list_table = content_frame.add({
            type = "table",
            column_count = 6,
            style = "table",
        })
        list_table.style.horizontally_stretchable = true
        list_table.style.horizontal_spacing = 0
        list_table.style.vertical_spacing = 0

        table.sort(group.anchors, function(a, b)
            return a.id < b.id
        end)

        for _, anchor in ipairs(group.anchors) do
            add_table_row(list_table, anchor, p_data)
        end
    end
end

-- ============================================================================
-- 公开接口与事件处理
-- ============================================================================

function GUI.toggle_main_window(player)
    local frame = player.gui.screen[NAMES.frame]
    if frame then
        GUI.close_window(player)
    else
        -- 1. 创建主窗口
        frame = player.gui.screen.add({ type = "frame", name = NAMES.frame, direction = "vertical" })
        frame.auto_center = true -- 居中

        -- 2. 标题栏 (代码保持不变，含搜索、固定、关闭等)
        local titlebar = frame.add({ type = "flow", name = NAMES.titlebar, direction = "horizontal", style = "flib_titlebar_flow" })
        titlebar.drag_target = frame
        titlebar.add({ type = "label", style = "frame_title", caption = { "gui-title.aetherlink-main" }, ignored_by_interaction = true })
        titlebar.add({ type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true })

        local p_data = State.get_player_data(player.index)

        -- 搜索框逻辑 (保持不变)
        local search_visible = p_data.show_search == true
        titlebar.add({ type = "textfield", name = NAMES.search_textfield, visible = search_visible, style_mods = { width = 100, top_margin = -2 } })
        titlebar.add({ type = "sprite-button", name = NAMES.search_btn, style = "frame_action_button", sprite = "aetherlink-icon-search", tooltip = { "gui.aetherlink-tooltip-search" } })

        -- 固定按钮 (保持不变)
        local pin_style = p_data.is_pinned and "flib_selected_frame_action_button" or "frame_action_button"
        titlebar.add({ type = "sprite-button", name = NAMES.pin_btn, style = pin_style, sprite = "aetherlink-icon-pin", tooltip = { "gui.aetherlink-tooltip-pin" } })
        titlebar.add({ type = "sprite-button", name = NAMES.close_btn, style = "frame_action_button", sprite = "utility/close" })

        -- ====================================================================
        -- 3. 主体内容 (三栏布局) - [修改版]
        -- ====================================================================
        local body = frame.add({ type = "flow", direction = "horizontal" })
        body.style.horizontal_spacing = 8
        -- [关键] 让 body 也能纵向拉伸，填满 frame
        body.style.vertically_stretchable = true

        -- [栏 1] 左侧导航
        local nav_frame = body.add({ type = "frame", style = "inside_deep_frame", direction = "vertical" })
        nav_frame.style.padding = 0
        nav_frame.style.vertically_stretchable = true -- [修复] 纵向拉伸

        local nav_scroll = nav_frame.add({
            type = "scroll-pane",
            name = NAMES.nav_scroll,
            -- [修改] 使用带有条纹背景的原版样式
            style = "list_box_under_subheader_scroll_pane",
            horizontal_scroll_policy = "never",
            vertical_scroll_policy = "auto",
        })

        -- [修复 2] 删除 extra_right_padding，防止按钮挤压
        -- [修复 1] 强制垂直拉伸，确保条纹背景填满整个高度
        nav_scroll.style.vertically_stretchable = true

        -- [修复 2] 宽度加宽到 220
        nav_scroll.style.minimal_width = 220
        nav_scroll.style.maximal_width = 220
        nav_scroll.style.maximal_height = 800
        nav_scroll.style.minimal_height = 600

        -- [栏 2] 中间列表
        local list_frame = body.add({ type = "frame", style = "inside_deep_frame", direction = "vertical" })
        list_frame.style.padding = 4
        list_frame.style.vertically_stretchable = true -- [修复] 纵向拉伸

        local list_scroll = list_frame.add({
            type = "scroll-pane",
            name = NAMES.left_scroll,
            -- [修改] 使用带有条纹背景的原版样式
            style = "list_box_under_subheader_scroll_pane",
            horizontal_scroll_policy = "never",
        })

        -- [修复 2] 删除 extra_right_padding
        -- [修复 1] 强制垂直拉伸
        list_scroll.style.vertically_stretchable = true

        list_scroll.style.minimal_width = 350
        list_scroll.style.maximal_height = 800

        -- [栏 3] 右侧监控
        local cam_frame = body.add({ type = "frame", style = "inside_deep_frame", direction = "vertical" })
        cam_frame.style.padding = 0
        cam_frame.style.vertically_stretchable = true -- [修复] 纵向拉伸

        local camera = cam_frame.add({
            type = "camera",
            name = NAMES.camera,
            position = { 0, 0 },
            surface_index = 1,
            zoom = 0.2,
        })
        camera.style.minimal_width = 300
        camera.style.minimal_height = 300
        camera.style.vertically_stretchable = true
        camera.style.horizontally_stretchable = true
        camera.style.maximal_height = 800

        player.opened = frame
        p_data.is_gui_open = true

        -- 初始化：如果没有选中的导航，默认选中当前星球
        if not p_data.selected_nav then
            p_data.selected_nav = player.surface.index
        end

        update_list_view(frame, player)

        -- 初始打开时，如果选中的是星球，让摄像头对准主塔
        if type(p_data.selected_nav) == "number" then
            local anchors = State.get_list_by_surface(p_data.selected_nav)
            for _, a in pairs(anchors) do
                if a.type == "aetherlink-obelisk" then
                    camera.position = a.position
                    camera.surface_index = a.surface_index
                    break
                end
            end
        end
    end
end

function GUI.close_window(player)
    local frame = player.gui.screen[NAMES.frame]
    if frame then
        frame.destroy()
    end

    local rename = player.gui.screen[NAMES.rename_frame]
    if rename then
        rename.destroy()
    end

    local p_data = State.get_player_data(player.index)
    p_data.is_gui_open = false
end

function GUI.handle_click(event)
    local element = event.element
    if not (element and element.valid) then
        return
    end

    local name = element.name
    local player = game.get_player(event.player_index)
    local frame = player.gui.screen[NAMES.frame]

    -- 获取玩家数据
    local p_data = State.get_player_data(player.index)

    -- ============================================================
    -- 1. 全局/标题栏按钮
    -- ============================================================

    -- 全局关闭
    if name == NAMES.close_btn then
        GUI.close_window(player)
        return
    end

    -- 固定按钮
    if name == NAMES.pin_btn then
        if not p_data.is_pinned then
            p_data.is_pinned = false
        end
        p_data.is_pinned = not p_data.is_pinned
        element.style = p_data.is_pinned and "flib_selected_frame_action_button" or "frame_action_button"
        return
    end

    -- 搜索按钮
    if name == NAMES.search_btn then
        if p_data.show_search == nil then
            p_data.show_search = false
        end
        p_data.show_search = not p_data.show_search

        local titlebar = element.parent
        if titlebar[NAMES.search_textfield] then
            titlebar[NAMES.search_textfield].visible = p_data.show_search
            if not p_data.show_search then
                titlebar[NAMES.search_textfield].text = ""
                update_list_view(frame, player)
            end
        end
        return
    end

    -- ============================================================
    -- 2. [新增] 左侧导航栏逻辑 (三栏布局核心)
    -- ============================================================

    -- 逻辑 A: 点击导航项 (切换视图)
    if string.find(name, NAMES.btn_nav_item) then
        -- 获取存在 tags 里的导航 ID (可能是数字也可能是字符串 "__all__")
        local nav_id = element.tags.nav_id

        -- 更新选中状态
        p_data.selected_nav = nav_id

        -- 刷新界面 (让中间列表变化)
        update_list_view(frame, player)

        -- [联动] 如果选中的是具体星球，让右侧摄像头自动对准该星球的主塔
        if type(nav_id) == "number" then
            local anchors = State.get_list_by_surface(nav_id)
            -- 寻找主塔
            for _, a in pairs(anchors) do
                if a.type == "aetherlink-obelisk" then
                    -- 找到摄像头控件
                    local cam = find_element_by_name(frame, NAMES.camera)
                    if cam then
                        cam.position = a.position
                        cam.surface_index = a.surface_index
                        cam.zoom = 0.2
                    end
                    break
                end
            end
        end
        return
    end

    -- 逻辑 B: 点击导航栏上的传送按钮
    if string.find(name, NAMES.btn_nav_tp) then
        local anchor_id = element.tags.anchor_id
        if anchor_id then
            local anchor = State.get_by_id(anchor_id)
            -- [修改] 安全传送逻辑
            if anchor and anchor.entity and anchor.entity.valid then
                local surface = anchor.entity.surface
                local center = anchor.entity.position

                -- 参数说明: "character"=玩家碰撞盒, center=搜索中心, 10=搜索半径, 1=精度
                -- 这会自动跳过建筑本身的碰撞体积，找到最近的空地
                local safe_pos = surface.find_non_colliding_position("character", center, 10, 1)

                if safe_pos then
                    player.teleport(safe_pos, anchor.surface_index)
                else
                    -- 极少数情况找不到空地，才传送到中心
                    player.teleport(center, anchor.surface_index)
                end

                if not p_data.is_pinned then
                    GUI.close_window(player)
                end
            else
                player.print({ "gui.aetherlink-anchor-not-found" })
            end
        end
        return
    end

    -- ============================================================
    -- 3. 中间列表逻辑
    -- ============================================================

    -- 如果主窗口不存在，后续逻辑无法执行
    if not frame then
        return
    end

    -- 折叠/展开地表 (在"所有网络"模式下使用)
    if name == NAMES.btn_fold then
        local s_idx = element.tags.surface_index
        if not p_data.collapsed_surfaces then
            p_data.collapsed_surfaces = {}
        end
        p_data.collapsed_surfaces[s_idx] = not p_data.collapsed_surfaces[s_idx]
        update_list_view(frame, player)
        return
    end

    -- 改名确认 (钩子按钮)
    if string.find(name, NAMES.rename_confirm) then
        local anchor_id = element.tags.anchor_id
        local textfield_name = NAMES.rename_textfield .. anchor_id
        local table_elem = element.parent -- [修复] 按钮的直接父级就是 table
        if table_elem[textfield_name] then
            State.set_anchor_name(anchor_id, table_elem[textfield_name].text)
            p_data.editing_anchor_id = nil
            update_list_view(frame, player)
        end
        return
    end

    -- GPS 发送
    if string.find(name, NAMES.btn_gps) then
        if element.tags.gps_string then
            -- [修复] 使用 game.print()，它对单人和多人游戏都有效，且保证不报错
            game.print(element.tags.gps_string)
        end
        return
    end

    -- 列表项传送
    if string.find(name, NAMES.btn_teleport) then
        local anchor = State.get_by_id(element.tags.anchor_id)
        -- [修改] 安全传送逻辑 (同上)
        if anchor and anchor.entity and anchor.entity.valid then
            local surface = anchor.entity.surface
            local center = anchor.entity.position
            local safe_pos = surface.find_non_colliding_position("character", center, 10, 1)

            if safe_pos then
                player.teleport(safe_pos, anchor.surface_index)
            else
                player.teleport(center, anchor.surface_index)
            end

            if not p_data.is_pinned then
                GUI.close_window(player)
            end
        end
        return
    end

    -- 列表项选中 (更新摄像头)
    if string.find(name, NAMES.btn_select) then
        update_detail_pane(frame, element.tags.anchor_id)
        return
    end

    -- 收藏按钮
    if string.find(name, NAMES.btn_fav) then
        local id = element.tags.anchor_id
        if not p_data.favorites then
            p_data.favorites = {}
        end
        p_data.favorites[id] = not p_data.favorites[id]
        update_list_view(frame, player)
        return
    end

    -- 改名按钮 (进入编辑模式)
    if string.find(name, NAMES.btn_edit) then
        p_data.editing_anchor_id = element.tags.anchor_id
        update_list_view(frame, player)
        return
    end
end

-- 确认事件 (改名框回车)
function GUI.handle_confirm(event)
    -- [修改] 使用 string.find 匹配输入框名字
    if string.find(event.element.name, NAMES.rename_textfield) then
        local player = game.get_player(event.player_index)
        local frame = player.gui.screen[Config.Names.main_frame]
        local anchor_id = event.element.tags.anchor_id

        if anchor_id then
            State.set_anchor_name(anchor_id, event.element.text)

            local p_data = State.get_player_data(player.index)
            p_data.editing_anchor_id = nil -- 退出编辑模式

            if frame then
                update_list_view(frame, player)
            end
        end
    end
end

-- 自动刷新逻辑
function GUI.refresh_all()
    for _, p in pairs(game.connected_players) do
        local f = p.gui.screen[Config.Names.main_frame]
        if f and f.valid then
            update_list_view(f, p)
        end
    end
end

-- [新增] 处理搜索文本变更
function GUI.handle_search(event)
    if event.element.name == NAMES.search_textfield then
        local player = game.get_player(event.player_index)
        local frame = player.gui.screen[NAMES.frame]
        if frame then
            update_list_view(frame, player)
        end
    end
end

return GUI
