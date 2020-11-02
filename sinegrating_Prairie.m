function sinegrating_Prairie(tempfreq,spfreq,sduration,iduration,nsessions)

%sinegrating_Prairie(2,0.05,5,5,10)

datestr = date;
savefile = [datestr '_'];
[fnm pnm] = uiputfile('*.mat','Save File A..',savefile);

lum_center = 128;
AssertOpenGL; % Make sure this is running on OpenGL Psychtoolbox:
screenid = max(Screen('Screens')); % Choose screen with maximum id - the secondary display on a dual-display setup for display

x = ((0:255).^(1/2.2))'; % gamma correction
table = repmat(x/max(x),1,3);
Screen('LoadNormalizedGammaTable',screenid,table);

resolution = Screen('Resolution', screenid); % # of pixels
resheight = resolution.height;
reswidth = resolution.width;

stimwidth = 15*(resolution.width/16); %full field (with 1/16 of the screen blank for the diode)
stimheight = resolution.height;
stimwindow = [stimwidth stimheight];

% create data acquisition session
 session = daq.createSession ('ni');
 session.addAnalogOutputChannel('Dev1','ao0','Voltage'); % visual stim
 session.IsContinuous = true;
 session.Rate = 10000;
 session.outputSingleScan(0); % create output value and output a single scan

cpd = .2967; % cm per degree when distance between eye and monitor is 15 cm i.e. tand.5 x 15 x 2 =  0.2618
spfreq_new = spfreq/(cpd*reswidth/(40.64)); % convert # of cycles per degree to # of cycles per pixel; 40.64 is the screen width in cm 
rotateMode = kPsychUseTextureMatrixForRotation;
angles = [0 45 90 135 180 225 270 315];
contrasts = 1; %[0.08 0.16 0.32 0.64 0.8 1];
all_combs = combn(1:max([length(angles),length(contrasts)]),2);
all_combs(length(contrasts)*length(angles)+1:end,:) = [];
if length(angles) > length(contrasts)
    all_combs = fliplr(all_combs);
end

comb_all_sessions = zeros(size(all_combs,1),nsessions);
for i = 1:nsessions
    comb_all_sessions(:,i) = randperm(length(contrasts)*length(angles))';
end

amplitude = .5;
phase = 0; % Phase is the phase shift in degrees (0-360 etc.) applied to the sine grating:
win = Screen('OpenWindow', screenid, lum_center); % Open a fullscreen onscreen window on that display, choose a background color of 128 = gray, i.e. 50% max intensity
AssertGLSL; % Make sure the GLSL shading language is supported
ifi = Screen('GetFlipInterval', win, lum_center); % Retrieve video redraw interval for later control of our animation timing
phaseincrement = (tempfreq * 360) * ifi; % Compute increment of phase shift per redraw

diodeBox = 25; % size of the diode box
offset = lum_center/255;

Screen('FillRect', win, lum_center);
Screen('Flip', win);
tic
while (toc<=60) % wait 50 seconds for the screen to adjust
    tim = toc;
    [keyIsDown,secs,keyCode] = KbCheck;
    if keyCode(27); break; end
end
sequence = nan(nsessions*length(angles)*length(contrasts),2); %initialize the sequence array
abort = 0; count = 0;
for i = 1:nsessions % loop over sessions
    disp(['Session ',int2str(i),'/',int2str(nsessions)])
    
    for j = 1:size(comb_all_sessions,1) % loop over orientations
        count = count+1;
        ori = angles(all_combs(comb_all_sessions(j,i),1));
        con = contrasts(all_combs(comb_all_sessions(j,i),2));
        sequence(count,1) = ori;
        sequence(count,2) = con;
        
        gratingtex = CreateProceduralSineGrating(win, stimwindow(1), stimwindow(2), offset*[1,1,1,0], [], con);
        Screen('FillRect', win, lum_center);
        Screen('Flip', win);
        
        tic
        while (toc<=iduration)
            tim = toc;
        end
        [keyIsDown,secs,keyCode] = KbCheck;
        if keyCode(27); abort = 1; break; end
        
        tim = Screen('Flip', win);
        vblStime = tim + sduration;
        while (tim<vblStime)
            phase = phase + phaseincrement; % Increment phase by 1 degree
            Screen('DrawTexture', win, gratingtex, [], [1 1 stimwidth stimheight], ori, [], [], [], [], rotateMode, [phase, spfreq_new, amplitude, 0]);
            Screen('FillRect', win, [255 255 255], [reswidth-diodeBox resheight-diodeBox reswidth resheight]); %show the diode box in white
            tim = Screen('Flip', win, tim + 0.5 * ifi); % Show it at next retrace
            session.outputSingleScan(all_combs(comb_all_sessions(j,i))); % create output value and output a single scan
        end
        session.outputSingleScan(0); % create output value and output a single scan
        [keyIsDown,secs,keyCode] = KbCheck;
        if keyCode(27); abort = 1; break; end
    end
    if abort==1 ; break ; end    
end

% Close the window. This will also release all other ressources:
Screen('CloseAll');
parameters.spfreq = spfreq;
parameters.tempfreq = tempfreq;
parameters.sduration = sduration;
parameters.iduration = iduration;
parameters.nsessions = nsessions;
parameters.sequence = sequence;
savefile = strcat(pnm,fnm);
save(savefile,'parameters');

return;
