local M = {}

local function open_file(perm)
  local file = io.open('.resurrect', perm)
  if file == nil then
    error('could not open resurrection file')
    return
  end
  return file
end

function M.load_buffers()
  local buffers = {}
  local file = open_file('r')
  if file == nil then
    return
  end
  for c in file:lines() do
    table.insert(buffers, c)
  end
  return buffers
end

function M.del(path)
  local file = open_file('r')
  if file == nil then
    return
  end
  local ct = file:read('a')
  file:close()

  os.remove('.resurrect')

  file = open_file('w')
  if file == nil then
    return
  end
  for c in ct:gmatch('[^\r\n]+') do
    if c ~= path then
      file:write(c .. '\n')
    end
  end
  file:flush()
  file:close()
end

function M.add(path)
  local file = open_file('a')
  if file == nil then
    return
  end
  file:write(path .. '\n')
  file:flush()
  file:close()
end

return M
