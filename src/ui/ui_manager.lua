--[[
    UI管理器 (UIManager)
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    功能:
    - TTS XML UI系统管理
    - 主面板和子面板管理
    - UI事件处理和分发
    - 动态UI更新和状态同步
--]]

-- 基于ModuleBase创建UIManager
local UIManager = ModuleBase:new({
    name = "UIManager",
    version = "1.0.0",
    description = "桌游伴侣UI管理器",
    author = "LeadDeveloperAI",
    dependencies = {},
    
    default_config = {
        theme = "default",
        auto_resize = true,
        show_tooltips = true,
        animation_speed = 300,
        default_position = {x = 100, y = 100},
        default_size = {width = 400, height = 600}
    }
})

-- UI组件注册表
UIManager.components = {}
UIManager.active_panels = {}
UIManager.ui_state = "HIDDEN" -- HIDDEN, SHOWN, MINIMIZED

-- UI主题配置
UIManager.themes = {
    default = {
        colors = {
            primary = "#2C3E50",
            secondary = "#34495E", 
            accent = "#3498DB",
            text_primary = "#FFFFFF",
            text_secondary = "#BDC3C7",
            background = "#1A1A1A",
            border = "#7F8C8D",
            success = "#27AE60",
            warning = "#F39C12",
            error = "#E74C3C"
        },
        fonts = {
            header = 16,
            normal = 12,
            small = 10
        },
        spacing = {
            small = 5,
            medium = 10,
            large = 20
        }
    }
}

-- 子类初始化方法
function UIManager:onInitialize(save_data)
    Logger:info("初始化UI管理器")
    
    -- 加载UI配置
    self:loadUIConfig(save_data)
    
    -- 注册UI组件
    self:registerUIComponents()
    
    -- 设置默认主题
    self:setTheme(self.config.theme)
    
    -- 创建主面板
    self:createMainPanel()
    
    -- 注册事件监听器
    self:setupEventListeners()
    
    Logger:info("UI管理器初始化完成")
end

-- 显示UI
function UIManager:showUI()
    if self.ui_state == "SHOWN" then
        return
    end
    
    local main_xml = self.components.MainPanel.xml_template
    if main_xml then
        UI.setXml(main_xml)
        self.ui_state = "SHOWN"
        self.components.MainPanel.visible = true
        
        Logger:info("UI已显示")
        self:emitEvent("ui_shown", {panel = "MainPanel"})
    else
        Logger:error("主面板XML模板未找到")
    end
end

-- UI事件处理器 (全局函数，供TTS调用)
function UIManager.showMenu()
    Logger:info("显示主菜单")
    broadcastToAll("[桌游伴侣] 菜单功能开发中...", {0.8, 0.8, 0.8})
end

function UIManager.showStatus()
    Logger:info("显示状态信息")
    local status = MainController:getSystemStatus()
    local message = string.format("状态: %s | 模块: %d | 运行时间: %d秒", 
                                 status.state, status.modules_count, status.uptime)
    broadcastToAll("[桌游伴侣] " .. message, {0.3, 0.8, 0.3})
end

function UIManager.showHelp()
    Logger:info("显示帮助信息")
    broadcastToAll("[桌游伴侣] 帮助: 输入 /tc help 查看命令列表", {0.3, 0.3, 0.8})
end

-- 设置全局引用
_G.UIManager = UIManager

-- 导出UIManager模块
return UIManager 