require("coroutine");
-- local pretty = require("cc.pretty");
local spk = { peripheral.find("speaker") };

term.setTextColour(colors.lightBlue);
print("ccloselessplayer player");
term.setTextColour(colors.white);

-- Settings Begin
SERVER = "http://127.0.0.1:5000/";
FLOORDBFS = 120; -- dBFS in postive, floor of dBFS meter
EXTDISPLAY = true; -- use monitor instead of term
USEBAR = true; -- dBFS bar instead of value
-- Settings End

local displayText = "";
local pause = true;
local output = { { 1 } }; -- 1 device, device 1: "1 channel, channel 1 is speaker 1"
local channels = 1; -- channel number of the most channels device
local url = "";
local buffer = 3000; -- in samples
local dontflush = false; -- do not flush screen
local rereq = false; -- re-request
local volume = 1.0;

local mon;
if EXTDISPLAY then
	mon = peripheral.find("monitor");
else
	mon = term;
end

local function playthread()
    local mw, mh;
    while true do
        mw, mh = mon.getSize();
        local files = {};
        local run = true;
        repeat
            if url == "" or url == nil or channels < 1 then
                printError("Argument Error");
                dontflush = true;
                pause = true;
                coroutine.yield();
                pause = false;
            else
                for i = 1, channels do
                    if files[i] ~= nil then files[i].close(); end
                    files[i] = http.get(SERVER .. "?url=" .. url .. "&chn=" ..
                        tostring(i - 1), {}, true);
                end
                break
            end
        until false
        while run do
			mon.setCursorPos(1,1);
			mon.write(displayText);
            for i = 1, channels do
                if files[i] == nil then
					printError("Empty file");
					dontflush = true;
					pause = true;
					coroutine.yield();
					pause = false;
                    run = false;
                    break
                end
                local data = {};
                local summary = 0;
                for _ = 1, buffer do
                    local a = files[i].read();
                    if a == nil then
                        rereq = true; -- cannot seek and i dont know why.
                        pause = true;
                        coroutine.yield();
                        run = false;
                        break;
                    end
                    table.insert(data, math.min(math.max(-128, (a - 128) * volume), 127));
                    summary = summary + math.abs(volume * (a - 128));
                end
                summary = summary / buffer;
                mon.setCursorPos(1, mh - channels + i);
                mon.clearLine();
                if USEBAR then
					mon.write(string.rep("#",
						(FLOORDBFS +
							20 * math.log10(
								summary / 127
							)
						) / FLOORDBFS * mw
					));
				else
					mon.write(tostring(20 * math.log10(summary / 127)) .. "dBFS");
				end
                for _, dev in ipairs(output) do
                    if dev[i] ~= nil then
                        while not spk[dev[i]].playAudio(data) do
                            os.pullEvent("speaker_audio_empty");
                        end
                    end
                end
            end
            parallel.waitForAny(function() sleep(0); end, function()
                local e, k = os.pullEvent("key_up");
                if k == keys.p then pause = true; end
            end);
            if pause == true then
				if EXTDISPLAY then
					mon.clear();
				end
                coroutine.yield();
                pause = false;
                --term.clear();
                if rereq then
                    rereq = false;
                    break
                end
            end
        end
        for _, v in ipairs(files) do if v ~= nil then v.close(); end end
    end
end

local coro = coroutine.create(playthread);
while true do
    write("player> ");
    local cmd = read();
    if cmd == "play" then
        pause = false;
        dontflush = false;
        local ok, msg = coroutine.resume(coro);
        while coroutine.status(coro) ~= "dead" and pause ~= true do
            local event = table.pack(os.pullEvent());
            ok, msg = coroutine.resume(coro, table.unpack(event, 1, event.n));
        end
        if not ok then
            printError(msg);
            dontflush = true;
        end
        if not dontflush and not EXTDISPLAY then
            term.clear();
            term.setCursorPos(1, 1);
        end
        dontflush = false;
    elseif cmd == "exit" then
		printError("Exit!")
        return;
    elseif cmd == "setbuf" then
        buffer = tonumber(read());
    elseif cmd == "seturl" then
        url = read();
        rereq = true;
    elseif cmd == "setvol" then
        volume = tonumber(read())
    elseif cmd == "setdev" then
        print(#spk);
        local cnt = tonumber(read());
        channels = 0;
        output = {};
        for i = 1, cnt do
            local dev = {};
            local cntx = tonumber(read());
            channels = math.max(channels, cntx);
            for j = 1, cntx do
                local id = tonumber(read());
                spk[id].playNote("pling");
                table.insert(dev, id);
            end
            table.insert(output, dev);
        end
    elseif cmd == "settext" then
        displayText = read();
    else
        print("Unknown command");
    end
end
