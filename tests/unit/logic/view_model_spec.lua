local vm = require("ascii-ui-actions.logic.view_model")
local eq = require("tests.assertions").eq

describe("logic.view_model", function()
	it("utc_epoch parses ISO timestamps with fixed hour math", function()
		local a = vm.utc_epoch("2026-09-05T12:00:00Z")
		local b = vm.utc_epoch("2026-09-05T13:00:00Z")
		eq(3600, b - a)
	end)

	it("fmt_duration covers s/m/h ranges", function()
		eq("12s", vm.fmt_duration(12))
		eq("2m14s", vm.fmt_duration(134))
		eq("1h2m3s", vm.fmt_duration(3723))
		eq("0s", vm.fmt_duration(-5))
	end)

	it("run_duration: completed uses created→updated, running uses created→run_started fallback", function()
		local done = { status = "completed", created_at = "2026-09-05T12:00:00Z", updated_at = "2026-09-05T12:02:14Z" }
		eq("2m14s", vm.run_duration(done, 0))
		local running =
			{ status = "in_progress", created_at = "2026-09-05T12:00:00Z", run_started_at = "2026-09-05T12:00:30Z" }
		eq("30s", vm.run_duration(running, 0))
	end)

	it("rel_time buckets seconds/minutes/hours/days", function()
		local now = vm.utc_epoch("2026-09-05T12:00:00Z")
		eq("30s ago", vm.rel_time("2026-09-05T11:59:30Z", now))
		eq("5m ago", vm.rel_time("2026-09-05T11:55:00Z", now))
		eq("3h ago", vm.rel_time("2026-09-05T09:00:00Z", now))
		eq("2d ago", vm.rel_time("2026-09-03T12:00:00Z", now))
		eq("", vm.rel_time(nil, now))
	end)

	describe("run_actions gating", function()
		it("rerun follows can_re_run", function()
			local a = vm.run_actions({ status = "completed", conclusion = "success", can_re_run = true })
			eq({ rerun = true, rerun_failed = false, cancel = false }, a)
		end)
		it("rerun_failed requires conclusion failed AND the flag", function()
			local ok = vm.run_actions({
				status = "completed",
				conclusion = "failed",
				can_re_run = true,
				can_re_run_failed = true,
			})
			eq(true, ok.rerun_failed)
			local no = vm.run_actions({ status = "completed", conclusion = "success", can_re_run_failed = true })
			eq(false, no.rerun_failed)
		end)
		it("cancel requires queued/in_progress AND can_cancel", function()
			local q = vm.run_actions({ status = "queued", can_cancel = true })
			eq(true, q.cancel)
			local i = vm.run_actions({ status = "in_progress", can_cancel = true })
			eq(true, i.cancel)
			local c = vm.run_actions({ status = "completed", conclusion = "failure", can_cancel = true })
			eq(false, c.cancel)
		end)
		it("nil-safe", function()
			eq({ rerun = false, rerun_failed = false, cancel = false }, vm.run_actions(nil))
		end)
	end)

	it("workflow_rows picks the newest run per workflow", function()
		local now = vm.utc_epoch("2026-09-05T12:00:00Z")
		local rows = vm.workflow_rows({
			{ id = 1, name = "CI", path = ".github/workflows/ci.yml", state = "active" },
			{ id = 2, name = "Docker", path = ".github/workflows/docker.yml", state = "inactive" },
		}, {
			{ workflow_id = 1, status = "completed", conclusion = "success", created_at = "2026-09-05T11:00:00Z" },
			{ workflow_id = 1, status = "completed", conclusion = "failure", created_at = "2026-09-05T09:00:00Z" },
		}, now)
		eq("success", rows[1].state)
		eq("✓", rows[1].glyph)
		eq("1h ago", rows[1].updated)
		eq(true, rows[1].can_dispatch)
		eq("neutral", rows[2].state)
		eq(false, rows[2].can_dispatch)
	end)

	it("run_rows formats columns and carries availability", function()
		local now = vm.utc_epoch("2026-09-05T12:00:00Z")
		local rows = vm.run_rows({
			{
				id = 5,
				display_title = "fix bug",
				head_branch = "main",
				event = "push",
				actor = { login = "ric" },
				status = "completed",
				conclusion = "success",
				created_at = "2026-09-05T11:57:46Z",
				updated_at = "2026-09-05T12:00:00Z",
				can_re_run = true,
			},
		}, now)
		eq(5, rows[1].id)
		eq("fix bug", rows[1].name)
		eq("main", rows[1].branch)
		eq("push", rows[1].event)
		eq("ric", rows[1].actor)
		eq("2m14s", rows[1].duration)
		eq(true, rows[1].actions.rerun)
	end)

	it("job_rows render with status and duration", function()
		local rows = vm.job_rows({
			{
				id = 1,
				name = "lint",
				status = "completed",
				conclusion = "success",
				started_at = "2026-09-05T12:00:00Z",
				completed_at = "2026-09-05T12:00:12Z",
			},
			{
				id = 2,
				name = "test",
				status = "completed",
				conclusion = "failure",
				started_at = "2026-09-05T12:00:00Z",
				completed_at = "2026-09-05T12:01:00Z",
			},
		}, 0)
		eq("success", rows[1].state)
		eq("12s", rows[1].duration)
		eq("failure", rows[2].state)
		eq("1m0s", rows[2].duration)
	end)

	it("run_meta lists label/value pairs", function()
		local now = vm.utc_epoch("2026-09-05T12:00:00Z")
		local meta = vm.run_meta({
			name = "CI",
			head_branch = "main",
			head_sha = "abcdef1234567890",
			event = "workflow_dispatch",
			actor = { login = "ric" },
			created_at = "2026-09-05T12:00:00Z",
			updated_at = "2026-09-05T12:00:00Z",
			status = "completed",
		}, now)
		eq(
			{ "workflow", "branch", "commit", "trigger", "actor", "created", "duration" },
			vim.iter(meta)
				:map(function(m)
					return m.label
				end)
				:totable()
		)
		eq("abcdef1", meta[3].value)
	end)

	it("cap trims to 50 and reports load-more", function()
		local rows = {}
		for i = 1, 60 do
			table.insert(rows, { id = i })
		end
		local capped, more = vm.cap(rows, vm.has_more(#rows, 60, 50))
		eq(50, #capped)
		eq(true, more)
		eq(false, vm.has_more(2, 2, 2), "short page means end")
		eq(true, vm.has_more(50, 60, 50))
	end)

	it("breadcrumb per view kind", function()
		eq("select repository", vm.breadcrumb({ kind = "picker" }))
		eq(" o/r", vm.breadcrumb({ kind = "workflows", repo = "o/r" }))
		eq(" o/r › CI", vm.breadcrumb({ kind = "runs", repo = "o/r", workflow_name = "CI" }))
		eq(" o/r › all workflows", vm.breadcrumb({ kind = "runs", repo = "o/r" }))
	end)

	describe("status_line", function()
		it("in-flight pending shows running indicator", function()
			local s = { pending_action = { kind = "rerun", state = "running" } }
			local line = vm.status_line(s)
			assert(line.text:find("in flight", 1, true), line.text)
			eq("warn", line.kind)
		end)
		it("refresh error with cache shows stale marker", function()
			local s = { error = { kind = "api", message = "boom" }, stale = true }
			local line = vm.status_line(s)
			assert(line.text:find("boom", 1, true) and line.text:find("stale", 1, true), line.text)
			eq("error", line.kind)
		end)
		it("action message wins over fetched-at", function()
			local s = { action_message = "rerun started", fetched_at = "12:00" }
			assert(vm.status_line(s).text:find("rerun started", 1, true))
		end)
		it("idle shows fetched time", function()
			local s = { status = "ready", fetched_at = "12:04:31" }
			assert(vm.status_line(s).text:find("fetched 12:04:31", 1, true))
		end)
	end)
end)
