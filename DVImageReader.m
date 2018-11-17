classdef DVImageReader < handle
    % depend on BFmatlab: https://www.openmicroscopy.org/bio-formats/downloads/
    properties (SetAccess = private)
        nZSlice;
        nChannel;
        nSteps;
        filterInfo;
        timeInfo;
        rawData;
        fileName;
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
            res = bfopen(fpath);
            info = regexp(res{1}{1,2},...
                'Z=\d/(?<ZSlice>\d+); C=\d/(?<Channel>\d+); T=\d/(?<Steps>\d+)','names');
            obj.nZSlice = str2double(info.ZSlice);
            obj.nChannel = str2double(info.Channel);
            obj.nSteps = str2double(info.Steps);
            obj.filterInfo = cell(obj.nImages,1);
            obj.timeInfo = zeros(obj.nImages,1);
            
            fieldKeys = res{2}.keys;
            while(fieldKeys.hasNext)
                fieldName = fieldKeys.next;
                tmp = regexp(fieldName,'Global Image (?<imageID>\d+)','names');
                if ~isempty(tmp)
                    if contains(fieldName,'Time Point')
                        getTime = res{2}.get(fieldName);
                        getTime = strsplit(getTime,' ');
                        obj.timeInfo(str2double(tmp.imageID)) = str2double(getTime{1});
                    elseif contains(fieldName,'EM filter')
                        obj.filterInfo{str2double(tmp.imageID)} = res{2}.get(fieldName);
                    end
                end
            end
            obj.rawData = res{1}(:,1);
            obj.rawData = reshape(obj.rawData,[obj.nZSlice,obj.nChannel,obj.nSteps]);
            obj.filterInfo = reshape(obj.filterInfo,[obj.nZSlice,obj.nChannel,obj.nSteps]);
            obj.timeInfo = reshape(obj.timeInfo,[obj.nZSlice,obj.nChannel,obj.nSteps]);
        end
        
        function res = get.nImages(obj)
            res = obj.nZSlice*obj.nChannel*obj.nSteps;
        end
        
        function res = get.imSize(obj)
            res = size(obj.rawData{1},1);
        end
        
        function im = subSet(obj,Z,T,Channel)
            if ~exist('Z','var')
                Z = 1;
            end
            if ~exist('T','var')
                T = 1;
            end
            if ~exist('Channel','var')
                Channel = {'POL'};
            end
            im = zeros(obj.imSize,obj.imSize,length(Z)*length(T)*length(Channel));
            [~,cIndex] = ismember(Channel,obj.filterInfo(1,:,1));
            if any(cIndex<1)
                error('unable to find channel: %s',Channel{cIndex(cIndex<1)});
            end
            if max(Z) > obj.nZSlice
                error('too large Z slice');
            end
            if max(T) > obj.nSteps
                error('too large time steps');
            end
            counter = 1;
            for m = 1:length(Z)
                for n = 1:length(T)
                    for c = 1:length(cIndex)
                        im(:,:,counter) = obj.rawData{m,cIndex(c),n};
                        counter = counter + 1;
                    end
                end
            end
        end
    end
    
end

