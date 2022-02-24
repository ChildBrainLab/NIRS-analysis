function [betas,tstats,indices] = extractMeanData( SubjStats , GroupStats , SubjContrast , GroupContrast , threshold )
% Extract the subject data from the mean of significant group-level channels
%
% Usage: [betas,tstats] = nirs.util.extractMeanData( SubjStats , GroupStats , SubjContrast , GroupContrast , threshold )
if nargin<2
    error('Must provide SubjStats and GroupStats');
end
if ~(isa(SubjStats,'nirs.core.ChannelStats') || isa(SubjStats,'nirs.core.sFCStats'))
    error('Unsupported data type: %s',class(SubjStats));
end
if length(SubjStats(1).conditions)>1 && (~exist('SubjContrast','var') || isempty(SubjContrast))
    error('Must specify subject contrast if there are multiple conditions at subject level');
end
if length(GroupStats(1).conditions)>1 && (~exist('GroupContrast','var') || isempty(GroupContrast))
    error('Must specify group contrast if there are multiple conditions at group level');
end
if exist('SubjContrast','var') && ~isempty(SubjContrast)
    SubjStats = SubjStats.ttest(SubjContrast);
end
if exist('GroupContrast','var') && ~isempty(GroupContrast)   
    GroupStats = GroupStats.ttest(GroupContrast);
end
if ~exist('threshold','var') || isempty(threshold)
    threshold = 'q<.05';
end
threshold = strrep(threshold,' ','');
ltind = strfind(threshold,'<');
if isempty(ltind)
    error('Not a valid threshold with "<"');
end
field = threshold(1:ltind-1);
value = str2double(threshold(ltind+1:end));

if ~isprop(GroupStats,field)
    error('Data type "%s" does not contain field "%s"',class(GroupStats),field);
end
if isnan(value)
    error('Value %s does not correspond to a valid number',threshold(ltind+1:end));
end

betas = nan(length(SubjStats),1);
tstats = nan(length(SubjStats),1);

issig = GroupStats.(field) < value;
indices = find(issig);
numsig = sum(issig(:));
if numsig==0
    return
end

if isa(SubjStats,'nirs.core.ChannelStats')
    
    signif_links = GroupStats.variables(issig,:);
    
    for i = 1:length(SubjStats)

        sigbeta = nan(numsig,1);
        sigtstat = nan(numsig,1);
        for j = 1:numsig
        
            ismatch = (SubjStats(i).variables.source==signif_links.source(j)) & (SubjStats(i).variables.detector==signif_links.detector(j)) &  strcmpi(SubjStats(i).variables.type,signif_links.type(j));
            assert(isequal(SubjStats(i).variables(ismatch,:),signif_links(j,:)),'Variable mismatch');
            sigbeta(j) = SubjStats(i).beta(ismatch);
            sigtstat(j) = SubjStats(i).tstat(ismatch);
            
        end

        betas(i) = nanmean(sigbeta);
        tstats(i) = nanmean(sigtstat);
    
    end
    
elseif isa(SubjStats,'nirs.core.sFCStats')
    
    issig = GroupStats.(field) < value;
    
    for i = 1:length(SubjStats)
        
        assert(isequal(SubjStats(i).probe.link,SubjStats(1).probe.link),'Probe link mismatch!');
        
        betas(i) = nanmean(SubjStats(i).Z(issig));
        tstats(i) = nanmean(SubjStats(i).t(issig));
        
    end

end    

end