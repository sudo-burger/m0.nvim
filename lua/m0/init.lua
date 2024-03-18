local M = {}
Current_backend = ""

-- Util functions.
function M.get_api_key(name)
	return vim.fn.system("echo -n $(pass " .. name .. ")")
end

-- Create an Anthropic handler.
--
local function make_backend(backend, params)
	if backend == nil or params == nil then
		Print("No configuration. Bailing out.")
		return {}
	end
	return {
		run = function(messages)
			local data = {
				model = params.model,
				max_tokens = params.max_tokens,
				temperature = params.temperature,
				messages = messages,
			}
			local auth_param = ""

			if backend == "anthropic" then
				auth_param = "x-api-key: " .. (params.api_key or "")
				data.system = params.prompt or ""
			elseif backend == "openai" then
				auth_param = "Authorization: Bearer " .. (params.api_key or "")
				local prompt = {
					role = "system",
					content = params.prompt or "",
				}
				table.insert(messages, 1, prompt)
			else
				print("Unknown backend: " .. backend)
				return {}
			end

			local cmd = "curl -s "
				.. vim.fn.shellescape(params.url or "https://example.com")
				.. " -d "
				.. vim.fn.shellescape(vim.fn.json_encode(data))
				.. " -H "
				.. vim.fn.shellescape("Content-Type: application/json")
				.. " -H "
				.. vim.fn.shellescape(auth_param)

			if backend == "anthropic" then
				cmd = cmd
					.. " -H "
					.. vim.fn.shellescape("anthropic-version: " .. (params.anthropic_version or "2023-06-01"))
			end

			print(cmd)
			local response = vim.fn.system(cmd)
			local json_response = vim.fn.json_decode(response)

			local ret = {}
			if backend == "anthropic" then
				ret = {
					error = json_response.error,
					reply = (json_response.content[1].text or ""),
				}
			elseif backend == "openai" then
				ret = {
					error = json_response.error,
					reply = (json_response.choices[1].message.content or ""),
				}
			end
			return ret
		end,
	}
end

function M.make_openai(params)
	return make_backend("openai", params)
end

function M.make_anthropic(params)
	return make_backend("anthropic", params)
end

local config = {
	backends = {
		["openai-0"] = {
			type = "openai",
			url = "https://api.openai.com/v1/chat/completions",
			api_key = M.get_api_key("api.openai.com/key-0"),
			model = "gpt-3.5-turbo",
			max_tokens = 100,
			temperature = 0.7,
			prompt = "You are literally "
				.. "Charles Bukowski."
				.. " You wash dishes every day; dirty dishes, half-clean dishes. "
				.. "Dishes of the poor, dishes of the privileged.",
		},
		["anthropic-0"] = {
			type = "anthropic",
			url = "https://api.anthropic.com/v1/messages",
			api_key = M.get_api_key("api.anthropic.com/key-0"),
			anthropic_version = "2023-06-01",
			-- model = "claude-3-opus-20240229",
			model = "claude-3-haiku-20240307",
			max_tokens = 100,
			temperature = 0.7,
			prompt = "You are literally Marilyn Monroe.",
		},
	},
	default_backend = "anthropic-0",
}

-- Exported functions.
--
function M.M0chat(backend)
	local conversation = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local messages = {}
	local section_mark = "====="
	Current_backend = (backend or Current_backend)

	local i = 1
	local role = {
		"user",
		"assistant",
	}
	local role_idx = 1
	while i <= #conversation do
		-- Switch between roles when meeting a section mark in the conversattion.
		if conversation[i]:sub(1, 5) == section_mark then
			i = i + 1
			if role_idx == 1 then
				role_idx = 2
			else
				role_idx = 1
			end
		end

		local message = { role = role[role_idx], content = "" }

		while i <= #conversation and conversation[i]:sub(1, 5) ~= section_mark do
			message.content = message.content .. conversation[i] .. "\n"
			i = i + 1
		end

		table.insert(messages, message)
	end

	print("Current_backend: " .. Current_backend)
	local chat = make_backend(config.backends[Current_backend].type, config.backends[Current_backend])
	local result = chat.run(messages)
	if result.error then
		vim.api.nvim_err_writeln("Error: " .. result.error.message)
	elseif result.reply then
		-- Build and print the reply in the current buffer.
		-- The reply is enclosed in "section_marks".
		-- The section marks are also used to distinguish between
		-- user and assistant input when building the API calls.
		vim.api.nvim_buf_set_lines(0, -1, -1, false, { section_mark })
		vim.api.nvim_buf_set_lines(0, -1, -1, false, vim.fn.split(result.reply, "\n"))
		vim.api.nvim_buf_set_lines(0, -1, -1, false, { section_mark })
	else
		vim.api.nvim_err_writeln("Error: Unable to get response.")
	end
end

function M.setup(user_config)
	user_config = user_config or {}
	config = vim.tbl_extend("force", config, user_config)
	Current_backend = config.default_backend
	if config.backends[Current_backend] == nil then
		error("Current_backend (" .. Current_backend .. ") set to non-existing configuration.", 2)
	end
end

vim.api.nvim_create_user_command("M0chat", function(opts)
	M.M0chat(opts.args)
end, {
	nargs = 1,
	complete = function()
		local ret = {}
		for k, _ in pairs(config.backends) do
			table.insert(ret, k)
		end
		return ret
	end,
})

return M
