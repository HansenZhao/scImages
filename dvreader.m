function [ result,filterInfo,sizeInfo ] = dvreader(fp,T,Z,C)
    %ref: bio-formats
    autoloadBioFormats = 1;
    stitchFiles = 0;
    status = bfCheckJavaPath(autoloadBioFormats);
    assert(status,['Missing Bio-Formats library. Either add bioformats_package.jar '...
    'to the static Java path or add it to the Matlab path.']);
    bfInitLogging();
    r = bfGetReader(fp,stitchFiles);
    
    sizeZ = r.getSizeZ();
    sizeC = r.getSizeC();
    sizeT = r.getSizeT();
    
    if nargin == 2 && isempty(T)
        result = [];
        filterInfo = [];
        sizeInfo = [sizeZ,sizeC,sizeT];
        r.close()
        return;
    end
    r.setSeries(0);
    
    if ~exist('T','var') || isempty(T)
        T = 1:sizeT;
    end
    if ~exist('Z','var') || isempty(Z)
        Z = 1:sizeZ;
    end
    if ~exist('C','var') || isempty(C)
        C = 1:sizeC;
    end
    if max(T) > sizeT
        error('max time point is %d, get %d instead',sizeT,max(T))
    end
    if max(Z) > sizeZ
        error('max z-stack is %d, get %d instead',sizeZ,max(Z))
    end
    if max(C) > sizeC
        error('max channel num is %d, get %d instead',sizeC,max(C))
    end
    
    nFrame = length(T);
    nZ = length(Z);
    nChannel = length(C);
    
    result = cell(nZ,nChannel,nFrame);
    filterInfo = cell(1,sizeC);
    
    for t = 1:nFrame
        for c = 1:nChannel
            for z = 1:nZ
                idx = (T(t)-1)*sizeZ*sizeC+(C(c)-1)*sizeZ+Z(z);
                arr = bfGetPlane(r,idx);

%                 zct = r.getZCTCoords(idx-1);
%                 fprintf('Z: %d, C: %d, T: %d\n',zct(1)+1,zct(2)+1,zct(3)+1);

                result{z,c,t} = arr;
            end
        end
    end
    
    meta = r.getSeriesMetadata();
    javaMethod('merge','loci.formats.MetadataTools',...
        r.getGlobalMetadata(),meta,'Global ');
    for m = 1:sizeC
        tmp = meta.get(sprintf('Global Image %d. EM filter',1+sizeZ*(m-1)));
        if isempty(tmp)
            tmp = 'unknown';
        end
        filterInfo{m} = tmp;
    end
    filterInfo = filterInfo(C);
    r.close();
end

