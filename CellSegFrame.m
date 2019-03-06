classdef CellSegFrame
    
    properties(SetAccess=private)
        cellArea;
        cellPos;
        cellBox;
        indexedMat;
        rawImage;
    end
    
    properties(Dependent)
        nCell;
        maxWidth;
        maxHeight;
        maxLength;
        bgIntense;
        nChannel;
        maxIntense;
        NNDistance;
        estAreaFactor;
    end
    
    methods
        function obj = CellSegFrame(indexedMat,rawIm)
            obj.indexedMat = indexedMat;
            obj.rawImage = rawIm;
            stats = regionprops('table',indexedMat,'Area','BoundingBox',...
                'Centroid');
            obj.cellArea = stats.Area;
            obj.cellPos = stats.Centroid;
            obj.cellBox = stats.BoundingBox;
        end
        function nc = get.nCell(obj)
            nc = size(obj.cellArea,1);
        end
        function w = get.maxWidth(obj)
            w = max(obj.cellBox(:,3));
        end
        function h = get.maxHeight(obj)
            h = max(obj.cellBox(:,4));
        end
        function l = get.maxLength(obj)
            l = max([obj.maxWidth,obj.maxHeight]);
        end
        function intens = get.bgIntense(obj)
            if obj.nChannel == 1
                intens = CellSegFrame.getBGMedian(obj.rawImage,obj.indexedMat);
            else
                intens = zeros(obj.nChannel,1);
                for m = 1:obj.nChannel
                    intens(m) = CellSegFrame.getBGMedian(obj.rawImage(:,:,m),obj.indexedMat);
                end
            end
        end
        function intens = get.maxIntense(obj)
            if obj.nChannel == 1
                intens = double(max(obj.rawImage(:)));
            else
                intens = zeros(obj.nChannel,1);
                for m = 1:obj.nChannel
                    intens(m) = double(max(max(obj.rawImage(:,:,m))));
                end
            end
        end
        function nnd = get.NNDistance(obj)
            mat = pdist2(obj.cellPos,obj.cellPos,'euclidean');
            mat = mat + eye(obj.nCell)*max(mat(:));
            nnd = min(mat,[],2);
        end
        function nc = get.nChannel(obj)
            if ndims(obj.rawImage) == 2
                nc = 1;
            else
                nc = size(obj.rawImage,3);
            end
        end
        function af = get.estAreaFactor(obj)
            areaLoss = power((prctile(obj.cellArea,75) - prctile(obj.cellArea,25)),2);
            distLoss = power(median(obj.NNDistance),2);
            af = distLoss/areaLoss;
        end
        function scatterCentroid(obj,hA,faceColor,edgeColor)
            if ~exist('hA','var')
                hf = figure;
                hA = axes('Parent',hf);
            end
            if ~exist('faceColor','var')
                faceColor = [1,1,1];
            end
            if ~exist('edgeColor','var')
                edgeColor = [0,0,0];
            end
            scatter(hA,obj.cellPos(:,1),obj.cellPos(:,2),15,...
                'MarkerFaceColor',faceColor,'MarkerEdgeColor',edgeColor);
        end
        function im = getCellMaskedImage(obj,cellMarker,s,fillMethod,BGSub)
            if ~exist('s','var')
                s = obj.maxLength;
            end
            if ~exist('fillMethod','var')
                fillMethod = 'zero';
            end
            if ~exist('BGSub','var')
                BGSub = 1;
            end
            if s < obj.maxLength
                error('CellSegFrame: cell mask length %d smaller than max length %d!',...
                    s,obj.maxLength);
            end
            switch fillMethod
                case 'median'
                    fillValue = obj.bgIntense;
                case 'max'
                    fillValue = obj.maxIntense;
                otherwise
                    fillValue = zeros(obj.nChannel,1);
            end
            if obj.nChannel == 1
                im = ones(s)*fillValue;
            else
                im = ones(s,s,obj.nChannel).*reshape(fillValue,[1,1,obj.nChannel]);
            end
            w = obj.cellBox(cellMarker,3);
            h = obj.cellBox(cellMarker,4);
            x0 = ceil(obj.cellBox(cellMarker,1));
            y0 = ceil(obj.cellBox(cellMarker,2));
            x = floor((s-w)/2) + 1;
            y = floor((s-h)/2) + 1;
            mask = obj.indexedMat(y0:(y0+h-1),x0:(x0+w-1))==cellMarker;
            if obj.nChannel == 1
                tmp = obj.rawImage(y0:(y0+h-1),x0:(x0+w-1));
                if BGSub
                    tmp(~mask) = fillValue;
                end
                im(y:(y+h-1),x:(x+w-1)) = tmp;
            else
                tmp = obj.rawImage(y0:(y0+h-1),x0:(x0+w-1),:);
                if BGSub
                    for m = 1:obj.nChannel
                    singleFrame = tmp(:,:,m);
                    singleFrame(~mask) = fillValue(m);
                    tmp(:,:,m) = singleFrame;
                    end
                end
                im(y:(y+h-1),x:(x+w-1),:) = tmp;
            end
        end
        function show(obj,c)
            if nargin == 1
                rawMat = obj.rawImage;
            else
                rawMat = obj.rawImage(:,:,c);
            end
            figure;
            subplot(121);
            imagesc(rawMat); colormap(gray);
            subplot(122);
            imagesc(obj.indexedMat); colormap(jet);
        end
    end
    
    methods(Static)
        function intens = getBGMedian(mat,mask)
            tmp = mat(:);
            tmp(mask(:)>0) = [];
            intens = double(median(tmp));
        end
    end  
end

