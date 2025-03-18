local M = {}

function M.choose_session(opts, choices, cb)
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
  local previewers = require('telescope.previewers')

  local choose = function(buf)
    actions.close(buf)
    local result = action_state.get_selected_entry().value
    vim.print(action_state.get_selected_entry())
    vim.schedule(function()
      cb(result)
    end)
  end
  local file_list_previewer = previewers.new_buffer_previewer({
    title = 'Session Files',
    define_preview = function(self, entry, status)
      -- Clear the buffer
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {})

      -- Add a title
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { entry.display .. ':', '' })

      if #entry.files == 0 then
        return
      end
      -- Add each file in the list to the preview buffer
      local line_count = 2
      for i, f in ipairs(entry.files) do
        vim.api.nvim_buf_set_lines(
          self.state.bufnr,
          line_count,
          line_count,
          false,
          { '- ' .. M.extract_path_end(f.path, opts.preview_depth or 4) }
        )
        line_count = line_count + 1
      end
    end,
  })

  pickers
    .new({
      layout_config = {
        width = 0.8,
        preview_width = 0.75,
        preview_cutoff = 1,
      },
    }, {
      prompt_title = opts.title,
      finder = finders.new_table({
        results = assert(choices or 'No table provided'),
        entry_maker = function(entry)
          return {
            value = entry,
            -- display = entry.name:match('^([^:]*)') .. ' → [' .. files_str .. ']',
            display = entry.name:match('^([^:]*)'),
            ordinal = entry.name,
            files = entry.files,
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
      previewer = file_list_previewer,
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
