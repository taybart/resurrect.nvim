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

return M
