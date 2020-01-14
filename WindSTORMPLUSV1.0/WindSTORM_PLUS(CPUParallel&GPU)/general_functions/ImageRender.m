function ImageRender(result,imRW,imRH,imW,imH)
% ------------------------------------------------------------------------------------
% 显示重建图像效果
% 
% By Wen Xiao @SZU
%------------------------------------------------------------------------------------
imSR = zeros((imH)*5,(imW)*5);
Xc = result(:,3);
Yc = result(:,4);
for n=1:length(result)
    if (Xc(n)<imH) && (Yc(n)<imW) && (Xc(n)>1) && (Yc(n)>1) 
        imSR(round(Yc(n)*5),round(Xc(n)*5)) = imSR(round(Yc(n)*5),round(Xc(n)*5)) +1;
    end
end
imSR = filter2(ones(3,3)/9,imSR);

figure('name','Super Resolution Image Simulation')
imSSR = imSR(1:imRH*5,1:imRW*5);
clims = [0 0.4];
imagesc(imSSR,clims)
axis image, axis off
colormap(gray), colorbar;
end