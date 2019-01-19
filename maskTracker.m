function varargout = maskTracker(varargin)
% MASKTRACKER MATLAB code for maskTracker.fig
%      MASKTRACKER, by itself, creates a new MASKTRACKER or raises the existing
%      singleton*.
%
%      H = MASKTRACKER returns the handle to a new MASKTRACKER or the handle to
%      the existing singleton*.
%
%      MASKTRACKER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MASKTRACKER.M with the given input arguments.
%
%      MASKTRACKER('Property','Value',...) creates a new MASKTRACKER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before maskTracker_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to maskTracker_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help maskTracker

% Last Modified by GUIDE v2.5 18-Jan-2019 14:58:19

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @maskTracker_OpeningFcn, ...
                   'gui_OutputFcn',  @maskTracker_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before maskTracker is made visible.
function maskTracker_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to maskTracker (see VARARGIN)

% Choose default command line output for maskTracker
handles.output = hObject;
handles.dvObj = varargin{1};
handles.predMat = varargin{2};
if handles.dvObj.nSteps ~= size(handles.predMat,1)
    error('image time step in dv object and prediction mat should be the same,get %d and %d',...
        handles.dvObj.nSteps,size(handles.predMat,1))
end
handles.rmSmallThres = 1;
handles.bbThres = 1;
handles.rExtThres = 1;
handles.curFrame = 1;
handles.curZPos = 1;
handles.curChannel = 1;
handles.axesLim = [];
handles.overlayRatio = 0.3;
handles.curCell = 1;
handles.csfObjs = cell(handles.dvObj.nSteps,1);
handles.btn_load.BackgroudColor = [1,0,0];
handles.sd_curFrame.Value = 1;
handles.sd_curFrame.Min = 1;
handles.sd_curFrame.Max = handles.dvObj.nSteps;
if handles.dvObj.nSteps > 1
    handles.sd_curFrame.SliderStep = [1,1]/(handles.dvObj.nSteps-1);
else
    handles.sd_curFrame.SliderStep = [1,1];
end
handles.sd_curZPos.Value = 1;
handles.sd_curZPos.Min = 1;
handles.sd_curZPos.Max = handles.dvObj.nZSlice;
if handles.dvObj.nZSlice > 1
    handles.sd_curZPos.SliderStep = [1,1]/(handles.dvObj.nZSlice-1);
else
    handles.sd_curZPos.SliderStep = [1,1];
end
handles.sd_curChannel.Value = 1;
handles.sd_curChannel.Min = 1;
handles.sd_curChannel.Max = handles.dvObj.nChannel;
handles.fixSize = 1;
if handles.dvObj.nChannel > 1
    handles.sd_curChannel.SliderStep = [1,1]/(handles.dvObj.nChannel-1);
else
    handles.sd_curChannel.SliderStep = [1,1];
end
% Update handles structure
handles.trackControl = [];
handles.isTrackMode = false;
handles.displayLength = 2;
handles.maxTrackDist = inf;
handles.csfObjs{handles.curFrame} = updateUI(handles);
guidata(hObject, handles);
linkaxes([handles.ax_rawSeg,handles.ax_finalSeg,handles.ax_overlay],'xy');

% UIWAIT makes maskTracker wait for user response (see UIRESUME)
% uiwait(handles.figure1);
function [csfObj,controller] = updateUI(handles,isFull)
    if ~exist('isFull','var')
        isFull = 0;
    end
    handles.edt_rmSmallThres.String = num2str(handles.rmSmallThres);
    if handles.cb_rmSmall.Value
        handles.edt_rmSmallThres.Enable = 'on';
    else
        handles.edt_rmSmallThres.Enable = 'off';
    end
    %handles.pm_breakMethod.Value = handles.bbMethodIndex;
    handles.edt_breakThres.String = num2str(handles.bbThres);
    if handles.cb_breakBridge.Value
        handles.pm_breakMethod.Enable = 'on';
        handles.edt_breakThres.Enable = 'on';
    else
        handles.pm_breakMethod.Enable = 'off';
        handles.edt_breakThres.Enable = 'off';
    end
    %handles.pm_rExtMethod.Value = handles.rExtMethodIndex;
    handles.edt_rExtThres.String = num2str(handles.rExtThres);
    if handles.cb_regionExt.Value
        handles.pm_rExtMethod.Enable = 'on';
        handles.edt_rExtThres.Enable = 'on';
    else
        handles.pm_rExtMethod.Enable = 'off';
        handles.edt_rExtThres.Enable = 'off';
    end
    if handles.cb_fixSize.Value
        handles.edt_fixSize.Enable = 'on';
    else
        handles.edt_fixSize.Enable = 'off';
    end
    if handles.isTrackMode
        handles.btn_trackMode.BackgroundColor = [1,0,0];
        handles.edt_displayLength.Enable = 'on';
        handles.btn_rollback.Enable = 'on';
        handles.edt_rollbackFrame.Enable = 'on';
        handles.btn_trackNext.Enable = 'on';
        handles.edt_maxDist.Enable = 'on';
        handles.btn_trackTillEnd.Enable = 'on';
        handles.sd_curFrame.Enable = 'off';
    else
        handles.btn_trackMode.BackgroundColor = 0.85*ones(1,3);
        handles.edt_displayLength.Enable = 'off';
        handles.btn_rollback.Enable = 'off';
        handles.edt_rollbackFrame.Enable = 'off';
        handles.btn_trackNext.Enable = 'off';
        handles.edt_maxDist.Enable = 'off';
        handles.btn_trackTillEnd.Enable = 'off';
        cla(handles.ax_trackMap);
        xticks(handles.ax_trackMap,[]);
        yticks(handles.ax_trackMap,[]);
        handles.sd_curFrame.Enable = 'on';
    end
    handles.edt_overlayRatio.String = num2str(handles.overlayRatio);
    handles.tx_t.String = sprintf('T: %d/%d',handles.curFrame,handles.dvObj.nSteps);
    handles.tx_z.String = sprintf('Z: %d/%d',handles.curZPos,handles.dvObj.nZSlice);
    handles.tx_c.String = sprintf('C: %d/%d',handles.curChannel,handles.dvObj.nChannel);
    %% draw picture
    rawMask = squeeze(handles.predMat(handles.curFrame,:,:)==2);
    imagesc(handles.ax_rawSeg,rawMask);
    colormap(gray);
    xticks(handles.ax_rawSeg,[]);
    yticks(handles.ax_rawSeg,[]);
    [finalMask,L] = procImage(rawMask,handles);
    handles.tx_nCell.String = sprintf('%d/%d',handles.curCell,max(L(:)));
    imagesc(handles.ax_finalSeg,finalMask); 
    xticks(handles.ax_finalSeg,[]); 
    yticks(handles.ax_finalSeg,[]);
    expIm = handles.dvObj.rawData{handles.curZPos,handles.curChannel,handles.curFrame};
    imagesc(handles.ax_overlay,expIm); 
    handles.ax_overlay.NextPlot = 'add';
    h = imagesc(handles.ax_overlay,finalMask);
    h.AlphaData = handles.overlayRatio;
    handles.ax_overlay.NextPlot = 'replace';
    xticks(handles.ax_overlay,[]); 
    yticks(handles.ax_overlay,[]);
    if ~isempty(handles.axesLim)
        handles.ax_rawSeg.XLim = handles.axesLim{1};
        handles.ax_rawSeg.YLim = handles.axesLim{2};
    end
    csfObj = CellSegFrame(L,handles.dvObj.subSet(handles.curFrame));
    %% single cell
    scImage = csfObj.getCellMaskedImage(handles.curCell,max([csfObj.maxLength,handles.fixSize]),...
        'median',handles.cb_scBGSub.Value);
    index = handles.dvObj.nChannel*(handles.curZPos-1)+handles.curChannel;
    imagesc(handles.ax_singleCell,squeeze(scImage(:,:,index)));
    xticks(handles.ax_singleCell,[]);
    yticks(handles.ax_singleCell,[]);
    handles.tx_cellSizeRange.String = sprintf('%d-%d',min(csfObj.cellArea),max(csfObj.cellArea));
    handles.tx_cellWidthRange.String = sprintf('%d-%d',min(csfObj.cellBox(:,3)),max(csfObj.cellBox(:,3)));
    handles.tx_cellHeightRange.String = sprintf('%d-%d',min(csfObj.cellBox(:,4)),max(csfObj.cellBox(:,4)));
    handles.edt_fixSize.String = num2str(max([handles.fixSize,csfObj.maxLength]));
    %% track
    handles.maxTrackDist = min([handles.maxTrackDist,csfObj.maxLength]);
    handles.edt_displayLength.String = num2str(handles.displayLength);
    handles.edt_maxDist.String = num2str(handles.maxTrackDist);
    handles.edt_rollbackFrame.String = '';
    if isFull
        if handles.isTrackMode 
            if isempty(handles.trackControl)
                if handles.curFrame ~= 1
                    error('handles.curFrame expect as 1, get %d',handles.curFrame)
                end
                handles.trackControl = CellTrackController(csfObj,handles.dvObj.nSteps);
            elseif handles.curFrame == (handles.trackControl.curFrame + 1)
                handles.trackControl.commitNew(csfObj,handles.maxTrackDist);
            elseif handles.curFrame <= handles.trackControl.curFrame
                handles.trackControl.rollBackTo(handles.curFrame);
                if handles.curFrame == 1
                    handles.trackControl = CellTrackController(csfObj,handles.dvObj.nSteps);
                else
                    handles.trackControl.refreshCurFrame(csfObj,handles.maxTrackDist);
                end
            else
                error('unsolved track action, current frame: %d, record frame: %d',...
                    handles.curFrame,handles.trackControl.curFrame);
            end
            handles.trackControl.trackMap(handles.ax_trackMap);
        end
    end
    if handles.cb_showCentroid.Value
        if handles.isTrackMode
            handles.trackControl.showTrack(handles.ax_finalSeg,...
                handles.curFrame,...
                max([1,handles.curFrame-handles.displayLength+1]));
        else
            handles.ax_finalSeg.NextPlot = 'add';
            csfObj.scatterCentroid(handles.ax_finalSeg,ones(1,3)*0.8,ones(1,3)*0);
            handles.ax_finalSeg.NextPlot = 'replace';
        end     
    end
    if isempty(handles.trackControl)
        handles.tx_nTrack.String = 'NaN-NaN';
        handles.tx_trackLength.String = 'NaN-NaN';
    else
        handles.tx_nTrack.String = num2str(handles.trackControl.nTrack);
        trackLength = handles.trackControl.trackLength;
        handles.tx_trackLength.String = sprintf('%d-%d',min(trackLength),max(trackLength));
    end
    controller = handles.trackControl;


function [im,L] = procImage(rawMat,handles)
    if handles.cb_fillHole.Value
        rawMat = imfill(rawMat,'holes');
    end
    if handles.cb_breakBridge.Value
        cont = cellstr(handles.pm_breakMethod.String);
        rawMat = imopen(rawMat,strel(cont{handles.pm_breakMethod.Value},handles.bbThres));
    end
    if handles.cb_rmSmall.Value
        rawMat = bwareaopen(rawMat,handles.rmSmallThres);
    end
    if handles.cb_eedge.Value
        rawMat = imclearborder(rawMat,4);
    end
    cc = bwconncomp(rawMat,8);
    L = labelmatrix(cc);
    if handles.cb_regionExt.Value
        cont = cellstr(handles.pm_rExtMethod.String);
        L = imdilate(L,strel(cont{handles.pm_rExtMethod.Value},handles.rExtThres));
    end
    im = label2rgb(L,'jet','k','shuffle');
    if handles.cb_markCell.Value
        mask = L == handles.curCell;
        im(repmat(mask,[1,1,3])) = intmax('uint8');
    end

% --- Outputs from this function are returned to the command line.
function varargout = maskTracker_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in popupmenu7.
function popupmenu7_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu7 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu7


% --- Executes during object creation, after setting all properties.
function popupmenu7_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in btn_trackNext.
function btn_trackNext_Callback(hObject, eventdata, handles)
% hObject    handle to btn_trackNext (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if handles.curFrame == handles.dvObj.nSteps
    warndlg('Track done!','MT');
    return
else
    handles.curFrame = handles.curFrame + 1;
    handles.sd_curFrame.Value = handles.curFrame;
    [handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
    guidata(hObject,handles);
end

% --- Executes on button press in cb_showCentroid.
function cb_showCentroid_Callback(hObject, eventdata, handles)
% hObject    handle to cb_showCentroid (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
updateUI(handles);
% Hint: get(hObject,'Value') returns toggle state of cb_showCentroid



function edt_displayLength_Callback(hObject, eventdata, handles)
% hObject    handle to edt_displayLength (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.displayLength = str2double(get(hObject,'String'));
updateUI(handles);
guidata(hObject,handles);
% Hints: get(hObject,'String') returns contents of edt_displayLength as text
%        str2double(get(hObject,'String')) returns contents of edt_displayLength as a double


% --- Executes during object creation, after setting all properties.
function edt_displayLength_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edt_displayLength (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function sd_curFrame_Callback(hObject, eventdata, handles)
% hObject    handle to sd_curFrame (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.curFrame = round(get(hObject,'Value'));
handles.csfObjs{handles.curFrame} = updateUI(handles);
guidata(hObject,handles);
% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function sd_curFrame_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sd_curFrame (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

% --- Executes on slider movement.
function sd_curZPos_Callback(hObject, eventdata, handles)
% hObject    handle to sd_curZPos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.curZPos = round(get(hObject,'Value'));
guidata(hObject,handles);
updateUI(handles);
% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function sd_curZPos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sd_curZPos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

% --- Executes on slider movement.
function sd_curChannel_Callback(hObject, eventdata, handles)
% hObject    handle to sd_curChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
hObject.Value = max([hObject.Min,hObject.Value]);
hObject.Value = min([hObject.Max,hObject.Value]);
handles.curChannel = round(get(hObject,'Value'));
guidata(hObject,handles);
updateUI(handles);
% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

% --- Executes during object creation, after setting all properties.
function sd_curChannel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sd_curChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in btn_lastCell.
function btn_lastCell_Callback(hObject, eventdata, handles)
% hObject    handle to btn_lastCell (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.curCell = handles.curCell - 1;
if handles.curCell < 1
    handles.curCell = handles.csfObjs{handles.curFrame}.nCell;
end
updateUI(handles);
guidata(hObject,handles);

% --- Executes on button press in btn_nextCell.
function btn_nextCell_Callback(hObject, eventdata, handles)
% hObject    handle to btn_nextCell (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
maxNum = handles.csfObjs{handles.curFrame}.nCell;
handles.curCell = handles.curCell + 1;
if handles.curCell > maxNum
    handles.curCell = 1;
end
updateUI(handles);
guidata(hObject,handles);

% --- Executes on button press in cb_scBGSub.
function cb_scBGSub_Callback(hObject, eventdata, handles)
% hObject    handle to cb_scBGSub (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
updateUI(handles);
% Hint: get(hObject,'Value') returns toggle state of cb_scBGSub


% --- Executes on button press in cb_fillHole.
function cb_fillHole_Callback(hObject, eventdata, handles)
% hObject    handle to cb_fillHole (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
guidata(hObject,handles);
% Hint: get(hObject,'Value') returns toggle state of cb_fillHole


% --- Executes on button press in cb_rmSmall.
function cb_rmSmall_Callback(hObject, eventdata, handles)
% hObject    handle to cb_rmSmall (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
guidata(hObject,handles);
% Hint: get(hObject,'Value') returns toggle state of cb_rmSmall


% --- Executes on button press in cb_breakBridge.
function cb_breakBridge_Callback(hObject, eventdata, handles)
% hObject    handle to cb_breakBridge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% handles    structure with handles and user data (see GUIDATA)
[handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
guidata(hObject,handles);
% Hint: get(hObject,'Value') returns toggle state of cb_breakBridge


% --- Executes on button press in cb_regionExt.
function cb_regionExt_Callback(hObject, eventdata, handles)
% hObject    handle to cb_regionExt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% handles    structure with handles and user data (see GUIDATA)
[handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
guidata(hObject,handles);
% Hint: get(hObject,'Value') returns toggle state of cb_regionExt



function edt_rmSmallThres_Callback(hObject, eventdata, handles)
% hObject    handle to edt_rmSmallThres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.rmSmallThres = str2double(get(hObject,'String'));
% handles    structure with handles and user data (see GUIDATA)
[handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
guidata(hObject,handles);
% Hints: get(hObject,'String') returns contents of edt_rmSmallThres as text
%        str2double(get(hObject,'String')) returns contents of edt_rmSmallThres as a double


% --- Executes during object creation, after setting all properties.
function edt_rmSmallThres_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edt_rmSmallThres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edt_breakThres_Callback(hObject, eventdata, handles)
% hObject    handle to edt_breakThres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.bbThres = str2double(get(hObject,'String'));
[handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
guidata(hObject,handles);
% Hints: get(hObject,'String') returns contents of edt_breakThres as text
%        str2double(get(hObject,'String')) returns contents of edt_breakThres as a double


% --- Executes during object creation, after setting all properties.
function edt_breakThres_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edt_breakThres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edt_rExtThres_Callback(hObject, eventdata, handles)
% hObject    handle to edt_rExtThres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.rExtThres = str2double(get(hObject,'String'));
[handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
guidata(hObject,handles);
% Hints: get(hObject,'String') returns contents of edt_rExtThres as text
%        str2double(get(hObject,'String')) returns contents of edt_rExtThres as a double


% --- Executes during object creation, after setting all properties.
function edt_rExtThres_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edt_rExtThres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in pm_breakMethod.
function pm_breakMethod_Callback(hObject, eventdata, handles)
% hObject    handle to pm_breakMethod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
guidata(hObject,handles);
% Hints: contents = cellstr(get(hObject,'String')) returns pm_breakMethod contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pm_breakMethod


% --- Executes during object creation, after setting all properties.
function pm_breakMethod_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pm_breakMethod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in pm_rExtMethod.
function pm_rExtMethod_Callback(hObject, eventdata, handles)
% hObject    handle to pm_rExtMethod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
guidata(hObject,handles);
% Hints: contents = cellstr(get(hObject,'String')) returns pm_rExtMethod contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pm_rExtMethod


% --- Executes during object creation, after setting all properties.
function pm_rExtMethod_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pm_rExtMethod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in cb_fixSize.
function cb_fixSize_Callback(hObject, eventdata, handles)
% hObject    handle to cb_fixSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
updateUI(handles);
% Hint: get(hObject,'Value') returns toggle state of cb_fixSize



function edt_fixSize_Callback(hObject, eventdata, handles)
% hObject    handle to edt_fixSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.fixSize = str2double(get(hObject,'String'));
updateUI(handles);
guidata(hObject,handles);
% Hints: get(hObject,'String') returns contents of edt_fixSize as text
%        str2double(get(hObject,'String')) returns contents of edt_fixSize as a double


% --- Executes during object creation, after setting all properties.
function edt_fixSize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edt_fixSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edt_overlayRatio_Callback(hObject, eventdata, handles)
% hObject    handle to edt_overlayRatio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.overlayRatio = str2double(get(hObject,'String'));
guidata(hObject,handles);
updateUI(handles);
% Hints: get(hObject,'String') returns contents of edt_overlayRatio as text
%        str2double(get(hObject,'String')) returns contents of edt_overlayRatio as a double


% --- Executes during object creation, after setting all properties.
function edt_overlayRatio_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edt_overlayRatio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in btn_hold.
function btn_hold_Callback(hObject, eventdata, handles)
% hObject    handle to btn_hold (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isempty(handles.axesLim)
    handles.axesLim = {handles.ax_rawSeg.XLim,handles.ax_rawSeg.YLim};
    hObject.BackgroundColor = [0,1,0];
else
    handles.axesLim = [];
    hObject.BackgroundColor = [1,0,0];
end
guidata(hObject,handles);
updateUI(handles);

% --- Executes during object creation, after setting all properties.
function btn_hold_CreateFcn(hObject, eventdata, handles)
% hObject    handle to btn_hold (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes on button press in cb_eedge.
function cb_eedge_Callback(hObject, eventdata, handles)
% hObject    handle to cb_eedge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
guidata(hObject,handles);
% Hint: get(hObject,'Value') returns toggle state of cb_eedge


% --- Executes on button press in cb_markCell.
function cb_markCell_Callback(hObject, eventdata, handles)
% hObject    handle to cb_markCell (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
updateUI(handles);
% Hint: get(hObject,'Value') returns toggle state of cb_markCell


% --- Executes on button press in btn_trackMode.
function btn_trackMode_Callback(hObject, eventdata, handles)
% hObject    handle to btn_trackMode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.isTrackMode = ~handles.isTrackMode;
if handles.isTrackMode && isempty(handles.trackControl)
    handles.curFrame = 1;
elseif handles.isTrackMode
    handles.curFrame = handles.trackControl.curFrame;
end
handles.sd_curFrame.Value = handles.curFrame;
[handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
guidata(hObject,handles);




% --- Executes on button press in btn_rollback.
function btn_rollback_Callback(hObject, eventdata, handles)
% hObject    handle to btn_rollback (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if handles.curFrame > 1
    handles.curFrame = handles.curFrame - 1;
    handles.sd_curFrame.Value = handles.curFrame;
    [handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
    guidata(hObject,handles);
end


function edt_rollbackFrame_Callback(hObject, eventdata, handles)
% hObject    handle to edt_rollbackFrame (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
f = str2double(get(hObject,'String'));
if f>=1 && f<= handles.dvObj.nSteps
    handles.curFrame = f;
    handles.sd_curFrame.Value = handles.curFrame;
    [handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
    guidata(hObject,handles);
end
% Hints: get(hObject,'String') returns contents of edt_rollbackFrame as text
%        str2double(get(hObject,'String')) returns contents of edt_rollbackFrame as a double


% --- Executes during object creation, after setting all properties.
function edt_rollbackFrame_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edt_rollbackFrame (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edt_maxDist_Callback(hObject, eventdata, handles)
% hObject    handle to edt_maxDist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.maxTrackDist = str2double(get(hObject,'String'));
[handles.csfObjs{handles.curFrame},handles.trackControl] = updateUI(handles,1);
guidata(hObject,handles);
% Hints: get(hObject,'String') returns contents of edt_maxDist as text
%        str2double(get(hObject,'String')) returns contents of edt_maxDist as a double


% --- Executes during object creation, after setting all properties.
function edt_maxDist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edt_maxDist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in btn_trackTillEnd.
function btn_trackTillEnd_Callback(hObject, eventdata, handles)
% hObject    handle to btn_trackTillEnd (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
nFrame = handles.dvObj.nSteps - handles.curFrame;
hsAbleHandle(handles.figure1,'off');
hbar = waitbar(0,'tracking...');
for m = 1:nFrame
    frame = handles.curFrame+m;
    rawMask = squeeze(handles.predMat(frame,:,:)==2);
    [~,L] = procImage(rawMask,handles);
    csfObj = CellSegFrame(L,handles.dvObj.subSet(frame));
    handles.trackControl.commitNew(csfObj,handles.maxTrackDist);
    if mod(m,5)==0
        waitbar(m/nFrame,hbar);
    end
end
waitbar(1,hbar);
hsAbleHandle(handles.figure1,'on');
handles.curFrame = handles.dvObj.nSteps;
handles.sd_curFrame.Value = handles.dvObj.nSteps;
updateUI(handles,1);
close(hbar);
guidata(hObject,handles);


% --- Executes on button press in btn_expToWS.
function btn_expToWS_Callback(hObject, eventdata, handles)
% hObject    handle to btn_expToWS (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
assignin('base','trackControl',handles.trackControl)