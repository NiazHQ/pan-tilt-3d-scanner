function [intersect, distance, dir] = measure_distance_cone(orig, pan_angle, tilt_angle, vert1, vert2, vert3, cone_angle, number_of_rays, layers)
% Distance seen by a cone-shaped beam: many rays, closest hit wins.
% Ray 1 is the centre ray; the rest sit on rings ("layers") around it.

    pan_offsets  = zeros(1, number_of_rays);
    tilt_offsets = zeros(1, number_of_rays);

    if number_of_rays > 1
        % Outer rings get more rays (weight sqrt(L/layers))
        layer_sum = sum(sqrt((1:layers) / layers));

        ray_index = 1;
        for L = 1:layers
            n_layer = floor((sqrt(L/layers) / layer_sum) * (number_of_rays - 1) + 0.5);
            radius  = (L/layers) * (cone_angle/2);          % ring size, degrees
            for k = 1:n_layer
                ray_index = ray_index + 1;
                if ray_index > number_of_rays, break, end
                angle = 2*pi * (k-1) / n_layer;             % spread evenly round the ring
                pan_offsets(ray_index)  = cos(angle) * radius;
                tilt_offsets(ray_index) = sin(angle) * radius;
            end
        end
    end

    % Measure every ray and keep the closest
    distances = 600 * ones(1, number_of_rays);
    for n = 1:number_of_rays
        [intersect, distances(n), dir] = measure_distance(orig, pan_angle + pan_offsets(n), ...
            tilt_angle + tilt_offsets(n), vert1, vert2, vert3);
    end
    distance = min(distances);
end
