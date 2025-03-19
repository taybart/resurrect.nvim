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
local ui = require('resurrect/ui')

function M.setup(config)
  M.config = config
  M.db = sqlite({
    uri = M.config.db_path,
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
      row = 'integer',
      col = 'integer',
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
    vim.notify('found existing session', vim.log.levels.DEBUG)
    self.session.id = sessions[1].id
    self.session.name = sessions[1].name
    self.session.files = M:get_files(self.session)
    return false
  end
  local success, id = self.db:insert('sessions', { name = session_name })
  if not success then
    error('could not add new session')
  end
  self.session.id = id
  self.session.name = session_name
  return true
end

function M:has_sessions()
  local session_name = '%:' .. vim.fn.getcwd()
  local sessions = self.db:eval('select count(*) from sessions where name like ?', session_name)
  local count = sessions[1]['count(*)']
  self.session_count = count
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
      ui.choose_session(
        { title = 'Found sessions', preview_depth = self.config.preview_depth },
        sessions,
        function(s)
          arg(u.session_shortname(s.name), s)
        end
      )
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
  if type(sessions) == 'boolean' then
    vim.notify('no sessions', vim.log.levels.INFO)
    return
  end
  if #sessions == 1 and not self.config.always_choose then
    self.session.id = sessions[1].id
    cb(u.session_shortname(sessions[1].name), M:load())
    return
  end
  if #sessions > 0 then
    for _, s in ipairs(sessions) do
      s.files = M:get_files(s)
    end
    ui.choose_session(
      { title = 'Found sessions', preview_depth = self.config.preview_depth },
      sessions,
      function(s)
        self.session.id = s.id
        cb(u.session_shortname(s.name), M:load())
      end
    )
  end
end

function M:delete_session(id)
  if not self.db:delete('sessions', { where = { id = id } }) then
    error('could not delete resurrect session')
  end
end

function M:load()
  self.session.files = self.db:select('files', { where = { session_id = self.session.id } })
  if self.config.debug then
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
  self.db:insert('files', { path = filepath, session_id = self.session.id })
end

function M:update_file(update) -- TODO add cursor position
  if path ~= '' then
    self.db:update('files', {
      where = { session_id = self.session.id, path = update.path },
      set = { path = update.path, row = update.row, col = update.col, session_id = self.session.id },
    })
  end
end

function M:del_file(filepath)
  self.db:delete('files', { where = { path = filepath, session_id = self.session.id } })
end

return M
