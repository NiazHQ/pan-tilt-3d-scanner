%% Lab 8 Task 2 - reconstruct the Task 1 scan
% Uses the readings Task 1 left in s.UserData.

%% Settings
MAX_RANGE     = 6000;    % mm, readings above this are dropped (ToF timeout = 8190)
GIMBAL_HEIGHT = 128.5;   % mm, base bottom to tilt axis (CAD)
BEARING       = 0;       % deg, direction the scanner faces
PAN_CENTRE    = 90;      % servo angle looking straight ahead
TILT_CENTRE   = 108;     % servo angle looking level
TILT_DIR      = 1;       % raw tilt increases upward (140 = up, 60 = down)
MOUNT_F       = 12.7;    % mm, sensor forward of the tilt axis (CAD)
MOUNT_H       = 69.8;    % mm, sensor above the tilt axis (CAD)

%% Get the readings
n_all = s.UserData.n;
pan  = s.UserData.pan_ang(1:n_all).';
tilt = s.UserData.tilt_ang(1:n_all).';
dist = s.UserData.distance(1:n_all).';

%% Keep valid readings (before any correction)
valid = (dist > 0) & (dist < MAX_RANGE);
fprintf('Captured %i, kept %i, dropped %i\n', n_all, sum(valid), sum(~valid));
if ~any(valid)
    error('No valid readings - check MAX_RANGE is in mm (6000).');
end
pan  = pan(valid);
tilt = tilt(valid);
dist = dist(valid);

%% Servo angles to simulation angles (0 = straight ahead / level)
pan  = pan - PAN_CENTRE;
tilt = TILT_DIR * (tilt - TILT_CENTRE);

%% Build the 7-column array: [pan, tilt, distance, orig_x, orig_y, orig_z, bearing]
n = numel(dist);
output_data = [pan, tilt, dist, zeros(n,1), zeros(n,1), ...
               GIMBAL_HEIGHT*ones(n,1), BEARING*ones(n,1)];

%% Mount correction (sensor sits in front of and above the tilt axis)
R     = sqrt(MOUNT_F^2 + MOUNT_H^2);
mount = atan2(MOUNT_H, MOUNT_F);
t = deg2rad(output_data(:,2));
d = output_data(:,3);
u = R*cos(t + mount) + d.*cos(t);       % forward
w = R*sin(t + mount) + d.*sin(t);       % up
output_data(:,3) = sqrt(u.^2 + w.^2);
output_data(:,2) = rad2deg(atan2(w, u));

%% Plot the points
figure
DisplayScatter(output_data, 'scan', MAX_RANGE);
title(sprintf('Hardware scan (%i readings)', n));
