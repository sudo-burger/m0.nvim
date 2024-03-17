local api_key = vim.fn.system("echo -n $(pass api.openai.com/key-0)")
local model = "gpt-3.5-turbo"

local function chatgpt()
	local conversation = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local prompt = table.concat(conversation, "\n")

	local url = "https://api.openai.com/v1/chat/completions"
	local headers = {
		"Content-Type: application/json",
		"Authorization: Bearer " .. api_key,
	}
	local data = {
		model = model,
		max_tokens = 100,
		temperature = 0.7,
		messages = {
			{ role = "user", content = prompt },
		},
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
		vim.api.nvim_buf_set_lines(0, -1, -1, false, { reply })
	else
		vim.api.nvim_err_writeln("Error: Unable to get response from OpenAI API")
	end
end

return {
	chatgpt = chatgpt,
}
