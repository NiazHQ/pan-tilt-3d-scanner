function output_array = RunConeScan(vert1, vert2, vert3, origin_array, bearing_array, ...
                                    pan_angles, tilt_angles, cone_angle, number_of_rays, layers, use_parallel)
% Simulated cone scan from every origin, pan and tilt angle.
% Output rows: [pan, tilt, distance, orig_x, orig_y, orig_z, bearing]

    scans    = size(origin_array, 1);
    num_pan  = length(pan_angles);
    num_tilt = length(tilt_angles);
    N = scans * num_pan * num_tilt;
    output_array = zeros(N, 7);

    % M = 0 runs the loop without a parallel pool
    if use_parallel, M = Inf; else, M = 0; end

    parfor (idx = 1:N, M)
        [s, p, t] = ind2sub([scans, num_pan, num_tilt], idx);
        orig       = origin_array(s, :);
        bearing    = bearing_array(s);
        pan_angle  = pan_angles(p);
        tilt_angle = tilt_angles(t);

        % Ray direction in the room = pan + bearing
        [~, d, ~] = measure_distance_cone(orig, pan_angle + bearing, tilt_angle, ...
            vert1, vert2, vert3, cone_angle, number_of_rays, layers);

        output_array(idx, :) = [pan_angle, tilt_angle, d, orig, bearing];
    end
end
