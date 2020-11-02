function boar_5sec_op(moviedir,nmovies,imi,nsessions)

% moviedir = 'Z:\Inbal\visual_stim\RF_movies\';
% nmovies is a vector of the number of movies to present [1:4];
% boar_5sec(moviedir,1,5,10) %each movie is 5sec; interval is 5sec

movies = dir([moviedir,'*.mov']);
[nnn,idx] = sort([movies.datenum]);

datestr = date;
savefile = [datestr '_'];
[fnm pnm] = uiputfile('*.mat','Save File A..',savefile);

AssertOpenGL; % Make sure this is running on OpenGL Psychtoolbox
screenid = max(Screen('Screens')); % Choose screen with maximum id - the secondary display on a dual-display setup for display

x = ((0:255).^(1/2.2))'; % gamma correction
table = repmat(x/max(x),1,3);
Screen('LoadNormalizedGammaTable', screenid, table);

resolution = Screen('Resolution', screenid);
reswidth = resolution.width;
resheight = resolution.height;

% create data acquisition session
 session = daq.createSession ('ni');
 session.addAnalogOutputChannel('Dev1','ao0','Voltage'); % visual stim
 session.IsContinuous = true;
 session.Rate = 1000;
 session.outputSingleScan(0); % create output value and output a single scan

% Open a fullscreen onscreen window on that display, choose a background color of 128 = gray, i.e. 50% max intensity:
win = Screen('OpenWindow', screenid, 128);
AssertGLSL;  % Make sure the GLSL shading language is supported
ifi = Screen('GetFlipInterval', win, 128); % Retrieve video redraw interval for later control of our animation timing

vbl = Screen('Flip', win);
vblItime = vbl + 6; % wait 60 sec until start for the gamma correction to take effect
while (vbl<vblItime)
    Screen('FillRect', win, 128);
    vbl = Screen('Flip', win, vbl + 0.5*ifi);
    [keyIsDown,secs,keyCode] = KbCheck;
    if keyCode(27)
        break
    end
end

abort = 0;
diodeBox = 25; %the diode box size

movienames = {[moviedir 'boar_5sec_all.mov']};
sequence = zeros(length(movienames),nsessions);

for j = 1:nsessions
    k = randperm(length(movienames));
    sequence(:,j) = k;
    for i = 1:length(k)
        disp(['Movie #',int2str(nmovies(k(i)))])
        [movie movieduration fps imgw imgh] = Screen('OpenMovie', win, movienames{k(i)});
        
        stimwidth_orig=15*(resolution.width/16);
        stimheight_orig=resolution.height;
        stimtop = (stimheight_orig - (stimwidth_orig/imgw)*imgh)/2;
        stimheight = (stimwidth_orig/imgw)*imgh + stimtop;
        stimwidth = stimwidth_orig;
        
        Screen('PlayMovie', movie, 1); % Start playback engine
        
        while ~KbCheck  % Playback loop: Runs until end of movie or keypress
            tex = Screen('GetMovieImage', win, movie); % Wait for next movie frame, retrieve texture handle to it
            if tex<=0 % Valid texture returned? A negative value means end of movie reached
                break;
            end
            
            %         if i==1
            %             upperleftx = reswidth/2-imgw/2;
            %             upperlefty = resheight/2-imgh/2;
            %             lowerrightx = reswidth/2+imgw/2;
            %             lowerrighty = resheight/2+imgh/2;
            %         end
            
            Screen('DrawTexture', win, tex, [], [1 stimtop stimwidth stimheight]);  %Screen('DrawTexture', win, tex, [], [upperleftx upperlefty lowerrightx lowerrighty]); % Draw the new texture immediately to screen (upper left corner and lower right corner)
            Screen('FillRect', win, [255 255 255], [reswidth-diodeBox resheight-diodeBox reswidth resheight]);
            Screen('Flip', win); % Update display
            Screen('Close', tex); % Release texture
            
            session.outputSingleScan(nmovies(k(i))); % create output value and output a single scan

            [keyIsDown,secs,keyCode] = KbCheck;
            if keyCode(27)
                abort=1; break
            end
        end
        
        session.outputSingleScan(0); % create output value and output a single scan
       
        vbl = Screen('Flip', win);
        vblItime = vbl + imi;
        while (vbl<vblItime) % the interval between the movies
            Screen('FillRect', win, 128);
            vbl = Screen('Flip', win, vbl + 0.5 * ifi);
            [keyIsDown,secs,keyCode] = KbCheck;
            if keyCode(27)
                abort=1; break
            end
        end
        if abort==1
            break
        end
    end
end

Screen('CloseAll');
parameters.directory = moviedir;
parameters.movies = sequence;
parameters.imi = imi;

savefile = strcat(pnm,fnm);
save(savefile,'parameters');

