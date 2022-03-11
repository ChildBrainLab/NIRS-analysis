function [raw,stats] = load_nirs( task , visit , rootdir , trackingform )
%% Load NIRS data
% raw = EmoGrow.load_nirs( task* , visit* , rootdir, trackingform );
%
% Inputs:
%   task: An EmoGrow task name (e.g., 'Fetch', 'Monkey', 'PetStoreStroop', 'Jumble', 'GoNoGo', 'DBDOS') [required]
%   visit: The visit number (e.g., 'V1', 'V3', 'V5') [required]
%   rootdir: The directory containing the subject-level folders containing nirs data (default: current directory)
%   trackingform: The location of the excel file tracking subject IDs (default: "R01-EmoGrow Tracking Form.xlsx" in rootdir)
%
% Outputs:
%   raw: An array of nirs.core.Data objects containing the nirs data for each file
%   stats: A structure containing information about data loss due to different sources (missing files, stim marks, etc)
if nargin<2
    error('Please specify task and visit: EmoGrow.load_nirs(task,visit)')
end

if ~exist('rootdir','var'), rootdir = []; end
if ~exist('trackingform','var'), trackingform = []; end

if isempty(rootdir)
    rootdir = pwd;
end
if isempty(trackingform)
    trackingform = [rootdir '/R01-EmoGrow Tracking Form.xlsx'];
end
task = strrep(strrep(strrep(task,'-',''),'_',''),' ','');

% Check inputs
if ~any(strcmpi({'fetch','monkey','petstorestroop','jumble','gonogo','dbdos','dbdospuzzle','dbdosfreeplay'},task))
    error('Task not recognized: %s',task)
end
if ~any(strcmpi({'V1','V3','V5'},visit))
    error('Visit not recognized: %s',visit);
end
if ~exist(rootdir,'dir')
    error('Could not find rootdir: %s',rootdir);
end
if ~exist(trackingform,'file')
    error('Could not find tracking form: %s',trackingform);
end

% Get list of subjects
tbl = readtable(trackingform);
subject = cell(height(table),1);
for i=1:height(tbl)
    subject{i,1} = sprintf('%03i',tbl.SubjectID(i));
end
stats = table(subject);
stats.WasScanned = ~isnat(tbl.Date);

% Select sheet name by visit
switch upper(visit)
    case 'V1'
        sheetname = 'Visit 1';
    case 'V3'
        sheetname = 'Visit 3';
    case 'V5'
        sheetname = 'Visit 5';
    otherwise
        error('Unrecognized visit: %s',visit);
end

% Get corresponding scan numbers
N_total = length(subject);
[subj,scan] = scanlist_from_runsheet( trackingform , task , {} , sheetname );
nScan = length(scan);
N_orig = length(unique(subj));
stats.DidTask = ismember(stats.subject,subj);

% Find the visit folders containing NIRx data based on subject/scan numbers
folders = cell(nScan,1);
for i = 1:nScan
    folders{i} = fullfile(rootdir,subj{i},visit,'*',['*' scan{i}],'/');
end

% Adjust for hyperscanning data
if contains(upper(task),'DBDOS')
    folders = reshape([strcat(folders,filesep,'Subject1/') strcat(folders,filesep,'Subject2/')]',[],1);
    subj = [subj; subj]; scan = [scan; scan];
    nScan = 2*nScan;
end 

% Check if folders exist, expand wildcards to actual paths
notfound = false(nScan,1);
for i = 1:nScan
    dir = rdir(folders{i});
    if ~isempty(dir)
        folders{i} = dir.folder;
    else
        notfound(i)=1;
        fprintf('Folder not found: %s\n',folders{i});
    end
end
folders(notfound)=[]; nScan = length(folders);
subj = subj(~notfound);
N_found = length(unique(subj));

stats.FoundFile = ismember(stats.subject,subj);

%% Load data (do probe stuff only on first file)
raw = nirs.core.Data(nScan);
raw(1) = nirs.io.loadNIRx( folders{1} , true );
for i = 2:nScan
    try
        raw(i) = nirs.io.loadNIRx( folders{i} , false );
        raw(i).probe = raw(1).probe;
    catch err
        warning('%s (%s)',err.message,folders{i});
    end
end
empty = false(size(raw));
for i=1:nScan
    if isempty(raw(i).data)
        empty(i) = true;
    end
    tmpname = raw(i).demographics('Name'); % Remove trailing 1/2 for DBDOS
    if length(tmpname)>3
        raw(i).demographics('Name') = tmpname(1:3);
    end
end
raw(empty)=[];
N_loaded = length(unique(subj(~empty)));
demo = nirs.createDemographicsTable(raw);
stats.NotEmpty = ismember(stats.subject,demo.Name);

%% Remove stimless
job = nirs.modules.RemoveStimless( );
raw = job.run( raw );
demo = nirs.createDemographicsTable(raw);
N_hasstims = length(unique(demo.Name));
nScan = length(raw);
stats.HasStims = ismember(stats.subject,demo.Name);

%% Fix demographics
for i=1:length(raw)
    if(isempty(raw(i).demographics('Name')))
        n=raw(i).demographics('subject');
        n=unique(nirs.createDemographicsTable(raw).Name(ismember(nirs.createDemographicsTable(raw).subject,n)));
        raw(i).demographics('Name')=n{end};
    end
    raw(i).demographics('Visit') = upper(visit);
end

%% Fix subject names 1 => '001'
for i = nScan:-1:1
    if isempty(raw(i).data)
        raw(i) = [];
    end
    tmp_name = raw(i).demographics('Name');
    if contains(upper(task),'DBDOS')
        tmp_name = tmp_name(1:3);
    end
    raw(i).demographics('Name') = sprintf('%03i',str2double(tmp_name));
end

%% Add task name to demographics
for i = 1:length(raw)
    raw(i).demographics('Task') = task;
end

fprintf('%i subjects total, %i scans listed, %i files found, %i files loaded, %i had stim marks\n',N_total,N_orig,N_found,N_loaded,N_hasstims);

end

function [subj,scan] = scanlist_from_runsheet( trackingform , taskname , filter , sheetname )
% Extract list of subjects and scans from run sheet
% [subject,scan] = scanlist_from_runsheet( trackingform , taskname , filter )
% 
if nargin<3, filter = {}; end

tbl=readtable(trackingform,'Sheet',sheetname);
tbl(isnan(tbl.SubjectID),:)=[];

Name = cell(height(table),1);
for i=1:height(tbl)
    Name{i,1} = sprintf('%03i',tbl.SubjectID(i));
end
tbl=[table(Name) tbl];
tbl.SubjectID=[];

if ~isempty(filter)
    fdata = tbl.(filter{1});
end

if contains(upper(taskname),'DBDOS')
    taskname = 'DBDOS';
end

% Get the fixed task name
colnames = tbl.Properties.VariableNames;
colnames2 = strrep(strrep(strrep(colnames,'-',''),'_',''),' ','');
taskname = colnames{strcmpi(colnames2,taskname)};
scan_list = tbl.(taskname);
if isnumeric(scan_list)
    scan_list = arrayfun(@num2str,scan_list,'UniformOutput',false);
end

scan_list = strrep(strrep(strrep(strrep(scan_list,'.',''),'scan',''),' ',''),',','/');

subj = {}; scan = {};
for i = 1:length(scan_list)
    
    if ~isempty(filter)
        if ~strcmpi(fdata{i},filter{2})
            continue;
        end
    end
        
    scans = strsplit(scan_list{i},'/');
    if all(cellfun(@isempty,scans))
        continue;
    end
    
    for j = 1:length(scans)
        if ~strcmpi(scans{j},'NaN')
            subj(end+1,1) = Name(i);
            scan(end+1,1) = {sprintf('%03i',str2double(scans{j}))};
        end
    end
    
end

end
