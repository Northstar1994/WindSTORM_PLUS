function imRAWBlock = imRAW2imRAWBlock(imRAW,imW,imH,imF,block)
seg = floor(imF/block);
imRAWBlock = single(zeros(imH,imW,block,seg));
for i=1:seg
    imRAWBlock(:,:,:,i) = imRAW(:,:,(i-1)*block+1:i*block);
end