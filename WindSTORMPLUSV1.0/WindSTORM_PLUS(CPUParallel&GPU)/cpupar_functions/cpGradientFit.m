function [xc,yc,T,f] = cpGradientFit(ROI,ROIsub,IDs,x0,y0)
% ------------------------------------------------------------------------------------
% single emitter localization based on gradient fitting
%
% Input:    ROI             the extracted central emitters
%           ROIsub          the surrounding emitters to be deducted
%           IDs             the coordinates of the extracted emitter
%           x0              the initial x position of the extracted emitter
%           y0              the initial y position of the extracted emitter
%
% Output:   xc              the estimated x position of the extracted emitter
%           yc              the estimated y position of the extracted emitter
%           T               the estimated intensity of the extracted emitter
%           f               the frame ID of the extracted emitter
%
% By Hongqiang Ma @ PITT July 2018
% Modificated by Wen Xiao @SZU 2019
%------------------------------------------------------------------------------------
if(~isempty(IDs))
num = length(IDs);
RegR = 3;
GraR = 2;
[m,n] = meshgrid(0.5-GraR:GraR-0.5,0.5-GraR:GraR-0.5,zeros(num,1));

% define the exact gradient at each position
Gx = (x0-m);
Gy = (y0-n);
G = sqrt(Gx.^2 + Gy.^2);
G(G<0.00000000001) = 0.00000000001;

% caculate the measured gradients
xID = RegR-GraR:RegR+GraR-1;
yID = xID;
gx = ROI(yID,xID+3,:)+ 2*ROI(yID+1,xID+3,:)+ 2*ROI(yID+2,xID+3,:)+ ROI(yID+3,xID+3,:)...
    -ROI(yID,xID,:)  - 2*ROI(yID+1,xID,:)  - 2*ROI(yID+2,xID,:)  - ROI(yID+3,xID,:);

gy = ROI(yID+3,xID,:)  + 2*ROI(yID+3,xID+1,:)  + 2*ROI(yID+3,xID+2,:)  + ROI(yID+3,xID+3,:)...
    -ROI(yID,xID,:)- 2*ROI(yID,xID+1,:)- 2*ROI(yID,xID+2,:)- ROI(yID,xID+3,:);

ROI3 = ROI + ROIsub;
wa = (ROI(yID+1,xID+1,:) + ROI(yID+1,xID+2,:) + ROI(yID+2,xID+1,:) + ROI(yID+2,xID+2,:));
wb = (ROI3(yID+1,xID+1,:) + ROI3(yID+1,xID+2,:) + ROI3(yID+2,xID+1,:) + ROI3(yID+2,xID+2,:));
W  = wa./wb;
W = (W).^2;

a1 = sum(sum(W.*gy.*gy./G));
b1 = -sum(sum(W.*gx.*gy./G));
c1 = sum(sum(W.*(n.*gx.*gy-m.*gy.*gy)./G));

a2 = -b1;
b2 = -sum(sum(W.*gx.*gx./G));
c2 = sum(sum(W.*(n.*gx.*gx-m.*gx.*gy)./G));

R = (a2.*b1-a1.*b2);
R(R<0.00000000001) = 0.00000000001;

x = (b2.*c1-b1.*c2)./R;
y = (a1.*c2-a2.*c1)./R;

xc = reshape(x,num,1) + IDs(:,2);
yc = reshape(y,num,1) + IDs(:,1);
T = reshape(sum(sum(ROI)),num,1);
f = IDs(:,5);
else
    xc=[];
    yc=[];
    T=[];
    f=[];
end