function raw = load_nirs_all( task , visit , rootdir )
% This function loads all nirs files, then optionally filters out those 
%  with the wrong task or visit. Doesn't rely on a tracking form, but is 
%  extremely slow. Recommend using EmoGrow.load_nirs function instead 
%  unless you're debugging
%
% Usage: raw = EmoGrow.load_nirs_all( task, visit, rootdir );
%
% If no options are supplied, it searches the current directory for NIRS 
% files from all tasks and visits

if ~exist('task','var') || isempty(task)
    task = '';
end
if ~exist('visit','var') || isempty(visit)
    visit = '';
end
if ~exist('rootdir','var') || isempty(rootdir)
    
end

if ~isempty(task)
    task = strrep(strrep(strrep(task,' ',''),'_',''),'-','');
    switch lower(task)
        case 'dbdos'
            stim = 'channel_10';
        case 'jumble'
            stim = 'channel_11';
        case 'gonogo'
            stim = 'channel_12';
        case 'petstorestroop'
            stim = 'channel_13';
        case 'monkey'
            stim = 'channel_14';
        case 'fetch'
            stim = 'channel_15';
        otherwise
            error('Unrecognized task: %s',task);
    end
end

% Load all files from study (slow)
raw = nirs.io.loadDirectory(rootdir,{'Subject','Visit','Session','Scan'});

% Filter wrong visit, wrong task, and pilot data
demo = nirs.createDemographicsTable( raw );
for i=length(raw):-1:1
    
    % Always remove pilot data
    if strcmp(demo.Subject{i}(1),'9')
        raw(i)=[];
        continue;
    end
    
    % Remove wrong task
    if ~isempty(task)
        if ~any(strcmpi(raw(i).stimulus.keys,stim))
            raw(i)=[];
            continue;
        end
    end

    % Remove wrong visit
    if ~isempty(visit)
        if ~strcmpi(demo.Visit{i},visit)
            raw(i)=[];
            continue;
        end
    end
    
    raw(i).demographics('Task') = task;
    
end

end