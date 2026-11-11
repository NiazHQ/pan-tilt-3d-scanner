%% Lab 8 Task 1 - line scan capture
% Sends the scan settings to Scanner.ino, runs one scan and stores the
% readings in s.UserData. Leaves s open for Task 2 and Task 3.

clear all
close all
cmd_delay = 0.2;                 % s between commands

%% Scan settings (raw servo degrees: pan centre 90, tilt level 108)
PAN_START  = 90;
PAN_STOP   = 90;
PAN_STEP   = 1;
TILT_LEVEL = 100;                 % tilt start = stop gives a line scan
TILT_STEP  = 1;
PAN_DELAY  = 50;                 % ms
TILT_DELAY = 50;                 % ms

%% Open the port (this resets the Arduino, so wait 2 s)
s = serialport("COM8", 115200);
configureTerminator(s, 'CR/LF');
pause(2);
flush(s);

%% Send the settings
writeline(s, 's');                              pause(cmd_delay);
writeline(s, sprintf('g %i', PAN_DELAY));       pause(cmd_delay);
writeline(s, sprintf('h %i', TILT_DELAY));      pause(cmd_delay);
writeline(s, sprintf('c %i', PAN_START));       pause(cmd_delay);
writeline(s, sprintf('d %i', PAN_STOP));        pause(cmd_delay);
writeline(s, sprintf('p %i', PAN_STEP));        pause(cmd_delay);
writeline(s, sprintf('e %i', TILT_LEVEL));      pause(cmd_delay);
writeline(s, sprintf('f %i', TILT_LEVEL));      pause(cmd_delay);
writeline(s, sprintf('t %i', TILT_STEP));       pause(cmd_delay);

%% Storage for the readings
N = 20000;
ud.pan_ang   = zeros(1, N);
ud.tilt_ang  = zeros(1, N);
ud.distance  = zeros(1, N);
ud.n         = 0;                % readings stored
ud.lines     = 0;                % lines received
ud.skipped   = 0;                % lines that were not data
ud.complete  = false;
ud.first_bad = strings(1, 5);
s.UserData = ud;

% sensor_read (bottom of file) runs every time a line arrives
configureCallback(s, "terminator", @sensor_read)

%% Run and wait for "SCAN COMPLETE"
IDLE_TIMEOUT = 15;               % s with no data before giving up
HARD_MAX     = 300;              % s maximum

writeline(s, 'r');
t_start = tic;
t_last  = tic;
last_n  = 0;
while toc(t_start) < HARD_MAX
    pause(0.5);
    if s.UserData.complete
        fprintf('Scan completed.\n');
        break
    elseif s.UserData.n > last_n
        last_n = s.UserData.n;
        t_last = tic;
    elseif toc(t_last) > IDLE_TIMEOUT
        fprintf('No data for %g s - stopping.\n', IDLE_TIMEOUT);
        break
    end
end
writeline(s, 's');
pause(0.5);

%% Summary
fprintf('Lines received:  %i\n', s.UserData.lines);
fprintf('Readings stored: %i\n', s.UserData.n);
fprintf('Lines skipped:   %i\n', s.UserData.skipped);
if s.UserData.skipped > 0
    disp(s.UserData.first_bad(s.UserData.first_bad ~= ""));
end

%% Plot the line scan
pan  = s.UserData.pan_ang(1:s.UserData.n);
dist = s.UserData.distance(1:s.UserData.n);
[pan, order] = sort(pan);        % scans alternate direction, so sort by angle
dist = dist(order);

figure
plot(pan, dist)
xlabel('Pan angle (raw servo deg)', 'FontSize', 14)
ylabel('Distance (mm)', 'FontSize', 14)
title('Line scan')
ylim([150 600])

% Run "clear s" when finished with the hardware (releases the port)

%% Callback - stores each data line
function sensor_read(obj, ~)
    data = readline(obj);
    obj.UserData.lines = obj.UserData.lines + 1;

    if contains(data, "SCAN COMPLETE")
        obj.UserData.complete = true;
        return
    end

    values = sscanf(data, '%i');         % pan, tilt, tof, us
    if numel(values) < 3                 % not a data line
        k = obj.UserData.skipped + 1;
        obj.UserData.skipped = k;
        if k <= 5
            obj.UserData.first_bad(k) = data;
        end
        return
    end

    n = obj.UserData.n + 1;
    obj.UserData.n = n;
    obj.UserData.pan_ang(n)  = values(1);
    obj.UserData.tilt_ang(n) = values(2);
    obj.UserData.distance(n) = values(3);
end
