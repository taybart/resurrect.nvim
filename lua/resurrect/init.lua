local M = {}
local buffers = {}

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

local function enable()
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

local function restore()
  enable()
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

local function start_session()
  local bufnums = vim.tbl_filter(function(buf)
    return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, 'buflisted')
  end, vim.api.nvim_list_bufs())

  for _, v in ipairs(bufnums) do
    local path = vim.api.nvim_buf_get_name(v)
    file.add(path)
  end
  enable()
end

function M.setup()
  if vim.fn.filereadable('.resurrect') == 1 then
    enable()
  end
  vim.api.nvim_create_user_command('Resurrect', restore, {})
  vim.api.nvim_create_user_command('ResurrectStart', start_session, {})
end

return M
