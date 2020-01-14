function [imBS, imBG] = cpBgSub_low(imRAW)
% ------------------------------------------------------------------------------------
% Estimate and subtract the background from the raw image with background
% of 1~5 photons/pixel/frame
%
% Input:    imRAW    the raw image stack with a unit of photons
%
% Output:   imBS     the background subtracted image 
%           imBG     the estimated background 
% 
% By Hongqiang Ma @ PITT October 2018
% ------------------------------------------------------------------------------------
[imW,imH,imF] = size(imRAW);
imBS = imRAW;
imSTD = std(imRAW,0,3);
imROI = ones(imW,imH);
imROI(imSTD>5) = 0;
BG = imROI.*imRAW(:,:,1); 
BG = sum(BG(:))/sum(imROI(:));
imBG = ones(imW,imH,imF)*BG;
imBS = imBS - BG;
imBS(imBS<0) = 0;
end