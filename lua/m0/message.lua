---@class RawMessage
---@field role string
---@field content string

-- Abstract class for message handlers.
---@class Message
---@field get_messages fun(self:Message):RawMessage[]
---@field append_lines fun(self:Message, lines: string[])
---@field get_last_line fun(self:Message):string
---@field set_last_line fun(self:Message, Message, string)
---@field open_section fun(self:Message)
---@field close_section fun(self:Message)

---@type Message
local M = {}
return M
