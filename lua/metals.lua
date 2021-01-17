local api = vim.api
local fn = vim.fn
local uv = vim.loop

local decoration = require 'metals.decoration'
local diagnostic = require 'metals.diagnostic'
local log = require 'metals.log'
local messages = require 'metals.messages'
local setup = require 'metals.setup'
local ui = require 'metals.ui'

local M = {}

-- Since we want metals to be the entrypoint for everything, just for ensure that it's
-- easy to set anything for users, we simply include them in here and then expose them.
M.bare_config = setup.bare_config
M.initialize_or_attach = setup.initialize_or_attach
M.install_or_update = setup.install_or_update
M.worksheet_hover = decoration.worksheet_hover
M.open_all_diagnostics = diagnostic.open_all_diagnostics

-- General function used to execute various server commands.
-- @param command_params (optional, table) Paramets to send to the server (arguments and command).
-- @param callback (function) callback function for the request response.
local function execute_command(command_params, callback)
  vim.lsp.buf_request(0, 'workspace/executeCommand', command_params, function(err, method, resp)
    if callback then
      callback(err, method, resp)
    elseif err then
      log.error(err.message)
      print('Could not execute command: ' .. err.message)
    end
  end)
end

M.ammonite_end = function()
  execute_command({command = 'metals.ammonite-end'})
end

M.ammonite_start = function()
  execute_command({command = 'metals.ammonite-start'})
end

M.bsp_switch = function()
  execute_command({command = 'metals.bsp-switch'})
end

M.build_connect = function()
  execute_command({command = 'metals.build-connect'})
end

M.build_disconnect = function()
  execute_command({command = 'metals.build-disconnect'})
end

M.build_import = function()
  execute_command({command = 'metals.build-import'})
end

M.build_restart = function()
  execute_command({command = 'metals.build-restart'})
end

M.compile_cancel = function()
  execute_command({command = 'metals.compile-cancel'})
end

M.compile_cascade = function()
  execute_command({command = 'metals.compile-cascade'})
end

M.compile_clean = function()
  execute_command({command = 'metals.compile-clean'})
end

M.copy_worksheet_output = function()
  local uri = vim.uri_from_bufnr(0)
  if not (string.match(uri, 'worksheet.sc$')) then
    print('You must be in a worksheet to use this command.')
  elseif vim.bo['modified'] then
    print('Please save your worksheet before using this command.')
  else
    local copy_response = function(err, method, resp)
      if err then
        log.error(err.message)
        print(string.format('LSP[Metals][Error] - server error with [%s]. Check logs for details.',
                            method))
      elseif resp.value then
        fn.setreg('+', resp.value)
        print('Copied worksheet output to your +register')
        -- no final else needed since if there is no err and there is no val, Metals will
        -- return a warning with logMessage, so we can skip it here.
      end
    end
    execute_command({command = 'metals.copy-worksheet-output', arguments = uri}, copy_response)
  end
end

M.doctor_run = function()
  execute_command({command = 'metals.doctor-run'})
end

M.generate_bsp_config = function()
  execute_command({command = 'metals.generate-bsp-config'})
end

-- Capture info about the currently installed Metals and display it in a floating window.
M.info = function()
  if not uv.fs_stat(setup.metals_bin) then
    log.warn("Attempted to call MetalsInfo but Metals is not installed")
    print(messages.metals_not_installed)
  else
    local info = fn.system(setup.metals_bin .. ' --version')

    local win_info = ui.percentage_range_window(0.75, 0.4)
    local bufnr, win_id = win_info.bufnr, win_info.win_id

    local lines = {}
    for s in info:gmatch('[^\r\n]+') do
      table.insert(lines, s)
    end
    table.insert(lines, 2, '#####################')
    lines = vim.lsp.util._trim_and_pad(lines, {pad_left = 2, pad_top = 1})
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    vim.lsp.util.close_preview_autocmd({'BufHidden', 'BufLeave'}, win_id)
  end
end

M.logs_toggle = function()
  local bufs = api.nvim_list_bufs()
  for _, v in ipairs(bufs) do
    local buftype = api.nvim_buf_get_option(v, 'buftype')
    if buftype == 'terminal' then
      print('Logs are already opened. Try an :ls to see where it is.')
      return
    end
  end
  -- Only open them if a terminal isn't already open
  api.nvim_command [[vsp term://tail -f .metals/metals.log]]
end

-- Implements the new-scala-file feature.
-- https://scalameta.org/metals/docs/integrations/new-editor.html#create-new-scala-file
--
-- @param directory_uri_opt Path URI for the new file. e.g. 'file:///home/...'
-- @param name_opt Name for the scala file. e.g.: 'MyNewClass'. If nil, it's asked in an input box.
-- @param file_type_opt Type of file. e.g.: 'worksheet'
M.new_scala_file = function(directory_uri_opt, name_opt, file_type_opt)
  local args_string_array = {}
  if directory_uri_opt then
    table.insert(args_string_array, 1, directory_uri_opt)
  else
    table.insert(args_string_array, 1, vim.NIL)
  end

  if name_opt then
    table.insert(args_string_array, 2, name_opt)
  else
    table.insert(args_string_array, 2, vim.NIL)
  end

  if file_type_opt then
    table.insert(args_string_array, 3, file_type_opt)
  else
    table.insert(args_string_array, 3, vim.NIL)
  end

  execute_command({command = 'metals.new-scala-file', arguments = args_string_array})
end

M.new_scala_project = function()
  execute_command({command = 'metals.new-scala-project'})
end

M.sources_scan = function()
  execute_command({command = 'metals.sources-scan'})
end

M.reset_choice = function()
  execute_command({command = 'metals.reset-choice'})
end

-- Notify the server when document has been focused
-- This needs to be called in the appropriate autocommand, i.e. FocusGained
M.did_focus = function()
  local focused_uri = vim.uri_from_bufnr(0)
  vim.lsp.buf_notify(0, 'metals/didFocusTextDocument', focused_uri, function(err, _, _)
    if err then
      log.error(err.message)
      print('LSP[Metals][Error] - server error with `metals/didFocusTextDocument`')
    end
  end)
end

return M
