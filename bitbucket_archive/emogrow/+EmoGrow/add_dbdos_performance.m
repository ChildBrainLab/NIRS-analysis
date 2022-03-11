function raw = add_dbdos_performance(raw,input_dir)
% Loads the puzzle count performance data from the DB-DOS
%
% raw = EmoGrow.add_dbdos_performance(raw,input_dir);
if nargin<2
    input_dir = pwd;
end
puzzlefile = fullfile(input_dir,'R01 Puzzle Counts.xlsx');
if ~exist(puzzlefile,'file')
    error('Could not find file "R01 Puzzle Counts.xlsx" file in directory: %s',input_dir);
end
tbl = readtable(puzzlefile);

Name = cell(height(tbl),1);
for i = 1:height(tbl)
    if iscell(tbl.Var1)
        Name{i} = sprintf('%03i',str2double(tbl.Var1{i}));
    else
        Name{i} = sprintf('%03i',tbl.Var1(i));
    end
end
PuzzlesCompleted = sum(table2array(tbl(:,2:5)),2);
PuzzleLeader = tbl.TypeOfInteraction;

for i=1:length(raw)
    
    ind = find(strcmp(Name,raw(i).demographics('Name')));
    if ~isempty(ind)
        raw(i).demographics('PuzzlesCompleted') = PuzzlesCompleted(ind);
        raw(i).demographics('PuzzleLeader') = PuzzleLeader(ind);
    else
        raw(i).demographics('PuzzlesCompleted') = nan;
        raw(i).demographics('PuzzleLeader') = {''};
    end
    
end

end