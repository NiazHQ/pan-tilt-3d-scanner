%% Lab 8 Task 3 - repeatability and beam angle
% Run Task 1 first: this script reuses its open port (s) and scan settings.
%   Part A  repeatability: 10 line scans of the same setup
%   Part B1 beam angle from a narrow object
%   Part B2 beam angle from a bare wall

%% Setup - measure with a ruler
OBJECT_WIDTH    = 110;     % mm, narrow object width
OBJECT_DISTANCE = 314;    % mm, pivot to the object's front face
WALL_DISTANCE   = 400;    % mm, pivot to the wall, square on (Part B2)

PAN_CENTRE   = 90;        % servo angle looking straight ahead
MAX_RANGE    = 6000;      % mm
IDLE_TIMEOUT = 15;        % s
HARD_MAX     = 120;       % s

%% Part A - repeatability
repeats  = 10;
min_dist = zeros(1, repeats);
min_ang  = zeros(1, repeats);

figure
hold on
for k = 1:repeats
    [pan, dist] = run_one_scan(s, IDLE_TIMEOUT, HARD_MAX);
    pan = pan - PAN_CENTRE;

    keep = (dist > 0) & (dist < MAX_RANGE);
    pan  = pan(keep);
    dist = dist(keep);
    [pan, order] = sort(pan);          % scans alternate direction
    dist = dist(order);

    plot(pan, dist)
    [min_dist(k), i] = min(dist);
    min_ang(k) = pan(i);
end
hold off
grid on
xlabel('Pan angle (deg from centre)', 'FontSize', 14)
ylabel('Distance (mm)', 'FontSize', 14)
title(sprintf('%i repeated line scans', repeats))

fprintf('\n--- Repeatability ---\n');
fprintf('Minimum distance: mean %.1f mm, std %.2f mm, range %.1f mm\n', ...
    mean(min_dist), std(min_dist), max(min_dist) - min(min_dist));
fprintf('Angle of minimum: mean %.2f deg, std %.2f deg, range %.1f deg\n', ...
    mean(min_ang), std(min_ang), max(min_ang) - min(min_ang));
fprintf('Ruler distance: %g mm, difference: %.1f mm\n', ...
    OBJECT_DISTANCE, mean(min_dist) - OBJECT_DISTANCE);

%% Part B1 - beam angle from a narrow object (uses the last scan)
% A real beam "sees" the object slightly before and after it is in line,
% so the object looks wider than it is. The extra width is the beam angle.
% The object needs a clear step (50 mm or more) in front of the background.
background = median(dist(dist > mean(dist)));
threshold  = (background + min(dist)) / 2;     % halfway down the step
on_object  = dist < threshold;

fprintf('\n--- Beam angle, narrow object ---\n');
if any(on_object) && ~all(on_object)
    detected_width = max(pan(on_object)) - min(pan(on_object));
    true_width     = 2 * atand((OBJECT_WIDTH/2) / OBJECT_DISTANCE);
    beam_angle     = detected_width - true_width;

    fprintf('Detected width: %.1f deg, true width: %.1f deg\n', detected_width, true_width);
    fprintf('Beam angle: %.1f deg (spot %.0f mm wide at %g mm)\n', ...
        beam_angle, 2*OBJECT_DISTANCE*tand(beam_angle/2), OBJECT_DISTANCE);
else
    fprintf('Object not separated from the background - widen the pan range\n');
    fprintf('or move the object further in front of the wall.\n');
end

%% Part B2 - beam angle from a bare wall
% A thin beam on a flat wall gives d = A/cos(angle). A wider beam finds a
% closer part of the wall, which flattens the curve. The half-angle that
% best fits the measured curve is the beam's half-angle.
% Set RUN_WALL_FIT = true after scanning a bare wall (no object).
RUN_WALL_FIT = false;

if RUN_WALL_FIT
    fprintf('\n--- Beam angle, flat wall ---\n');
    predicted = WALL_DISTANCE ./ cosd(pan);
    levels = max(predicted) - min(predicted);      % mm of variation (1 mm steps)
    fprintf('Variation across the sweep: %.1f mm\n', levels);

    if levels < 5
        fprintf('Too little variation to fit - use a wider pan range or a closer wall.\n');
    else
        half_angles = 0:0.5:20;
        residual = zeros(size(half_angles));
        for j = 1:numel(half_angles)
            h = half_angles(j);
            model = zeros(size(pan));
            for i = 1:numel(pan)
                model(i) = min(WALL_DISTANCE ./ cosd(pan(i)-h : 0.25 : pan(i)+h));
            end
            residual(j) = sqrt(mean((dist - model).^2));
        end
        [best, bi] = min(residual);
        fprintf('Best half-angle %.1f deg (RMS %.2f mm), beam angle %.1f deg\n', ...
            half_angles(bi), best, 2*half_angles(bi));

        figure
        plot(half_angles, residual, '-o')
        grid on
        xlabel('Cone half-angle (deg)', 'FontSize', 14)
        ylabel('RMS residual (mm)', 'FontSize', 14)
        title('Flat-wall fit')
    end
end

% Use the measured beam angle as the cone angle in the simulation.

%% Helper - one scan with Task 1's settings
function [pan, dist] = run_one_scan(s, idle_timeout, hard_max)
    ud = s.UserData;
    ud.pan_ang(:)  = 0;
    ud.tilt_ang(:) = 0;
    ud.distance(:) = 0;
    ud.n = 0; ud.lines = 0; ud.skipped = 0; ud.complete = false;
    s.UserData = ud;

    writeline(s, 'r');
    t_start = tic; t_last = tic; last_n = 0;
    while toc(t_start) < hard_max
        pause(0.5);
        if s.UserData.complete
            break
        elseif s.UserData.n > last_n
            last_n = s.UserData.n;
            t_last = tic;
        elseif toc(t_last) > idle_timeout
            break
        end
    end
    writeline(s, 's');
    pause(0.5);

    pan  = s.UserData.pan_ang(1:s.UserData.n).';
    dist = s.UserData.distance(1:s.UserData.n).';
end
