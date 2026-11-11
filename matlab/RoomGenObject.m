function [x, y, z] = RoomGenObject(xsize, ysize, gridsize, x_start, x_end, y_start, y_end, rect_height)
% Flat room floor with one box-shaped object on it.

    [x, y] = meshgrid(1:gridsize:xsize, 1:gridsize:ysize);
    z = zeros(size(x));

    % Raise the grid points inside the object's footprint
    inside = x >= x_start & x <= x_end & y >= y_start & y <= y_end;
    z(inside) = rect_height;
end
