function sat_struct = updateSatellite(tle_file, time)
    sat_struct = struct();
    tleStruct = tleread(tle_file);
    [r, v]= propagateOrbit(time, tleStruct);
    sat_struct.time = time;
    sat_struct.x = r(1);
    sat_struct.y = r(2);
    sat_struct.z = r(3);
    sat_struct.vx = v(1);
    sat_struct.vy = v(2);
    sat_struct.vz = v(3);
end