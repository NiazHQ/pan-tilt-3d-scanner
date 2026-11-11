function DisplayScatter(output_array, colour_by, max_range)
% Plots scan data as points (no surface fitting).
%   DisplayScatter(data)                  colour by scan position
%   DisplayScatter(data, 'height')        colour by z
%   DisplayScatter(data, 'distance')      colour by measured distance
%   DisplayScatter(data, 'scan', 6000)    max_range: 600 for simulation, 6000 for ToF (mm)
% Input: [pan, tilt, distance, orig_x, orig_y, orig_z, bearing]

    if nargin < 2 || isempty(colour_by), colour_by = 'scan'; end
    if nargin < 3 || isempty(max_range), max_range = 600;    end

    % Keep valid readings
    valid = (output_array(:,3) > 0) & (output_array(:,3) < max_range);
    data  = output_array(valid, :);
    if isempty(data)
        warning('DisplayScatter:NoData', 'No valid readings (0 < distance < %g).', max_range);
        return
    end

    % Spherical to x, y, z (world pan = pan + bearing), then add the origin
    [x, y, z] = sph2cart(deg2rad(data(:,1) + data(:,7)), deg2rad(data(:,2)), data(:,3));
    x = x + data(:,4);
    y = y + data(:,5);
    z = z + data(:,6);
    n_kept  = size(data, 1);
    n_total = size(output_array, 1);

    switch lower(colour_by)
        case 'scan'
            % One colour per scanner position (origin + bearing)
            [poses, ~, id] = unique(data(:,4:7), 'rows', 'stable');
            colours = lines(size(poses, 1));
            hold on
            for k = 1:size(poses, 1)
                m = (id == k);
                scatter3(x(m), y(m), z(m), 3, colours(k,:), 'filled', ...
                    'DisplayName', sprintf('scan %d: [%g %g %g] bearing %g (%d pts)', ...
                    k, poses(k,:), sum(m)));
            end
            hold off
            legend('Location', 'bestoutside');
            title(sprintf('Scan data by position (%d of %d readings)', n_kept, n_total));

        case 'height'
            scatter3(x, y, z, 3, z, 'filled');
            c = colorbar; c.Label.String = 'Height (z)';
            title(sprintf('Scan data by height (%d of %d readings)', n_kept, n_total));

        case 'distance'
            scatter3(x, y, z, 3, data(:,3), 'filled');
            c = colorbar; c.Label.String = 'Measured distance';
            title(sprintf('Scan data by distance (%d of %d readings)', n_kept, n_total));

        otherwise
            error('colour_by must be ''scan'', ''height'' or ''distance''.');
    end

    xlabel('X'); ylabel('Y'); zlabel('Z');
    grid on
    axis equal
    view(3)
end
