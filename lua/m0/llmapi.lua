require 'm0.message'

---@alias DeltaEventType
---| "delta" # the server sent a text delta
---| "cruft" # the server sent data we consider to be cruft
---| "done" # the server signaled that the text transfer is done.
---| "other" # we received something we cannot interpret.

---Abstract class for LLM APIs.
---@class LLMAPI
---@field opts? BackendOptions
---@field make_body? fun(self:LLMAPI):table Make the API request body.
---@field make_headers? fun(self:LLMAPI):table Make the API request headers.
---@field get_messages? fun(self:LLMAPI, messages:RawMessage[]):RawMessage[] get the chat messages.
---@field get_response_text? fun(self:LLMAPI, data:string):string? Returns the text content of an API response.
---Returns delta_event,data
---where
---  data: the delta text (for delta_event "delta"), or the http body for other events.
---@async
---@field get_delta_text? fun(LLMAPI:LLMAPI, body:string):DeltaEventType,string

---@type LLMAPI
local M = {}
M.__index = M

return M
