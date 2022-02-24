function draw_hyperscan_3D(connstats,pthr,scale,condition,useZ)
if ~exist('pthr','var') || isempty(pthr), pthr='q<.05'; end
if ~exist('scale','var') || isempty(scale), scale = [-4 4]; end
if ~exist('condition','var') || isempty(condition), condition=[]; end
if ~exist('useZ','var') || isempty(useZ), useZ=false; end

linewid=6;  % line width

if isempty(condition)
    if length(connstats.conditions)>1
        error('Please specify which condition to draw: %s',strjoin(connstats.conditions,', '));
    end
    condition = connstats.conditions{1};
else
    if ~contains(connstats.conditions,condition)
        error('Condition "%s" not found',condition);
    end
end

connstats = connstats.ttest(condition);

SD.SrcPos=[];
SD.DetPos=[];

% Specify bottom head
SD.SrcPos(1,:)=[7007  369]; %
SD.SrcPos(2,:)=[6600  627]; %
SD.SrcPos(3,:)=[6182 1133]; %
SD.SrcPos(4,:)=[5935 1315]; %
SD.SrcPos(5,:)=[5935 2464]; %
SD.SrcPos(6,:)=[6188 2635]; %
SD.SrcPos(7,:)=[6705 3185]; %
SD.SrcPos(8,:)=[7150 3377]; %

SD.DetPos(1,:)=[6699  462]; %
SD.DetPos(2,:)=[6204  809]; %
SD.DetPos(3,:)=[6260 2950]; %
SD.DetPos(4,:)=[6840 3322]; %

% Specify top head
SD.SrcPos(8+1,:)=[2921 3405];
SD.SrcPos(8+2,:)=[3328 3146];
SD.SrcPos(8+3,:)=[3746 2629];
SD.SrcPos(8+4,:)=[3993 2448];
SD.SrcPos(8+5,:)=[3993 1304];
SD.SrcPos(8+6,:)=[3740 1139];
SD.SrcPos(8+7,:)=[3223  583];
SD.SrcPos(8+8,:)=[2778  396];

SD.DetPos(4+1,:)=[3223 3317];
SD.DetPos(4+2,:)=[3713 2970];
SD.DetPos(4+3,:)=[3674  825];
SD.DetPos(4+4,:)=[3091  468];

SD.SrcPos = fliplr(SD.SrcPos);
SD.DetPos = fliplr(SD.DetPos);

SD.SrcPos = SD.SrcPos * .09;
SD.DetPos = SD.DetPos * .09;

link=connstats.table;

lstValid=ismember(link.TypeDest,link.TypeOrigin{1}) &...
    ismember(link.TypeOrigin,link.TypeOrigin{1});

if exist('condition','var')
    lstValid = lstValid & strcmpi(link.condition,condition);
end
lstValid = find(lstValid);
link=link(lstValid,:);

figure;
if useZ
    tstat = link.Z;
else
    tstat = link.t;
end
if(~contains(pthr,'q'))
    pval=link.pvalue;
else
    pval=link.qvalue;
end
pval(abs(tstat)==Inf)=1;
tstat(abs(tstat)==Inf)=0;

pthr=str2num(pthr(strfind(pthr,'<')+1:end));

img_dir = fileparts(which('EmoGrow.draw_hyperscan_3D'));
img_hyperscan = fullfile(img_dir,'hyperscan.png');
img_probe = fullfile(img_dir,'hyperscan_probe.png');
J=imread(img_hyperscan);
[K,~,Kalpha]=imread(img_probe);

imshow(J);
set(gcf,'Renderer','Painters');

hold on;

if(nargin<4)
    GCmax=max(abs(tstat(:)));
    GCmin=-GCmax;
    if(isempty(GCmin)), GCmin=0; end;
else
    GCmax=scale(2);
    GCmin=scale(1);
end

tstat(tstat<GCmin) = GCmin;
tstat(tstat>GCmax) = GCmax;

caxis([GCmin GCmax]);

if GCmin<0
    [~,cmap] = evalc('flipud( cbrewer(''seq'',''YlOrRd'',500) )');
    cmap = flipud([cmap; 1 1 1; flipud(cmap(:,[3 2 1]))]);
else
    [~,cmap] = evalc('flipud( cbrewer(''seq'',''YlOrRd'',1001) )');
    cmap = flipud(cmap);
end
colormap(cmap);
cm=colormap;

hold on;
cnt=1;
midpt = [];
probelink = table([],[],'VariableNames',{'source','detector'});
for i=1:height(connstats.probe.link)
    if iscell(connstats.probe.link.source(i))
        sI=connstats.probe.link.source{i};
        dI=connstats.probe.link.detector{i};
    else
        sI=connstats.probe.link.source(i);
        dI=connstats.probe.link.detector(i);
    end
    for j=1:length(sI)
        sp=SD.SrcPos(sI(j),:);
        dp=SD.DetPos(dI(j),:);
        probelink(end+1,:) = table(sI(j),dI(j));
        midpt(end+1,:)=(sp+dp)/2;
        cnt=cnt+1;
    end
end

l=[];
GCline=[];
[~,sortidx] = sort(abs(tstat),'ascend');
for ind=1:length(lstValid)
    i = sortidx(ind);
    sIO=link.SourceOrigin(i);
    dIO=link.DetectorOrigin(i);
    sID=link.SourceDest(i);
    dID=link.DetectorDest(i);
    if iscell(sIO)
        sIO = sIO{1};
        dIO = dIO{1};
        sID = sID{1};
        dID = dID{1};
    end
    
    origs = find(any(probelink.source==sIO & probelink.detector==dIO,2));
    dests = find(any(probelink.source==sID & probelink.detector==dID,2));
    
    for j = 1:length(origs)
        for k = 1:length(dests)
            Orig = origs(j);
            Dest = dests(k);

            Vthis=tstat(i);
            pthis=pval(i);

            c(1)=interp1([0:1/(size(cm,1)-1):1]*(GCmax-GCmin)+GCmin,cm(:,1),Vthis);
            c(2)=interp1([0:1/(size(cm,1)-1):1]*(GCmax-GCmin)+GCmin,cm(:,2),Vthis);
            c(3)=interp1([0:1/(size(cm,1)-1):1]*(GCmax-GCmin)+GCmin,cm(:,3),Vthis);

            if any(isnan(c)), continue; end

            if(pthis<=pthr)
                    GCline(end+1)=line([midpt(Orig,1) midpt(Dest,1)],[midpt(Orig,2) midpt(Dest,2)]);
                    set(GCline(end),'Color',c);
            end
        end
    end
end

hold on;

colormap(gca,cmap);
set(GCline,'linewidth',linewid)
set(gca,'Fontsize',24)
set(gcf,'Color','w')
set(gca,'Xtick',[],'Ytick',[])
image(K,'AlphaData',Kalpha);
axis off
