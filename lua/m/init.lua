local api_key = vim.fn.system("echo -n $(pass api.openai.com/key-0)")
local model = "gpt-3.5-turbo"
local config = {
	["openai-0"] = {
		api_key = "",
		url = "https://api.openai.com/v1/chat/completions",
		model = "gpt-3.5-turbo",
		max_tokens = 100,
		temperature = 0.7,
		prompt = "You are literally "
			.. "Charles Bukowski."
			.. " You wash dishes every day; dirty dishes, half-clean dishes. "
			.. "Dishes of the poor, dishes of the privileged.",
	},
}


local function chatgpt()
	local conversation = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local messages = {}

	local i = 1
	while i <= #conversation do
		if conversation[i]:sub(1, 5) == "User:" then
			local user_message = { role = "user", content = "" }
			i = i + 1
			while i <= #conversation and conversation[i]:sub(1, 10) ~= "Assistant:" do
				user_message.content = user_message.content .. conversation[i] .. "\n"
				i = i + 1
			end
			messages[#messages + 1] = user_message
		elseif conversation[i]:sub(1, 10) == "Assistant:" then
			local assistant_message = { role = "assistant", content = "" }
			i = i + 1
			while i <= #conversation and conversation[i]:sub(1, 5) ~= "User:" do
				assistant_message.content = assistant_message.content .. conversation[i] .. "\n"
				i = i + 1
			end
			messages[#messages + 1] = assistant_message
		else
			i = i + 1
		end
	end

	local url = "https://api.openai.com/v1/chat/completions"
	local headers = {
		"Content-Type: application/json",
		"Authorization: Bearer " .. api_key,
	}
	local data = {
		model = model,
		max_tokens = 100,
		temperature = 0.7,
		messages = messages,
	}

	local cmd = "curl -s '"
		.. url
		.. "' -H '"
		.. headers[1]
		.. "' -H '"
		.. headers[2]
		.. "' -d '"
		.. vim.fn.json_encode(data)
		.. "'"
	print(cmd)
	local response = vim.fn.system(cmd)
	local result = vim.fn.json_decode(response)
	if result then
		local reply = result.choices[1].message.content
		vim.api.nvim_buf_set_lines(0, -1, -1, false, { "Assistant:" })
		vim.api.nvim_buf_set_lines(0, -1, -1, false, { reply })
	else
		vim.api.nvim_err_writeln("Error: Unable to get response from OpenAI API")
	end
end

local function setup(user_config)
	config = vim.tbl_extend("force", config, user_config)
end

return {
	chatgpt = chatgpt,
	setup = setup,
}
