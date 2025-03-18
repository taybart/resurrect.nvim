local M = {}

function M.choose_session(opts, choices, cb)
  -- vim.print(opts.title, type(choices))
  if not package.loaded['telescope'] then
    vim.ui.select(choices, {
      prompt = 'Sessions',
      format_item = function(s)
        return s.name
      end,
    }, function(choice)
      cb(choice)
    end)
  end
  -- telescope
  local actions = require('telescope.actions')
  local finders = require('telescope.finders')
  local pickers = require('telescope.pickers')
  local action_state = require('telescope.actions.state')

  local choose = function(buf)
    actions.close(buf)
    local result = action_state.get_selected_entry().value
    vim.print(action_state.get_selected_entry())
    vim.schedule(function()
      cb(result)
    end)
  end

  pickers
    .new({}, {
      prompt_title = opts.title,
      finder = finders.new_table({
        results = assert(choices or 'No table provided'),
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.name:match('^([^:]*)'),
            ordinal = entry.name,
          }
        end,
      }),
      attach_mappings = function(buf, map)
        map('i', '<CR>', function()
          choose(buf)
        end)
        map('n', '<CR>', function()
          choose(buf)
        end)
        return true
      end,
    })
    :find()

  -- end telescope
end

function M.user_command(command_name, cmds)
  local function complete(arg_lead)
    local commands = {}
    for name in pairs(cmds) do
      if name ~= 'default' then
        table.insert(commands, name)
      end
    end
    vim.print(commands)

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

return M
