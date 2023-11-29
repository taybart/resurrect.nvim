local M = {}
local buffers = {}

M.enabled = false

local file = require('resurrect.file')

local function add(ev)
  if ev.match ~= nil then
    table.insert(buffers, ev.match)
    file.add(ev.match)
  end
end

local function del(ev)
  local path = ev.match
  for i, v in ipairs(buffers) do
    if v == path then
      table.remove(buffers, i)
      file.del(path)
      break
    end
  end
end

local function restore()
  M.enable()
  local bfs = file.load_buffers()
  if bfs == nil then
    return
  end
  buffers = bfs
  os.remove('./.resurrect')
  for _, v in ipairs(buffers) do
    vim.cmd('e ' .. v)
  end
end

function M.enable()
  M.enabled = true

  local group_name = 'resurrect'
  vim.api.nvim_create_augroup(group_name, {})
  -- vim.api.nvim_create_autocmd('UIEnter', {
  --   group = group_name,
  --   callback = load_buffers,
  -- })
  vim.api.nvim_create_autocmd('BufAdd', {
    group = group_name,
    callback = add,
  })
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group_name,
    callback = del,
  })
end

function M.setup(config)
  local cfg = config or {}

  if cfg.auto_enable then
    M.enable()
  end
  vim.api.nvim_create_user_command('ResurrectEnable', M.enable, {})
  vim.api.nvim_create_user_command('Resurrect', restore, {})
end

return M
