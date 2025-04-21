local M = {}

local u = require('resurrect/util')

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
      for _, f in ipairs(entry.files) do
        vim.api.nvim_buf_set_lines(
          self.state.bufnr,
          line_count,
          line_count,
          false,
          { '- ' .. u.extract_path_end(f.path, opts.preview_depth or 4) }
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

function M.confirmation(opts)
  local prompt = opts.prompt or '? [y/N]'

  if opts.default == nil then
    opts.default = false
  end

  -- Get dimensions
  local width = #prompt + 4 -- Add some padding
  local height = 3

  -- Calculate position (center of screen)
  local lines = vim.o.lines
  local columns = vim.o.columns
  local row = math.floor((lines - height) / 2)
  local col = math.floor((columns - width) / 2)

  -- Create the buffer for our floating window
  local buf = vim.api.nvim_create_buf(false, true)

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    string.rep(' ', width), -- Empty padding line
    '  ' .. prompt, -- Prompt with padding
    string.rep(' ', width), -- Empty padding line
  })
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

  -- Create the floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Confirm ',
    title_pos = 'center',
  })

  -- Set up keymaps
  local maps = { ['y'] = true, ['n'] = true, ['<esc>'] = false, ['<enter>'] = opts.default }
  for k, v in pairs(maps) do
    vim.keymap.set('n', k, function()
      vim.api.nvim_win_close(win, true)
      if opts.callback then
        opts.callback(v)
      end
    end, { noremap = true, silent = true, buffer = buf })
  end

  -- Return focus to the window
  vim.api.nvim_set_current_win(win)
end

return M
