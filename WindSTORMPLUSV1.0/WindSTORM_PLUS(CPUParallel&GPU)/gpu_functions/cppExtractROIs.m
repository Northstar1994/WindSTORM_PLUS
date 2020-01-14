function [ROI,ROIsub,IDs,x0,y0] = cppExtractROIs(imDeconv,impeak,imBS,Sigma)
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
% Modifited By Wen Xiao @ SZU 2019
%------------------------------------------------------------------------------------
[imW,imH,imF] = size(imBS);
imT = zeros(imW,imH,imF);
imX = zeros(imW,imH,imF);
imY = zeros(imW,imH,imF);
IDs1 = cell(imF,1);

AA = 0.2528*Sigma^2-1.2313*Sigma+1.7575;
SS = 0.1337*Sigma^2+0.4162*Sigma+0.8070;
ROIr = 7;

parfor f=1:imF
    imD = imDeconv(:,:,f);
    imP = impeak(:,:,f);
    im = imBS(:,:,f);

    imPsum = filter2(ones(3,3),imP);
    imD(imPsum>1) = imD(imPsum>1)*0.5; % seperate close emitters
    imDsum = filter2(ones(3,3),imD); % relative total emitter intensity 
    imSum = filter2(ones(3,3),im); % relative central emitter intensity
    
    % initial estimation of emitter intensity and position
    [row,col] = find(imP>0);
    T = col;
    A = col;
    xc = col;
    yc = col;
    for m = 1:length(row)
        xp = imD(row(m)-1,col(m)+1) + imD(row(m),col(m)+1) + imD(row(m)+1,col(m)+1);
        xo = imD(row(m)-1,col(m)) + imD(row(m),col(m)) + imD(row(m)+1,col(m));
        xn = imD(row(m)-1,col(m)-1) + imD(row(m),col(m)-1) + imD(row(m)+1,col(m)-1);

        yp = imD(row(m)+1,col(m)-1) + imD(row(m)+1,col(m)) + imD(row(m)+1,col(m)+1);
        yo = imD(row(m),col(m)-1) + imD(row(m),col(m)) + imD(row(m),col(m)+1);
        yn = imD(row(m)-1,col(m)-1) + imD(row(m)-1,col(m)) + imD(row(m)-1,col(m)+1);

        T(m) = imDsum(row(m),col(m));
        A(m) = imSum(row(m),col(m));
        xc(m) = (xp^2-xn^2)./(xp^2+xo^2+xn^2);
        yc(m) = (yp^2-yn^2)./(yp^2+yo^2+yn^2);
    end
    
    % estimate emitter intensity
    imOL = zeros(imW,imH);
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
%     for m = 1:length(row)
%         imT(row(m),col(m),f) = T(m);
%         imX(row(m),col(m),f) = xc(m);
%         imY(row(m),col(m),f) = yc(m);
%     end
    
    IDs1(f,1) = {[row,col,xc,yc,f*ones(length(row),1),T]};
end

IDs1 = cell2mat(IDs1);
num = length(IDs1);

for m=1:num
    imT(IDs1(m,1),IDs1(m,2),IDs1(m,5)) = IDs1(m,6);
    imX(IDs1(m,1),IDs1(m,2),IDs1(m,5)) = IDs1(m,3);
    imY(IDs1(m,1),IDs1(m,2),IDs1(m,5)) = IDs1(m,4);
end

IDs = IDs1(1:num,1:end-1);
ROI = zeros(7,7,num);
ROIsub = zeros(7,7,num);
[X,Y] = meshgrid(1:(2*ROIr+1));
x0 = zeros(4,4,num);
y0 = zeros(4,4,num);
IDsrow = IDs(:,1);
IDscol= IDs(:,2);
IDsf= IDs(:,5);
IDs1 = zeros(num,1);
IDs2 = zeros(num,1);
IDs3 = zeros(num,1);
IDs4 = zeros(num,1);
% surrounding emitter subtraction
parfor m=1:num
    ROI1 = imBS(IDsrow(m)-ROIr:IDsrow(m)+ROIr,IDscol(m)-ROIr:IDscol(m)+ROIr,IDsf(m));
    tROI = imT(IDsrow(m)-ROIr:IDsrow(m)+ROIr,IDscol(m)-ROIr:IDscol(m)+ROIr,IDsf(m));
    xROI = imX(IDsrow(m)-ROIr:IDsrow(m)+ROIr,IDscol(m)-ROIr:IDscol(m)+ROIr,IDsf(m));
    yROI = imY(IDsrow(m)-ROIr:IDsrow(m)+ROIr,IDscol(m)-ROIr:IDscol(m)+ROIr,IDsf(m));
    tROI(ROIr+1,ROIr+1) = 0;
    [rowp,colp] = find(tROI>0);
    ROI2 = zeros(2*ROIr+1,2*ROIr+1);
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
    IDs1(m) = IDsrow(m) + YY;
    IDs2(m) = IDscol(m) + XX;
    IDs3(m) = Xb;
    IDs4(m) = Yb;
    % ROI extraction
    ROI(:,:,m) = ROI3(ROIr+1+YY-3:ROIr+1+YY+3,ROIr+1+XX-3:ROIr+1+XX+3);
    ROIsub(:,:,m) = ROI2(ROIr+1+YY-3:ROIr+1+YY+3,ROIr+1+XX-3:ROIr+1+XX+3);
    x0(:,:,m) = IDs3(m)*ones(4,4);
    y0(:,:,m) = IDs4(m)*ones(4,4);
end
IDs = [IDs1,IDs2,IDs3,IDs4,IDsf];
end


