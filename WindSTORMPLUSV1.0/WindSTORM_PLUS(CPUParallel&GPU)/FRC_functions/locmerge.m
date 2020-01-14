clc
close all
pathname = {''};
[number,~] = size(pathname);
for i=1:number
    pa = char(pathname(i));
results = csvread(pa,1,0);
disp('reading csv file finished');
zoom = 25;
zoomresults = zeros(length(results),3);
zoomresults(:,2:3) = round(results(:,2:3)*zoom);
[~,ia,~] = unique(zoomresults(:,2:3),'row');
mergeResult= results(ia,:);
dhead = '"frame","x [px]","y [px]"';
fid = fopen( [pa(1:end-4),'merge','.csv'], 'w' );
fprintf( fid, '%s\n', dhead);
fclose( fid );
dlmwrite([pa(1:end-4),'merge','.csv'],mergeResult,'-append');
disp(['½áÊø',num2str(length(mergeResult))]);
end