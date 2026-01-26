obs = obslua
bit = require("bit")

enabled = true
check_interval_ms = 200

silence_threshold_db = -45.0
silence_hold_sec = 1.5

motion_threshold = 0.003
still_hold_sec = 1.5

sample_width = 64
sample_height = 36

audio_source_name = "Mic/Aux"

hotkey_id = obs.OBS_INVALID_HOTKEY_ID

last_audio_active_sec = 0.0
last_motion_active_sec = 0.0
paused_by_script = false

audio_supported = false
audio_channels = 0
volmeter = nil

texrender = nil
stagesurf = nil
prev_frame = nil
prev_linesize = nil

function now_sec()
	-- os_gettime_ns is monotonic.
	return obs.os_gettime_ns() / 1000000000.0
end

function log_info(msg)
	obs.script_log(obs.LOG_INFO, "[auto-pause-idle] " .. msg)
end

function log_warn(msg)
	obs.script_log(obs.LOG_WARNING, "[auto-pause-idle] " .. msg)
end

-- ----------------------------------------------------------------------
-- Base64 decode (fallback if gs_stagesurface_map returns base64_data only)
-- ----------------------------------------------------------------------

base64_map = nil

function base64_init()
	if base64_map ~= nil then
		return
	end

	base64_map = {}
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #chars do
		base64_map[chars:sub(i, i)] = i - 1
	end
end

function base64_decode(data)
	base64_init()

	local out = {}
	local out_len = 0
	local val = 0
	local valb = -8

	for i = 1, #data do
		local c = data:sub(i, i)
		if c ~= "=" then
			local v = base64_map[c]
			if v ~= nil then
				val = val * 64 + v
				valb = valb + 6
				if valb >= 0 then
					out_len = out_len + 1
					out[out_len] = string.char(bit.band(bit.rshift(val, valb), 0xFF))
					valb = valb - 8
				end
			end
		end
	end

	return table.concat(out)
end

-- ----------------------------------------------------------------------
-- Audio monitoring (best-effort; depends on available bindings)
-- ----------------------------------------------------------------------

last_audio_db = -1000.0

function array_max(arr, n)
	local max = -1000.0

	if type(arr) == "table" then
		for i = 1, #arr do
			local v = tonumber(arr[i])
			if v ~= nil and v > max then
				max = v
			end
		end
		return max
	end

	if n ~= nil and n > 0 then
		for i = 0, n - 1 do
			local v = tonumber(arr[i])
			if v ~= nil and v > max then
				max = v
			end
		end
	end

	return max
end

function on_volmeter_update(param, magnitude, peak, input_peak)
	-- magnitude is typically per-channel dB values; take the loudest channel.
	local max_db = array_max(magnitude, audio_channels)
	if max_db ~= -1000.0 then
		last_audio_db = max_db
	end
end

function teardown_audio()
	if volmeter == nil then
		return
	end

	pcall(function()
		obs.obs_volmeter_remove_callback(volmeter, on_volmeter_update)
	end)
	pcall(function()
		obs.obs_volmeter_remove_callback(volmeter, on_volmeter_update, nil)
	end)

	pcall(function()
		obs.obs_volmeter_detach_source(volmeter)
	end)
	pcall(function()
		obs.obs_volmeter_destroy(volmeter)
	end)

	volmeter = nil
	audio_supported = false
	audio_channels = 0
	last_audio_db = -1000.0
end

function setup_audio()
	teardown_audio()

	if audio_source_name == nil or audio_source_name == "" then
		return
	end

	if obs.obs_volmeter_create == nil then
		log_warn("obs_volmeter_* API not available; audio silence detection disabled.")
		return
	end

	local source = obs.obs_get_source_by_name(audio_source_name)
	if source == nil then
		log_warn("Audio source not found: " .. audio_source_name)
		return
	end

	volmeter = obs.obs_volmeter_create(obs.OBS_FADER_IEC)
	if volmeter == nil then
		obs.obs_source_release(source)
		log_warn("Failed to create volmeter; audio silence detection disabled.")
		return
	end

	local ok_attach = obs.obs_volmeter_attach_source(volmeter, source)
	obs.obs_source_release(source)
	if not ok_attach then
		teardown_audio()
		log_warn("Failed to attach volmeter; audio silence detection disabled.")
		return
	end

	audio_channels = obs.obs_volmeter_get_nr_channels(volmeter)

	local ok_cb = pcall(function()
		obs.obs_volmeter_add_callback(volmeter, on_volmeter_update)
	end)
	if not ok_cb then
		ok_cb = pcall(function()
			obs.obs_volmeter_add_callback(volmeter, on_volmeter_update, nil)
		end)
	end

	if not ok_cb then
		teardown_audio()
		log_warn("Failed to register volmeter callback; audio silence detection disabled.")
		return
	end

	audio_supported = true
	log_info("Audio monitoring enabled (source=\"" .. audio_source_name .. "\", channels=" .. tostring(audio_channels) .. ")")
end

-- ----------------------------------------------------------------------
-- Video motion monitoring (main output texture sampling)
-- ----------------------------------------------------------------------

function teardown_video()
	prev_frame = nil
	prev_linesize = nil

	if texrender ~= nil then
		pcall(function()
			obs.obs_enter_graphics()
			obs.gs_texrender_destroy(texrender)
			obs.obs_leave_graphics()
		end)
		texrender = nil
	end

	if stagesurf ~= nil then
		pcall(function()
			obs.obs_enter_graphics()
			obs.gs_stagesurface_destroy(stagesurf)
			obs.obs_leave_graphics()
		end)
		stagesurf = nil
	end
end

function ensure_video()
	if texrender ~= nil and stagesurf ~= nil then
		return true
	end

	teardown_video()

	local ok = pcall(function()
		obs.obs_enter_graphics()
		texrender = obs.gs_texrender_create(obs.GS_RGBA, obs.GS_ZS_NONE)
		stagesurf = obs.gs_stagesurface_create(sample_width, sample_height, obs.GS_RGBA)
		obs.obs_leave_graphics()
	end)

	if not ok or texrender == nil or stagesurf == nil then
		teardown_video()
		return false
	end

	return true
end

function capture_frame()
	if not ensure_video() then
		return nil, nil
	end

	local ok_map, data, linesize, base64_data = false, nil, nil, nil

	obs.obs_enter_graphics()

	local ok_begin = obs.gs_texrender_begin(texrender, sample_width, sample_height)
	if ok_begin then
		obs.gs_ortho(0.0, sample_width, 0.0, sample_height, -100.0, 100.0)
		obs.gs_clear(obs.GS_CLEAR_COLOR, {0.0, 0.0, 0.0, 0.0}, 0.0, 0)

		obs.obs_render_main_texture()
		obs.gs_texrender_end(texrender)

		local tex = obs.gs_texrender_get_texture(texrender)
		if tex ~= nil then
			obs.gs_stage_texture(stagesurf, tex)
			ok_map, data, linesize, base64_data = obs.gs_stagesurface_map(stagesurf)
			if ok_map then
				obs.gs_stagesurface_unmap(stagesurf)
			end
		end

		obs.gs_texrender_reset(texrender)
	end

	obs.obs_leave_graphics()

	if not ok_map then
		return nil, nil
	end

	if type(data) == "string" then
		return data, linesize
	end

	if type(base64_data) == "string" then
		return base64_decode(base64_data), linesize
	end

	return nil, nil
end

function motion_metric(curr, linesize)
	if prev_frame == nil or prev_linesize == nil then
		prev_frame = curr
		prev_linesize = linesize
		return 1.0
	end

	if prev_linesize ~= linesize or #prev_frame ~= #curr then
		prev_frame = curr
		prev_linesize = linesize
		return 1.0
	end

	local row_active = sample_width * 4
	local step = 8
	local sum = 0
	local count = 0

	for y = 0, sample_height - 1 do
		local row_start = y * linesize
		for x = 1, row_active, step do
			local idx = row_start + x
			local a = curr:byte(idx)
			local b = prev_frame:byte(idx)
			if a ~= nil and b ~= nil then
				sum = sum + math.abs(a - b)
				count = count + 1
			end
		end
	end

	prev_frame = curr
	prev_linesize = linesize

	if count == 0 then
		return 1.0
	end

	return sum / (count * 255.0)
end

-- ----------------------------------------------------------------------
-- Main loop
-- ----------------------------------------------------------------------

function reset_activity(now)
	last_audio_active_sec = now
	last_motion_active_sec = now
	paused_by_script = false
	last_audio_db = -1000.0
	prev_frame = nil
	prev_linesize = nil
end

function maybe_pause_tick()
	if not enabled then
		return
	end

	if not obs.obs_frontend_recording_active() then
		return
	end

	local now = now_sec()

	-- Audio active?
	if audio_supported then
		if last_audio_db > silence_threshold_db then
			last_audio_active_sec = now
		end
	else
		-- If we can't detect audio, assume "active" to avoid pausing unexpectedly.
		last_audio_active_sec = now
	end

	-- Motion active?
	local frame, linesize = capture_frame()
	if frame ~= nil and linesize ~= nil then
		local m = motion_metric(frame, linesize)
		if m > motion_threshold then
			last_motion_active_sec = now
		end
	else
		-- If we can't detect motion, assume "active" to avoid pausing unexpectedly.
		last_motion_active_sec = now
	end

	local silent = (now - last_audio_active_sec) >= silence_hold_sec
	local still = (now - last_motion_active_sec) >= still_hold_sec

	if silent and still then
		if not obs.obs_frontend_recording_paused() then
			obs.obs_frontend_recording_pause(true)
			paused_by_script = true
		end
	else
		if paused_by_script and obs.obs_frontend_recording_paused() then
			obs.obs_frontend_recording_pause(false)
			paused_by_script = false
		end
	end
end

function on_frontend_event(event)
	if event == obs.OBS_FRONTEND_EVENT_RECORDING_STARTED then
		reset_activity(now_sec())
	elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_STOPPED then
		paused_by_script = false
	elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_PAUSED then
		-- If user pauses manually, don't auto-resume unless we paused it.
		if not paused_by_script then
			paused_by_script = false
		end
	elseif event == obs.OBS_FRONTEND_EVENT_RECORDING_UNPAUSED then
		-- If user resumes manually, clear our state.
		paused_by_script = false
		reset_activity(now_sec())
	end
end

function toggle_enabled(pressed)
	if not pressed then
		return
	end

	enabled = not enabled
	log_info("Enabled set to " .. tostring(enabled))

	if not enabled and paused_by_script and obs.obs_frontend_recording_paused() then
		obs.obs_frontend_recording_pause(false)
		paused_by_script = false
	end

	reset_activity(now_sec())
end

function restart_timer()
	obs.timer_remove(maybe_pause_tick)
	if check_interval_ms > 0 then
		obs.timer_add(maybe_pause_tick, check_interval_ms)
	end
end

-- ----------------------------------------------------------------------
-- OBS script interface
-- ----------------------------------------------------------------------

function script_description()
	return "Auto-pauses recording when BOTH the mic is silent and the screen is (almost) still, then resumes on activity. This is \"live trimming\" (does not require post-processing)."
end

function script_properties()
	local props = obs.obs_properties_create()

	obs.obs_properties_add_bool(props, "enabled", "Enabled")
	obs.obs_properties_add_int(props, "check_interval_ms", "Check interval (ms)", 50, 2000, 50)

	obs.obs_properties_add_text(props, "audio_source_name", "Audio source name (e.g. Mic/Aux)", obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_float_slider(props, "silence_threshold_db", "Silence threshold (dB)", -80.0, -10.0, 1.0)
	obs.obs_properties_add_float_slider(props, "silence_hold_sec", "Silence hold (sec)", 0.2, 10.0, 0.1)

	obs.obs_properties_add_float_slider(props, "motion_threshold", "Motion threshold (0..1)", 0.0, 0.05, 0.001)
	obs.obs_properties_add_float_slider(props, "still_hold_sec", "Still hold (sec)", 0.2, 10.0, 0.1)

	obs.obs_properties_add_int(props, "sample_width", "Motion sample width", 16, 256, 1)
	obs.obs_properties_add_int(props, "sample_height", "Motion sample height", 9, 144, 1)

	return props
end

function script_defaults(settings)
	obs.obs_data_set_default_bool(settings, "enabled", true)
	obs.obs_data_set_default_int(settings, "check_interval_ms", check_interval_ms)

	obs.obs_data_set_default_string(settings, "audio_source_name", audio_source_name)
	obs.obs_data_set_default_double(settings, "silence_threshold_db", silence_threshold_db)
	obs.obs_data_set_default_double(settings, "silence_hold_sec", silence_hold_sec)

	obs.obs_data_set_default_double(settings, "motion_threshold", motion_threshold)
	obs.obs_data_set_default_double(settings, "still_hold_sec", still_hold_sec)
	obs.obs_data_set_default_int(settings, "sample_width", sample_width)
	obs.obs_data_set_default_int(settings, "sample_height", sample_height)
end

function script_update(settings)
	enabled = obs.obs_data_get_bool(settings, "enabled")
	check_interval_ms = obs.obs_data_get_int(settings, "check_interval_ms")

	audio_source_name = obs.obs_data_get_string(settings, "audio_source_name")
	silence_threshold_db = obs.obs_data_get_double(settings, "silence_threshold_db")
	silence_hold_sec = obs.obs_data_get_double(settings, "silence_hold_sec")

	motion_threshold = obs.obs_data_get_double(settings, "motion_threshold")
	still_hold_sec = obs.obs_data_get_double(settings, "still_hold_sec")

	sample_width = obs.obs_data_get_int(settings, "sample_width")
	sample_height = obs.obs_data_get_int(settings, "sample_height")

	setup_audio()
	teardown_video()
	restart_timer()
	reset_activity(now_sec())
end

function script_load(settings)
	hotkey_id = obs.obs_hotkey_register_frontend("archpostinstall.auto_pause_idle.toggle", "Toggle Auto-Pause Idle", toggle_enabled)
	local hotkey_save_array = obs.obs_data_get_array(settings, "archpostinstall.auto_pause_idle.toggle")
	obs.obs_hotkey_load(hotkey_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)

	obs.obs_frontend_add_event_callback(on_frontend_event)
	reset_activity(now_sec())
	restart_timer()
end

function script_save(settings)
	local hotkey_save_array = obs.obs_hotkey_save(hotkey_id)
	obs.obs_data_set_array(settings, "archpostinstall.auto_pause_idle.toggle", hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end

function script_unload()
	obs.timer_remove(maybe_pause_tick)
	teardown_audio()
	teardown_video()
end
