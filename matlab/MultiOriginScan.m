%% Multi-origin scan - added after the demonstration
% Combines scans saved with the GUI's Save Scan button, each taken from a
% different scanner position. The GUI saves origin and bearing as zero, so
% this script fills them in, then reconstructs all scans together.

clear
close all

%% Placements - one row per saved scan (brick centre = 0, 0)
% Brick: 110 mm wide (front/back faces), 77 mm deep (side faces), 230 mm tall.
% Scanner placed 314 mm from each face, measured to the pan axis.
% origin  = point under the pan axis, mm
% bearing = direction the scanner faces at pan 90 (0 = +x, 90 = +y)
% Positions go anticlockwise seen from above, starting at the front face.
files   = { 'pos1.mat', 'pos2.mat', 'pos3.mat', 'pos4.mat' };
origins = [ -352.5,    0, 0 ;      % front: 314 + 77/2
               0, -369, 0 ;        % right side (seen from pos 1): 314 + 110/2
             352.5,    0, 0 ;      % back
               0,  369, 0 ];       % left side
bearing = [ 0; 90; 180; -90 ];

n_scans = numel(files);
if size(origins, 1) ~= n_scans || numel(bearing) ~= n_scans
    error('Need one origin and one bearing per file.');
end

%% Load each scan and add its origin and bearing
scans = cell(1, n_scans);
for k = 1:n_scans
    loaded = load(files{k});
    if ~isfield(loaded, 'measured_values')
        error('%s has no measured_values - save it with Save Scan.', files{k});
    end
    data = loaded.measured_values;
    data(:, 4:6) = repmat(origins(k, :), size(data, 1), 1);
    data(:, 7)   = bearing(k);
    scans{k} = data;
    fprintf('%s: %i readings, origin (%g, %g, %g) mm, bearing %g deg\n', ...
        files{k}, size(data, 1), origins(k, :), bearing(k));
end
all_data = vertcat(scans{:});

%% Points, one colour per scan
figure
hold on
colours = lines(n_scans);
for k = 1:n_scans
    [~, ~, ~, pts] = ReconstructHardware(scans{k});
    scatter3(pts(:,1), pts(:,2), pts(:,3), 6, colours(k,:), 'filled', ...
        'DisplayName', sprintf('Scan %i', k));
    plot3(origins(k,1), origins(k,2), origins(k,3), 'k^', 'MarkerSize', 10, ...
        'MarkerFaceColor', colours(k,:), 'DisplayName', sprintf('Origin %i', k));
end
hold off
axis equal
grid on
view(3)
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title(sprintf('Multi-origin scan: %i positions', n_scans));
legend('Location', 'bestoutside');

%% Surface of all scans together
[X, Y, Z] = ReconstructHardware(all_data);
if ~isempty(X)
    figure
    mesh(X, Y, Z);
    axis equal
    xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
    title(sprintf('Multi-origin surface: %i positions', n_scans));
end

%% Save the merged data
save('multi_origin_scan.mat', 'all_data', 'origins', 'bearing', 'files');
fprintf('Saved multi_origin_scan.mat (%i readings)\n', size(all_data, 1));
