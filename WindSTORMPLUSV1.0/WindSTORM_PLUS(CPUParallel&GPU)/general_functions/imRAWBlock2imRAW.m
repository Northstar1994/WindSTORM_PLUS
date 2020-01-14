function imRAW = imRAWBlock2imRAW(imRAWBlock)
%---------------------------------------------
%
%---------------------------------------------
[imH,imW,imF,seg] = size(imRAWBlock);
imRAW = single(zeros(imH,imW,imF*seg));
for i=1:seg
    imRAW(:,:,100*(i-1)+1:i*100) = imRAWBlock(:,:,:,i);
end
end