function run_analysis_longitudinal_V1V3
%% Configuration
nirs_data_dir = '/data/R01-EmoGrow/Scan Data';
demographics_dir = '/data/R01-EmoGrow/Scan Data';
synchrony_dir = '/data/R01-EmoGrow/Scan Data/Codes';
puzzle_dir = '/data/R01-EmoGrow/Scan Data';

%% Load all data
% Load NIRS data
raw1 = EmoGrow.load_nirs('DBDOS','V1', nirs_data_dir);
raw3 = EmoGrow.load_nirs('DBDOS','V3', nirs_data_dir);

raw1 = EmoGrow.fix_stims(raw1,true);
raw3 = EmoGrow.fix_stims(raw3,true);

%% Only keep subjects who have all 3 visits
% Get list of good subjects
demo1 = nirs.createDemographicsTable(raw1);
demo3 = nirs.createDemographicsTable(raw3);

goodsubs = intersect(demo1.Name, demo3.Name );

% Remove all but the good subjects
raw1=raw1(ismember(demo1.Name,goodsubs));
raw3=raw3(ismember(demo3.Name,goodsubs));

% Combine data across visits
raw = [raw1(:); raw3(:)];

%%
raw = EmoGrow.register_probe(raw);

% Use 10-20 probe
for i = 1:length(raw)
    raw(i).probe.defaultdrawfcn = '10-20';
end

% Add in the demographics/puzzle/synchrony data
raw = EmoGrow.add_demographics(raw, demographics_dir);
% raw = EmoGrow.add_dbdos_synchrony(raw, synchrony_dir);
% raw = EmoGrow.add_dbdos_performance(raw, puzzle_dir);

%% Separate out puzzle and free play
j = nirs.modules.KeepStims();
j = nirs.modules.RenameStims(j);

j.prevJob.listOfStims = {'Puzzle'};
j.listOfChanges = {'Puzzle','DBDOS'};
raw_puzzle = j.run(raw);

j.prevJob.listOfStims = {'FreePlay'};
j.listOfChanges = {'FreePlay','DBDOS'};
raw_freeplay = j.run(raw);

raw = [raw_puzzle(:); raw_freeplay(:)];

save('EmoGrow_DBDOS_0_raw.mat','raw','-v7.3');

%% Preprocessing
job = nirs.modules.TrimBaseline();
    job.preBaseline = 5;
    job.postBaseline = 5;
job = nirs.modules.OpticalDensity(job);
job = nirs.modules.TDDR(job);
job = nirs.modules.Resample(job);
    job.Fs = 4;
    job.antialias = true;
job = eeg.modules.BandPassFilter(job);
    job.lowpass = [];
    job.highpass = .01;
    job.do_downsample = false;
job = nirs.modules.BeerLambertLaw(job);
job = nirs.modules.KeepTypes(job);
    job.types = {'hbo'};
    
hb = job.run(raw);

clear raw;

nch = size(hb(1).data,2);

%% Standardize timing across everyone (needed for permutation testing)
hb = nirs.util.standardize_timings( hb );

%% Set the hyperscan field so that the hyperscanning job can determine which subjects go together
for i=1:length(hb)
    hb(i).demographics('hyperscan')=[hb(i).demographics('Name') hb(i).demographics('Visit')] ;
end

save('EmoGrow_DBDOS_1_preprocessed.mat','hb','job','-v7.3');

%% Create parallel workers
delete(gcp('nocreate'));
parpool(4);

%% Run the 1st-level hyperscanning analysis (separate for each condition)
% Create hyperscanning synchrony job
job = nirs.modules.Hyperscanning();
    job.divide_events = true;
    job.ignore = 0;
    job.symetric = true;
    job.corrfcn = @(data) nirs.sFC.ar_corr_full(data,'8xFs',true); % Note this function is in the LCBD toolbox
    job.estimate_null = true;
    job.verbose = false;

SubjStats_puzzle = job.run(hb(1:end/2));
SubjStats_freeplay = job.run(hb(end/2+1:end));

clear hb;

%% Destroy parallel workers
delete(gcp('nocreate'));

%% Separate actual/null results
demo_full_puzzle = nirs.createDemographicsTable2(SubjStats_puzzle);
demo_full_freeplay = nirs.createDemographicsTable2(SubjStats_freeplay);
isnull_puzzle = strcmp(demo_full_puzzle.Pairing,'Null');
isnull_freeplay = strcmp(demo_full_freeplay.Pairing,'Null');

SubjStats_puzzle_actual = SubjStats_puzzle(~isnull_puzzle);
SubjStats_puzzle_null = SubjStats_puzzle(isnull_puzzle);
SubjStats_freeplay_actual = SubjStats_freeplay(~isnull_freeplay);
SubjStats_freeplay_null = SubjStats_freeplay(isnull_freeplay);

nsub = sum(~isnull_puzzle);
nnull = sum(isnull_puzzle);
clear SubjStats_puzzle SubjStats_freeplay;

save('EmoGrow_DBDOS_2a_SubjStats-actual.mat','SubjStats_puzzle_actual','SubjStats_freeplay_actual','job','-v7.3');

%% Estimate the null distribution and adjust the observed values to compensate
% Extract the computed synchrony values
Rs_puzzle_actual = nan(nch,nch,nsub);
Rs_puzzle_null = nan(nch,nch,nnull);
Rs_freeplay_actual = nan(nch,nch,nsub);
Rs_freeplay_null = nan(nch,nch,nnull);
for i = 1:nsub
    Rs_puzzle_actual(:,:,i) = SubjStats_puzzle_actual(i).R(1:end/2, end/2+1:end);
    Rs_freeplay_actual(:,:,i) = SubjStats_freeplay_actual(i).R(1:end/2, end/2+1:end);
end
for i = 1:nnull
    Rs_puzzle_null(:,:,i) = SubjStats_puzzle_null(i).R(1:end/2, end/2+1:end);
    Rs_freeplay_null(:,:,i) = SubjStats_freeplay_null(i).R(1:end/2, end/2+1:end);
end
clear SubjStats_null;

save('EmoGrow_DBDOS_2b_SubjStats-all-values.mat','Rs_puzzle_actual','Rs_puzzle_null','Rs_freeplay_actual','Rs_freeplay_null','-v7.3');

% Convert correlations to absolute synchrony
Rs_puzzle_actual = abs(Rs_puzzle_actual);
Rs_puzzle_null = abs(Rs_puzzle_null);
Rs_freeplay_actual = abs(Rs_freeplay_actual);
Rs_freeplay_null = abs(Rs_freeplay_null);

% Pool the null data from all channels and subjects
Rs_puzzle_null = permute(Rs_puzzle_null(:),[2 3 4 1]);
Rs_freeplay_null = permute(Rs_freeplay_null(:),[2 3 4 1]);

% Perform the perumtation test by calculating the probability of the observed 
% synchrony values coming from the null distribution. This is done by simply 
% calculating the proportion of null synchrony instances that were larger than the
% observed data. The p-values here is bounded to (1/Nnull, 1-1/Nnull)
prob_puzzle = nan(nch,nch,nsub);
prob_freeplay = nan(nch,nch,nsub);
for i = 1:nsub
    prob_puzzle(:,:,i) = (sum(Rs_puzzle_null>=Rs_puzzle_actual(:,:,i),4)+1) ./ (size(Rs_puzzle_null,4)+2);
    prob_freeplay(:,:,i) = (sum(Rs_freeplay_null>=Rs_freeplay_actual(:,:,i),4)+1) ./ (size(Rs_freeplay_null,4)+2);
end

% Generate the adjusted values from these p-values using the cdf for the standard normal distribution.
% The observed values way greater than the null distribution (p-value near 0) get large Z-values,
% while those much lower than the null (p-value near 1) get large negative Z-values, and those in
% the middle of the null distribution (p-value near 0.5) get a Z-value near zero.
Zs_puzzle_adjusted = norminv(1-prob_puzzle);
Zs_freeplay_adjusted = norminv(1-prob_freeplay);

% Convert to r-values and put into SubjStats_adjusted
SubjStats_puzzle_adjusted = SubjStats_puzzle_actual;
SubjStats_freeplay_adjusted = SubjStats_freeplay_actual;
for i=1:nsub
    R = tanh(Zs_puzzle_adjusted(:,:,i)); % tanh() = Fisher's Z-to-R conversion
    SubjStats_puzzle_adjusted(i).R(:) = nan;
    SubjStats_puzzle_adjusted(i).R(1:end/2,end/2+1:end) = R;
    SubjStats_puzzle_adjusted(i).R(end/2+1:end,1:end/2) = R';
    
    R = tanh(Zs_freeplay_adjusted(:,:,i)); % tanh() = Fisher's Z-to-R conversion
    SubjStats_freeplay_adjusted(i).R(:) = nan;
    SubjStats_freeplay_adjusted(i).R(1:end/2,end/2+1:end) = R;
    SubjStats_freeplay_adjusted(i).R(end/2+1:end,1:end/2) = R';
end

%% Combine the null-adjusted version of both conditions
SubjStats_adjusted = repmat(nirs.core.sFCStats,[nsub 1]);
for i=1:length(SubjStats_adjusted)
    
    Sp = SubjStats_puzzle_adjusted(i);
    Sf = SubjStats_freeplay_adjusted(i);
    assert(isequal(Sp.demographics{1}('Name'),Sf.demographics{1}('Name')),'Mismatch');
    assert(isequal(Sp.demographics{2}('Name'),Sf.demographics{2}('Name')),'Mismatch');
    
    SubjStats_adjusted(i) = Sp;
    SubjStats_adjusted(i).R(:,:,2) = Sf.R;
    SubjStats_adjusted(i).dfe(2) = Sf.dfe;
    SubjStats_adjusted(i).conditions = {'Puzzle','FreePlay'};
    
end
demo = nirs.createDemographicsTable2(SubjStats_adjusted);

clear SubjStats_puzzle_adjusted SubjStats_freeplay_adjusted;

%% Save subject-level observed and null-adjusted results
save('EmoGrow_DBDOS_2c_SubjStats-adjusted.mat','SubjStats_adjusted','demo','-v7.3');

%% Remove outlier subjects
Zs = nan(nsub,nch,nch,2);
for i=1:nsub
    Zs(i,:,:,:) = SubjStats_adjusted(i).Z(1:end/2,end/2+1:end,:);
end
isoutlier = any(any(any(abs(zscore(Zs)) > 4 ,4),3),2);
outliers = demo.Name(isoutlier);
isoutlier = contains(demo.Name,outliers); % Remove all scans from an outlier subject (not just the outlier scan)
SubjStats_adjusted(isoutlier) = [];
demo(isoutlier,:) = [];

%% Add Time as a continuous analog of Visit so we can do a regression
for i = 1:length(SubjStats_adjusted)
    SubjStats_adjusted(i).demographics{1}('Time') = (1+str2double(strrep(SubjStats_adjusted(i).demographics{1}('Visit'),'V','')))/2;
    SubjStats_adjusted(i).demographics{2}('Time') = (1+str2double(strrep(SubjStats_adjusted(i).demographics{2}('Visit'),'V','')))/2;
end

%% Run the group-level analysis
job = nirs.modules.MixedEffectsConnectivity();
job.formula='beta ~ -1 + cond + cond:Time + (1|Name)';

GroupStats = job.run( SubjStats_adjusted );

%% Save group-level results
save('EmoGrow_DBDOS_3_GroupStats.mat','GroupStats','outliers','-v7.3');

%% Extract subject-level values for peak and mean synchrony
[sync_mean_puzzle,~,idx_signif_puzzle] = nirs.util.extractMeanData( SubjStats_adjusted, GroupStats, 'Puzzle', 'Puzzle:Time', 'q<.05');
[sync_peak_puzzle] = nirs.util.extractPeakData( SubjStats_adjusted, GroupStats, 'Puzzle', 'Puzzle:Time');

[sync_mean_freeplay,~,idx_signif_freeplay] = nirs.util.extractMeanData( SubjStats_adjusted, GroupStats, 'FreePlay', 'FreePlay:Time', 'q<.05');
[sync_peak_freeplay] = nirs.util.extractPeakData( SubjStats_adjusted, GroupStats, 'FreePlay', 'FreePlay:Time');

%% Separate by Visit
demo = nirs.createDemographicsTable(SubjStats_adjusted);
isV1 = strcmp(demo.Visit,'V1');
isV3 = strcmp(demo.Visit,'V3');

% Check that the subject order matches
assert(isequal(demo.Name(isV1),demo.Name(isV3)),'Subject mismatch');

sync_mean_puzzle_V1 = sync_mean_puzzle(isV1);
sync_mean_puzzle_V3 = sync_mean_puzzle(isV3);
sync_peak_puzzle_V1 = sync_peak_puzzle(isV1);
sync_peak_puzzle_V3 = sync_peak_puzzle(isV3);

sync_mean_freeplay_V1 = sync_mean_freeplay(isV1);
sync_mean_freeplay_V3 = sync_mean_freeplay(isV3);
sync_peak_freeplay_V1 = sync_peak_freeplay(isV1);
sync_peak_freeplay_V3 = sync_peak_freeplay(isV3);

%% Get change across visits
sync_mean_puzzle_diff = sync_mean_puzzle_V3 - sync_mean_puzzle_V1;
sync_peak_puzzle_diff = sync_peak_puzzle_V3 - sync_peak_puzzle_V1;
sync_mean_freeplay_diff = sync_mean_freeplay_V3 - sync_mean_freeplay_V1;
sync_peak_freeplay_diff = sync_peak_freeplay_V3 - sync_peak_freeplay_V1;

%% Save mean and peak synchrony values for correlation analysis
save('EmoGrow_DBDOS_4_extracted.mat',...
    'sync_mean_puzzle_V1','sync_mean_puzzle_V3','sync_mean_puzzle_diff',...
    'sync_peak_puzzle_V1','sync_peak_puzzle_V3','sync_peak_puzzle_diff',...
    'sync_mean_freeplay_V1','sync_mean_freeplay_V3','sync_mean_freeplay_diff',...
    'sync_peak_freeplay_V1','sync_peak_freeplay_V3','sync_peak_freeplay_diff' );

demo = demo(isV1,:);
demo.sync_mean_puzzle_V1 = sync_mean_puzzle_V1;
demo.sync_mean_puzzle_V3 = sync_mean_puzzle_V3;
demo.sync_mean_puzzle_diff = sync_mean_puzzle_diff;

demo.sync_peak_puzzle_V1 = sync_peak_puzzle_V1;
demo.sync_peak_puzzle_V3 = sync_peak_puzzle_V3;
demo.sync_peak_puzzle_diff = sync_peak_puzzle_diff;

demo.sync_mean_freeplay_V1 = sync_mean_freeplay_V1;
demo.sync_mean_freeplay_V3 = sync_mean_freeplay_V3;
demo.sync_mean_freeplay_diff = sync_mean_freeplay_diff;

demo.sync_peak_freeplay_V1 = sync_peak_freeplay_V1;
demo.sync_peak_freeplay_V3 = sync_peak_freeplay_V3;
demo.sync_peak_freeplay_diff = sync_peak_freeplay_diff;

writetable(demo,'EmoGrow_DBDOS_4_extracted.xlsx');

%% Print results
fprintf('Significant change in synchrony during Puzzle found for %i channel-pairs\n',length(idx_signif_puzzle));
fprintf('Significant change in synchrony during FreePlay found for %i channel-pairs\n',length(idx_signif_freeplay));

%% Draw figures
EmoGrow.draw_hyperscan_3D(GroupStats,'q<.05',[-4 4],'Puzzle');
print(gcf,'Puzzle.png','-r300','-dpng');
close(gcf);

EmoGrow.draw_hyperscan_3D(GroupStats,'q<.05',[-4 4],'FreePlay');
print(gcf,'FreePlay.png','-r300','-dpng');
close(gcf);

EmoGrow.draw_hyperscan_3D(GroupStats,'q<.05',[-4 4],'Puzzle:Time');
print(gcf,'Puzzle_x_Time.png','-r300','-dpng');
close(gcf);

EmoGrow.draw_hyperscan_3D(GroupStats,'q<.05',[-4 4],'FreePlay:Time');
print(gcf,'FreePlay_x_Time.png','-r300','-dpng');
close(gcf);

end
