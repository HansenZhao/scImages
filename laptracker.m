function [ res,costs,distance ] = laptracker( sourcePos,targetPos,sourceArea,tarArea,maxDist,af,histDistCosts )
    % ref:  Jaqaman, K.; Loerke, D.; Mettlen, M.; Kuwata, H.; Grinstein, S.; 
    % Schmid, S. L.; Danuser, G. Nat. Methods 2008, 5, 695
%     AREA_FACTOR = 9;
    ESTBOOST = 1.2;
%     CUTOFF_AREA_RATIO = 1.25;
%     SIZE_L_VAR = 0.85;
%     SIZE_H_VAR = 1.5;
    
    if size(sourcePos,1) ~= size(maxDist,1)
        error('size of source pos should be consist with size of maxDist, get %d and %d',...
            size(sourcePos,1),size(maxDist,1))
    end
    ns = size(sourcePos,1);
    nt = size(targetPos,1);
    distMat = pdist2(sourcePos,targetPos,'squaredeuclidean');
    ULCostMat = distMat;
    ULCostMat(ULCostMat>repmat(maxDist(:).^2,1,nt)) = inf;
    
    NNCost = pdist2(sourcePos,sourcePos,'squaredeuclidean');
    NNCost = NNCost + eye(ns)*max(NNCost(:));
    NNCost = min(NNCost,[],2);
    NNTerminCost = median(NNCost);
    
    if ~exist('histDistCosts','var') || isempty(histDistCosts)
        sourceMinCost = min(ULCostMat,[],2);
        I = or(isnan(sourceMinCost),isinf(sourceMinCost));
        estTerminCost = min([max(sourceMinCost(~I))*1.05,NNTerminCost]); %nearest neighbor costs
    else
        estTerminCost = min([max(histDistCosts),NNTerminCost]);
    end
%     disp(estTerminCost);
    if af > 0
%         ratio = tarArea(:)' ./ sourceArea;
%         areaFrac = (sourceArea - min(sourceArea))/(max(sourceArea)-min(sourceArea));
%         I = areaFrac > 0.5;
%         areaFracModify = 2*(1-SIZE_L_VAR)*areaFrac + SIZE_L_VAR;
%         areaFracModify(I) = 2*(SIZE_H_VAR-1)*areaFrac(I) + 2 - SIZE_H_VAR;
%         areaCost = max(ratio,1./ratio).^repmat(AREA_FACTOR*areaFracModify,[1,nt])-1;
%         if CellTrackController.DEBUG_MODE
%             figure;
%             imagesc(subplot(221),ULCostMat);
%             imagesc(subplot(222),af*areaCost);
%             histogram(subplot(223),ULCostMat(:),100);
%             histogram(subplot(224),af*areaCost(:),100);
%         end
        ULCostMat = ULCostMat + estTerminCost * areaCost(sourceArea,tarArea);
    end
    URCostMat = inf(ns);
    URCostMat(logical(eye(ns))) = estTerminCost*ESTBOOST;
    LLCostMat = inf(nt);
    LLCostMat(logical(eye(nt))) = estTerminCost*ESTBOOST;
    costMat = [ULCostMat,URCostMat;LLCostMat,ULCostMat'];
    % https://www.mathworks.com/matlabcentral/fileexchange
    % /26836-lapjv-jonker-volgenant-algorithm-for-linear-assignment-problem-v3-0
    % Yi Cao
    res = lapjv(costMat,min(costMat(:))/10); 
    costs = zeros(ns+nt,1);
    distance = zeros(ns,1);
    for m = 1:(ns+nt)
        if m <= ns
            if res(m) <= nt
                costs(m) = costMat(m,res(m));
                distance(m) = distMat(m,res(m));
%                 if af > 0 && costs(m) > estTerminCost
%                     fprintf('%d->%d,cost: %.2f,ratio: %.2f, area frac: %.2f, distance: %.2f\n',...
%                         m,res(m),costs(m),(areaCost(m,res(m))+1)^(1/AREA_FACTOR),areaFrac(m),distMat(m,res(m)));
%                     disp('s');
%                 end
            else
                costs(m) = estTerminCost;
            end
        else
            if res(m) <= nt
                costs(m) = estTerminCost;
            else
                costs(m) = costMat(m,res(m));
            end
        end
    end
%     if CellTrackController.DEBUG_MODE
%         figure;
%         histogram(costs,100);
%         hold on;
%         plot(ones(2,1)*estTerminCost,[0,ns+nt],'r--');
%     end
end

