local M = {}

function M.current_branch()
  local current_branch = vim.fn.system('git branch --show-current')
  return current_branch:gsub('\n', '')
end

function M.watch_branch(cb)
  local branch_timer = vim.loop.new_timer()
  local current_branch = M.current_branch()
  branch_timer:start(
    0,
    1000,
    vim.schedule_wrap(function()
      local new_branch = M.current_branch()
      if new_branch ~= current_branch then
        cb({ current = current_branch, new = new_branch })
        current_branch = new_branch
      end
    end)
  )
end

return M
