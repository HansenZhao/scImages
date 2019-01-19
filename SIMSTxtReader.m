classdef SIMSTxtReader < handle
    properties (Constant)
        nZSlice = 1;
        nSteps = 1;
        timeInfo = 1;
        sliceInfo = 1;
    end
    
    properties (SetAccess=private)
        filterInfo;
        rawData;
        fileName;
        filePath;
        mz;
    end
    
    properties(Dependent)
        nChannel;
        nImages;
        imSize;
        sumRes;
    end
    
    methods
        function obj = SIMSTxtReader(fpath)
            if nargin < 1
                obj.filePath = uigetdir();
            else
                obj.filePath = fpath;
            end
            tmp = strsplit(obj.filePath,'\');
            obj.fileName = tmp{end};
            [fn,fp] = listFile('*.txt',obj.filePath);
            L = length(fn);
            obj.rawData = cell(1,L);
            obj.mz = zeros(L,1);
            obj.filterInfo = cell(L,1);
            counter = 0;
            for m = 1:L
                sd = SIMSTxtData(fp{m},fn{m});
                if sd.mz < 0
                    continue;
                else
                    counter = counter + 1;
                end
                obj.rawData{counter} = sd.rawMat;
                obj.mz(counter) = sd.mz;
                obj.filterInfo{counter} = num2str(sd.mz,'%.2f');
                if mod(m,50) == 0
                    fprintf(1,'%d/%d\n',m,L);
                end
            end
            obj.rawData((counter+1):L) = [];
            obj.mz((counter+1):L) = [];
            obj.filterInfo((counter+1):L) = [];
            obj.sortMS();
        end
        
        function sortMS(obj)
            [obj.mz,I] = sort(obj.mz);
            obj.rawData = obj.rawData(I);
            obj.filterInfo = obj.filterInfo(I);
        end
        
        function nc = get.nChannel(obj)
            nc = length(obj.mz);
        end
        
        function nIm = get.nImages(obj)
            nIm = obj.nChannel;
        end
        
        function r = get.sumRes(obj)
            r = zeros(obj.imSize);
            for m = 1:obj.nImages
                r = r + obj.rawData{m};
            end
        end
        
        function imS = get.imSize(obj)
            imS = size(obj.rawData{1},1);
        end
        
        function subRegion(obj,nR,nC,iR,iC)
            if mod(obj.imSize,nR) ~= 0 || mod(obj.imSize,nC) ~= 0
                disp('invalid spliting');
            end
            blockSizeR = obj.imSize/nR;
            blockSizeC = obj.imSize/nC;
            startR = 1 + (iR-1)*blockSizeR;
            endR = iR*blockSizeR;
            startC = 1 + (iC-1)*blockSizeC;
            endC = iC*blockSizeC;
            obj.rawData = cellfun(@(x)x(startR:endR,startC:endC),obj.rawData,...
                'UniformOutput',0);
        end
    end
    
end

