function [Xq, Yq, Zq, points] = ReconstructHardware(output_array, max_range)
% Turns measured scan data into a surface for mesh().
% Input:  [pan, tilt, distance, orig_x, orig_y, orig_z, bearing], distance in mm
% Output: grid X, Y, Z in mm (empty if no surface can be fitted)
%         points = corrected [x y z] of every valid reading, for scatter3

    if nargin < 2 || isempty(max_range)
        max_range = 6000;          % mm
    end

    % 1. Keep valid readings only (must come first, so a timeout value
    %    is never corrected into a fake short reading)
    valid = (output_array(:,3) > 0) & (output_array(:,3) < max_range);
    data  = output_array(valid, :);
    if size(data, 1) < 3
        warning('ReconstructHardware:NoData', 'Fewer than 3 valid readings.');
        Xq = []; Yq = []; Zq = []; points = zeros(0, 3);
        return
    end
    line_scan = numel(unique(data(:,2))) < 2;   % only one tilt angle

    % 2. ToF calibration (reading = gain * true + offset, from tape measurements)
    CAL_GAIN   = 1.03653;
    CAL_OFFSET = 15.687;
    data(:,3) = (data(:,3) - CAL_OFFSET) / CAL_GAIN;

    % 3. Mount correction: the sensor sits in front of and above the
    %    tilt axis, so each ray starts from a different point as the head tilts
    MOUNT_F = 12.7;    % mm forward of the tilt axis (CAD)
    MOUNT_H = 69.8;    % mm above the tilt axis (CAD)
    R     = sqrt(MOUNT_F^2 + MOUNT_H^2);
    mount = atan2(MOUNT_H, MOUNT_F);
    t = deg2rad(data(:,2));
    d = data(:,3);
    u = R*cos(t + mount) + d.*cos(t);       % forward
    w = R*sin(t + mount) + d.*sin(t);       % up
    data(:,3) = sqrt(u.^2 + w.^2);          % range from the tilt axis
    data(:,2) = rad2deg(atan2(w, u));       % angle from the tilt axis

    % 4. Spherical to x, y, z (world pan = pan + bearing), then add the origin
    [x, y, z] = sph2cart(deg2rad(data(:,1) + data(:,7)), deg2rad(data(:,2)), data(:,3));
    x = x + data(:,4);
    y = y + data(:,5);
    z = z + data(:,6);
    points = [x, y, z];

    % 5. A line scan (one tilt or one pan angle) has no surface to fit
    if line_scan || range(x) < eps || range(y) < eps
        warning('ReconstructHardware:Collinear', 'Points lie on a line - use a scatter plot.');
        Xq = []; Yq = []; Zq = [];
        return
    end

    % 6. Interpolate onto a 100 x 100 grid
    [Xq, Yq] = meshgrid(linspace(min(x), max(x), 100), linspace(min(y), max(y), 100));
    Zq = griddata(x, y, z, Xq, Yq);
end
