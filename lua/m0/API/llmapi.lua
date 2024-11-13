---@alias DeltaEventType
---| "cruft" # we received data we will not parse.
---| "delta" # we received a delta.
---| "done" # the call is done.
---| "error" # we received something we cannot parse.
---| "stats" # we received statistics.

---Abstract class for LLM APIs.
---@class M0.API.LLMAPI
---@field opts M0.BackendOptions
---@field error? string For the error object.
---Make the API request body.
---@field make_body fun(self:M0.API.LLMAPI, messages:string[]):table
---Make the API request headers.
---@field make_headers fun(self:M0.API.LLMAPI):table
---Rewrite the chat messages in API format.
---@field protected make_messages fun(self:M0.API.LLMAPI, messages:string[]):string[]
---Get the text content of a non-streaming API response.
---Returns:
---  success: boolean
---  data: the response text if successful, or an error string otherwise.
---  stats: stats if successful, otherwise nil.
---@field get_response_text fun(self:M0.API.LLMAPI, data:string):boolean,string,string?
---Extract a streaming response's content.
---
---@async
---@field stream fun(LLMAPI:M0.API.LLMAPI, data:string, opts:table):boolean,string?

---@type M0.API.LLMAPI
---@diagnostic disable-next-line: missing-fields
local M = {}
---@diagnostic disable-next-line: inject-field
M.__index = M

return M
