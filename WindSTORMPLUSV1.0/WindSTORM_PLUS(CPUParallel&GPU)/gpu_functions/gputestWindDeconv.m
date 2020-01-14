function [imDeconv, imPeak]  = gputestWindDeconv(imBS,imBG,Sigma,minIntensity)
% ------------------------------------------------------------------------------------
% Wind deconvolution based on frequency weighting and find the peak pixel
% of candidate emitters
%
% Input:    imBS        the background-subtracted image 
%           Sigma       the Gaussain kernel width of the PSF 
%
% Output:   imDeconv    the deconvolved image
%           imPeak      the emitter peak image

% By Hongqiang Ma @ PITT July 2018
% Modificated by Wen Xiao @SZU 2019 
%------------------------------------------------------------------------------------
[imW,imH,imF] = size(imBS);
[X,Y] = meshgrid(1:imH,1:imW);
PSF = gpuArray(single(exp(-((X-imH/2-1).^2+(Y-imW/2-1).^2)/(2*Sigma^2))/(2*pi*Sigma^2)));
H = fft2(PSF);
W = conj(H)./(H.*conj(H)); % inverse deconvolution filter

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
W = W(1:end,1:end,ones(imF,1));
%for f = 1:imF 并行化编程不用for循环
G = fft2(imBS);
F = W.*G;
imd = real(fftshift(ifft2(W.*fft2(imBS))));
Threshold = minIntensity/(2*pi*Sigma*Sigma);
% eliminate the dim emitters by thresholding
if (Threshold<10)
    ims = imfilter(imBS,ones(3,3)/9);
    imd(ims<(sqrt(imBG+Threshold))) = 0;
else
    imd(imBS<(3*sqrt(imBG)+Threshold)) = 0;
end
imd(imd<0) = 0;

% eliminate fake emitters with very small size
imES = gpuArray.zeros(imW,imH,imF,'single');
edgeW = 7;
imES(edgeW+1:end-edgeW,edgeW+1:end-edgeW,:) = (imd(edgeW+1-1:end-edgeW-1,edgeW+1-1:end-edgeW-1,:) > 1)...
    + (imd(edgeW+1-1:end-edgeW-1,edgeW+1:end-edgeW,:) > 1)...
    + (imd(edgeW+1-1:end-edgeW-1,edgeW+1+1:end-edgeW+1,:) > 1)...
    + (imd(edgeW+1:end-edgeW,edgeW+1-1:end-edgeW-1,:) > 1)...
    + (imd(edgeW+1:end-edgeW,edgeW+1:end-edgeW,:) > 1) ...
    + (imd(edgeW+1:end-edgeW,edgeW+1+1:end-edgeW+1,:) > 1)...
    + (imd(edgeW+1+1:end-edgeW+1,edgeW+1-1:end-edgeW-1,:) > 1)...
    + (imd(edgeW+1+1:end-edgeW+1,edgeW+1:end-edgeW,:) > 1)...
    + (imd(edgeW+1+1:end-edgeW+1,edgeW+1+1:end-edgeW+1,:) > 1);
imd(imES<5) = 0;
imd(imd<1) = 0;
imDeconv = imd;

% find the emitter peak
EnhanceMask = [-0.5 -1 -1 -1 -0.5;
-1  0.5  1.5  0.5 -1;
-1  1.5  1.8  1.5 -1;
-1  0.5  1.5  0.5 -1;
-0.5 -1 -1 -1 -0.5];
imdm = imd;
imdm(imdm>0)=1;
if (Sigma<1.6)
    imdms = imfilter(imdm,EnhanceMask);
    imdms(imdms<0)=0;
    imDE = imd.*imdms;
else
    imDE = imfilter(imd,EnhanceMask);
    imDE(imDE<0)=0;
end

imPK = gpuArray.zeros(imW,imH,imF,'single');
centerPixel = imDE(edgeW+1:end-edgeW,edgeW+1:end-edgeW,:);
sr = round(Sigma-0.1); % search radius
for m=-sr:sr
    for n=-sr:sr
        imPK(edgeW+1:end-edgeW,edgeW+1:end-edgeW,:) = imPK(edgeW+1:end-edgeW,edgeW+1:end-edgeW,:)+(centerPixel > imDE(edgeW+1+m:end-edgeW+m,edgeW+1+n:end-edgeW+n,:));
    end
end
imPK(imPK<((2*sr+1)*(2*sr+1)-1)) = 0;
imPK(imPK>0) = 1;
imPeak = imPK;
%[imDeconv, imPeak] = pagefun(@impkimde,imBS,imBG,W);
end

%end
function [imDeconv, imPeak] = impkimde(imBS,imBG,W)
G = fft2(imBS);
F = W.*G;
imd = real(fftshift(ifft2(F)));
Threshold = minIntensity/(2*pi*Sigma*Sigma);
% eliminate the dim emitters by thresholding
if (Threshold<10)
    ims = imfilter(imBS,ones(3,3)/9);
    imd(ims<(sqrt(imBG+Threshold))) = 0;
else
    imd(imBS<(3*sqrt(imBG)+Threshold)) = 0;
end
imd(imd<0) = 0;

% eliminate fake emitters with very small size
imES = gpuArray.zeros(imW,imH,'single');
edgeW = 7;
imES(edgeW+1:end-edgeW,edgeW+1:end-edgeW) = (imd(edgeW+1-1:end-edgeW-1,edgeW+1-1:end-edgeW-1) > 1)...
    + (imd(edgeW+1-1:end-edgeW-1,edgeW+1:end-edgeW) > 1)...
    + (imd(edgeW+1-1:end-edgeW-1,edgeW+1+1:end-edgeW+1) > 1)...
    + (imd(edgeW+1:end-edgeW,edgeW+1-1:end-edgeW-1) > 1)...
    + (imd(edgeW+1:end-edgeW,edgeW+1:end-edgeW) > 1) ...
    + (imd(edgeW+1:end-edgeW,edgeW+1+1:end-edgeW+1) > 1)...
    + (imd(edgeW+1+1:end-edgeW+1,edgeW+1-1:end-edgeW-1) > 1)...
    + (imd(edgeW+1+1:end-edgeW+1,edgeW+1:end-edgeW) > 1)...
    + (imd(edgeW+1+1:end-edgeW+1,edgeW+1+1:end-edgeW+1) > 1);
imd(imES<5) = 0;
imd(imd<1) = 0;
imDeconv = imd;

% find the emitter peak
EnhanceMask = [-0.5 -1 -1 -1 -0.5;
-1  0.5  1.5  0.5 -1;
-1  1.5  1.8  1.5 -1;
-1  0.5  1.5  0.5 -1;
-0.5 -1 -1 -1 -0.5];
imdm = imd;
imdm(imdm>0)=1;
if (Sigma<1.6)
    imdms = imfilter(imdm,EnhanceMask);
    imdms(imdms<0)=0;
    imDE = imd.*imdms;
else
    imDE = imfilter(imd,EnhanceMask);
    imDE(imDE<0)=0;
end

imPK = gpuArray.zeros(imW,imH,'single');
centerPixel = imDE(edgeW+1:end-edgeW,edgeW+1:end-edgeW);
sr = round(Sigma-0.1); % search radius
for m=-sr:sr
    for n=-sr:sr
        imPK(edgeW+1:end-edgeW,edgeW+1:end-edgeW) = imPK(edgeW+1:end-edgeW,edgeW+1:end-edgeW)+(centerPixel > imDE(edgeW+1+m:end-edgeW+m,edgeW+1+n:end-edgeW+n));
    end
end
imPK(imPK<((2*sr+1)*(2*sr+1)-1)) = 0;
imPK(imPK>0) = 1;
imPeak = imPK;
end