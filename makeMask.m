function varargout = makeMask(varargin)
% MAKEMASK MATLAB code for makeMask.fig
%      MAKEMASK, by itself, creates a new MAKEMASK or raises the existing
%      singleton*.
%
%      H = MAKEMASK returns the handle to a new MAKEMASK or the handle to
%      the existing singleton*.
%
%      MAKEMASK('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MAKEMASK.M with the given input arguments.
%
%      MAKEMASK('Property','Value',...) creates a new MAKEMASK or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before makeMask_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to makeMask_OpeningFcn via varargin.
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help makeMask

% Last Modified by GUIDE v2.5 24-Dec-2018 15:38:22

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @makeMask_OpeningFcn, ...
                   'gui_OutputFcn',  @makeMask_OutputFcn, ...
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


% --- Executes just before makeMask is made visible.
function makeMask_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to makeMask (see VARARGIN)

% Choose default command line output for makeMask
handles.output = hObject;
handles.curZPos = 1;
handles.curTPos = 1;
handles.curChannel = 1;
handles.curLabel = 0;
handles.labelColor = [0,0,0;1,0,0];
handles.nLabel = 2;
handles.mixRatio = 0;
handles.mode = 1;
handles.bushSize = 1;
handles.isMouseDown = 0;
handles.isNormalize = 0;
handles.isMaskView = 0;
handles.data = varargin{1};
handles.mask = zeros(handles.data.imSize);
handles.slider_ZPos.Min = 1;
handles.slider_ZPos.Max = length(handles.data.sliceInfo);
handles.slider_ZPos.Value = 1;
handles.slider_ZPos.SliderStep = [1,1]/max(1,(length(handles.data.sliceInfo)-1));
handles.slider_TPos.Min = 1;
handles.slider_TPos.Max = length(handles.data.timeInfo);
handles.slider_TPos.Value = 1;
handles.slider_TPos.SliderStep = [1,1]/max(1,(length(handles.data.timeInfo)-1));
handles.slider_CPos.Min = 1;
handles.slider_CPos.Max = length(handles.data.filterInfo);
handles.slider_CPos.Value = 1;
handles.slider_CPos.SliderStep = [1,1]/max(1,(length(handles.data.filterInfo)-1));
handles.slider_curLabel.Min = 0;
handles.slider_curLabel.Max = handles.nLabel - 1;
handles.slider_curLabel.Value = 0;
handles.slider_curLabel.SliderStep = [1,1]/(handles.nLabel-1);
handles.axesLim = [];
% Update handles structure
guidata(hObject, handles);
refreshUI(handles);
% UIWAIT makes makeMask wait for user response (see UIRESUME)
% uiwait(handles.figure1);
function refreshUI(h)
    if h.isMaskView
        bw = h.mask == h.curLabel;
        cc = bwconncomp(bw,4);
        cc_mat = labelmatrix(cc);
        cc_rgb = label2rgb(cc_mat,'spring','c','shuffle');
        edge = bwperim(bw);
        im_overlap = imoverlay(cc_rgb,edge,[0,0,0]);
        imagesc(h.axes1,im_overlap); xticks([]); yticks([]);
    else
        imMat = h.data.rawData{h.curZPos,h.curChannel,h.curTPos};
        if h.isNormalize
            imMat = imMat/max(imMat(:));
            imMat = adapthisteq(imMat);
        end
        imMat = repmat(double(imMat)/double(max(imMat(:))),[1,1,3]);
        maskMat = zeros(h.data.imSize,h.data.imSize,3);
        for m = 1:3
            for n = 1:(h.nLabel-1)
                I = h.mask == n;
                if sum(I(:)) > 0
                    tmp = maskMat(:,:,m);
                    tmp(I) = h.labelColor(n+1,m);
                    maskMat(:,:,m) = tmp;
                end
            end
        end
        overlapMat = imMat * (1-h.mixRatio) + maskMat * h.mixRatio;
        BW = h.mask == 0;
        for m = 1:3
            overlapMat(:,:,m) = overlapMat(:,:,m) + imMat(:,:,m).*BW*h.mixRatio;
        end
        imagesc(h.axes1,overlapMat); xticks([]); yticks([]);       
    end
    h.txt_curLabel.String = num2str(h.curLabel);
    h.btn_curColor.BackgroundColor = h.labelColor(h.curLabel+1,:);
    h.txt_ZPos.String = sprintf('Z: %d',h.data.sliceInfo(h.curZPos));
    h.txt_TPos.String = sprintf('T: %d',h.data.timeInfo(h.curTPos));
    h.txt_CPos.String = sprintf('Channel: %s',h.data.filterInfo{h.curChannel});
    h.txt_mixRatio.String = sprintf('Mix Ratio: %.2f',h.mixRatio);
    h.edt_curBushSize.String = num2str(h.bushSize);
    if h.mode
        h.btn_mode.String = 'Region Mode';
    else
        h.btn_mode.String = 'Bush Mode';
    end
    if ~isempty(h.axesLim)
        h.axes1.XLim = h.axesLim(1:2);
        h.axes1.YLim = h.axesLim(3:4);
    end

% --- Outputs from this function are returned to the command line.
function varargout = makeMask_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on slider movement.
function slider_ZPos_Callback(hObject, eventdata, handles)
% hObject    handle to slider_ZPos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tmp = get(hObject,'Value');
tmp = round(tmp);
if tmp < 0 || tmp > handles.data.nZSlice
    return;
else
    handles.curZPos = tmp;
    guidata(hObject,handles);
    refreshUI(handles);
end
% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider_ZPos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_ZPos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider_TPos_Callback(hObject, eventdata, handles)
% hObject    handle to slider_TPos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tmp = get(hObject,'Value');
tmp = round(tmp);
if tmp < 0 || tmp > handles.data.nSteps
    return;
else
    handles.curTPos = tmp;
    guidata(hObject,handles);
    refreshUI(handles);
end
% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider_TPos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_TPos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider_CPos_Callback(hObject, eventdata, handles)
% hObject    handle to slider_CPos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tmp = get(hObject,'Value');
tmp = round(tmp);
if tmp < 0 || tmp > handles.data.nChannel
    return;
else
    handles.curChannel = tmp;
    guidata(hObject,handles);
    refreshUI(handles);
end
% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider_CPos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_CPos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider_curLabel_Callback(hObject, eventdata, handles)
% hObject    handle to slider_curLabel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tmp = get(hObject,'Value');
tmp = round(tmp);
if tmp < 0 || tmp > handles.nLabel
    return;
else
    handles.curLabel = tmp;
    guidata(hObject,handles);
    refreshUI(handles);
end
% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider_curLabel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_curLabel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in btn_curColor.
function btn_curColor_Callback(hObject, eventdata, handles)
% hObject    handle to btn_curColor (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if handles.curLabel
    c = uisetcolor();
    handles.labelColor(handles.curLabel+1,:) = c;
    guidata(hObject,handles);
    refreshUI(handles);
end

% --- Executes on button press in btn_newLabel.
function btn_newLabel_Callback(hObject, eventdata, handles)
% hObject    handle to btn_newLabel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.nLabel = handles.nLabel + 1;
handles.slider_curLabel.Min = 0;
handles.slider_curLabel.Max = handles.nLabel - 1;
handles.slider_curLabel.Value = handles.nLabel - 1;
handles.slider_curLabel.SliderStep = [1,1]/(handles.nLabel-1);
handles.labelColor = [handles.labelColor;0,0,0];
handles.curLabel = handles.nLabel - 1;
guidata(hObject,handles);
refreshUI(handles);


function edt_curBushSize_Callback(hObject, eventdata, handles)
% hObject    handle to edt_curBushSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tmp = get(hObject,'String');
tmp = round(str2double(tmp));
if ~isnan(tmp)
    handles.bushSize = tmp;
    guidata(hObject,handles);
end
refreshUI(handles);
% Hints: get(hObject,'String') returns contents of edt_curBushSize as text
%        str2double(get(hObject,'String')) returns contents of edt_curBushSize as a double


% --- Executes during object creation, after setting all properties.
function edt_curBushSize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edt_curBushSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in btn_done.
function btn_done_Callback(hObject, eventdata, handles)
% hObject    handle to btn_done (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
assignin('base',sprintf('imMask_T%d',handles.curTPos),handles.mask);
csvwrite(sprintf('image_mask_T%d.csv',handles.curTPos),handles.mask);
disp('successfully export and saved');


% --- Executes on button press in btn_mode.
function btn_mode_Callback(hObject, eventdata, handles)
% hObject    handle to btn_mode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.mode = ~handles.mode;
guidata(hObject,handles);
refreshUI(handles);


% --- Executes on slider movement.
function slider_mixRatio_Callback(hObject, eventdata, handles)
% hObject    handle to slider_mixRatio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tmp = get(hObject,'Value');
if tmp < 0 || tmp > 1
    return;
else
    handles.mixRatio = tmp;
    guidata(hObject,handles);
    refreshUI(handles);
end
% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider_mixRatio_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_mixRatio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in btn_action.
function btn_action_Callback(hObject, eventdata, handles)
% hObject    handle to btn_action (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if handles.mode % mode == 1 : region mode
    hObject.Enable = 'off';
    try
        curIm = handles.data.rawData{handles.curZPos,handles.curChannel,handles.curTPos};
        mask = roipoly(curIm./max(curIm(:)));
        handles.mask(mask) = handles.curLabel;
        guidata(hObject,handles);
        refreshUI(handles);
    catch
        hObject.Enable = 'on';
    end
    hObject.Enable = 'on';
end


% --- Executes during object creation, after setting all properties.
function axes1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to axes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
% Hint: place code in OpeningFcn to populate axes1


% --- Executes on mouse press over figure background, over a disabled or
% --- inactive control, or over an axes background.
function figure1_WindowButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.isMouseDown = 1;
guidata(hObject,handles);


% --- Executes on mouse press over figure background, over a disabled or
% --- inactive control, or over an axes background.
function figure1_WindowButtonUpFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.isMouseDown = 0;
guidata(hObject,handles);



% --- Executes on mouse motion over figure - except title and menu.
function figure1_WindowButtonMotionFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if handles.isMouseDown && handles.mode == 0 %mode == 0 : draw mode
    pos = handles.axes1.CurrentPoint;
    pos = round(pos(1,1:2));
    if all(pos>0) && all(pos<handles.data.imSize)
        [X,Y] = meshgrid(1:handles.data.imSize);
        Dis = sqrt((X - pos(1)).^2 + (Y - pos(2)).^2);
        handles.mask(Dis<handles.bushSize) = handles.curLabel;
        guidata(hObject,handles);
        refreshUI(handles);
    end    
end


% --- Executes on button press in btn_release.
function btn_release_Callback(hObject, eventdata, handles)
% hObject    handle to btn_release (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isempty(handles.axesLim)
    hObject.String = 'release';
    handles.axesLim = [handles.axes1.XLim,handles.axes1.YLim];
else
    hObject.String = 'hold';
    handles.axesLim = [];
end
guidata(hObject,handles);
refreshUI(handles);


% --- Executes on key release with focus on figure1 or any of its controls.
function figure1_WindowKeyReleaseFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.FIGURE)
%	Key: name of the key that was released, in lower case
%	Character: character interpretation of the key(s) that was released
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) released
% handles    structure with handles and user data (see GUIDATA)
switch eventdata.Key
    case '1'
        handles.slider_mixRatio.Value = 0;
        handles.mixRatio = 0;
    case '2'
        handles.slider_mixRatio.Value = 0.25;
        handles.mixRatio = 0.25;
    case '3'
        handles.slider_mixRatio.Value = 0.5;
        handles.mixRatio = 0.5;
    case '4'
        handles.slider_mixRatio.Value = 0.75;
        handles.mixRatio = 0.75;
    case '5'
        handles.slider_mixRatio.Value = 1;
        handles.mixRatio = 1;
end
guidata(hObject,handles);
refreshUI(handles);


% --- Executes on button press in btn_loadMask.
function btn_loadMask_Callback(hObject, eventdata, handles)
% hObject    handle to btn_loadMask (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[fn,fp,index] = uigetfile('*.csv');
if index
    try
        mat = importdata(strcat(fp,fn));
        if size(mat,1) == handles.data.imSize
            nLabels = length(unique(mat(:)));
            if max(nLabels,max(mat(:))+1) > handles.nLabel
                warndlg(sprintf('label number: %d is needed for parsing this mask',max(nLabels,max(mat(:))+1)));
                return;
            else
                handles.mask = mat;
                guidata(hObject,handles);
                refreshUI(handles);
                warndlg('read successfully!');
            end
        else
            warndlg(sprintf('Expected image size: %d, get: %d',handles.data,imSize,size(mat,1)));
            return;
        end
    catch
    end
end


% --- Executes on button press in btn_init_est.
function btn_init_est_Callback(hObject, eventdata, handles)
% hObject    handle to btn_init_est (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
answer = questdlg('Estimation Method:','mask','Edge','AutoContour','Edge');
curIm = handles.data.rawData{handles.curZPos,handles.curChannel,handles.curTPos};
curIm = curIm/max(curIm(:));
im = adapthisteq(curIm);
if strcmp(answer,'Edge')
    grad = imgradient(curIm);
    grad = grad/max(grad(:));
    answer = inputdlg({'intensity','gradients'},'mask',1,{'0.65','0.3'});
    handles.mask = or(handles.mask,and(im>str2double(answer{1}),grad<str2double(answer{2})));
else
    answer = inputdlg({'iteration steps'},'mask',1,{'1000'});
    handles.mask = segmentImage(im,str2double(answer{1}));
end
guidata(hObject,handles);
refreshUI(handles);



% --- Executes on button press in rbt_normalize.
function rbt_normalize_Callback(hObject, eventdata, handles)
% hObject    handle to rbt_normalize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.isNormalize = get(hObject,'Value');
guidata(hObject,handles);
refreshUI(handles);
% Hint: get(hObject,'Value') returns toggle state of rbt_normalize


% --- Executes on button press in btn_clear.
function btn_clear_Callback(hObject, eventdata, handles)
% hObject    handle to btn_clear (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.mask = zeros(size(handles.mask));
guidata(hObject,handles);
refreshUI(handles);


% --- Executes on button press in rbt_mask_view.
function rbt_mask_view_Callback(hObject, eventdata, handles)
% hObject    handle to rbt_mask_view (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.isMaskView = get(hObject,'Value');
guidata(hObject,handles);
refreshUI(handles);
% Hint: get(hObject,'Value') returns toggle state of rbt_mask_view
