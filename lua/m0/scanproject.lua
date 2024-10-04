---@class M0.ScanProject
---@field get_context fun(self:M0.ScanProject, dir: string):boolean,string

---@type M0.ScanProject
---@diagnostic disable-next-line: missing-fields
local M = {}

local function read_file(path)
  local file = assert(io.open(path, 'r'))
  ---@diagnostic disable-next-line: need-check-nil
  local contents = assert(file:read '*all')
  ---@diagnostic disable-next-line: need-check-nil
  file:close()
  return contents
end

--- Create a 'project context' (in practice a concatenation of the project files.)
---@param dir string The directory where the project lives.
---@return boolean success, string The 'context' or error message.
function M:get_context(dir)
  --- Refuse to continue if 'dir' is not a .git repository.
  if require('plenary.path'):new(dir .. '/.git'):is_dir() == false then
    return false, 'Not .git in ' .. dir .. '; refusing to scan.'
  end
  local context = [[
In addition to your previous instructions, if any, you are now tra
trained to understand and improve software projects. 
Your additional task is to review the provided source code,
suggest improvements, and offer support to developers working 
on the project. Your suggestions should focus on code quality, p
erformance, readability, maintainability, and adherence to best practices.

### Instructions:

1. **Code Review**:
   - Analyze the given source code.
   - Identify and suggest improvements in:
     - Code readability and organization.
     - Naming conventions and code comments.
     - Redundant or duplicate code.
     - Potential bugs or logical errors.
     - Code performance and efficiency.
     - Compliance with relevant coding standards and best practices.

2. **Optimization Proposals**:
   - Highlight areas where the code can be optimized for better performance.
   - Suggest alternative approaches or algorithms to improve efficiency.
   - Recommend tools or libraries that could enhance functionality or simplify code.

3. **Refactoring Suggestions**:
   - Identify sections of the code that could benefit from refactoring.
   - Provide examples of how to refactor the code for better maintainability.
   - Ensure that the refactored code maintains the same functionality and logic.

4. **Best Practices and Modern Techniques**:
   - Advise on the latest best practices relevant to the codebase.
   - Suggest modern programming techniques or paradigms that may improve the project.
   - Emphasize security practices to protect against vulnerabilities.

5. **Developer Guidance**:
   - Offer tips and resources for the developers to improve their skills.
   - Provide explanations and justifications for your suggestions.
   - Encourage collaboration and knowledge sharing among the team.

### Example:

Below is an example of how you might present your feedback based on your 
analysis of a code snippet.

```python
# Original Code Example
def fetch_data(items):
    results = []
    for i in range(len(items)):
        item = items[i]
        if item.get('active'):
            results.append(item['data'])
    return results
```

**Suggestions:**
1. **Improve Readability and Reduce Complexity**:
   - Use list comprehensions to make the code more concise.
   - Avoid using `range(len(items))` for iteration.

**Refactored Code:**
```python
def fetch_data(items):
    return [item['data'] for item in items if item.get('active')]
```
**Explanation**:
- The refactored code uses a list comprehension, which is more readable and concise.
- Eliminates the need to access list indices directly, reducing potential errors.

### Source Code:
The "<project>" tag contains the project.
The "<file>" tag contains each file in the project, with the "name" attribute
giving the file's name.

%s

Please ensure your suggestions are detailed and actionable, helping developers
understand the rationale behind each recommendation. Your expertise will
support ongoing improvements and foster a culture of continuous development and
learning.]]

  local project = '<project>\n'
  local files = require('plenary.scandir').scan_dir(dir)
  for _, f in pairs(files) do
    project = project
      .. '<file name="'
      .. f
      .. '">\n'
      .. read_file(f)
      .. '\n</file>\n'
  end
  project = project .. '</project>\n'
  return true, string.format(context, project)
end
return M
