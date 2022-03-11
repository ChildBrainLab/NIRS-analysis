function [betas,tstats,idx_peak] = extractPeakData( SubjStats , GroupStats , SubjContrast , GroupContrast )
% Extract the subject data from the peak group-level channel
%
% Usage: [betas,tstats] = nirs.util.extractPeakData( SubjStats , GroupStats , SubjContrast , GroupContrast )
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

betas = nan(length(SubjStats),1);
tstats = nan(length(SubjStats),1);

if isa(SubjStats,'nirs.core.ChannelStats')
    
    idx_peak = find(GroupStats.tstat == max(GroupStats.tstat(:)),1);
    peak_link = GroupStats.variables(idx_peak,:);
    
    for i = 1:length(SubjStats)

        ismatch = (SubjStats(i).variables.source==peak_link.source) & (SubjStats(i).variables.detector==peak_link.detector) &  strcmpi(SubjStats(i).variables.type,peak_link.type);
        assert(isequal(SubjStats(i).variables(ismatch,:),peak_link),'Variable mismatch');

        betas(i) = SubjStats(i).beta(ismatch);
        tstats(i) = SubjStats(i).tstat(ismatch);
    
    end
    
elseif isa(SubjStats,'nirs.core.sFCStats')
    
    idx_peak = find( GroupStats.t == max(GroupStats.t(:)) , 1 );
    
    for i = 1:length(SubjStats)
        
        assert(isequal(SubjStats(i).probe.link,SubjStats(1).probe.link),'Probe link mismatch!');
        
        betas(i) = SubjStats(i).Z(idx_peak);
        tstats(i) = SubjStats(i).t(idx_peak);
        
    end

end    

end