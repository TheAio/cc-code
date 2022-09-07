local Editor = require "code.Editor"

local Code = {}

local on = {}

function Code:new(filename)
  self._running = true
  self._editor = Editor()
  self._editor:loadFromFile(filename)
  self._actions = {}
  self:registerDefaultActions()

  self._modifierKeys = {
    ctrl = false,
    shift = false,
    alt = false,
  }
end

function Code:registerDefaultActions()
  self:registerScript("shift?+left", "editor:cursorLeft(shift)")
  self:registerScript("ctrl+shift?+left", "editor:cursorWordLeft(shift)")

  self:registerScript("shift?+right", "editor:cursorRight(shift)")
  self:registerScript("ctrl+shift?+right", "editor:cursorWordRight(shift)")

  self:registerScript("shift?+up", "editor:moveCursor(0, -1, shift)")
  self:registerScript("ctrl+up", "editor:scrollBy(0, -1)")

  self:registerScript("shift?+down", "editor:moveCursor(0, 1, shift)")
  self:registerScript("ctrl+down", "editor:scrollBy(0, 1)")

  self:registerScript("backspace", "editor:backspace()")
  self:registerScript("ctrl+backspace", "editor:backspaceWord()")

  self:registerScript("delete", "editor:delete()")
  self:registerScript("ctrl+delete", "editor:deleteWord()")
  self:registerScript("shift+delete", "editor:deleteLine()")

  self:registerScript("shift?+home", "editor:cursorLineHome(shift)")
  self:registerScript("ctrl+shift?+home", "editor:cursorDocumentHome(shift)")

  self:registerScript("shift?+end", "editor:cursorLineEnd(shift)")
  self:registerScript("ctrl+shift?+end", "editor:cursorDocumentEnd(shift)")

  self:registerScript("alt+pageUp", "editor:scrollPageUp()")
  self:registerScript("shift?+pageUp", "editor:cursorPageUp(shift)")

  self:registerScript("alt+pageDown", "editor:scrollPageDown()")
  self:registerScript("shift?+pageDown", "editor:cursorPageDown(shift)")

  self:registerScript("ctrl+a", "editor:selectAll()")

  self:registerScript("ctrl+z", "editor:undo()")
  self:registerScript("ctrl+shift+z", "editor:redo()")
  self:registerScript("ctrl+y", "editor:redo()")

  self:registerScript("ctrl+x", "editor:cut()")
  self:registerScript("ctrl+c", "editor:copy()")
  -- Only triggers a paste event and is hardcoded there.
  -- self:registerScript("ctrl+v", "editor:paste()")

  self:registerScript("ctrl+s", "code:save()")
  self:registerScript("ctrl+w", "code:quit()")
end

function Code:createAction(script)
  local env = _ENV
  return assert(load(script, nil, nil, setmetatable({
    code = self,
    editor = self._editor,
  }, {
    __index = function(action, key)
      if key == "ctrl" then
        return action.code._modifierKeys.ctrl
      elseif key == "shift" then
        return action.code._modifierKeys.shift
      elseif key == "alt" then
        return action.code._modifierKeys.alt
      else
        return env[key]
      end
    end,
  })))
end

function Code:registerAction(combo, action)
  local optional = combo:match("(%w+)%?%+")
  if optional then
    self:registerAction(combo:gsub(optional .. "%?%+", ""), action)
    self:registerAction(combo:gsub(optional .. "%?", optional), action)
  else
    self._actions[combo] = action
  end
end

function Code:registerScript(combo, script)
  self:registerAction(combo, self:createAction(script))
end

function Code:quit()
  self._running = false
end

function on:char(char)
  self._editor:insert(char)
  return true
end

function on:key(key, _held)
  if key == keys.leftCtrl or key == keys.rightCtrl then
    self._modifierKeys.ctrl = true
  elseif key == keys.leftShift or key == keys.rightShift then
    self._modifierKeys.shift = true
  elseif key == keys.leftAlt or key == keys.rightAlt then
    self._modifierKeys.alt = true
  else
    local ctrl = self._modifierKeys.ctrl and "ctrl+" or ""
    local shift = self._modifierKeys.shift and "shift+" or ""
    local alt = self._modifierKeys.alt and "alt+" or ""
    local action = self._actions[ctrl .. shift .. alt .. keys.getName(key)]
    if action then
      local ok, err = pcall(action, self)
      if not ok then
        printError(err)
      end
      return true
    end
  end
end

function on:key_up(key)
  if key == keys.leftCtrl or key == keys.rightCtrl then
    self._modifierKeys.ctrl = false
  elseif key == keys.leftShift or key == keys.rightShift then
    self._modifierKeys.shift = false
  elseif key == keys.leftAlt or key == keys.rightAlt then
    self._modifierKeys.alt = false
  end
end

function on:term_resize()
end

function on:mouse_click(button, x, y)
  self._editor:click(x, y)
  return true
end

function on:mouse_drag(button, x, y)
  self._editor:drag(x, y)
  return true
end

function on:mouse_scroll(direction, x, y)
  self._editor:scrollBy(0, direction * 3)
  return true
end

function on:mouse_up(button, x, y)
  self._editor:release()
end

function on:paste(text)
  if self._modifierKeys.shift then
    self._editor:insert(text)
  else
    self._editor:paste()
  end
  return true
end

function Code:processEvent(event, ...)
  local handler = on[event]
  if handler then
    return handler(self, ...)
  end
end

function Code:render()
  self._editor:render()
end

function Code:run()
  self:render()
  while self._running do
    if self:processEvent(os.pullEvent()) then
      self:render()
    end
  end
end

return require "code.class" (Code)
