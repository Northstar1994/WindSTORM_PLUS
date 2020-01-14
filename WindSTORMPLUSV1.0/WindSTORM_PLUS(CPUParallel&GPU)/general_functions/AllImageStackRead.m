function [imRAW,imW,imH,Totalimage,imRW,imRH] = AllImageStackRead(FileNames,PathName,Count2photon,Baseline)
% ------------------------------------------------------------------------------------
% 读取一个文件夹下的所有子堆栈 
% by Wen Xiao @SZU 2019
%------------------------------------------------------------------------------------
%然后根据后缀名筛选出指定类型文件并读入
[n , ~] = size(FileNames);%获得大小

Totalimage = 0;
for i = 1:n
    if ~isempty( strfind(FileNames{i}, '.tif') )%筛选出tif文件
        filename = FileNames{i};
        filepath = fullfile(PathName,filename);
        Data = bfOpen3DVolume(filepath);        
        imgStack = Data{1,1}{1,1};
        [imH,imW,imF] = size(imgStack);
        imR = zeros(imH,imW,imF);
        for f = 1:imF
            imR(:,:,f) = (imgStack(:,:,f)-Baseline)*Count2photon;
        end        
        imRAW(:,:,Totalimage+1:Totalimage +imF) = imR;
        Totalimage = Totalimage +imF;  
    end
end

%补零实验
[imRAW, imW, imH,Totalimage,imRW,imRH] = imRawResize(imRAW,imW,imH,Totalimage);
if (~isempty(gcp('nocreate')))
    imRAW = imRAW2imRAW100(imRAW,imW,imH,Totalimage);
end
end