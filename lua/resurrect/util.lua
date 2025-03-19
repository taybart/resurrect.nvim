local M = {}

function M.user_command(command_name, cmds)
  local function complete(arg_lead)
    local commands = {}
    for name in pairs(cmds) do
      if name ~= 'default' then
        table.insert(commands, name)
      end
    end
    local pattern = arg_lead:gsub('(.)', function(c)
      return string.format('%s[^%s]*', c:lower(), c:lower())
    end)
    -- Case-insensitive fuzzy matching
    local matches = {}
    for _, command in ipairs(commands) do
      if string.find(command:lower(), pattern) then
        table.insert(matches, command)
      end
    end
    return matches
  end
  vim.api.nvim_create_user_command(command_name, function(opts)
    local args = vim.split(opts.args, '%s+', { trimempty = true })
    -- Default
    if #args == 0 then
      cmds['default'](opts)
      return
    end

    local command = args[1]
    if cmds[command] == nil then
      print('unknown command:', command)
      return
    end

    table.remove(args, 1) -- Remove command
    if type(cmds[command]) == 'function' then
      cmds[command](opts)
    elseif cmds[command].basic then
      cmds[command].cb(args)
    else
      cmds[command].cb(opts)
    end
  end, {
    nargs = '*',
    bang = true,
    complete = complete,
  })
end

function M.file_exists(name)
  local f = io.open(name, 'r')
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

function M.open_files(files)
  local dead_files = {}
  for _, v in ipairs(files) do
    if M.file_exists(v.path) then
      vim.cmd('e ' .. v.path)
    else
      table.insert(dead_files, v)
    end
  end
  return dead_files
end

function M.close_files()
  vim.cmd('bufdo! bd!')
end

function M.extract_path_end(path, depth)
  local components = {}
  for part in path:gmatch('[^/]+') do
    table.insert(components, part)
  end

  local result = {}
  for i = math.max(1, #components - depth + 1), #components do
    table.insert(result, components[i])
  end

  return table.concat(result, '/')
end

function M.session_shortname(name)
  return name:match('^([^:]*)')
end

return M
