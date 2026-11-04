require("git"):setup()

require("full-border"):setup({
  -- Available values: ui.Border.PLAIN, ui.Border.ROUNDED
  type = ui.Border.ROUNDED,
})

-- title_format was removed in Yazi 26. Keep the previous window title.
ps.sub("ind-app-title", function(args)
  local cwd = tostring(cx.active.current.cwd)
  args.value = "Yazi: " .. cwd
  return args
end)

function Linemode:size_and_mtime()
  local time = math.floor(self._file.cha.mtime or 0)
  if time == 0 then
    time = ""
  elseif os.date("%Y", time) == os.date("%Y") then
    time = os.date("%b %d %H:%M", time)
  else
    time = os.date("%b %d  %Y", time)
  end

  local size = self._file:size()
  return string.format("%s %s", size and ya.readable_size(size) or "-", time)
end
