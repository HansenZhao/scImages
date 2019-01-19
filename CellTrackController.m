classdef CellTrackController < handle
    
    properties(SetAccess = private)
        nFrame;
        csfObjs;
        trackArray;
        trackCost;
        trackDist;
        trackNNDist;
        trackArea;
        curFrame;
    end
    
    properties(Dependent)
        nTrack;
        trackLength;
        inferMaxDist;
        inferAreaFac;
    end
    
    properties(Constant)
        DEBUG_MODE = 0;
        MAX_REF_STEP = 5;
    end
    
    methods
        function obj = CellTrackController(initObj,nFrame)
            obj.nFrame = nFrame;
            obj.csfObjs = cell(nFrame,1);
            [obj.trackArray,obj.trackCost,obj.trackDist,obj.trackNNDist,...
                obj.trackArea] = deal(cell(initObj.nCell,1));
            obj.curFrame = 1;
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
            tl = cellfun(@(x)sum(x>0),obj.trackArray);
        end
        
        function md = get.inferMaxDist(obj)
            if obj.curFrame == 1
                md = obj.csfObjs{1}.NNDistance/2;
                return;
            end
            ns = obj.csfObjs{obj.curFrame}.nCell;
            md = zeros(ns,1);
            for m = 1:ns
                trackID = obj.cellIndex2trackID(m,obj.curFrame);
                r = obj.getTrackRange(trackID);
                if range(r)>1 %length > 2
                    r(1) = max([r(1),r(2)-CellTrackController.MAX_REF_STEP+1]);
                    R1 = std(obj.trackDist{trackID}(r(1):r(2)))*3; 
                    R2 = mean(obj.trackNNDist{trackID}(r(1):r(2)))/2;
                    md(m) = max([R1,R2]);
                elseif range(r)>0  %length == 1
                    R1 = obj.trackDist{trackID}(r(2))*2;
                    R2 = mean(obj.trackNNDist{trackID}(r(1):r(2)))/2;
                    md(m) = max([R1,R2]);
                else
                    md(m) = obj.trackNNDist{trackID}(r(2))/2;
                end
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
        
        function tID = cellIndex2trackID(obj,index,frame)
            if ~exist('frame','var')
                frame = obj.curFrame;
            end
            searchRes = cellfun(@(x)x(frame)==index,obj.trackArray);
            tID = find(searchRes);
        end
        
        function commitNew(obj,csfObj,maxDist)
            ns = obj.csfObjs{obj.curFrame}.nCell;
            nt = csfObj.nCell;
            if CellTrackController.DEBUG_MODE
                fprintf(1,'commit %d->%d: %d cells to %d cells\n',...
                    obj.curFrame,obj.curFrame+1,ns,nt)
            end
            [linkRes,linkCost] = laptracker(obj.csfObjs{obj.curFrame}.cellPos,...
                csfObj.cellPos,maxDist);
            nnd = csfObj.NNDistance;
            for m = 1:(ns+nt)
                r = linkRes(m);
                if m <= ns 
                    trackID = obj.cellIndex2trackID(m);
                    if r <= nt %valid link
                        obj.pushTrackData(trackID,m,r,linkCost(m),nnd(r),csfObj.cellArea(r));
                    else %end of track
                        obj.pushTrackData(trackID,m,0,linkCost(m),0,0);
                    end
                elseif r <= nt %begin of link
                    obj.pushTrackData(-1,m,r,linkCost(m),nnd(r),csfObj.cellArea(r));
                end
            end 
            obj.curFrame = obj.curFrame + 1;
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
                xy(m,:) = csfObj.cellPos(cellId,:);
            end
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
                obj.csfObjs{stepTo}.scatterCentroid(hA);
                return;
            end
            tracks = cell(obj.nTrack,1);
            ticks = cell(obj.nTrack,1);
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
                count = count + 1;
            end
            tracks((count+1):end) = [];
            ticks((count+1):end) = [];
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
                    plot(hA,tracks{m}(:,1),tracks{m}(:,2),'LineWidth',1,'Color',[0,0,0]);
                else
                    plot3(hA,tracks{m}(:,1),tracks{m}(:,2),ticks{m},'LineWidth',1,'Color',[0,0,0]);
                end
            end
            hA.NextPlot = 'replace';
        end
        
        function refreshCurFrame(obj,csfObj,maxDist)
            obj.rollBackTo();
            obj.commitNew(csfObj,maxDist);
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
    end
    
    methods(Access=private)
        function a = initTrackArray(obj,index,frame)
            a = zeros(obj.nFrame,1);
            a(1:(frame-1)) = -1;
            a(frame) = index;
        end
        function pushTrackData(obj,trackID,sourceCell,r,cost,tarNND,tarArea)
            if trackID > 0 && r > 0
                if CellTrackController.DEBUG_MODE
                    fprintf(1,'Track: %d commit new point {%d:%d} -> {%d:%d}\n',...
                        trackID,obj.curFrame,sourceCell,obj.curFrame+1,r);
                end
                obj.trackArray{trackID}(obj.curFrame+1) = r;
                obj.trackCost{trackID}(obj.curFrame+1) = cost;
                obj.trackDist{trackID}(obj.curFrame+1) = sqrt(cost);
                obj.trackNNDist{trackID}(obj.curFrame+1) = tarNND;
                obj.trackArea{trackID}(obj.curFrame+1) = tarArea;
            elseif trackID > 0 && r==0
                if CellTrackController.DEBUG_MODE
                    fprintf(2,'Track: %d end at frame: %d\n',trackID,obj.curFrame+1);
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
    end
    
end

