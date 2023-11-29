local M = {}
local buffers = {}

local augroup_name = 'resurrect'

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

local function create_augroup()
  vim.api.nvim_create_augroup(augroup_name, {})
  vim.api.nvim_create_autocmd('BufAdd', {
    group = augroup_name,
    callback = add,
  })
  vim.api.nvim_create_autocmd('BufDelete', {
    group = augroup_name,
    callback = del,
  })
end

local function start()
  local bufnums = vim.tbl_filter(function(buf)
    return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, 'buflisted')
  end, vim.api.nvim_list_bufs())

  for _, v in ipairs(bufnums) do
    local path = vim.api.nvim_buf_get_name(v)
    table.insert(buffers, path)
    file.add(path)
  end
  create_augroup()
end

local function stop()
  vim.api.nvim_del_augroup_by_name(augroup_name)
end

local function resurrect(fargs)
  if fargs.bang then
    stop()
    return
  end

  create_augroup()
  local bfs = file.load_buffers()
  if bfs == nil then
    return
  end
  buffers = bfs
  os.remove('.resurrect')
  for _, v in ipairs(buffers) do
    vim.cmd('e ' .. v)
  end
end

function M.setup()
  if vim.fn.filereadable('.resurrect') == 1 then
    create_augroup()
  end
  vim.api.nvim_create_user_command('Resurrect', resurrect, { bang = true })
  vim.api.nvim_create_user_command('ResurrectStart', start, {})
end

return M
