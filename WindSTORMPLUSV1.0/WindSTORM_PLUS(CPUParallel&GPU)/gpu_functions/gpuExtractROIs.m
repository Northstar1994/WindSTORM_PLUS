function [ROI,ROIsub,IDs,x0,y0] = gpuExtractROIs(imDeconv,impeak,imBS,Sigma)
% ------------------------------------------------------------------------------------
% Extract the ROI of candidate emitters and calculate their initial
% position and subtract surrounding emitters
%
% Input:    imDeconv        the deconvolved image 
%           impeak          the emitter peak image 
%           imBS            the background subtracted image
%           Sigma           the Gaussain kernel width of the PSF 
%
% Output:   ROI             the extracted central emitters
%           ROIsub          the surrounding emitters to be deducted
%           IDs             the coordinates of the extracted emitter
%           x0              the initial x position of the extracted emitter
%           y0              the initial y position of the extracted emitter
%
% By Hongqiang Ma @ PITT July 2018
% Modificated by Wen Xiao @ SZU 2019
%------------------------------------------------------------------------------------
%% ****** Attention:当前该算法较难使用，因为存在大量的嵌套for循环
%% ******           GPU比CPU单核速度慢500倍以上，正在想办法减少for循环

[imW,imH,imF] = size(imBS);
imT = gpuArray.zeros(imH,imW,imF,'single');
imX = gpuArray.zeros(imH,imW,imF,'single');
imY = gpuArray.zeros(imH,imW,imF,'single');
IDs1 = gpuArray.zeros(500000,5,'single');
AA = 0.2528*Sigma^2-1.2313*Sigma+1.7575;
SS = 0.1337*Sigma^2+0.4162*Sigma+0.8070;
ROIr = 7;
num = 0;

imPs = imfilter(impeak,ones(3,3));
imDeconv(imPs>1) = imDeconv(imPs>1)*0.5; % seperate close emitters
imDs = imfilter(imDeconv,ones(3,3)); % relative total emitter intensity 
imS = imfilter(imBS,ones(3,3)); % relative central emitter intensity

for f=1:imF
    imD = imDeconv(:,:,f);
    imP = impeak(:,:,f);
    
    imDsum = imDs(:,:,f);
    imSum = imS(:,:,f);
%     imPsum = filter2(ones(3,3),imP);
%     imD(imPsum>1) = imD(imPsum>1)*0.5; % seperate close emitters
%     imDsum = filter2(ones(3,3),imD); % relative total emitter intensity 
%     imSum = filter2(ones(3,3),im); % relative central emitter intensity
    
    % initial estimation of emitter intensity and position
    [row,col] = find(imP>0);
%     T = col;
%     A = col;
%     xc = col;
%     yc = col;
%     for m = 1:length(row)
%         xp = imD(row(m)-1,col(m)+1) + imD(row(m),col(m)+1) + imD(row(m)+1,col(m)+1);
%         xo = imD(row(m)-1,col(m)) + imD(row(m),col(m)) + imD(row(m)+1,col(m));
%         xn = imD(row(m)-1,col(m)-1) + imD(row(m),col(m)-1) + imD(row(m)+1,col(m)-1);
% 
%         yp = imD(row(m)+1,col(m)-1) + imD(row(m)+1,col(m)) + imD(row(m)+1,col(m)+1);
%         yo = imD(row(m),col(m)-1) + imD(row(m),col(m)) + imD(row(m),col(m)+1);
%         yn = imD(row(m)-1,col(m)-1) + imD(row(m)-1,col(m)) + imD(row(m)-1,col(m)+1);
%    
%         T(m) = imDsum(row(m),col(m));
%         A(m) = imSum(row(m),col(m));
%         xc(m) = (xp^2-xn^2)./(xp^2+xo^2+xn^2);
%         yc(m) = (yp^2-yn^2)./(yp^2+yo^2+yn^2);
%     end
    [T,A,xc,yc] = arrayfun(@es_position,imD,imDsum,imSum,row,col);
    
    % estimate emitter intensity
    imOL = gpuArray.zeros(imW,imH,'single');
    Tol = T;
    for m = 1:length(row)
        pROI = imP(row(m)-ROIr:row(m)+ROIr,col(m)-ROIr:col(m)+ROIr);
        pROI(ROIr+1,ROIr+1) = 0;
        [rowp,colp] = find(pROI>0);
        for mm = 1:length(rowp)
            Dist = (rowp(mm)-(ROIr+1+yc(m)))^2 + (colp(mm)-(ROIr+1+xc(m)))^2;
            imOL(row(m)+rowp(mm)-(ROIr+1),col(m)+colp(mm)-(ROIr+1)) = T(m)*AA*exp(-Dist/(2*SS*SS))+imOL(row(m)+rowp(mm)-(ROIr+1),col(m)+colp(mm)-(ROIr+1));
        end
    end
    for m = 1:length(row)
        Tol(m) = imOL(row(m),col(m));
        Dist = yc(m)^2 + xc(m)^2;
        Ar = (AA*exp(-Dist/(2*SS*SS)));
        T(m) = A(m)*T(m)*Ar/(T(m)*Ar+Tol(m))/Ar;
    end
    for m = 1:length(row)
        imT(row(m),col(m),f) = T(m);
        imX(row(m),col(m),f) = xc(m);
        imY(row(m),col(m),f) = yc(m);
    end
    
    id = num+1:num+length(row);
    IDs1(id,:) = [row,col,xc,yc f*ones(length(row),1)];
    num = num + length(row);
end

IDs = real(IDs1(1:num,:));
ROI = gpuArray.zeros(7,7,num,'single');
ROIsub = gpuArray.zeros(7,7,num,'single');
[X,Y] = meshgrid(1:(2*ROIr+1));
x0 = gpuArray.zeros(4,4,num,'single');
y0 = gpuArray.zeros(4,4,num,'single');

% surrounding emitter subtraction
for m=1:num
    IDsm1 = real(IDs(m,1));
    IDsm2 = real(IDs(m,2));
    IDsm5 = real(IDs(m,5));
    ROI1 = imBS(IDsm1-ROIr:IDsm1+ROIr,IDsm2-ROIr:IDsm2+ROIr,IDsm5);
    tROI = imT(IDsm1-ROIr:IDsm1+ROIr,IDsm2-ROIr:IDsm2+ROIr,IDsm5);
    xROI = imX(IDsm1-ROIr:IDsm1+ROIr,IDsm2-ROIr:IDsm2+ROIr,IDsm5);
    yROI = imY(IDsm1-ROIr:IDsm1+ROIr,IDsm2-ROIr:IDsm2+ROIr,IDsm5);
    tROI(ROIr+1,ROIr+1) = 0;
    [rowp,colp] = find(tROI>0);
    ROI2 = zeros(2*ROIr+1,2*ROIr+1,'gpuArray');
    for mm = 1:length(rowp)
        T = tROI(rowp(mm),colp(mm));
        xc = xROI(rowp(mm),colp(mm));
        yc = yROI(rowp(mm),colp(mm));
        ROI2 = ROI2 + T/(2*pi*Sigma*Sigma)*exp(-((Y-rowp(mm)-yc).^2+(X-colp(mm)-xc).^2)/(2*Sigma*Sigma));
    end
    ROI3 = ROI1-ROI2;
    ROI3(ROI3<0)=0;
    xc = xROI(ROIr+1,ROIr+1);
    yc = yROI(ROIr+1,ROIr+1);
    XX = round(xc);
    YY = round(yc);
    Xb = XX - xc;
    Yb = YY - yc;
    IDs(m,1) = IDs(m,1) + YY;
    IDs(m,2) = IDs(m,2) + XX;
    IDs(m,3) = Xb;
    IDs(m,4) = Yb;
    % ROI extraction
    ROI(:,:,m) = ROI3(ROIr+1+real(YY)-3:ROIr+1+real(YY)+3,ROIr+1+real(XX)-3:ROIr+1+real(XX)+3);
    ROIsub(:,:,m) = ROI2(ROIr+1+real(YY)-3:ROIr+1+real(YY)+3,ROIr+1+real(XX)-3:ROIr+1+real(XX)+3);
    x0(:,:,m) = IDs(m,3)*ones(4,4);
    y0(:,:,m) = IDs(m,4)*ones(4,4);
end
end

function [T,A,xc,yc] = es_position(imD,imDsum,imSum,row,col)
        xp = imD(row-1,col+1) + imD(row,col+1) + imD(row+1,col+1);
        xo = imD(row-1,col) + imD(row,col) + imD(row+1,col);
        xn = imD(row-1,col-1) + imD(row,col-1) + imD(row+1,col-1);

        yp = imD(row+1,col-1) + imD(row+1,col) + imD(row+1,col+1);
        yo = imD(row,col-1) + imD(row,col) + imD(row,col+1);
        yn = imD(row-1,col-1) + imD(row-1,col) + imD(row-1,col+1);
   
        T = imDsum(row,col);
        A = imSum(row,col);
        xc = (xp^2-xn^2)./(xp^2+xo^2+xn^2);
        yc = (yp^2-yn^2)./(yp^2+yo^2+yn^2);
end


