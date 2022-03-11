function raw = add_demographics(raw,rootdir)
% Load EmoGrow demographic data from tracking form, IQ form, CBQ form, and MAP-DB form
if ~exist('rootdir','var') || isempty(rootdir)
    rootdir = pwd;
end
trackingform = [rootdir filesep 'R01-EmoGrow Tracking Form.xlsx'];
IQform = [rootdir filesep 'KBIT2.xlsx'];
ARIform = [rootdir filesep 'ARI(Q1-6) EmoGrow Full Study.xlsx'];
MAPform = [rootdir filesep 'MAP Emogrow Full Study.xlsx'];
CBQform = [rootdir filesep 'CBQ EmoGrow Full Study.xlsx'];
PRQform = [rootdir filesep 'PRQ Emogrow Full Study.xlsx'];
NEOform = [rootdir filesep 'NEO Emogrow Full Study.xlsx'];
CCNESform = [rootdir filesep 'CCNES EmoGrow Full Study.xlsx'];

warning('off','MATLAB:table:ModifiedVarnames');
warning('off','MATLAB:table:RowsAddedNewVars');

track = readtable( trackingform );
IQ = readtable( IQform );
ARI = readtable( ARIform );
MAP = readtable( MAPform );
CBQ = readtable( CBQform );
PRQ = readtable( PRQform );
NEO = readtable( NEOform );

% Make the ARI irritability name more descriptive
ARI.Properties.VariableNames = strrep(ARI.Properties.VariableNames,'Irritability','ARI_irritability');

% Split raw and T rows of the NEO into separate columns
neosub = NEO(strcmpi(NEO.Var2,'Raw Score'),1);
neoraw = NEO(strcmpi(NEO.Var2,'Raw Score'),3:end);
neot = NEO(strcmpi(NEO.Var2,'T Score'),3:end);
neoraw.Properties.VariableNames = strcat(neoraw.Properties.VariableNames,'_raw');
neot.Properties.VariableNames = strcat(neot.Properties.VariableNames,'_T');
NEO = [neosub neoraw neot];

opts = detectImportOptions(CCNESform);
CCNES = readtable(CCNESform,opts);

IQ2 = table( IQ.SubjectID , IQ.Vocabulary_StandardScore , IQ.Matrices_StandardScore , IQ.IQComposite );
IQ2.Properties.VariableNames = {'SubjectID','IQ_verbal','IQ_quantitative','IQ'};

for i = 1:height(track)
    track.Name(i) = { sprintf('%03i',track.SubjectID(i)) };
end
for i = 1:height(IQ2)
    IQ2.Name(i) = { sprintf('%03i',IQ2.SubjectID(i)) };
end
for i=1:height(CBQ)
    CBQ.Name(i) = { sprintf('%03i',CBQ.Subject_(i)) };
end
for i=1:height(MAP)
    MAP.Name(i) = { sprintf('%03i',MAP.SubjectID(i)) };
end
for i=1:height(ARI)
    ARI.Name(i) = { sprintf('%03i',ARI.SubjectID_V1_(i)) };
end
for i=1:height(PRQ)
    PRQ.Name(i) = { sprintf('%03i',PRQ.SubjectID(i)) };
end
for i=1:height(NEO)
    NEO.Name(i) = { sprintf('%03i',NEO.SubjectNumber(i)) };
end
for i=1:height(CCNES)
    CCNES.Name(i) = { sprintf('%03i',CCNES.SubjectID(i)) };
end

track.SubjectID = [];
IQ2.SubjectID = [];
ARI.SubjectID_V1_ = [];
MAP.SubjectID = [];
CBQ.Subject_ = [];
NEO.SubjectNumber = [];
CCNES.SubjectID = [];

logMAP = MAP; MAPnames = MAP.Properties.VariableNames;
for i=1:height(logMAP)
    for j = 1:length(MAPnames)-1
        logMAP.(MAPnames{j})(i) = log( 1 + MAP.(MAPnames{j})(i) );
    end
end
for j = 1:length(MAPnames)-1
    MAPnames{j} = ['log' MAPnames{j}];
end
logMAP.Properties.VariableNames = MAPnames;

warning('on','MATLAB:table:ModifiedVarnames');
warning('on','MATLAB:table:RowsAddedNewVars');

demo = outerjoin( track , IQ2 , 'Key' , 'Name' , 'Type' , 'Left' , 'MergeKeys' , true );
demo = outerjoin( demo , CBQ , 'Key' , 'Name' , 'Type' , 'Left' , 'MergeKeys' , true );
demo = outerjoin( demo , MAP , 'Key' , 'Name' , 'Type' , 'Left' , 'MergeKeys' , true );
demo = outerjoin( demo , logMAP , 'Key' , 'Name' , 'Type' , 'Left' , 'MergeKeys' , true );
demo = outerjoin( demo , PRQ , 'Key' , 'Name' , 'Type' , 'Left' , 'MergeKeys' , true );
demo = outerjoin( demo , ARI , 'Key' , 'Name' , 'Type' , 'Left' , 'MergeKeys' , true );
demo = outerjoin( demo , NEO , 'Key' , 'Name' , 'Type' , 'Left' , 'MergeKeys' , true );
demo = outerjoin( demo , CCNES , 'Key' , 'Name' , 'Type' , 'Left' , 'MergeKeys' , true );

demo.Age = demo.AgeInMonths/12;
demo.IsMale = strcmpi( demo.Gender , 'M' );
demo.IQ = demo.KBIT;
demo.IQ_verbal = demo.KBITVocabulary_Standard;
demo.IQ_quantitative = demo.KBITMatrices_Standard;
demo.subject = demo.Name;

% Label subjects with eyetracker IR noise
demo.HasEyetracker = false(height(demo),1);
eyetracker_subject_list = {'001', '002', '003', '004', '005', '006', '007', '008' ...
                  , '009', '010', '011', '013', '014', '015', '016', '017' ...
                  , '018', '020', '021', '022', '023', '030' };
for i = 1:height(demo)
    if any(strcmp(eyetracker_subject_list,demo.Name{i}))
        demo.HasEyetracker(i) = true;
    end
end

% Specify parent or child
for i = 1:length(raw)
    if raw(i).demographics('Age') > 0
        raw(i).demographics('IsChild') = true;
    else
        raw(i).demographics('IsChild') = false;
    end
end

% Attach demographics to nirs data (only for subjects that have it)
job = nirs.modules.AddDemographics();
job.varToMatch = 'Name';
job.allowMissing = true;
job.demoTable = demo;
raw = job.run( raw );

end
