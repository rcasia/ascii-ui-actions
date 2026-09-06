--- Pure normalization of git remote URLs into `owner/repo` ids.
local M = {}

--- Strip an optional `user@` prefix (ssh remotes).
---@param hostish string
---@return string
local function strip_user(hostish)
	return (hostish:gsub("^[^@]+@", ""))
end

--- Normalize `git remote get-url origin` output to `owner/repo`.
--- Handles ssh (`git@github.com:o/r.git`), scp-like (`host:o/r`), https
--- (`https://github.com/o/r[.git]`) and nested paths (the last two segments
--- win, so GHES org trees work).
---@param url string
---@return string? owner_repo
function M.parse(url)
	if type(url) ~= "string" then
		return nil
	end
	local s = url:match("^%s*(.-)%s*$")
	if s == "" then
		return nil
	end
	s = s:gsub("^%w[%w+.-]*://", "") -- scheme://
	s = strip_user(s)
	-- host + separator (: or /) → path
	local path = s:match("^[^:/]+[:/](.+)$")
	if not path then
		return nil
	end
	path = path:gsub("/+$", ""):gsub("%.git$", "")
	local parts = vim.split(path, "/", { trimempty = true })
	if #parts < 2 then
		return nil
	end
	local owner, repo = parts[#parts - 1], parts[#parts]
	if owner == "" or repo == "" then
		return nil
	end
	if not owner:match("^[%w%._%-]+$") or not repo:match("^[%w%._%-]+$") then
		return nil
	end
	return owner .. "/" .. repo
end

--- Validate a user-typed `owner/repo` string.
---@param text string
---@return string? owner_repo
function M.parse_manual(text)
	if type(text) ~= "string" then
		return nil
	end
	local s = text:match("^%s*(.-)%s*$"):gsub("%.git$", "")
	local owner, repo = s:match("^([%w%._%-]+)/([%w%._%-]+)$")
	if owner and repo then
		return owner .. "/" .. repo
	end
	return nil
end

return M
