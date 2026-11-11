function [intersect, min_distance, dir_cartesian] = measure_distance(orig, pan_angle, tilt_angle, vert1, vert2, vert3)
% Distance from orig to the nearest triangle along one ray (600 = no hit).

    % Ray direction from pan and tilt (degrees)
    [dx, dy, dz] = sph2cart(deg2rad(pan_angle), deg2rad(tilt_angle), 25);
    dir_cartesian = [dx, dy, dz];

    % Hits are returned in units of the direction length, so scale them
    [intersect, dis] = TriangleRayIntersection(orig, dir_cartesian, vert1, vert2, vert3);
    hits = dis(intersect) * norm(dir_cartesian);

    if isempty(hits)
        min_distance = 600;
    else
        min_distance = min(hits);
    end
end
