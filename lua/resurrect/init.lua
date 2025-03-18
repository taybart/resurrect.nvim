local M = {
  db = nil,
  config = {
    status_icon = '🪦',
    add_commands = true,
  },
}
local buffers = {}

local augroup_name = 'resurrect'

local function add(ev)
  if ev.match ~= nil then
    M.db:add(ev.match)
  end
end
local function del(ev)
  if ev.match ~= nil then
    M.db:del(ev.match)
  end
end

local function create_augroup()
  local id = vim.api.nvim_create_augroup(augroup_name, {})
  vim.api.nvim_create_autocmd('BufAdd', {
    group = id,
    callback = add,
  })
  vim.api.nvim_create_autocmd('BufDelete', {
    group = id,
    callback = del,
  })
end

local function start(fargs)
  local bufnums = vim.tbl_filter(function(buf)
    return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, 'buflisted')
  end, vim.api.nvim_list_bufs())
  M.db.new_session(fargs.fargs[1])

  for _, v in ipairs(bufnums) do
    local path = vim.api.nvim_buf_get_name(v)
    table.insert(buffers, path)
    M.db:add(path)
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
  M.db.load_session(function(session_name, files)
    for _, v in ipairs(files) do
      vim.cmd('e ' .. v.path)
    end

    vim.g.has_resurrect_sessions = M.config.status_icon .. ' ' .. session_name
    create_augroup()
  end)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts)

  M.db = require('resurrect/db').setup(M.config)

  if M.db.has_sessions() then
    vim.g.has_resurrect_sessions = M.config.status_icon
    vim.notify('there are resurrect sessions available')
  end

  if M.config.add_commands then
    vim.api.nvim_create_user_command('Resurrect', resurrect, { bang = true })
    vim.api.nvim_create_user_command('ResurrectStart', start, { nargs = '*' })
    vim.api.nvim_create_user_command('ResurrectStop', stop, {})
  end
end

return M
