local M = {
  db = nil,
  active_session = nil,
  augroup_name = 'resurrect',
  config = {
    status_icon = '🪦',
    status_icon_active = '📓',
    add_command = true,
    always_choose = false, -- show picker even if one session exists
    quiet = false,
    preview_depth = 4,
    db_path = vim.fn.stdpath('data') .. '/resurrect.db',
    ignore = { '^term://', '^fugitive://' },
    -- hidden
    debug = false,
  },
}

local git = require('resurrect/git')
local u = require('resurrect/util')
local ui = require('resurrect/ui')

local function add(ev)
  if ev.match ~= nil and ev.match ~= '' then
    for _, m in ipairs(M.config.ignore) do
      if ev.match:match(m) ~= nil then
        return
      end
    end
    M.db:add_file(ev.match)
  end
end
local function del(ev)
  if ev.match ~= nil and ev.match ~= '' then
    M.db:del_file(ev.match)
  end
end

local function update_cursor(ev)
  if ev.match ~= nil then
    local cursor = vim.api.nvim_win_get_cursor(0)
    M.db:update_file({ path = ev.match, row = cursor[1], col = cursor[2] })
  end
end

local function create_augroup()
  local id = vim.api.nvim_create_augroup(M.augroup_name, {})
  vim.api.nvim_create_autocmd('BufAdd', {
    group = id,
    callback = add,
  })
  vim.api.nvim_create_autocmd('BufDelete', {
    group = id,
    callback = del,
  })
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = id,
    callback = update_cursor,
  })
end

local function set_status()
  if M.active_session then
    vim.g.has_resurrect_sessions = M.config.status_icon_active .. ' ' .. M.active_session
  elseif M.db:has_sessions() then
    vim.g.has_resurrect_sessions = M.config.status_icon
  else
    vim.g.has_resurrect_sessions = ''
  end
end

local function stop()
  M.active_session = nil
  vim.api.nvim_del_augroup_by_name(M.augroup_name)
end

local function start(args)
  if M.active_session then
    vim.notify('current session (' .. M.active_session .. ') still active', vim.log.levels.ERROR)
    return
  end
  local bufnums = vim.tbl_filter(vim.api.nvim_buf_is_valid, vim.api.nvim_list_bufs())
  local session_name = args[1] or 'default'
  if not M.db:new_session(session_name) then
    local dead_files = u.open_files(M.db.session.files)
    if #dead_files > 0 then
      vim.print(dead_files)
      vim.notify('there are ' .. #dead_files .. ' missing files in session', vim.log.levels.WARNING)
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
          vim.notify('adding new file ' .. path .. ' to session', vim.log.levels.INFO)
        end
        M.db:add_file(path)
      end
    end
  end

  M.active_session = session_name
  create_augroup()
  set_status()
end

local function start_git(args)
  if M.active_session then
    vim.notify('current session (' .. M.active_session .. ') still active', vim.log.levels.ERROR)
    return
  end

  local session_name = git.current_branch()
  if args[1] then
    session_name = session_name .. '@' .. args[1]
  end

  -- TODO: is a timer the best way to do this?
  git.watch_branch(function(branches)
    ui.confirmation({
      prompt = ('Git branch changed %s -> %s, switch? [y/N]'):format(
        branches.current,
        branches.new
      ),
      callback = function(yes)
        if yes then
          if M.active_session then
            stop()
          end
          u.close_files() -- FIXME: this leaves an empty buffer sometimes
          start({ branches.new })
        end
      end,
    })
  end)
  start({ session_name })
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
    vim.notify('current session (' .. M.active_session .. ') still active', vim.log.levels.ERROR)
    return
  end
  M.db:load_session(function(session_name, files)
    local dead_files = u.open_files(files)
    if #dead_files > 0 then
      vim.print(dead_files)
      vim.notify('there are ' .. #dead_files .. ' missing files in session', vim.log.levels.WARNING)
    end

    create_augroup()
    M.active_session = session_name
    set_status()
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
    set_status()
    return
  end
  M.db:get_session(function(name, s)
    ui.confirmation({
      prompt = ("You want to delete session '%s'? [y/N]"):format(name),
      callback = function(yes)
        if yes then
          if M.active_session == name then
            stop()
          end
          M.db:delete_session(s.id)
          set_status()
        end
      end,
    })
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
      git = { cb = start_git, basic = true },
      stop = stop,
      list = list,
      delete = { cb = delete_session, basic = true },
    })
  end
end

return M
