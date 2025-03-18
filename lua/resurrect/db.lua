local M = {
  db = nil,
  session_count = 0,
  session = {
    id = nil,
    name = nil,
    files = {},
  },
  config = nil,
}

local sqlite = require('sqlite')
local u = require('resurrect/util')

function M.setup(config)
  M.config = config
  M.db = sqlite({
    uri = vim.fn.stdpath('data') .. '/resurrect.db',
    opts = {
      foreign_keys = true,
    },
    sessions = {
      id = true,
      created = { 'timestamp', default = sqlite.lib.strftime('%s', 'now') },
      name = { 'text', unique = true },
    },
    files = {
      id = true, -- shortcut to primary and integer
      path = 'text',
      session_id = { 'integer', reference = 'sessions.id', on_delete = 'cascade' },
    },
  })
  M.db:open()
  return M
end

function M:new_session(in_name)
  local name = in_name or 'default'
  local session_name = name .. ':' .. vim.fn.getcwd()
  local sessions = self.db:select('sessions', { where = { name = session_name } })
  if #sessions > 0 then
    vim.print('found existing', sessions[1].name)
    M.session.id = sessions[1].id
    M.session.name = sessions[1].name
    return
  end
  local success, id = self.db:insert('sessions', { name = session_name })
  if not success then
    error('could not add new session')
  end
  M.session.id = id
  M.session.name = session_name
  return M
end

function M:has_sessions()
  local session_name = '%:' .. vim.fn.getcwd()
  local sessions = self.db:eval('select count(*) from sessions where name like ?', session_name)
  local count = sessions[1]['count(*)']
  M.session_count = count
  return count > 0
end

function M:get_session(arg)
  if type(arg) == 'function' then
    local session_name = '%:' .. vim.fn.getcwd()
    local sessions = self.db:eval('select * from sessions where name like ?', session_name)
    if #sessions > 0 then
      for _, s in ipairs(sessions) do
        s.files = M:get_files(s)
      end
      u.choose_session({ title = 'Found sessions' }, sessions, function(s)
        arg(s.name:match('^([^:]*)'), s)
      end)
    end
  end
  if type(arg) == 'string' then
    local session = self.db:select('sessions', { where = { name = arg .. ':' .. vim.fn.getcwd() } })
    return session
  end
end

function M:load_session(cb)
  local session_name = '%:' .. vim.fn.getcwd()
  local sessions = self.db:eval('select * from sessions where name like ?', session_name)
  if #sessions == 1 then
    M.id = sessions[1].id
    cb(sessions[1].name:match('^([^:]*)'), M:load())
    return
  end
  if #sessions > 0 then
    for _, s in ipairs(sessions) do
      s.files = M:get_files(s)
    end
    u.choose_session({ title = 'Found sessions' }, sessions, function(s)
      M.id = s.id
      cb(s.name:match('^([^:]*)'), M:load())
    end)
  end
end

function M:delete_session(id)
  if not self.db:delete('sessions', { where = { id = id } }) then
    error('could not delete resurrect session')
  end
end

function M:load()
  self.session.files = self.db:select('files', { where = { session_id = self.id } })
  if M.config.debug then
    vim.print(self.session.files)
  end
  return self.session.files
end

function M:get_files(session)
  local files = self.db:select('files', { where = { session_id = session.id } })
  -- vim.print(files)
  return files
end

function M:add_file(filepath) -- TODO add cursor position
  self.db:insert('files', { path = filepath, session_id = M.session.id })
end

function M:del_file(filepath)
  self.db:delete('files', { path = filepath, session_id = M.session.id })
end

return M
