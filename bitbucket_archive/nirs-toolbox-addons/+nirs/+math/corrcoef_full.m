function [r,p]=corrcoef_full(d,verbose,mask)
% This is the corrcoef function without downweighting
%
% This is a robust version of the corrcoef function
% Based on Shevlyakov and Smirnov (2011). Robust Estimation of the
% Correlation Coeficient: An Attempt of Survey.  Austrian J. of Statistics.
%  40(1&2) pp. 147-156


if(nargin<2 || isempty(verbose))
    verbose=false;
end

if(nargin<3)
    mask=ones(size(d));
end
mask = mask & ~isnan(d);
d(isnan(d)) = 0;

% d=bsxfun(@minus,d,median(d,1));
% d=bsxfun(@rdivide,d,1.4826*mad(d,1,1));

% all pairwise combinations
r=ones(size(d,2));
n=size(d,2)^2;

if(verbose)
    disp('Progress');
    str='  0';
    fprintf('%s %%',str(end-2:end));
end


cnt=1;
for i=1:size(d,2)
    for j=1:size(d,2)
        if(verbose)
            str=['   ' num2str(round(100*cnt/n))];
            fprintf('\b\b\b\b\b%s %%',str(end-2:end));
        end
        warning('off','stats:statrobustfit:IterationLimit')
        lst=find(mask(:,i) & mask(:,j));
         
        rs=regress(d(lst,i),[ones(length(lst),1) d(lst,j)]);
        r(i,j)=rs(2);
        cnt=cnt+1;
    end
end
if(verbose)
    disp('completed');
end
% Section 2.3 Eqn 6
% r = sqrt(b1*b2)
r=sign(r+r').*abs(sqrt(r.*r'));
r(abs(r)>1) = fix(r(abs(r)>1));

n=sum(mask(:,1));

Tstat = r .* sqrt((n-2) ./ (1 - r.^2));
p = 2*nirs.math.tpvalue(-abs(Tstat),n-2);
p=p+eye(size(p));

end

% function w = wfun(r)
% s = mad(r, 0) / 0.6745;
% r = r/s/4.685;
% 
% w = (1 - r.^2) .* (r < 1 & r > -1);
% end