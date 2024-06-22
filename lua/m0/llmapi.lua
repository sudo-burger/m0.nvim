---Abstract class for LLM APIs.
---@class LLMAPI
---@field opts BackendOptions
---@field make_body fun():table Makethe API request body.
---@field make_headers fun():table Make the API request headers.
---@field get_messages fun(self:LLMAPI, messages:table):table<Message> get the chat messages.
---@field get_response_text fun(self:LLMAPI, data:string):string? Returns the text content of an API response.
---Returns delta_event,data
---where
---  data: the delta text (for delta_event "delta"), or the http body for other events.
---@async
---@field get_delta_text? fun(LLMAPI:LLMAPI, body:string):delta_event_type,string

local M = {}
M.__index = M

return M
