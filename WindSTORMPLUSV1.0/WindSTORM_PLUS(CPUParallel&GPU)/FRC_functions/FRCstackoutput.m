function FRCstackoutput(results,pathname,filename,imH,imW,imRH,imRW)
zoom = 5;
imSR1 = zeros(imH*zoom,imW*zoom);
imSR2 = zeros(imH*zoom,imW*zoom);
for n=1:length(results)
    f = results(n,2);
    x = results(n,3);
    y = results(n,4);
    x= round(x*zoom);
    y= round(y*zoom);
    x(isnan(x)) = [];
    x(x==0)=[];
    y(isnan(y)) = [];
    y(y==0)=[];
    if mod(f,2)==0
        imSR1(x,y) = imSR1(x,y) + 1;
    else 
        imSR2(x,y) = imSR2(x,y) + 1;
    end
end
imwrite(uint16(imSR1(1:imRH*5,1:imRW*5)),[pathname,filename,'FRCstack.tif'])
imwrite(uint16(imSR2(1:imRH*5,1:imRW*5)),[pathname,filename,'FRCstack.tif'],'WriteMode','append')
end