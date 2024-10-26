---@alias DeltaEventType
---| "cruft" # we received data we will not parse.
---| "delta" # we received a delta.
---| "done" # the call is done.
---| "error" # we received something we cannot parse.
---| "stats" # we received statistics.

---Abstract class for LLM APIs.
---@class M0.LLMAPI
---@field opts M0.BackendOptions
---Make the API request body.
---@field make_body fun(self:M0.LLMAPI, messages:string[]):table
---Make the API request headers.
---@field make_headers fun(self:M0.LLMAPI):table
---Rewrite the chat messages in API format.
---@field protected make_messages fun(self:M0.LLMAPI, messages:string[]):string[]
---Get the text content of a non-streaming API response.
---Returns:
---  success: boolean
---  data: the response text if successful, or an error string otherwise.
---  stats: stats if successful, otherwise nil.
---@field get_response_text fun(self:M0.LLMAPI, data:string):boolean,string,string?
---Extract a streaming response's content.
---
---Returns: delta event, response
---where response is the delta text (when delta event is "delta"), or an error string.
---@async
---@field get_delta_text fun(LLMAPI:M0.LLMAPI, body:string):DeltaEventType,string

---@type M0.LLMAPI
---@diagnostic disable-next-line: missing-fields
local M = {}
---@diagnostic disable-next-line: inject-field
M.__index = M

return M
