classdef DVImageReader < handle
    % depend on BFmatlab: https://www.openmicroscopy.org/bio-formats/downloads/
    properties (SetAccess = private)
        nZSlice;
        nChannel;
        nSteps;
        filterInfo;
        timeInfo;
        sliceInfo;
        rawData;
        fileName;
        filePath;
    end
    
    properties (Dependent)
        nImages
        imSize;
    end
    
    methods
        function obj = DVImageReader(fpath)
            if nargin < 1
                [fn,fp,index] = uigetfile('*.dv');
                if index
                    fpath = strcat(fp,fn);
                else
                    obj = [];
                    return;
                end
            end
            tmp = strsplit(fpath,'\');
            obj.fileName = tmp{end}(1:(end-3));
            [~,~,sizeData] = dvreader(fpath,[]);
            obj.nZSlice = sizeData(1);
            obj.nChannel = sizeData(2);
            obj.nSteps = sizeData(3);
            fprintf(1,'image data with %d slices, %d channels and %d time point\n',...
            obj.nZSlice,obj.nChannel,obj.nSteps);
            obj.rawData = {};
            obj.filePath = fpath;
        end
        
        function res = get.nImages(obj)
            if isempty(obj.rawData)
                res = 0;
            else
                res = length(obj.rawData(:));
            end
        end
        
        function res = get.imSize(obj)
            if isempty(obj.rawData)
                res = 0;
            else
                res = size(obj.rawData{1},1);
            end
        end
        
        function parse(obj,T,Z,C)
            if nargin == 1 || strcmp(T,'all')
                T = 1:obj.nSteps;
                Z = 1:obj.nZSlice;
                C = 1:obj.nChannel;
            end
            [obj.rawData,obj.filterInfo] = dvreader(obj.filePath,T,Z,C);
            if isempty(T)
                obj.timeInfo = 1:obj.nSteps;
            else
                obj.timeInfo = T;
            end
            if isempty(Z)
                obj.sliceInfo = 1:obj.nZSlice;
            else
                obj.sliceInfo =Z;
            end
        end
        
        function im = subSet(obj,T,Z,Channel)
            if ~exist('Z','var')
                Z = obj.sliceInfo;
            end
            if ~exist('T','var')
                T = obj.timeInfo;
            end
            if ~exist('Channel','var')
                Channel = obj.filterInfo;
            end
            im = zeros(obj.imSize,obj.imSize,length(Z)*length(Channel),length(T));
            [~,cIndex] = ismember(Channel,obj.filterInfo(1,:,1));
            if any(cIndex<1)
                error('unable to find channel: %s',Channel{cIndex(cIndex<1)});
            end
            [~,zIndex] = ismember(Z,obj.sliceInfo);
            if any(zIndex<1)
                error('unable to find slice: %d',Z(find(zIndex<1,1)));
            end
            [~,tIndex] = ismember(T,obj.timeInfo);
            if any(tIndex<1)
                error('unable to find time point: %d',T(find(tIndex<1,1)));
            end
            
            for m = 1:length(T)
                counter = 1;
                for n = 1:length(Z)
                    for c = 1:length(cIndex)
                        im(:,:,counter,m) = obj.rawData{zIndex(n),cIndex(c),tIndex(m)};
                        counter = counter + 1;
                    end
                end
            end
        end
    end
    
end

