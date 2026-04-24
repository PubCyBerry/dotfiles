if vim.fn.has("win32") == 1 then
  vim.opt.shellcmdflag = "-c"
  vim.opt.shellxquote  = ""
end

require("config.lazy")
