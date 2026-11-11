function [Xq, Yq, Zq] = ReconstructData(output_array)
% Turns simulated scan data into a surface for mesh().
% Input: [pan, tilt, distance, orig_x, orig_y, orig_z, bearing]

    % Keep rays that hit something (600 = no hit)
    data = output_array(output_array(:,3) < 600, :);

    % Spherical to x, y, z (world pan = pan + bearing), then add the origin
    [x, y, z] = sph2cart(deg2rad(data(:,1) + data(:,7)), deg2rad(data(:,2)), data(:,3));
    x = x + data(:,4);
    y = y + data(:,5);
    z = z + data(:,6);

    % Interpolate onto a 500 x 500 grid
    [Xq, Yq] = meshgrid(linspace(min(x), max(x), 500), linspace(min(y), max(y), 500));
    Zq = griddata(x, y, z, Xq, Yq);
end
