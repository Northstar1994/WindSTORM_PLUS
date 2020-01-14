function [imRaw, imW, imH, imF,imRW, imRH] = imRawResize(imRaw,imW,imH,imF)
% ------------------------------------------------------------------------------------
% 对原始数据补零使其能够满足任意尺寸的数据处理，主要是满足FFT后的频域的截断
% 补零后进行傅里变换不会对实际数据的频谱造成影响
% 补零区域也不会定位问题的出现
% By Wen Xiao @SZU
%------------------------------------------------------------------------------------
    imRW = imW;
    imRH = imH;
    if((imW==imH) && (imW==64 ||imW==128 ||imW==256 ||imW==512 ||imW==1024 ||imW==2048))
    else
        if (max(imW,imH) <= 64)
            imRaw(64,64,imF)  = 0;
        elseif (max(imW,imH)<=128)
            imRaw(128,128,imF)  = 0;
        elseif(max(imW,imH)<=256)
            imRaw(256,256,imF)  = 0;
        elseif(max(imW,imH)<=512)
            imRaw(512,512,imF)  = 0;
        elseif(max(imW,imH)<=1024)
            imRaw(1024,1024,imF)  = 0;
        elseif(max(imW,imH)<=2048)
            imRaw(2048,2048,imF)  = 0;
        end
    end
    imRaw = single(imRaw);
    [imW,imH,imF] = size(imRaw); 
end