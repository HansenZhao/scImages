function [ res,costs ] = laptracker( source,target,maxDist )
    % ref:  Jaqaman, K.; Loerke, D.; Mettlen, M.; Kuwata, H.; Grinstein, S.; 
    % Schmid, S. L.; Danuser, G. Nat. Methods 2008, 5, 695
    ns = size(source,1);
    nt = size(target,1);
    ULCostMat = pdist2(source,target,'squaredeuclidean');
    ULCostMat(ULCostMat>power(maxDist,2)) = inf;
    estTerminCost = max(min(ULCostMat,[],2))*1.05;
    URCostMat = inf(ns);
    URCostMat(logical(eye(ns))) = estTerminCost;
    LLCostMat = inf(nt);
    LLCostMat(logical(eye(nt))) = estTerminCost;
    costMat = [ULCostMat,URCostMat;LLCostMat,ULCostMat'];
    % https://www.mathworks.com/matlabcentral/fileexchange
    % /26836-lapjv-jonker-volgenant-algorithm-for-linear-assignment-problem-v3-0
    % Yi Cao
    res = lapjv(costMat,min(costMat(:))/10); 
    costs = zeros(ns+nt,1);
    for m = 1:(ns+nt)
        costs(m) = costMat(m,res(m));
    end
end

