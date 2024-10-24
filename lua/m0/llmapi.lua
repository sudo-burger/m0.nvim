---@alias DeltaEventType
---| "cruft" # we received data we will not parse.
---| "delta" # we received a delta.
---| "done" # the call is done.
---| "error" # we received something we cannot parse.
---| "stats" # we received statistics.

---Abstract class for LLM APIs.
---@class M0.LLMAPI
---@field opts M0.BackendOptions
---@field make_body fun(self:M0.LLMAPI, messages:string[]):table Make the API request body.
---@field make_headers fun(self:M0.LLMAPI):table Make the API request headers.
---@field get_messages fun(self:M0.LLMAPI, messages:string[]):string[] Get the chat messages in API format.
---@field get_response_text fun(self:M0.LLMAPI, data:string):boolean,string?,string? Get the text content of an API response.
---Returns delta_event,data
---where
---  data: the delta text (for delta_event "delta"), or the http body for other events.
---@async
---@field get_delta_text fun(LLMAPI:M0.LLMAPI, body:string):DeltaEventType,string

---@type M0.LLMAPI
---@diagnostic disable-next-line: missing-fields
local M = {}
---@diagnostic disable-next-line: inject-field
M.__index = M

return M
