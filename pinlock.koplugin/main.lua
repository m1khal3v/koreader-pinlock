local Dispatcher = require("dispatcher")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")

local PinLock = WidgetContainer:extend{
    name = "pinlock_buttonpin",
    locked      = false,
    MAX_LEN     = 4,       -- Maximum length of the PIN
    DEFAULT_PIN = "0000",  -- Default PIN
    input       = "",      -- Current input from user
    dialog      = nil,     -- Current active dialog
}

-- Load PIN from KOReader settings
function PinLock:loadPin()
    local pin = G_reader_settings:readSetting("pinlock_pin") or self.DEFAULT_PIN
    if #pin ~= self.MAX_LEN then pin = self.DEFAULT_PIN end
    self.password = pin
end

-- Save PIN to KOReader settings
function PinLock:savePin(pin)
    self.password = pin
    G_reader_settings:saveSetting("pinlock_pin", pin)
end

-- Initialize the plugin
function PinLock:init()
    self:loadPin()
    Dispatcher:registerAction("pinlock_buttonpin_lock_screen", {
        category = "none",
        event    = "LockScreenButtons",
        title    = _("Lock Screen (Button PIN)"),
        filemanager = true,
    })
    self.ui.menu:registerToMainMenu(self)

    -- Lock screen on resume if not already locked
    function self:onResume()
        if not self.locked then self:lockScreen() end
    end
end

-- Update the dialog title to show filled and empty circles
function PinLock:updatePinTitle()
    if self.dialog then
        local circles = string.rep("●", #self.input) .. string.rep("○", self.MAX_LEN - #self.input)
        self.dialog:setTitle(circles)
    end
end

-- Create a PIN input dialog
-- onComplete: callback when PIN is fully entered
-- dismissable: whether the dialog can be dismissed
function PinLock:showPinDialog(onComplete, dismissable)
    self.input = ""

    local function makeButton(num)
        return {
            text = num,
            callback = function()
                if #self.input < self.MAX_LEN then
                    self.input = self.input .. num
                    self:updatePinTitle()
                    if #self.input == self.MAX_LEN then
                        onComplete(self.input)
                    end
                end
            end
        }
    end

    local function makeDeleteButton()
        return {
            text = "⌫",
            callback = function()
                self.input = self.input:sub(1, -2)
                self:updatePinTitle()
            end
        }
    end

    local function makeEmptyButton() return { text = " ", callback = function() end } end

    local buttons = {
        { makeButton("1"), makeButton("2"), makeButton("3") },
        { makeButton("4"), makeButton("5"), makeButton("6") },
        { makeButton("7"), makeButton("8"), makeButton("9") },
        { makeEmptyButton(), makeButton("0"), makeDeleteButton() },
    }

    self.dialog = ButtonDialog:new{
        title        = string.rep("○", self.MAX_LEN), -- Empty circles initially
        title_align  = "center",
        buttons      = buttons,
        width_factor = 1.0,
        dismissable  = dismissable,
    }

    UIManager:show(self.dialog)
    self:updatePinTitle()
end

-- Lock the screen and show the PIN dialog
function PinLock:lockScreen()
    self.locked = true
    self:showPinDialog(function(input)
        if input == self.password then
            self.locked = false
            if self.dialog then
                UIManager:close(self.dialog)
                self.dialog = nil
            end
            UIManager:show(InfoMessage:new{ text = _("Screen unlocked."), timeout = 1 })
        else
            -- Wrong PIN: reset input but keep the dialog open
            UIManager:show(InfoMessage:new{ text = _("Wrong PIN! Try again."), timeout = 1 })
            self.input = ""
            self:updatePinTitle()
        end
    end, false)  -- dismissable = false during unlock
end

-- Show dialog to set a new PIN
function PinLock:showSetPinDialog()
    self:showPinDialog(function(input)
        self:savePin(input)
        if self.dialog then
            UIManager:close(self.dialog)
            self.dialog = nil
        end
        UIManager:show(InfoMessage:new{ text = _("PIN changed successfully."), timeout = 1 })
    end, true)  -- dismissable = true when setting a new PIN
end

-- Add menu items to KOReader main menu
function PinLock:addToMainMenu(menu_items)
    menu_items.pinlock_buttonpin = {
        text     = _("Lock Screen"),
        callback = function() self:lockScreen() end
    }
    menu_items.pinlock_buttonpin_settings = {
        text     = _("Set PIN"),
        callback = function() self:showSetPinDialog() end
    }
end

return PinLock
