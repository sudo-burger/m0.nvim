local M = {}

-- Util functions.

local function split_lines(str)
	local lines = {}
	for line in str:gmatch("([^\n]*)\n?") do
		table.insert(lines, line)
	end
	return lines
end

-- local namespace = vim.api.nvim_create_namespace("m")

function M.get_api_key(name)
	return vim.fn.system("echo -n $(pass " .. name .. ")")
end

-- Create an OpenAI completions handler.
--
function M.make_openai(params)
	return {
		run = function(messages)
			local url = params.url
			local headers = {
				"Content-Type: application/json",
				"Authorization: Bearer " .. params.api_key,
			}
			local prompt = {
				role = "system",
				content = params.prompt,
			}

			table.insert(messages, 1, prompt)

			local data = {
				model = params.model,
				max_tokens = params.max_tokens,
				temperature = params.temperature,
				messages = messages,
			}

			local cmd = "curl -s "
				.. vim.fn.shellescape(url)
				.. " -H "
				.. vim.fn.shellescape(headers[1])
				.. " -H "
				.. vim.fn.shellescape(headers[2])
				.. " -d "
				.. vim.fn.shellescape(vim.fn.json_encode(data))
			print(cmd)
			local response = vim.fn.system(cmd)
			return vim.fn.json_decode(response)
		end,
	}
end

local config = {
	["openai-0"] = {
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
}

-- Exported functions.
--
function M.chatgpt()
	local conversation = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local messages = {}
	local section_mark = "====="

	local i = 1
	local role = {
		"user",
		"assistant",
	}
	local role_idx = 1
	while i <= #conversation do
		-- Switch between roles.
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

	local chat = config.default_model
	local result = chat.run(messages)
	if result.error then
		vim.api.nvim_err_writeln("Error: " .. result.error.message)
	elseif result.choices then
		local reply = result.choices[1].message.content
		vim.api.nvim_buf_set_lines(0, -1, -1, false, { section_mark })
		vim.api.nvim_buf_set_lines(0, -1, -1, false, split_lines(reply))
		vim.api.nvim_buf_set_lines(0, -1, -1, false, { section_mark })
	else
		vim.api.nvim_err_writeln("Error: Unable to get response from OpenAI API")
	end
end

function m.setup(user_config)
	user_config = user_config or {}
	config.default_model = M.make_openai(config["openai-0"])
	config = vim.tbl_extend("force", config, user_config)
end

return M
