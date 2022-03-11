function [raw,status] = add_dbdos_synchrony(raw, input_dir)
% Loads the behavioral synchrony data from the DB-DOS
%
% raw = EmoGrow.add_dbdos_synchrony(raw,input_dir);
if nargin<2
    input_dir = pwd;
end
ntpts = 545;

demo = nirs.createDemographicsTable(raw);
names = demo.Name;

status.good_puzzle = {};
status.good_freeplay = {};
status.filenotfound = {};
status.toofewpoints_puzzle = {};
status.toofewpoints_freeplay = {};
status.sheetnotfound_puzzle = {};
status.sheetnotfound_freeplay = {};

%% Load synchrony data from individual excel files
warning('off','MATLAB:table:ModifiedAndSavedVarnames');
behsync_puzzle = nan(ntpts,length(names));
behsync_freeplay = nan(ntpts,length(names));
for i = 1:length(names)
    
    % Get list of all excel files
    beh_files = rdir([input_dir '/' names{i} '_V1*.xlsx']);
    file_list = {beh_files.name};
    
    beh_files = rdir([input_dir '/Consensus/' names{i} '_V1*.xlsx']);
    file_list = [file_list {beh_files.name}];
    
    if isempty(file_list)
        status.filenotfound{end+1,1} = names{i};
        continue;
    end
    
    % Iterate over files and select one with the sheet names we expect
    file_scores = zeros(size(file_list));
    for j = 1:length(file_list)
        [~,sheetnames]=xlsfinfo(file_list{j});
        file_scores(j) = any(contains(sheetnames,'Puzzle','IgnoreCase',true)) + any(contains(sheetnames,'FreePlay','IgnoreCase',true));
    end
    best_file = file_list{find(file_scores==max(file_scores),1)};
    
    [~,sheetnames]=xlsfinfo(best_file);
    
    % Puzzle
    ispuzzle = contains(sheetnames,'Puzzle','IgnoreCase',true);
    puzzlesheet = sheetnames(ispuzzle);
    
    if isempty(puzzlesheet)
        status.sheetnotfound_puzzle{end+1,1} = names{i};
    else
        
        beh_tbl_puzzle = readtable(best_file,'Sheet',puzzlesheet{1});
        
        if height(beh_tbl_puzzle)<.65*ntpts
            status.toofewpoints_puzzle{end+1,1}=names{i};
        else
            for j = 2:length(beh_tbl_puzzle.Properties.VariableNames)
                colname = beh_tbl_puzzle.Properties.VariableNames{j};
                N = min(ntpts,height(beh_tbl_puzzle));
                issync = strcmpi(beh_tbl_puzzle.(colname)(1:N),'s');
                isasync = strcmpi(beh_tbl_puzzle.(colname)(1:N),'a');
                if (sum(issync) + sum(isasync))>100
                    behsync_puzzle(issync,i) = 1;
                    behsync_puzzle(isasync,i) = 0;
                end
            end
            status.good_puzzle{end+1,1}=names{i};
        end  
    end
    
    % Freeplay
    isfreeplay = contains(sheetnames,'FreePlay','IgnoreCase',true);
    freeplaysheet = sheetnames(isfreeplay);
    
    if isempty(freeplaysheet)
        status.sheetnotfound_freeplay{end+1,1} = names{i};
    else
        beh_tbl_freeplay = readtable(best_file,'Sheet',freeplaysheet{1});
            
        if height(beh_tbl_freeplay)<.65*ntpts
            status.toofewpoints_freeplay{end+1,1}=names{i};
        else
            for j = 2:length(beh_tbl_freeplay.Properties.VariableNames)
                colname = beh_tbl_freeplay.Properties.VariableNames{j};
                N = min(ntpts,height(beh_tbl_freeplay));
                issync = strcmpi(beh_tbl_freeplay.(colname)(1:N),'s');
                isasync = strcmpi(beh_tbl_freeplay.(colname)(1:N),'a');
                if (sum(issync) + sum(isasync))>100
                    behsync_freeplay(issync,i) = 1;
                    behsync_freeplay(isasync,i) = 0;
                end
            end
            status.good_freeplay{end+1,1}=names{i};
        end
    end
    
end

if all(isnan(behsync_puzzle(:)))
    error('Could not load any synchrony data');
end

%% Get the behavioral synchrony stats
behstats_puzzle = behsync_stats(behsync_puzzle);
behstats_freeplay = behsync_stats(behsync_freeplay);

%% Add synchrony stats to demographics field
behfields = behstats_puzzle.Properties.VariableNames;
for i = 1:length(raw)
    for j = 1:length(behfields)
        
        if iscell(raw(i).demographics)
            raw(i).demographics{1}([behfields{j} '_puzzle']) = behstats_puzzle.(behfields{j})(i);
            raw(i).demographics{1}([behfields{j} '_freeplay']) = behstats_freeplay.(behfields{j})(i);
            raw(i).demographics{2}([behfields{j} '_puzzle']) = behstats_puzzle.(behfields{j})(i);
            raw(i).demographics{2}([behfields{j} '_freeplay']) = behstats_freeplay.(behfields{j})(i);
        else
            raw(i).demographics([behfields{j} '_puzzle']) = behstats_puzzle.(behfields{j})(i);
            raw(i).demographics([behfields{j} '_freeplay']) = behstats_freeplay.(behfields{j})(i);
        end
        
    end
end

end

%% Calculate some behavioral synchrony statistics
function stats = behsync_stats(behsync)

[total_sync_time, percent_sync_time, num_state_changes, num_sync_blocks, mean_sync_dur, ...
    median_sync_dur, std_sync_dur, min_sync_dur, max_sync_dur] = deal(nan(size(behsync,2),1));

for i = 1:size(behsync,2)

    if all(isnan(behsync(:,i)))
        continue;
    end
    
    duration = sum(~isnan(behsync(:,i)));
    behsync(isnan(behsync(:,i)),i)=0;
    
    sync = behsync(:,i);
    dsync = diff(sync);
    
    total_sync_time(i,1) = sum(sync);
    percent_sync_time(i,1) = 100 * sum(sync) ./ duration;
    num_state_changes(i,1) = sum(dsync==1) + sum(dsync==-1);
    
    onsets = find(dsync==1);
    offsets = find(dsync==-1);
    if sync(1)==1
        onsets = [0; onsets];
    end
    if sync(end)==1
        offsets = [offsets; length(sync)];
    end
    
    if length(onsets)~=length(offsets) || any(onsets>offsets)
        warning('onset mismatch');
    end
    
    sync_dur = offsets - onsets;
    if isempty(sync_dur)
        sync_dur = 0;
    end
    
    num_sync_blocks(i) = length(onsets);
    mean_sync_dur(i) = mean(sync_dur);
    median_sync_dur(i) = median(sync_dur);
    std_sync_dur(i) = std(sync_dur);
    min_sync_dur(i) = min(sync_dur);
    max_sync_dur(i) = max(sync_dur);
    
end

stats = table(total_sync_time,percent_sync_time,mean_sync_dur,median_sync_dur,std_sync_dur,min_sync_dur,max_sync_dur);

end