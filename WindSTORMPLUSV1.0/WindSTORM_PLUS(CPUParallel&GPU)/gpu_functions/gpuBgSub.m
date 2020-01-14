function [imBS, imBG] = gpuBgSub(imRAW)
% ------------------------------------------------------------------------------------
% Estimate and subtract the background from the raw image 
%
% Input:    imRAW    the raw image stack with a unit of photons
%
% Output:   imBS     the background subtracted image 
%           imBG     the estimated background 
% 
% By Hongqiang Ma @ PITT July 2018
% Modificated Wen Xiao @ SZU 2019
% ------------------------------------------------------------------------------------
[imW,imH,imF] = size(imRAW);
    imMIN = min(imRAW,[],3);
    imMINs = filter2(ones(3,3)/9,imMIN);
    imMIN(4:end-3,4:end-3) = imMINs(4:end-3,4:end-3);
    imSTD = std(imRAW,0,3);
    imBG0 = 8.2469e-08*imMIN.^3-1.6481e-04*imMIN.^2+1.1546*imMIN+13.3655;
    imBGstd = sqrt(imBG0);
    % estimate the decay ratio
    imROI = gpuArray.ones(imW,imH,'single');
    imROI(imSTD>(2*imBGstd)) = 0;
    %imROIsum = gpuArray.zeros(100,1,'single');
    %向量化编程修改，速度下降较多
    imROIsum = sum(sum(imRAW.*imROI));
    imRatio = imROIsum/min(imROIsum);
    Ratio = 2*(mean(imRatio)-1)+1;
    A = -0.000000297314062*Ratio.^3 + 0.00000128935323*Ratio.^2 - 0.00000189625851*Ratio + 0.000000986743487;
    B = 0.000599978065*Ratio.^3 - 0.00258484372*Ratio.^2 + 0.0037791658*Ratio - 0.00195917478;
    C = -1.18390145*Ratio.^3 + 4.86119798*Ratio.^2 - 6.71530433*Ratio + 4.19208175;
    D = 12.6630675*Ratio.^3 - 43.1329389*Ratio.^2 + 41.5141569*Ratio + 2.33712427;
    % estimate background
    imBGe = A*imMIN.^3 + B*imMIN.^2 + C*imMIN + D;
    %这个地方的向量化编程不知道如何下手
%     for f=1:100
%     % calibrate the background according to the decay ratio
%     imBGc(:,:,f+100*s) = imBGe*imRatio(f)-5;
%     end
    imBG= arrayfun(@caliBgsb,imBGe,reshape(imRatio,1,1,imF));        
imBS = imRAW-imBG;
imBS(imBS<0) = 0;
end

function imBGc = caliBgsb(imBGe,imRatio)
    imBGc = imBGe*imRatio-5;
end