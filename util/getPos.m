
function sat_struct = getPos(old_sat_struct, time)

    sat_struct = old_sat_struct;
    height = old_sat_struct.height;                 % Satellite Height

    earth_radius = 6.371e6;                         % Earth Radius (m)

    radius = height+earth_radius;
    velocity = old_sat_struct.abs_velocity;         % Satellite Velocity (m/s)

    sat_omega = 4*pi^2*(height+earth_radius)/velocity;      % Angular Velocity
    
    phi = old_sat_struct.inclination;               % Inclination

    t = time;

    theta = sat_omega*t;
    

    x = radius .* cos(theta);
    y = radius .* sin(theta) .* cos(phi);
    z = radius .* sin(theta) .* sin(phi);

    vx = velocity .* sin(phi) .* cos(theta);
    vy = velocity .* sin(phi) .* sin(theta);
    vz = velocity .* cos(phi);

    sat_struct.pos = [x,y,z];
    sat_struct.vel = [vx, vy, vz];
    sat_struct.angular = sat_omega;
end

