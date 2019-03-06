classdef CellTrackController < matlab.mixin.Copyable
    
    properties(SetAccess = private)
        nFrame;
        csfObjs;
        trackArray;
        trackCost;
        trackDist;
        trackNNDist;
        trackArea;
        globalLinkDist;
        curFrame;
    end
    
    properties(Dependent)
        nTrack;
        trackLength;
        inferMaxDist;
        inferAreaFac;
        curCSF;
    end
    
    properties(Constant)
        DEBUG_MODE = 1;
        MAX_REF_STEP = 6;
        FRAME_SIZE = 512;
    end
    
    methods
        function obj = CellTrackController(initObj,nFrame)
            obj.nFrame = nFrame;
            obj.csfObjs = cell(nFrame,1);
            [obj.trackArray,obj.trackCost,obj.trackDist,obj.trackNNDist,...
                obj.trackArea] = deal(cell(initObj.nCell,1));
            obj.curFrame = 1;
            obj.globalLinkDist = cell(nFrame,1);
            nnd = initObj.NNDistance;
            for m = 1:obj.nTrack
                obj.trackArray{m} = obj.initTrackArray(m,1); %>0:link index, 0: no link, -1:not exist
                obj.trackCost{m} = obj.initTrackArray(eps,1);%eps:begin of track
                obj.trackDist{m} = obj.initTrackArray(eps,1);
                obj.trackNNDist{m} = obj.initTrackArray(nnd(m),1);
                obj.trackArea{m} = obj.initTrackArray(initObj.cellArea(m),1);
            end
            obj.csfObjs{1} = initObj;
        end
        
        function nt = get.nTrack(obj)
            nt = length(obj.trackArray);
        end
        
        function tl = get.trackLength(obj)
            [~,ticks] = obj.getAllTracks(1,obj.nFrame);
            tl = cellfun(@(x)x(end)-x(1)+1,ticks);
        end
        
        function md = get.inferMaxDist(obj)
            ns = obj.curCSF.nCell;
            md = zeros(ns,1);
            for m = 1:ns
                md(m) = obj.getMaxDist(obj.curFrame,m);
            end
        end
        
        function af = get.inferAreaFac(obj)
            if obj.curFrame == 1
                af = obj.csfObjs{1}.estAreaFactor;
                return;
            else
                st = max([1,obj.curFrame-CellTrackController.MAX_REF_STEP+1]);
                afs = cellfun(@(x)x.estAreaFactor,obj.csfObjs(st:obj.curFrame));
                af = mean(afs);
                return;
            end
        end
        
        function csf = get.curCSF(obj)
            csf = obj.csfObjs{obj.curFrame};
        end
        
        function tID = cellIndex2trackID(obj,index,frame)
            if ~exist('frame','var')
                frame = obj.curFrame;
            end
            searchRes = cellfun(@(x)x(frame)==index,obj.trackArray);
            tID = find(searchRes);
        end
        
        function commitNew(obj,csfObj,maxDist,af)
            if ~exist('af','var') || ~isnumeric(af)
                af = obj.inferAreaFac;
            end
            ns = obj.csfObjs{obj.curFrame}.nCell;
            nt = csfObj.nCell;
            if CellTrackController.DEBUG_MODE
                fprintf(1,'commit %d->%d: %d cells to %d cells, area factor: %.3f\n',...
                    obj.curFrame,obj.curFrame+1,ns,nt,af)
            end
            if obj.curFrame==162
                disp('s');
            end
            [linkRes,costs,linkDist] = laptracker(obj.csfObjs{obj.curFrame}.cellPos,...
                csfObj.cellPos,obj.csfObjs{obj.curFrame}.cellArea,...
                csfObj.cellArea,maxDist,af,cell2mat(obj.globalLinkDist(1:obj.curFrame))); %af = -1 : disable
            nnd = csfObj.NNDistance;
            for m = 1:(ns+nt)
                r = linkRes(m);
                if m <= ns 
                    trackID = obj.cellIndex2trackID(m);
                    if r <= nt %valid link
                        obj.pushTrackData(trackID,m,r,costs(m),nnd(r),csfObj.cellArea(r),linkDist(m));
                    else %end of track
                        obj.pushTrackData(trackID,m,0,costs(m),0,0,0);
                    end
                elseif r <= nt %begin of link
                    obj.pushTrackData(-1,m,r,costs(m),nnd(r),csfObj.cellArea(r),-1);
                end
            end
            obj.curFrame = obj.curFrame + 1;
%             obj.globalLinkDist{obj.curFrame} = linkDist;
            obj.globalLinkDist{obj.curFrame} = costs;
            obj.csfObjs{obj.curFrame} = csfObj;
        end
        
        function rollBackTo(obj,frame)
            if ~exist('frame','var')
                frame = obj.curFrame - 1;
            end
            if frame > obj.curFrame
                error('frame must by less than %d, get %d',obj.curFrame,frame);
            end
            if frame == obj.curFrame
                return
            end
            isExist = cellfun(@(x)x(frame) >= 0,obj.trackArray);
            if CellTrackController.DEBUG_MODE
                fprintf(1,'rollback %d->%d: %d tracks to be deleted\n',...
                    obj.curFrame,frame,sum(~isExist))
            end
            obj.trackArray(~isExist) = [];
            obj.trackCost(~isExist) = [];
            obj.trackDist(~isExist) = [];
            obj.trackNNDist(~isExist) = [];
            obj.trackArea(~isExist) = [];
            obj.curFrame = frame;
        end
        
        function [xy,se] = getTrackPos(obj,trackID)
            se = obj.getTrackRange(trackID);
            L = range(se)+1;
            xy = zeros(L,2);
            for m = 1:L
                frame = se(1)+m-1;
                csfObj = obj.csfObjs{frame};
                cellId = obj.trackArray{trackID}(frame);
                try
                    xy(m,:) = csfObj.cellPos(cellId,:);
                catch
                    xy(m,:) = [nan,nan];
                end
            end
        end
        
        function [tracks,ticks,areas] = getAllTracks(obj,stepFrom,stepTo)
            tracks = cell(obj.nTrack,1);
            ticks = cell(obj.nTrack,1);
            areas = cell(obj.nTrack,1);
            count = 1;
            for m = 1:obj.nTrack
                [xy,se] = obj.getTrackPos(m);
                index = (se(1):1:se(2))';
                I = and(index>=stepFrom,index<=stepTo);
                if isempty(I)
                    continue;
                end
                tracks{count} = xy(I,:);
                ticks{count} = index(I);
                areas{count} = obj.trackArea{m}(index(I));
                count = count + 1;
            end
            tracks((count+1):end) = [];
            ticks((count+1):end) = [];
        end
        
        function [tracks,ticks] = showTrack(obj,hA,stepTo,stepFrom,dim)
            if ~exist('hA','var')
                hf = figure;
                hA = axes('Parent',hf);
            end
            if ~exist('stepTo','var')
                stepTo = obj.curFrame;
            end
            if ~exist('stepFrom','var')
                stepFrom = 1;
            end
            if ~exist('dim','var')
                dim = 2;
            end
            if stepTo==stepFrom
                hA.NextPlot = 'add';
                obj.csfObjs{stepTo}.scatterCentroid(hA);
                hA.NextPlot = 'replace';
                return;
            end
            [tracks,ticks] = obj.getAllTracks(stepFrom,stepTo);
            arrTracks = cell2mat(tracks);
            arrticks = cell2mat(ticks);
            hA.NextPlot = 'add';
            if dim == 2
                scatter(hA,arrTracks(:,1),arrTracks(:,2),15,arrticks,'filled');
            else
                scatter3(hA,arrTracks(:,1),arrTracks(:,2),arrticks,25,arrticks,'filled');
            end
            for m = 1:length(tracks)
                if dim == 2
                    plot(hA,tracks{m}(:,1),tracks{m}(:,2),'LineWidth',1,'Color',[1,1,0]);
                else
                    plot3(hA,tracks{m}(:,1),tracks{m}(:,2),ticks{m},'LineWidth',1,'Color',[0,0,0]);
                end
            end
            hA.NextPlot = 'replace';
        end
        
        function refreshCurFrame(obj,csfObj,maxDist,af)
            obj.rollBackTo();
            obj.commitNew(csfObj,maxDist,af);
        end
        
        function trackMap(obj,hA)
            if ~exist('hA','var')
                hf = figure;
                hA = axes('Parent',hf);
            end
            mat = zeros(obj.nTrack,obj.nFrame);
            for m = 1:obj.nTrack
                tmpArray = obj.trackArray{m};
                tmpArray(tmpArray>0) = 1;
                mat(m,:) = tmpArray;
            end
            image = ind2rgb(mat+2,[0.3,0.3,0.3;0.8,0.8,0.8;0.9,0.4,0]);
            imagesc(hA,image); xticks(hA,[]); yticks(hA,[]);
        end
        
        function newObj = closeGap(obj,isCopy,frameTor,distTor)
            if ~exist('isCopy','var') || isCopy
                newObj = copy(obj);
                newObj.closeGap(0);
                return;
            end
            if ~exist('frameTor','var')
                frameTor = 3;
            end
            [tracks,ticks] = obj.getAllTracks(1,obj.nFrame);
            startPos = cell2mat(cellfun(@(x)x(1,:),tracks,'UniformOutput',0));
            endPos = cell2mat(cellfun(@(x)x(end,:),tracks,'UniformOutput',0));
            startFrame = cellfun(@(x)x(1),ticks);
            endFrame = cellfun(@(x)x(end),ticks);
            [startArea,endArea,startInferDist,endInferDist] = deal(zeros(obj.nTrack,1));
            for m = 1:obj.nTrack
                startArea(m) = obj.trackArea{m}(startFrame(m));
                endArea(m) = obj.trackArea{m}(endFrame(m));
                startInferDist(m) = obj.getMaxDist(startFrame(m),obj.trackArray{m}(startFrame(m)));
                endInferDist(m) = obj.getMaxDist(endFrame(m),obj.trackArray{m}(endFrame(m)));
            end
            startInferDist = 1.1*startInferDist;
            endInferDist = 1.1*endInferDist;
            if exist('distTor','var')
                startInferDist = min(startInferDist,distTor);
                endInferDist = min(endInferDist,distTor);
            end
            [res,~,~] = lapcloser(startPos,startFrame,startArea,endPos,endFrame,...
                endArea,frameTor,startInferDist,endInferDist);
            isClosed = zeros(obj.nTrack,1);
            for m = 1:obj.nTrack
                if ~isClosed(m)
                    ender = m;
                    counter = 0;
                    while (res(ender) <= obj.nTrack)
                        if CellTrackController.DEBUG_MODE
                            if counter == 0
                                fprintf(1,'%d{%d:%d} -> %d{%d:%d}',...
                                    ender,endFrame(ender),obj.trackArray{ender}(endFrame(ender)),...
                                    res(ender),startFrame(res(ender)),obj.trackArray{res(ender)}(startFrame(res(ender))));
                            else
                                fprintf(1,' -> %d{%d:%d}',...
                                    res(ender),startFrame(res(ender)),obj.trackArray{res(ender)}(startFrame(res(ender))));
                            end
                        end
                        p = startFrame(res(ender));
                        obj.trackArray{m} = [obj.trackArray{m}(1:(p-1));obj.trackArray{res(ender)}(p:end)];
                        obj.trackArea{m} = [obj.trackArea{m}(1:(p-1));obj.trackArea{res(ender)}(p:end)];
                        obj.trackCost{m} = [obj.trackCost{m}(1:(p-1));obj.trackCost{res(ender)}(p:end)];
                        obj.trackDist{m} = [obj.trackDist{m}(1:(p-1));obj.trackDist{res(ender)}(p:end)];
                        obj.trackNNDist{m} = [obj.trackNNDist{m}(1:(p-1));obj.trackNNDist{res(ender)}(p:end)];
                        isClosed(res(ender)) = 1;
                        ender = res(ender);
                        counter = counter + 1;
                    end
                    if counter > 0 && CellTrackController.DEBUG_MODE
                        fprintf(1,'\n');
                    end
                end
            end
            I = logical(isClosed);
            obj.delTrack(I);
            newObj = obj;
        end
        
        function delShortTrack(obj,thres)
            I = obj.trackLength < thres;
            obj.delTrack(I);
        end
        
        function reason = endReasoning(obj,maxFrame,maxDist)
            if ~exist('maxFrame','var')
                maxFrame = 2;
            end
            [tracks,ticks,areas] = obj.getAllTracks(1,obj.nFrame);
            startFrame = cellfun(@(x)x(1),ticks);
            endFrame = cellfun(@(x)x(end),ticks);
            startArea = cellfun(@(x)x(1),areas);
            endArea = cellfun(@(x)x(end),areas);
            startPos = cell2mat(cellfun(@(x)x(1,:),tracks,'UniformOutput',0));
            endPos = cell2mat(cellfun(@(x)x(end,:),tracks,'UniformOutput',0));
            [startDist,endDist] = deal(zeros(obj.nTrack,1));
            for m = 1:obj.nTrack
                startDist(m) = obj.csfObjs{startFrame(m)}.NNDistance(...
                    obj.trackArray{m}(startFrame(m)))*2;
                endDist(m) = obj.csfObjs{endFrame(m)}.NNDistance(...
                    obj.trackArray{m}(endFrame(m)))*1.5;
            end
            corrEndMat = abs(endFrame - endFrame');
            corrEndMat = corrEndMat + eye(obj.nTrack)*(maxFrame+1);
            corrEndMat(corrEndMat>maxFrame) = inf;
            
            corrStartMat = abs(endFrame - startFrame');
            I = startFrame' == 1;
            corrStartMat = corrStartMat + eye(obj.nTrack)*(maxFrame+1);
            corrStartMat(corrStartMat>maxFrame) = inf;
            corrStartMat(repmat(I,obj.nTrack,1)) = inf;
            
            posDistMat = pdist2(endPos,startPos);
            posDistMat(or(posDistMat > repmat(endDist,1,obj.nTrack),...
                posDistMat > repmat(startDist',obj.nTrack,1))) = inf;
            if exist('maxDist','var')
                posDistMat(posDistMat>maxDist) = inf;
            end
            
            reason = zeros(obj.nTrack,3);
            
            for m = 1:obj.nTrack
                if reason(m,1) > 0
                    continue;
                end
                if endFrame(m) == obj.nFrame
                    reason(m) = EndReason.EndOfFrame;
                    if CellTrackController.DEBUG_MODE
                        fprintf(1,'track %d, assigned: %s\n',m,EndReason(reason(m,1)));
                    end
                    continue;
                end
                validCell = ~isinf(posDistMat(m,:));
                corrEnd = find(and(~isinf(corrEndMat(m,:)),validCell));
                corrStart = find(and(~isinf(corrStartMat(m,:)),validCell));
                
                if ~isempty(corrEnd)
                    I = or(obj.trackLength>20,obj.trackLength/endFrame(m)>0.8);
                    corrEnd = corrEnd(I(corrEnd));
                end
                
                if ~isempty(corrStart)
                    I = or(obj.trackLength>20,obj.trackLength/(obj.nFrame-endFrame(m))>0.8);
                    corrStart = corrStart(I(corrStart));
                end
                
                if isempty(corrEnd) && isempty(corrStart)
                    if obj.isNearBorder(endFrame(m),obj.trackArray{m}(endFrame(m)))
                        reason(m,1) = EndReason.Disappear;
                    else
                        reason(m,1) = EndReason.FalseTrack;
                    end
                elseif isempty(corrStart)
                    reason(m,1) = EndReason.FalseFusion;
                elseif isempty(corrEnd)
                    if length(corrStart) == 1
                        r = endArea(m)/startArea(corrStart(1));
                        if r > 1.35
                            reason(m,1) = EndReason.Division;
                        else
                            reason(m,1) = EndReason.FalseTrack;
                        end
                        reason(m,2) = corrStart(1);
                    else
                        [~,I] = sort(posDistMat(m,corrStart));
                        r = endArea(m)/sum(startArea(corrStart(I(1:2))));
                        if r > 0.75 && r < 1.25
                            reason(m,1) = EndReason.Division;
                        else
                            reason(m,1) = EndReason.UnKnown;
                        end
                        reason(m,2:3) = corrStart(I(1:2));
                    end
                elseif length(corrEnd) >= length(corrStart)
                    reason(m,1) = EndReason.FalseFusion;
                else
                    [~,I] = sort(posDistMat(m,corrStart));
                    r = endArea(m)/sum(startArea(corrStart(I(1:2))));
                    if r > 0.75 && r < 1.25
                        reason(m,1) = EndReason.Division;
                    else
                        reason(m,1) = EndReason.UnKnown;
                    end
                    reason(m,2:3) = corrStart(I(1:2));
                end
                
                if CellTrackController.DEBUG_MODE
                    fprintf(1,'track %d, corrEndNum: %d, corrStartNum: %d, assigned: %s\n',...
                        m,length(corrEnd),length(corrStart),EndReason(reason(m,1)));
                    if reason(m,1) == 3
                        disp(reason(m,:));
                    end
                end
            end
        end
        
        function [indexList,tra] = transTraj2NewSpace(obj,coord,idtable,trajID,isDraw)
            if ~exist('isDraw','var')
                isDraw = 1;
            end
            if ischar(idtable)
                idtable = readtable(idtable);
            end
            if trajID > 0 && trajID <= obj.nTrack
                traj = obj.trackArray{trajID};
            else
                error('track id should be with in 1~%d, given %d', obj.nTrack, trajID);
            end
            if size(coord,1) ~= size(idtable,1)
                error('corrd length should be consist to the table length, given %d and %d.',...
                    size(coord,1),size(idtable,1));
            end
            startFrame = find(traj>0,1);
            endFrame = find(traj>0,1,'last');
            L = endFrame - startFrame + 1;
            indexList = zeros(L,1);
            for m = 1:L
                frame = startFrame+m-1;
                tmp = idtable.index(and(idtable.frame==frame,...
                    idtable.frameId == traj(frame)))+1;
                if length(tmp) ~= 1
                    error('cannot solve point at frame %d, ID: %d, found %d match.',...
                        frame,traj(frame),length(tmp));
                end
                indexList(m) = tmp;
            end
            tra = coord(indexList,:);
            if isDraw
                figure;
                scatter(coord(:,1),coord(:,2),5,[0.8,0.8,0.8],'filled');
                hold on;
                plot(tra(:,1),tra(:,2),'LineWidth',2);
                scatter(tra(:,1),tra(:,2),10,startFrame:endFrame,'filled');
            end
        end
    end
    
    methods(Access=private)
        function a = initTrackArray(obj,index,frame)
            a = zeros(obj.nFrame,1);
            a(1:(frame-1)) = -1;
            a(frame) = index;
        end
        function pushTrackData(obj,trackID,sourceCell,r,cost,tarNND,tarArea,displacement)
            if trackID > 0 && r > 0
                if CellTrackController.DEBUG_MODE
                    fprintf(1,'Track: %d commit new point {%d:%d} -> {%d:%d}\n',...
                        trackID,obj.curFrame,sourceCell,obj.curFrame+1,r);
                end
                obj.trackArray{trackID}(obj.curFrame+1) = r;
                obj.trackCost{trackID}(obj.curFrame+1) = cost;
                obj.trackDist{trackID}(obj.curFrame+1) = sqrt(displacement);
                obj.trackNNDist{trackID}(obj.curFrame+1) = tarNND;
                obj.trackArea{trackID}(obj.curFrame+1) = tarArea;
            elseif trackID > 0 && r==0
                if CellTrackController.DEBUG_MODE
                    fprintf(2,'Track: %d cell{%d} end at frame: %d\n',trackID,sourceCell,obj.curFrame+1);
                end
                obj.trackArray{trackID}(obj.curFrame+1) = 0;
                obj.trackCost{trackID}(obj.curFrame+1) = cost;
                obj.trackDist{trackID}(obj.curFrame+1) = nan;
                obj.trackNNDist{trackID}(obj.curFrame+1) = 0;
                obj.trackArea{trackID}(obj.curFrame+1) = 0;
            elseif trackID < 0
                trackID = obj.nTrack + 1;
                if CellTrackController.DEBUG_MODE
                    fprintf(2,'Track: %d begin at frame: %d, cell: %d\n',...
                        trackID,obj.curFrame+1,r);
                end
                obj.trackArray{trackID} = obj.initTrackArray(r,obj.curFrame+1);
                obj.trackCost{trackID} = obj.initTrackArray(cost,obj.curFrame+1);
                obj.trackDist{trackID} = obj.initTrackArray(eps,obj.curFrame+1);
                obj.trackNNDist{trackID} = obj.initTrackArray(tarNND,obj.curFrame+1);
                obj.trackArea{trackID} = obj.initTrackArray(tarArea,obj.curFrame+1);
            end
        end
        function r = getTrackRange(obj,trackID)
            r = [find(obj.trackArray{trackID}>0,1,'first'),...
                find(obj.trackArray{trackID}>0,1,'last')];
            r(2) = min([r(2),obj.curFrame]);
        end
        function md = getMaxDist(obj,frame,cellID)
            if frame == 1
                md = obj.csfObjs{1}.NNDistance(cellID)/2;
                return;
            end
            trackID = obj.cellIndex2trackID(cellID,frame);
            try
                r = obj.getTrackRange(trackID);
            catch
                disp(trackID);
            end
            if range(r)>2 %1,2,3,4
                r(1) = max([r(1)+1,r(2)-CellTrackController.MAX_REF_STEP+1]);
                R1 = std(obj.trackDist{trackID}(r(1):r(2)))*3;
                R2 = mean(obj.trackNNDist{trackID}(r(1):r(2)))/2;
                md = max([R1,R2]);
            elseif range(r)>1 %1,2,3
                R1 = mean(obj.trackDist{trackID}((r(1)+1):r(2)))*1.5;
                R2 = mean(obj.trackNNDist{trackID}(r(1):r(2)))/2;
                md = max([R1,R2]);
            elseif range(r)>0  %1,2
                R1 = obj.trackDist{trackID}(r(2))*1.5;
                R2 = mean(obj.trackNNDist{trackID}(r(1):r(2)))/2;
                md = max([R1,R2]);
            else
                md = obj.trackNNDist{trackID}(r(2))/2;
            end
        end
        function delTrack(obj,I)
            obj.trackArray(I) = [];
            obj.trackArea(I) = [];
            obj.trackCost(I) = [];
            obj.trackDist(I) = [];
            obj.trackNNDist(I) = [];
        end
        function b = isNearBorder(obj,frame,cellIndex)
            w = obj.csfObjs{frame}.cellBox(cellIndex,3);
            h = obj.csfObjs{frame}.cellBox(cellIndex,4);
            x = obj.csfObjs{frame}.cellPos(cellIndex,1);
            y = obj.csfObjs{frame}.cellPos(cellIndex,2);
            if x < w || x > (CellTrackController.FRAME_SIZE - w)
                b = 1;
            elseif y < h || y > (CellTrackController.FRAME_SIZE - h)
                b = 1;
            else
                b = 0;
            end
        end
    end
    
end

