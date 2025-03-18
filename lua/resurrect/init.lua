local M = {
  db = nil,
  active_session = nil,
  config = {
    status_icon = '🪦',
    add_command = true,
    always_choose = true, -- show picker even if one session exists
    quiet = false,
    preview_depth = 4,
    db_path = vim.fn.stdpath('data') .. '/resurrect.db',
    -- hidden
    debug = false,
  },
}

local augroup_name = 'resurrect'
local u = require('resurrect/util')

local function add(ev)
  if ev.match ~= nil then
    M.db:add_file(ev.match)
  end
end
local function del(ev)
  if ev.match ~= nil then
    M.db:del_file(ev.match)
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

local function start(args)
  if M.active_session then
    vim.print('current session (' .. M.active_session .. ') still active')
    return
  end
  local bufnums = vim.tbl_filter(function(buf)
    return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, 'buflisted')
  end, vim.api.nvim_list_bufs())
  local session_name = args[1] or 'default'
  if not M.db:new_session(session_name) then
    local dead_files = u.open_files(M.db.session.files)
    if #dead_files > 0 then
      vim.print(dead_files)
      vim.print('WARNING: there are ' .. #dead_files .. ' missing files in session')
    end
  end

  for _, v in ipairs(bufnums) do
    local path = vim.api.nvim_buf_get_name(v)
    if path ~= '' then
      local should_add = true
      for _, f in ipairs(M.db.session.files) do
        if f.path == path then
          should_add = false
        end
      end
      if should_add then
        if M.config.debug then
          print('adding new file ' .. path .. ' to session')
        end
        M.db:add_file(path)
      end
    end
  end

  create_augroup()
  vim.g.has_resurrect_sessions = M.config.status_icon .. ' ' .. session_name
  M.active_session = session_name
end

local function stop()
  M.active_session = nil
  vim.api.nvim_del_augroup_by_name(augroup_name)
end

local function list()
  M.db:get_session(function() end)
end

local function resurrect(fargs)
  if fargs.bang then
    stop()
    return
  end
  if M.active_session then
    vim.print('current session (' .. M.active_session .. ') still active')
    return
  end
  M.db:load_session(function(session_name, files)
    local dead_files = u.open_files(files)
    if #dead_files > 0 then
      vim.print(dead_files)
      vim.print('WARNING: there are ' .. #dead_files .. ' missing files in session')
    end

    create_augroup()
    vim.g.has_resurrect_sessions = M.config.status_icon .. ' ' .. session_name
    M.active_session = session_name
  end)
end

local function delete_session(arg)
  if #arg > 0 then
    local s = M.db:get_session(arg[1])
    if M.config.debug then
      vim.print(s)
    end
    if M.active_session == u.session_shortname(s.name) then
      stop()
    end
    M.db:delete_session(s.id)
    if M.db:has_sessions() then
      vim.g.has_resurrect_sessions = M.config.status_icon
    else
      vim.g.has_resurrect_sessions = ''
    end
    return
  end
  M.db:get_session(function(name, s)
    vim.ui.select({ 'no', 'yes' }, {
      prompt = "You want to delete session '" .. name .. "'?",
    }, function(input)
      if input == 'yes' then
        if M.active_session == name then
          stop()
        end
        M.db:delete_session(s.id)

        if M.db:has_sessions() then
          vim.g.has_resurrect_sessions = M.config.status_icon
        else
          vim.g.has_resurrect_sessions = ''
        end
      end
    end)
  end)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts)

  M.db = require('resurrect/db').setup(M.config)

  if M.db:has_sessions() then
    vim.g.has_resurrect_sessions = M.config.status_icon
    if not M.config.quiet then
      vim.notify('there are resurrect sessions available')
    end
  end

  if M.config.add_command then
    u.user_command('Resurrect', {
      default = resurrect,
      start = { cb = start, basic = true },
      stop = stop,
      list = list,
      delete = { cb = delete_session, basic = true },
    })
  end
end

return M
