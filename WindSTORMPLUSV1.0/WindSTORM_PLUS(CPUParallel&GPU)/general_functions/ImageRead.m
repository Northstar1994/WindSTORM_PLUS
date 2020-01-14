function [imRAW,imW,imH,imF,imRW,imRH] = ImageRead(Filename,Count2photon,Baseline)
% ------------------------------------------------------------------------------------
% Read image stack from a file and tansfer it from digital counts to physical photons.
% 
% By Wen Xiao @SZU
%------------------------------------------------------------------------------------

Data = bfOpen3DVolume(Filename);
imgStack = Data{1,1}{1,1};
[imH,imW,imF] = size(imgStack);
clear Data
imRAW = uint16(zeros(imH,imW,imF));

for f = 1:imF
    imRAW(:,:,f) = single((imgStack(:,:,f)-Baseline)*Count2photon);
end

%ฒนมใสตั้
[imRAW, imW, imH,imF,imRW,imRH] = imRawResize(imRAW,imW,imH,imF);
if (isempty(gcp('nocreate')))
else
    imRAW = reshape(imRAW,imH,imW,100,floor(imF/100));
end
end