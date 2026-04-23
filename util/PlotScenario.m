function PlotScenario(txPlat,rxPlat,tgtPlat, time)
% Helper to visualize scenario geometry using theater plotter
% 
% Plots:
%    - Transmitter and receiver orientation
%    - Position of all platforms
%    - Target trajectory 

    % Setup theater plotter
    earthRadius = 6371e3; 
    max_r = earthRadius+600e3;
    min_r = earthRadius - 2000;
    tp = theaterPlot(XLim=[min_r max_r],YLim=[-100000 100000],ZLim=[0, 200]); 
    tpFig = tp.Parent.Parent;
    tpFig.Units = 'normalized'; 
    tpFig.Position = [0.1 0.1 0.8 0.8];

    % Setup plotters:
    %   - Orientation plotters
    %   - Platform plotters
    %   - Trajectory plotters 
    opTx = orientationPlotter(tp,...
        LocalAxesLength=4e3,MarkerSize=1);
    opRx = orientationPlotter(tp,...
        LocalAxesLength=4e3,MarkerSize=1);
    plotterTx = platformPlotter(tp,DisplayName='Transmitter',Marker='^',MarkerSize=2,MarkerFaceColor=[0 0.4470 0.7410],MarkerEdgeColor=[0 0.4470 0.7410]);
    plotterRx = platformPlotter(tp,DisplayName='Receiver',Marker='v',MarkerSize=2,MarkerFaceColor=[0 0.4470 0.7410],MarkerEdgeColor=[0 0.4470 0.7410]);
    plotterTgt = platformPlotter(tp,DisplayName='Target',Marker='o',MarkerSize=2,MarkerFaceColor=[0.8500 0.3250 0.0980],MarkerEdgeColor=[0.8500 0.3250 0.0980]);
    trajPlotter = trajectoryPlotter(tp,DisplayName='Transmitter Trajectory',LineWidth=3);

    % Plot transmitter and receiver orientations
    
    plotOrientation(opTx,txPlat.Orientation(3),txPlat.Orientation(2),txPlat.Orientation(1),txPlat.Position)
    plotOrientation(opRx,rxPlat.Orientation(3),rxPlat.Orientation(2),rxPlat.Orientation(1),rxPlat.Position)

    %    Plot platforms
    plotPlatform(plotterTx,txPlat.Position,txPlat.Trajectory.Velocity,{['Tx, 4' newline 'Element' newline 'ULA']});
    plotPlatform(plotterRx,rxPlat.Position,rxPlat.Trajectory.Velocity,{['Rx, 16' newline 'Element' newline 'ULA']});
    plotPlatform(plotterTgt,tgtPlat.Position,tgtPlat.Trajectory.Velocity,{'Target'});
    
    ts = trackingScenario;
    tx = platform(ts);
    tx.Trajectory = txPlat.Trajectory;
    ts.StopTime = time;
    r = record(ts);
    pposes = [r(:).Poses];
    pposition = vertcat(pposes.Position);
    % Plot target trajectory 
    plotTrajectory(trajPlotter, {pposition})
    grid('on')
    title('Scenario')
    view([0 90])
    pause(0.1)
end