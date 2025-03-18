local M = {}

function M.current_branch()
  local current_branch = vim.fn.system('git branch --show-current')
  return current_branch:gsub('\n', '')
end

function M.watch_branch()
  local branch_timer = vim.loop.new_timer()
  local current_branch = M.current_branch()
  branch_timer:start(
    0,
    1000,
    vim.schedule_wrap(function()
      local new_branch = M.current_branch()
      if new_branch ~= current_branch then
        print('Git branch changed from ' .. current_branch .. ' to ' .. new_branch)
        current_branch = new_branch
        -- Trigger your actions here (refresh buffers, update UI, etc.)
      end
    end)
  )
end

return M
