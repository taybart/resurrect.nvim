---@class db
---@field db sqlite_db|nil
local M = {
  db = nil,
  session_count = 0,
  session = {
    id = nil,
    name = nil,
    files = {},
  },
  config = {
    db_path = "",
  },
}

function M.setup(config)
  local sqlite = require("sqlite")

  M.config = config

  M.db = sqlite({
    uri = M.config.db_path,
    opts = {
      foreign_keys = true,
    },
    sessions = {
      id = true,
      created = { "timestamp", default = sqlite.lib.strftime("%s", "now") },
      name = { "text", unique = true },
    },
    files = {
      id = true,
      path = "text",
      session_id = { "integer", reference = "sessions.id", on_delete = "cascade" },
      row = "integer",
      col = "integer",
    },
  })
  ---@diagnostic disable-next-line: missing-parameter
  M.db:open()
  return M
end

function M:new_session(in_name)
  local name = in_name or "default"
  local session_name = name .. ":" .. vim.fn.getcwd()
  ---@diagnostic disable-next-line: missing-fields
  local sessions = self.db:select("sessions", { where = { name = session_name } })
  if #sessions > 0 then
    vim.notify("found existing session", vim.log.levels.DEBUG)
    self.session.id = sessions[1].id
    self.session.name = sessions[1].name
    self.session.files = M:get_files(self.session)
    return false
  end
  local success, id = self.db:insert("sessions", { name = session_name })
  if not success then
    error("could not add new session")
  end
  self.session.id = id
  self.session.name = session_name
  return true
end

function M:has_sessions()
  local session_name = "%:" .. vim.fn.getcwd()
  local sessions = self.db:eval("select count(*) from sessions where name like ?", { session_name })
  local count = sessions[1]["count(*)"]
  self.session_count = count
  return count > 0
end

function M:get_session(arg)
  if type(arg) == "function" then
    local session_name = "%:" .. vim.fn.getcwd()
    local sessions = self.db:eval("select * from sessions where name like ?", { session_name })
    if type(sessions) == "table" and #sessions > 0 then
      for _, s in ipairs(sessions) do
        s.files = M:get_files(s)
      end
      require("resurrect/ui").choose_session(sessions, function(s)
        arg(require("resurrect/util").session_shortname(s.name), s)
      end)
    end
  end
  if type(arg) == "string" then
    ---@diagnostic disable-next-line: missing-fields
    local session = self.db:select("sessions", { where = { name = arg .. ":" .. vim.fn.getcwd() } })
    return session
  end
end

function M:load_session(cb)
  local session_name = "%:" .. vim.fn.getcwd()
  local sessions = self.db:eval("select * from sessions where name like ?", { session_name })
  if type(sessions) == "boolean" then
    vim.notify("no sessions", vim.log.levels.INFO)
    return
  end
  if #sessions == 1 and not self.config.always_choose then
    self.session.id = sessions[1].id
    cb(require("resurrect/util").session_shortname(sessions[1].name), M:load())
    return
  end
  if #sessions > 0 then
    for _, s in ipairs(sessions) do
      s.files = M:get_files(s)
    end
    require("resurrect/ui").choose_session(sessions, function(s)
      if not s then
        return
      end
      self.session.id = s.id
      cb(require("resurrect/util").session_shortname(s.name), M:load())
    end)
  end
end

function M:prune_session_files(dead_files)
  -- TODO: config option to put dead files in quickfix
  vim.notify("pruning dead files", vim.log.levels.DEBUG)
  for _, file in ipairs(dead_files) do
    M:del_file(file.path)
  end
end

function M:delete_session(id)
  if not self.db:delete("sessions", { id = id }) then
    error("could not delete resurrect session")
  end
end

function M:load()
  ---@diagnostic disable-next-line: missing-fields
  self.session.files = self.db:select("files", { where = { session_id = self.session.id } })
  if self.config.debug then
    vim.print(self.session.files)
  end
  return self.session.files
end

function M:get_files(session)
  ---@diagnostic disable-next-line: missing-fields
  local files = self.db:select("files", { where = { session_id = session.id } })
  return files
end

function M:add_file(filepath) -- TODO add cursor position
  if filepath and filepath ~= "" then
    self.db:insert("files", { path = filepath, session_id = self.session.id })
  end
end

function M:update_file(update) -- TODO add cursor position
  if update.path and update.path ~= "" then
    self.db:update("files", {
      where = { session_id = self.session.id, path = update.path },
      set = { path = update.path, row = update.row, col = update.col, session_id = self.session.id },
    })
  end
end

function M:del_file(filepath)
  self.db:delete("files", { path = filepath, session_id = self.session.id })
end

return M
