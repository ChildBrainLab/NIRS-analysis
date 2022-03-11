function raw = fix_stims( raw , enforce_stim_count )
% This function checks that the stim marks are correct and renames task conditons as appropriate
% 
% Usage: raw = EmoGrow.fix_stims( raw* , enforce_stim_count );
%
% Inputs:
%   raw: Array of nirs data objects
%   enforce_stim_count: Flag indicating whether files must have all trials, or if half is good enough (default: true)
%
% Output:
%   raw: Array of raw data with condition names fixed and bad files removed
%
if ~exist('enforce_stim_count','var'), enforce_stim_count = 0; end

out = nirs.core.Data.empty;

warnstate = warning;
warning('off');
try
    for i = 1:length(raw)

        tmp = raw(i);
        task = tmp.demographics('Task');
        task = strrep(strrep(strrep(strrep(strrep(task,'/',''),'\',''),'-',''),'_',''),' ','');

        %% Set task configuration
        stim = [];
        switch lower(task)
            case 'fetch'
                stim.mapping = {'channel_1', 'Rest'; ...
                                'channel_2', 'Win'; ...
                                'channel_3', 'Win'; ...
                                'channel_4', 'Win'; ...
                                'channel_5', 'Lose'; ...
                                'channel_6', 'Lose'; ...
                                'channel_7', 'Lose'; ...
                                'channel_8', 'EmoLabel_Final'};
                stim.keep = {'Win','Lose'};
                if enforce_stim_count
                    stim.counts = {'Stroop','==', 18; 'NonStroop','==', 18};
                else
                    stim.counts = {'Win','>',0; 'Lose','>',0};
                end
                stim.maxgap = ceil(22 * tmp.Fs);
                stim.mintime = 45;
                
            case 'petstorestroop'
                stim.mapping = {'channel_2', 'NonStroop'; 'channel_3', 'Stroop'};
                stim.keep = {'Stroop', 'NonStroop'};
                if enforce_stim_count
                    stim.counts = {'Stroop','==', 18; 'NonStroop','==', 18};
                else
                    stim.counts = {'Stroop','>=', 9; 'NonStroop','>=', 9; 'Stroop','<=', 18; 'NonStroop','<=', 18};
                end
                stim.props = {'Stroop', [], 5, []; 'NonStroop', [], 5, []};
                stim.maxgap = ceil(6 * tmp.Fs);

            case 'gonogo'
                stim.mapping = {'Control','Motor';  'Go-NoGo','NoGo'; 'channel_2','Motor'; 'channel_3', 'NoGo'};
                stim.keep = {'NoGo','Motor'};
                if enforce_stim_count
                    stim.counts = {'Motor','==', 60; 'NoGo','==', 60};
                else
                    stim.counts = {'Motor','>=', 30; 'NoGo','>=', 30; 'Motor','<=', 60; 'NoGo','<=', 60};
                end
                stim.maxgap = 50;
                
            case 'jumble'
                stim.mapping = {'channel_2','Jumble'; 'channel_3','Emotion'; 'channel_1','Rest'; 'channel_11','Task'};
                stim.keep = {'Jumble'};
                if enforce_stim_count
                    stim.counts = {'Jumble','==', 25};
                else
                    stim.counts = {'Jumble','>=', 13; 'Jumble','<=', 25};
                end
                stim.props = {'Jumble',[],5,1; 'Emotion',[],5,1};

            case 'monkey'
                stim.mapping = {'channel_1', 'Rest'; ...
                        'channel_2', 'Preparation'; ...
                        'channel_3', 'Position'; ...
                        'channel_4', 'FinalPosition'; ...
                        'channel_5', 'Delay'; ...
                        'channel_6', 'Response'; };
                stim.keep = {'Delay2','Delay3','Delay4','Delay5','Delay6'};
                if enforce_stim_count
                    stim.counts = {'Delay2','==',4; 'Delay3','==',4; 'Delay4','==',4; 'Delay5','==',4; 'Delay6','==',4};
                else
                    stim.counts = {'Delay2','<=',4; 'Delay3','<=',4; 'Delay4','<=',4; 'Delay5','<=',4; 'Delay6','<=',4
                                   'Delay2','>=',2; 'Delay3','>=',2; 'Delay4','>=',2; 'Delay5','>=',2; 'Delay6','>=',2};
                end

            case 'dbdos'
                stim.mapping = {'channel_2','Puzzle'; 'channel_3','FreePlay'};
                stim.keep = {'FreePlay','Puzzle'};
                if enforce_stim_count
                    stim.counts = {'FreePlay','==', 4; 'Puzzle','==', 4};
                else
                    stim.counts = {'FreePlay','>=', 2; 'Puzzle','>=', 2; 'FreePlay','<=', 4; 'Puzzle', '<=', 4};
                end
                stim.props = {'FreePlay',5,120,1; 'Puzzle',5,120,1};

            case 'dbdospuzzle'
                stim.mapping = {'channel_2','Puzzle'};
                stim.keep = {'Puzzle'};
                if enforce_stim_count
                    stim.counts = {'Puzzle','==', 4};
                else
                    stim.counts = {'Puzzle','>=', 2; 'Puzzle', '<=', 4};
                end
                stim.props = {'Puzzle',5,120,1};

            case 'dbdosfreeplay'
                stim.mapping = {'channel_3','FreePlay'};
                stim.keep = {'FreePlay'};
                if enforce_stim_count
                    stim.counts = {'FreePlay','==', 4};
                else
                    stim.counts = {'FreePlay','>=', 2; 'FreePlay', '<=', 4};
                end
                stim.props = {'FreePlay',5,120,1};

            otherwise
                error('Task not recognized: %s',task);
        end

        %% Stimulus condition renaming and pruning
        job = nirs.modules.RenameStims();
        job.listOfChanges = stim.mapping;

        tmp = job.run(tmp);

        if strcmpi(task,'monkey')
            tmp = task_fix_monkey(tmp);
        end
                
        %% Discard files with wrong stim counts
        job = advanced.nirs.modules.DiscardStimWrongCount(job);
            job.listOfCounts = stim.counts;

        %% Discard unneed conditions, files without needed conditions
        job = nirs.modules.KeepStims(job);
            job.listOfStims = stim.keep;
            job.required = true;
            
        %% Manually adjust onset/duration/amplitude
        if isfield(stim,'props')
            job = advanced.nirs.modules.FixStims(job);
            job.listOfChanges = stim.props;
        end
                
        %% Merge trials into blocks
        if isfield(stim,'maxgap')
            job = advanced.nirs.modules.RemoveStimGapsOld(job);
                job.max_gap_length = stim.maxgap;
        end
        
        %% Specify minimum allowable time
        if isfield(stim,'mintime')
            job = nirs.modules.RemoveShortStims(job);
                job.mintime = stim.mintime;
        end
        
        %% Remove empty
        job = nirs.modules.RemoveStimless(job);
        
        %% Run job and append output
        tmp = job.run(tmp);
        
        if strcmpi(task,'jumble')
            tmp = task_fix_jumble(tmp);
        end

        out = [out tmp];

    end
    raw = out;
    warning(warnstate);
catch err
    warning(warnstate);
    rethrow(err);
end

fprintf('%i files passed quality control\n',length(raw));

end

%% Fix Jumble task
function raw = task_fix_jumble(raw)

labels = {'Neutral','Happy','Fear','Happy','Neutral','Fear','Happy','Angry',...
    'Angry','Sad','Sad','Fear','Angry','Neutral','Happy','Fear','Sad',...
    'Neutral','Angry','Neutral','Sad','Happy','Fear','Sad','Angry'};

angry_inds = strcmpi(labels,'Angry');
fear_inds = strcmpi(labels,'Fear');
happy_inds = strcmpi(labels,'Happy');
neutral_inds = strcmpi(labels,'Neutral');
sad_inds = strcmpi(labels,'Sad');

for i=1:length(raw)
    
    stims = raw(i).stimulus('Jumble');
    
    if length(stims.onset)~=25
        continue
    end
    
    raw(i).stimulus('Angry') = nirs.design.StimulusEvents('Angry', stims.onset(angry_inds), stims.dur(angry_inds), stims.amp(angry_inds));
    raw(i).stimulus('Fear') = nirs.design.StimulusEvents('Fear', stims.onset(fear_inds), stims.dur(fear_inds), stims.amp(fear_inds));
    raw(i).stimulus('Happy') = nirs.design.StimulusEvents('Happy', stims.onset(happy_inds), stims.dur(happy_inds), stims.amp(happy_inds));
    raw(i).stimulus('Neutral') = nirs.design.StimulusEvents('Neutral', stims.onset(neutral_inds), stims.dur(neutral_inds), stims.amp(neutral_inds));
    raw(i).stimulus('Sad') = nirs.design.StimulusEvents('Sad', stims.onset(sad_inds), stims.dur(sad_inds), stims.amp(sad_inds));
    
    raw(i).stimulus = raw(i).stimulus.remove('Jumble');
    
end

end

%% Fix monkey task
function raw = task_fix_monkey( raw )
%% Create load levels for EmoGrow Monkey task
% 
delays = [ 4, 3, 5, 2, 4, 2, 3, 6, 5, 2, 6, 4, 2, 3, 6, 5, 4, 3, 6, 5 ];
for i = 1:length(raw)
    
    stim_delay = raw(i).stimulus('Delay');
    stim_response = raw(i).stimulus('Response');
    if isempty(stim_delay) || isempty(stim_response)
        warning('Missing conditions for: %s (%s). Skipping.',raw(i).demographics('Name'),raw(i).demographics('Visit'));
        continue;
    end
    
    onsets_delay = stim_delay.onset;
    onsets_response = stim_response.onset;
    
    if length(onsets_delay)~=20 || length(onsets_response)~=20
        warning('Wrong # of onsets (%i,%i) found for: %s (%s). Skipping.',length(onsets_delay),length(onsets_response),raw(i).demographics('Name'),raw(i).demographics('Visit'));
        continue;
    end
    
    durations = floor( onsets_response - onsets_delay )';
    if sum(durations~=delays)>10
        warning('Unexpected delays found for: %s (%s). Skipping.',raw(i).demographics('Name'),raw(i).demographics('Visit'));
        continue;
    end
    
    stims = Dictionary();
    s = nirs.design.StimulusEvents('Delay2');
    s.onset = onsets_delay(delays==2) - 2;
    s.dur = ones(size(s.onset)) * (2 + 2 + 5);
    s.amp = ones(size(s.onset));
    stims('Delay2') = s;
    
    s = nirs.design.StimulusEvents('Delay3');
    s.onset = onsets_delay(delays==3) - 2;
    s.dur = ones(size(s.onset)) * (2 + 3 + 5);
    s.amp = ones(size(s.onset));
    stims('Delay3') = s;
    
    s = nirs.design.StimulusEvents('Delay4');
    s.onset = onsets_delay(delays==4) - 2;
    s.dur = ones(size(s.onset)) * (2 + 4 + 5);
    s.amp = ones(size(s.onset));
    stims('Delay4') = s;
    
    s = nirs.design.StimulusEvents('Delay5');
    s.onset = onsets_delay(delays==5) - 2;
    s.dur = ones(size(s.onset)) * (2 + 5 + 5);
    s.amp = ones(size(s.onset));
    stims('Delay5') = s;
    
    s = nirs.design.StimulusEvents('Delay6');
    s.onset = onsets_delay(delays==6) - 2;
    s.dur = ones(size(s.onset)) * (2 + 6 + 5);
    s.amp = ones(size(s.onset));
    stims('Delay6') = s;
    
    raw(i).stimulus = stims;
    
end
end
