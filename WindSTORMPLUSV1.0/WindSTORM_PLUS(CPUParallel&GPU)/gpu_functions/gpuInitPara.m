function W = gpuInitPara(imRAW,Sigma,minIntensity)
[imW,imH,~] = size(imRAW);
[X,Y] = meshgrid(1:imH,1:imW);
PSF = gpuArray(single(exp(-((X-imH/2-1).^2+(Y-imW/2-1).^2)/(2*Sigma^2))/(2*pi*Sigma^2)));
H = fft2(PSF);
W = (conj(H)./(H.*conj(H))); % inverse deconvolution filter

%imBG = complex(imBG);

if (imW == 64)
    index = round(8.3333*Sigma*Sigma - 38.214*Sigma + 59.81);
elseif (imW == 128)
    index = round(17.857*Sigma*Sigma - 81.786*Sigma + 123.36);
elseif (imW == 256)
    index = round(38.095*Sigma*Sigma - 168.57*Sigma + 247.19);
elseif (imW == 512)
    index = round(73.81*Sigma*Sigma - 329.29*Sigma + 486.62);
elseif (imW == 1024)
    index = round(146.43*Sigma*Sigma - 656.07*Sigma + 970.93);
else
    %以下公式根据参数做的参数的线性推导
    index = round((0.14341*imW)*Sigma*Sigma - (0.6415*imW-0.2385)*Sigma + (0.94696*imW-1.82833)); 
end

if (minIntensity<400)
    index = index - 2;
end
% truncate the fft map
[X,Y] = meshgrid(1:imW,1:imH);
imB = ((X-imW/2-1).^2 + (Y-imH/2-1).^2); 
WW = fftshift(W);
WW(imB>index^2) = 0;
W = fftshift(WW);
end