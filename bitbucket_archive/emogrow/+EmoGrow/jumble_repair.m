function raw = jumble_repair(raw, draw_results)
if nargin<2
    draw_results = false;
end
%% Iterate over each scan
if length(raw)>1
    for i = 1:length(raw)
        raw(i) = EmoGrow.jumble_repair(raw(i), draw_results);
    end
    return;
end

fprintf('\nRepairing jumble for subject: %s\n',raw.demographics('Name'));

%% Check #1: Has all Jumble trials
has_jumble = false;
stim = raw.stimulus('channel_2');
if ~isempty(stim)
    onsets_jumble = stim.onset;
    if length(onsets_jumble)==25
        has_jumble = true;   
        fprintf('\tHas ALL Jumble trials\n');
    else
        fprintf('\tHas SOME Jumble trials (%i/25)\n',length(onsets_jumble));
    end
else
    onsets_jumble = [];
    fprintf('\tHas NO Jumble trials\n');
end

%% Check #2: Has all Emotion trials
has_emotion = false;
stim = raw.stimulus('channel_3');
if ~isempty(stim)
    onsets_emotion = stim.onset;
    if length(onsets_emotion)==25
        has_emotion = true;
        fprintf('\tHas ALL Emotion trials\n');
    else
        fprintf('\tHas SOME Emotion trials (%i/25)\n',length(onsets_emotion));
    end
else
    onsets_emotion = [];
    fprintf('\tHas NO Emotion trials\n');
end

%% Early exit if Jumble and Emotion are already ok
if has_jumble % && has_emotion
    fprintf('\tJumble repair not needed :)\n');
    return
end

%% Check #3: Has task start/end marks
time_start = nan;
time_end = nan;
stim = raw.stimulus('channel_11');
if ~isempty(stim)
    onsets_task = stim.onset;
    offsets_task = stim.onset + stim.dur;
    for i=1:length(onsets_task)
        if offsets_task(i)<=min([onsets_jumble; onsets_emotion])
            time_start = offsets_task(i);
        end
        if onsets_task(i)>=max([onsets_jumble; onsets_emotion])
            time_end = onsets_task(i);
        end
    end
end

if ~isnan(time_start)
    fprintf('\tHas task start\n');
else
    fprintf('\tHas NO task start\n');
end

if ~isnan(time_end)
    fprintf('\tHas task end\n');
else
    fprintf('\tHas NO task end\n');
end

%% Attempt to fix missing start time
stim = raw.stimulus('channel_1');
onsets_rest = stim.onset;
if isnan(time_start) && ~isempty(onsets_jumble) && ~isempty(onsets_emotion)
    
    % We assume that the first emotion trial is present
    if isempty(onsets_emotion)
        fprintf('\tCould not estimate task start, aborting :(\n');
        return; % Cannot continue without emotion data
    end
    
    onsets_middle = max(onsets_rest( onsets_rest>max(onsets_jumble) & onsets_rest<min(onsets_emotion) ));
    
    if ~isempty(onsets_middle)
        time_start = onsets_middle - 220; % (10s rest) + (25x 8s trials) + (10s rest)
        fprintf('\tEstimated task start\n');
    else
        fprintf('\tCould not estimate task start, aborting :(\n');
        return;
    end
else
    fprintf('\tCould not estimate task start, aborting :(\n');
end


%% Attempt to generate missing Jumble trials
if ~has_jumble && ~isnan(time_start)
    
    [X_orig,names_orig] = raw.getStimMatrix;
    
    onsets_jumble = time_start + 10 + (0:8:192);
    raw.stimulus('channel_2') = nirs.design.StimulusEvents('channel_2',onsets_jumble,ones(25,1),ones(25,1));
    
    [X_repair,names_repair] = raw.getStimMatrix;
    
    if draw_results
    
        f=figure('Visible','off');
        ax1=subplot(211,'Parent',f); plot(ax1,raw.time,X_orig); legend(ax1,names_orig);
        title(ax1,sprintf('Original marks (%s)',raw.demographics('Name'))); set(ax1,'ylim',[-.1 1.1]);
        ax2=subplot(212,'Parent',f); plot(ax2,raw.time,X_repair); legend(ax2,names_repair);
        title(ax2,sprintf('Repaired marks (%s)',raw.demographics('Name'))); set(ax2,'ylim',[-.1 1.1]);
        print(f,sprintf('jumble_repair_%s.png',raw.demographics('Name')),'-r300','-dpng');
        close(f);
        
    end
    
    fprintf('\tJumble trials repaired!\n');
    
end


end