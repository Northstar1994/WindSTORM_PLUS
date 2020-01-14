function imRAW = imRAW1002imRAW(imRAW100)
%---------------------------------------------
%
%---------------------------------------------
[imH,imW,imF,seg] = size(imRAW100);
imRAW = single(zeros(imH,imW,imF*seg));
for i=1:seg
    imRAW(:,:,100*(i-1)+1:i*100) = imRAW100(:,:,:,i);
end
end