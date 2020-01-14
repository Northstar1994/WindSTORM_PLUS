function varargout = WindSTORM_GUI(varargin)
% WINDSTORM_GUI MATLAB code for WindSTORM_GUI.fig
%      WINDSTORM_GUI, by itself, creates a new WINDSTORM_GUI or raises the existing
%      singleton*.
%
%      H = WINDSTORM_GUI returns the handle to a new WINDSTORM_GUI or the handle to
%      the existing singleton*.
%
%      WINDSTORM_GUI('CALLBACK',hObject,eclcventData,handles,...) calls the local
%      function named CALLBACK in WINDSTORM_GUI.M with the given input arguments.
%
%      WINDSTORM_GUI('Property','Value',...) creates a new WINDSTORM_GUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before WindSTORM_GUI_OpeningFcn gets called.  An
%      
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to WindSTORM_GUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help WindSTORM_GUI

% Last Modified by GUIDE v2.5 06-Dec-2019 17:46:36

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @WindSTORM_GUI_OpeningFcn, ...
                   'gui_OutputFcn',  @WindSTORM_GUI_OutputFcn, ...
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


% --- Executes just before WindSTORM_GUI is made visible.
function WindSTORM_GUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to WindSTORM_GUI (see VARARGIN)

% Choose default command line output for WindSTORM_GUI
handles.output = hObject;
    
% Update handles structure
guidata(hObject, handles);
addpath('bfmatlab')
addpath('cpu1_functions')
addpath('cpupar_functions')
addpath('general_functions')
addpath('gpu_functions')
addpath('FRC_functions')
% UIWAIT makes WindSTORM_GUI wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = WindSTORM_GUI_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes on button press in SelectFileButton.
function SelectFileButton_Callback(hObject, eventdata, handles)
% hObject    handle to SelectFileButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PathName FileName imRAW imW imH imF imRW imRH
[FileName,PathName] = uigetfile('.tif','Please select image stack');

Count2photon = str2double(get(handles.ADUedit,'String')); % count to photons ratio of the camera
Baseline = str2double(get(handles.baselineedit,'String'));
% read image
[imRAW,imW,imH,imF,imRW,imRH] = ImageRead([PathName,FileName],Count2photon,Baseline);

set(handles.imageW,'String',num2str(imRW));
set(handles.imageH,'String',num2str(imRH));
set(handles.imageF,'String',num2str(imF));
disp(['Image Reading:','OK']);

set(handles.pathedit,'String',[PathName,FileName]);
set(handles.selectfolderpushbutton,'Enable','off');
set(handles.allstackpathedit,'Enable','off');

% --- Executes on button press in WindSTORMButton.
function WindSTORMButton_Callback(hObject, eventdata, handles)
% hObject    handle to WindSTORMButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PathName FileName imRAW imW imH imF imRW imRH

Intensity = str2double(get(handles.intensityedit,'String')); % estimated average emitter intensity of the dataset
Sigma = str2double(get(handles.sigmaedit,'String')); % the kernel width of the PSF of the system
Mode = get(handles.RunningMode,'Value');
minIntensity = Intensity/4;   % a global threshold set to eliminate very weak emitters

pathname = PathName;
filename = FileName;

%% 分割子集并行
seg = floor(imF/100);
result = cell(seg,1);
if(Mode==1)
    if(length(size(imRAW))<4)
        imRAW = reshape(imRAW,imW,imH,100,seg);
        if (isempty(gcp('nocreate')))
            parpool;
        end
    end
    tic % start the timer
    parfor s=1:seg    
        
        %% WindSTORM step 1: Wind Deconvolution
        % background subtraction
        [imBS,imBG] = cpBgSub(imRAW(:,:,:,s)); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)
        % wind deconvolution and peak finding
        [imDeconv, imPeak] = cpWindDeconv(imBS,Sigma,imBG,minIntensity);
        %% WindSTORM step 2: Emitter extraction and localization
        % emitter extraction
        [ROI,ROIsub,IDs,x0,y0] = cpExtractROIs(imDeconv,imPeak,imBS,Sigma);
        % emitter localization
        [Xc, Yc, T, fn] = cpGradientFit(ROI,ROIsub,IDs,x0,y0);
        %% save result
        %disp([num2str(s/seg*100),'%']);

        result(s,1) = {[(1:length(fn))',(s-1)*100+fn,Xc,Yc,T]};
    end
    toltime = toc
    
elseif(Mode == 2)
    blocksize = str2double(get(handles.gpuBlockSize,'String'));
    imRAW = reshape(imRAW,imW,imH,blocksize,floor(imF/blocksize));
if((imW==512)||(imW==256))    
    tic
    W = gpuInitPara(imRAW,Sigma,minIntensity);
    parfor s=1:seg   
        
        [imBS,imBG] = gpuBgSub(gpuArray(imRAW(:,:,:,s))); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)
        
        [imDeconv, imPeak] = gpuWindDeconv(imBS,Sigma,imBG,minIntensity,W);
        [imBS,imDeconv,imPeak] = gather(imBS,imDeconv,imPeak);
        
        [ROI,ROIsub,IDs,x0,y0] = cpgpuExtractROIs(imDeconv,imPeak,imBS,Sigma);

        [Xc, Yc, T, fn] = gpuGradientFit(gpuArray(ROI),gpuArray(ROIsub),gpuArray(IDs),gpuArray(x0),gpuArray(y0));
        [Xc, Yc, T, fn] = gather(Xc, Yc, T, fn);
        if(~isempty(fn))
        result(s,1) = {[single((1:length(fn))'),(s-1)*blocksize+fn,Xc,Yc,T]}
        else
            result(s,1)={single([])};
        end
        %disp([num2str((s/seg)*100),'%']);
    end
    toltime = toc
elseif(imW==1024)
    tic
        W = gpuInitPara(imRAW,Sigma,minIntensity);
    parfor s=1:seg   
        
        [imBS,imBG] = cpBgSub(imRAW(:,:,:,s)); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)
        % wind deconvolution and peak finding
%         imBS  = reshape(imBS,1024,1024,50,2);
%         imBG  = reshape(imBG,1024,1024,50,2);
%         for i =1:2
%         imBS(:,:,:,s) = gather(imBSs);
%         imBG(:,:,:,s) = gather(imBGs);
%     end
%     parfor s=1:floor(imF/blocksize) 
        [imDeconv, imPeak] = gpuWindDeconv(gpuArray(imBS),Sigma,gpuArray(imBG),minIntensity,W);
        [imDeconv,imPeak] = gather(imDeconv,imPeak);
        
        [ROI,ROIsub,IDs,x0,y0] = cpgpuExtractROIs(imDeconv,imPeak,imBS,Sigma);

        [Xc, Yc, T, fn] = gpuGradientFit(gpuArray(ROI),gpuArray(ROIsub),gpuArray(IDs),gpuArray(x0),gpuArray(y0));
        [Xc, Yc, T, fn] = gather(Xc, Yc, T, fn);
        if(~isempty(fn))
        result(s,1) = {[single((1:length(fn))'),(s-1)*blocksize+fn,Xc,Yc,T]}
        else
            result(s,1)={single([])};
        end
        disp([num2str((s/seg)*100),'%']);
    end
    toltime = toc
end

elseif(Mode == 3)
    if(length(size(imRAW))<4)
        imRAW = reshape(imRAW,imW,imH,100,seg);
    end
    tic
    for s=1:seg    
        
        [imBS,imBG] = cpBgSub(imRAW(:,:,:,s)); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)

        [imDeconv, imPeak] = cpWindDeconv(imBS,Sigma,imBG,minIntensity);

        [ROI,ROIsub,IDs,x0,y0] = cpExtractROIs(imDeconv,imPeak,imBS,Sigma);

        [Xc, Yc, T, fn] = cpGradientFit(ROI,ROIsub,IDs,x0,y0);

        disp([num2str(s/seg*100),'%']);

        result(s,1) = {[(1:length(fn))',(s-1)*100+fn,Xc,Yc,T]};
    end
    toltime = toc
    

elseif(Mode ==4)

        if(length(size(imRAW))>3)
        imRAW = reshape(imRAW,imW,imH,imF);
        end
        tic
        [imBS,imBG] = c1BgSub(imRAW); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)
        
        [imDeconv, imPeak] = c1WindDeconv(imBS,Sigma,imBG,minIntensity);

        [ROI,ROIsub,IDs,x0,y0] = c1ExtractROIs(imDeconv,imPeak,imBS,Sigma);

        [Xc, Yc, T, fn] = c1GradientFit(ROI,ROIsub,IDs,x0,y0);
        
        toltime = toc

        result = {[(1:length(fn))',fn,Xc,Yc,T]};
        
end

    %% 计算总的运算时间
    %disp(['Total computation time is ',num2str(t2-t1),' seconds']);
    set(handles.edit10,'String',num2str(toltime));
    result = cell2mat(result);
    disp(['Total localization number is ',num2str(length(result))]);
    set(handles.edit11,'String',num2str(length(result)));

    %% 数据存储记录
%     isBatch = strcmp(get(handles.SelectFileButton,'Enable'),'off');
%     StoreResult(result,pathname,filename,isBatch,Intensity,Sigma,Mode);
    %FRCstackoutput(results,pathname,filename,imH,imW,imRH,imRW)
    %% image rendring
%    ImageRender(result,imRW,imRH,imW,imH);

% --- Executes on button press in selectfolderpushbutton.
function selectfolderpushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to selectfolderpushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global PathName FileName imRAW imW imH imF imRW imRH

PathName = uigetdir('','选择指定文件夹：');
dirs=dir(PathName);%dirs结构体类型,不仅包括文件名，还包含文件其他信息。
dircell=struct2cell(dirs)'; %类型转化，转化为元组类型
FileName=dircell(:,1) ;%文件类型存放在第一列
Count2photon = str2double(get(handles.ADUedit,'String')); % count to photons ratio of the camera
Baseline = str2double(get(handles.baselineedit,'String'));

[imRAW,imW,imH,imF,imRW,imRH] = AllImageStackRead(FileName,PathName,Count2photon,Baseline);

set(handles.allstackpathedit,'String',PathName);
set(handles.SelectFileButton,'Enable','off');
set(handles.pathedit,'Enable','off');

% --- Executes on button press in recoverybutton.
function recoverybutton_Callback(hObject, eventdata, handles)
% hObject    handle to recoverybutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.SelectFileButton,'Enable','on');
set(handles.pathedit,'Enable','on');
set(handles.pathedit,'String','');
set(handles.selectfolderpushbutton,'Enable','on');
set(handles.allstackpathedit,'Enable','on');
set(handles.allstackpathedit,'String','');

% --- Executes on button press in BatchButton.
function BatchButton_Callback(hObject, eventdata, handles)
% hObject    handle to BatchButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
Intensity = str2double(get(handles.intensityedit,'String')); % estimated average emitter intensity of the dataset
Sigma = str2double(get(handles.sigmaedit,'String')); % the kernel width of the PSF of the system
Count2photon = str2double(get(handles.ADUedit,'String')); % count to photons ratio of the camera
minIntensity = Intensity/4;   % a global threshold set to eliminate very weak emitters
Baseline = str2double(get(handles.baselineedit,'String'));
Mode = get(handles.RunningMode,'Value');
set(handles.selectfolderpushbutton,'Enable','off');
set(handles.allstackpathedit,'Enable','off');
path = (get(handles.BatchPath,'String')); 
disp(path);
[p,l] = size(path);
FileName = cell(p,1);
PathName = cell(p,1);

for k=1:p
    strcell = strsplit(path(k,:),'\');
    FileName(k,1) = strcell(length(strcell));
    PathName(k,1) = {strrep(path(k,:),char(FileName(k,1)),'')} ;
end

for k=1:p
    pathname = char(PathName{k,1});
    filename = char(FileName{k,1});
    disp(pathname);
    disp(filename);    
% read image
[imRAW,imW,imH,imF,imRW,imRH] = ImageRead([pathname,filename],Count2photon,Baseline);

disp(['Image Reading:','OK']);
%% 分割子集并行
if(imW==128||imH==256)
    Mode=1;
else
    Mode=2;
end
seg = floor(imF/100);
result = cell(seg,1);
if(Mode==1)
    if(length(size(imRAW))<4)
        imRAW = reshape(imRAW,imW,imH,100,seg);
        if (isempty(gcp('nocreate')))
            parpool;
        end
    end
    tic
    parfor s=1:seg    

        [imBS,imBG] = cpBgSub(imRAW(:,:,:,s)); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)

        [imDeconv, imPeak] = cpWindDeconv(imBS,Sigma,imBG,minIntensity);

        [ROI,ROIsub,IDs,x0,y0] = cpExtractROIs(imDeconv,imPeak,imBS,Sigma);

        [Xc, Yc, T, fn] = cpGradientFit(ROI,ROIsub,IDs,x0,y0);

        %disp([num2str(s/seg*100),'%']);

        result(s,1) = {[(1:length(fn))',(s-1)*100+fn,Xc,Yc,T]};
    end
    toltime = toc
    
elseif(Mode == 2)
    
    blocksize = str2double(get(handles.gpuBlockSize,'String'));
    imRAW = reshape(imRAW,imW,imH,blocksize,floor(imF/blocksize));
if(imW==512)    
    tic
    parfor s=1:floor(imF/blocksize)   
        

        [imBS,imBG] = gpuBgSub(gpuArray(imRAW(:,:,:,s))); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)

       [imDeconv, imPeak] = gpuWindDeconv(imBS,Sigma,imBG,minIntensity);
        [imBS,imDeconv,imPeak] = gather(imBS,imDeconv,imPeak);
        
        [ROI,ROIsub,IDs,x0,y0] = cpgpuExtractROIs(imDeconv,imPeak,imBS,Sigma);

        [Xc, Yc, T, fn] = gpuGradientFit(gpuArray(ROI),gpuArray(ROIsub),gpuArray(IDs),gpuArray(x0),gpuArray(y0));
        [Xc, Yc, T, fn] = gather(Xc, Yc, T, fn);
        
        result(s,1) = {[(1:length(fn))',(s-1)*blocksize+fn,Xc,Yc,T]};
        %disp([num2str(s/(floor(imF/blocksize))*100),'%']);
    end
    toltime = toc
elseif(imW==1024)
    tic
    parfor s=1:floor(imF/blocksize)   
        
        [imBS,imBG] = cpBgSub(imRAW(:,:,:,s)); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)
        % wind deconvolution and peak finding
%         imBS  = reshape(imBS,1024,1024,50,2);
%         imBG  = reshape(imBG,1024,1024,50,2);
%         for i =1:2
%         imBS(:,:,:,s) = gather(imBSs);
%         imBG(:,:,:,s) = gather(imBGs);
%     end
%     parfor s=1:floor(imF/blocksize) 
        [imDeconv, imPeak] = gpuWindDeconv(gpuArray(imBS),Sigma,gpuArray(imBG),minIntensity);
        [imDeconv,imPeak] = gather(imDeconv,imPeak);
        
        [ROI,ROIsub,IDs,x0,y0] = cpgpuExtractROIs(imDeconv,imPeak,imBS,Sigma);
        
        [Xc, Yc, T, fn] = gpuGradientFit(gpuArray(ROI),gpuArray(ROIsub),gpuArray(IDs),gpuArray(x0),gpuArray(y0));
        [Xc, Yc, T, fn] = gather(Xc, Yc, T, fn);
        
        result(s,1) = {[(1:length(fn))',(s-1)*blocksize+fn,Xc,Yc,T]};
%         end
        %disp([num2str(s/(floor(imF/blocksize))*100),'%']);
    end
    toltime = toc
end
elseif(Mode == 3)
    if(length(size(imRAW))<4)
        imRAW = reshape(imRAW,imW,imH,100,seg);
    end
    tic
    for s=1:seg    

        [imBS,imBG] = c1BgSub(imRAW(:,:,:,s)); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)
        % wind deconvolution and peak finding
        [imDeconv, imPeak] = c1WindDeconv(imBS,Sigma,imBG,minIntensity);
        %% WindSTORM step 2: Emitter extraction and localization
        % emitter extraction
        [ROI,ROIsub,IDs,x0,y0] = c1ExtractROIs(imDeconv,imPeak,imBS,Sigma);
        % emitter localization
        [Xc, Yc, T, fn] = c1GradientFit(ROI,ROIsub,IDs,x0,y0);
        %% save result
        disp([num2str(s/seg*100),'%']);

        result(s,1) = {[(1:length(fn))',(s-1)*100+fn,Xc,Yc,T]};
    end
    toltime = toc
    

elseif(Mode ==4)
        if(length(size(imRAW))>3)
        imRAW = reshape(imRAW,imW,imH,imF);
        end
        tic
        [imBS,imBG] = c1BgSub(imRAW); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)

        [imDeconv, imPeak] = c1WindDeconv(imBS,Sigma,imBG,minIntensity);

        [ROI,ROIsub,IDs,x0,y0] = c1ExtractROIs(imDeconv,imPeak,imBS,Sigma);

        [Xc, Yc, T, fn] = c1GradientFit(ROI,ROIsub,IDs,x0,y0);
        
        toltime = toc
        result = {[(1:length(fn))',fn,Xc,Yc,T]};
end

    set(handles.edit10,'String',num2str(toltime));
    result = cell2mat(result);
    disp(['Total localization number is ',num2str(length(result))]);
    set(handles.edit11,'String',num2str(length(result)));
    
    %% 数据存储记录
    isBatch = strcmp(get(handles.SelectFileButton,'Enable'),'off');
    StoreResult(result,pathname,filename,isBatch,Intensity,Sigma,Mode);
    fid = fopen('time-locs.txt','a');
    fprintf(fid,'%d\r\n',toltime);
    fprintf(fid,'%d\r\n',length(result));
    fclose(fid);
    %% image rendring
%     ImageRender(result,imRW,imRH,imW,imH);
clear imRAW result Xc Yc T fn imRAW100 imBS imBG imDeconv imPeak ROI ROIsub IDs x0 y0

end

for k=1:p
    pathname = char(PathName{k,1});
    filename = char(FileName{k,1});
    disp(pathname);
    disp(filename);    
% read image
[imRAW,imW,imH,imF,imRW,imRH] = ImageRead([pathname,filename],Count2photon,Baseline);

disp(['Image Reading:','OK']);
%% 分割子集并行
Mode=3;
seg = floor(imF/100);
result = cell(seg,1);
if(Mode==1)
    if(length(size(imRAW))<4)
        imRAW = reshape(imRAW,imW,imH,100,seg);
        if (isempty(gcp('nocreate')))
            parpool;
        end
    end
    tic
    parfor s=1:seg    

        [imBS,imBG] = cpBgSub(imRAW(:,:,:,s)); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)

        [imDeconv, imPeak] = cpWindDeconv(imBS,Sigma,imBG,minIntensity);

        [ROI,ROIsub,IDs,x0,y0] = cpExtractROIs(imDeconv,imPeak,imBS,Sigma);

        [Xc, Yc, T, fn] = cpGradientFit(ROI,ROIsub,IDs,x0,y0);

        %disp([num2str(s/seg*100),'%']);

        result(s,1) = {[(1:length(fn))',(s-1)*100+fn,Xc,Yc,T]};
    end
    toltime = toc
    
elseif(Mode == 2)
    
    blocksize = str2double(get(handles.gpuBlockSize,'String'));
    imRAW = reshape(imRAW,imW,imH,blocksize,floor(imF/blocksize));
if(imW==512)    
    tic
    parfor s=1:floor(imF/blocksize)   
        

        [imBS,imBG] = gpuBgSub(gpuArray(imRAW(:,:,:,s))); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)

       [imDeconv, imPeak] = gpuWindDeconv(imBS,Sigma,imBG,minIntensity);
        [imBS,imDeconv,imPeak] = gather(imBS,imDeconv,imPeak);
        
        [ROI,ROIsub,IDs,x0,y0] = cpgpuExtractROIs(imDeconv,imPeak,imBS,Sigma);

        [Xc, Yc, T, fn] = gpuGradientFit(gpuArray(ROI),gpuArray(ROIsub),gpuArray(IDs),gpuArray(x0),gpuArray(y0));
        [Xc, Yc, T, fn] = gather(Xc, Yc, T, fn);
        
        result(s,1) = {[(1:length(fn))',(s-1)*blocksize+fn,Xc,Yc,T]};
        %disp([num2str(s/(floor(imF/blocksize))*100),'%']);
    end
    toltime = toc
elseif(imW==1024)
    tic
    parfor s=1:floor(imF/blocksize)   
        
        [imBS,imBG] = cpBgSub(imRAW(:,:,:,s)); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)
        % wind deconvolution and peak finding
%         imBS  = reshape(imBS,1024,1024,50,2);
%         imBG  = reshape(imBG,1024,1024,50,2);
%         for i =1:2
%         imBS(:,:,:,s) = gather(imBSs);
%         imBG(:,:,:,s) = gather(imBGs);
%     end
%     parfor s=1:floor(imF/blocksize) 
        [imDeconv, imPeak] = gpuWindDeconv(gpuArray(imBS),Sigma,gpuArray(imBG),minIntensity);
        [imDeconv,imPeak] = gather(imDeconv,imPeak);
        
        [ROI,ROIsub,IDs,x0,y0] = cpgpuExtractROIs(imDeconv,imPeak,imBS,Sigma);
        
        [Xc, Yc, T, fn] = gpuGradientFit(gpuArray(ROI),gpuArray(ROIsub),gpuArray(IDs),gpuArray(x0),gpuArray(y0));
        [Xc, Yc, T, fn] = gather(Xc, Yc, T, fn);
        
        result(s,1) = {[(1:length(fn))',(s-1)*blocksize+fn,Xc,Yc,T]};
%         end
        %disp([num2str(s/(floor(imF/blocksize))*100),'%']);
    end
    toltime = toc
end
elseif(Mode == 3)
    if(length(size(imRAW))<4)
        imRAW = reshape(imRAW,imW,imH,100,seg);
    end
    tic
    for s=1:seg    

        [imBS,imBG] = c1BgSub(imRAW(:,:,:,s)); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)
        % wind deconvolution and peak finding
        [imDeconv, imPeak] = c1WindDeconv(imBS,Sigma,imBG,minIntensity);
        %% WindSTORM step 2: Emitter extraction and localization
        % emitter extraction
        [ROI,ROIsub,IDs,x0,y0] = c1ExtractROIs(imDeconv,imPeak,imBS,Sigma);
        % emitter localization
        [Xc, Yc, T, fn] = c1GradientFit(ROI,ROIsub,IDs,x0,y0);
        %% save result
        disp([num2str(s/seg*100),'%']);

        result(s,1) = {[(1:length(fn))',(s-1)*100+fn,Xc,Yc,T]};
    end
    toltime = toc
    

elseif(Mode ==4)
        if(length(size(imRAW))>3)
        imRAW = reshape(imRAW,imW,imH,imF);
        end
        tic
        [imBS,imBG] = c1BgSub(imRAW); %(background:10~1000)
        %[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)

        [imDeconv, imPeak] = c1WindDeconv(imBS,Sigma,imBG,minIntensity);

        [ROI,ROIsub,IDs,x0,y0] = c1ExtractROIs(imDeconv,imPeak,imBS,Sigma);

        [Xc, Yc, T, fn] = c1GradientFit(ROI,ROIsub,IDs,x0,y0);
        
        toltime = toc
        result = {[(1:length(fn))',fn,Xc,Yc,T]};
end

    set(handles.edit10,'String',num2str(toltime));
    result = cell2mat(result);
    disp(['Total localization number is ',num2str(length(result))]);
    set(handles.edit11,'String',num2str(length(result)));
    
    %% 数据存储记录
    isBatch = strcmp(get(handles.SelectFileButton,'Enable'),'off');
    StoreResult(result,pathname,filename,isBatch,Intensity,Sigma,Mode);
    fid = fopen('time-locs.txt','a');
    fprintf(fid,'%d\r\n',toltime);
    fprintf(fid,'%d\r\n',length(result));
    fclose(fid);
    %% image rendring
%     ImageRender(result,imRW,imRH,imW,imH);
clear imRAW result Xc Yc T fn imRAW100 imBS imBG imDeconv imPeak ROI ROIsub IDs x0 y0

end
% --- Executes on button press in Previewbutton.
function Previewbutton_Callback(hObject, eventdata, handles)
% hObject    handle to Previewbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global imRAW imRW imRH imW imH 

Intensity = str2double(get(handles.intensityedit,'String')); % estimated average emitter intensity of the dataset
Sigma = str2double(get(handles.sigmaedit,'String')); % the kernel width of the PSF of the system

%% Read image
minIntensity = Intensity/4;   % a global threshold set to eliminate very weak emitters

if(length(size(imRAW))>3)
    [imBS,imBG] = cpBgSub(imRAW(:,:,:,1)); %(background:10~1000)
else
    [imBS,imBG] = cpBgSub(imRAW(:,:,1:100));
end
%[imBS,imBG] = BgSub_low(imRAW); %(background:1~10)
% wind deconvolution and peak finding
[imDeconv, imPeak] = cpWindDeconv(imBS,Sigma,imBG,minIntensity);
%% WindSTORM step 2: Emitter extraction and localization
% emitter extraction
[ROI,ROIsub,IDs,x0,y0] = cpExtractROIs(imDeconv,imPeak,imBS,Sigma);
% emitter localization
[Xc, Yc, T, fn] = cpGradientFit(ROI,ROIsub,IDs,x0,y0);
%% save result
result = {[(1:length(fn))',fn,Xc,Yc,T]};
figure(1),imshow(imRAW(1:imRH,1:imRW,100),[]),title('Orignal');
figure(2)
subplot(2,2,1)
imshow(imBG(1:imRH,1:imRW,100),[]),title('Background');
subplot(2,2,2)
imshow(imBS(1:imRH,1:imRW,100),[]),title('Substrct Background');
subplot(2,2,3)
imshow(imDeconv(1:imRH,1:imRW,100),[]),title('Deconvolution');
subplot(2,2,4)
imshow(imPeak(1:imRH,1:imRW,100),[]),title('Peak Finding');
ImageRender(cell2mat(result),imRW,imRH,imW,imH);


% --- Executes on selection change in RunningMode.
function RunningMode_Callback(hObject, eventdata, handles)
% hObject    handle to RunningMode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns RunningMode contents as cell array
%        contents{get(hObject,'Value')} returns selected item from RunningMode
Mode = get(handles.RunningMode,'Value');
if((Mode==1)&&isempty(gcp('nocreate')))
    parpool;
elseif((Mode==3||Mode==4)&&~isempty(gcp('nocreate')))
    delete(gcp);
end
if(Mode==2)
    set(handles.gpuBlockSize,'Enable','on');
    set(handles.text15,'Enable','on');
else
    set(handles.gpuBlockSize,'Enable','off');
    set(handles.text15,'Enable','off');
end
