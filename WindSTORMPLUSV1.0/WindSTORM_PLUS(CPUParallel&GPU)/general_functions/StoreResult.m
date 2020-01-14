function StoreResult(result,pathname,filename,isBatch,Intensity,Sigma,Mode)
% ------------------------------------------------------------------------------------
% 数据存储结果
% [px]的csv表头文件能够倍ThunerSTORM所识别，以及进行后续训练
% By Wen Xiao @SZU
%------------------------------------------------------------------------------------
if(Mode == 1)
    modestring = 'CPUParallel';
elseif(Mode == 2)
    modestring = 'CPUGPU';
    elseif(Mode == 3)
        modestring = 'CPUBlock100';
        elseif(Mode == 4)
            modestring = 'SingleCPU';
end
if(isBatch)
    filename = char(filename);
    dhead = '"id","frame","x [px]","y [px]","intensity [photon]"';
    fid = fopen( [pathname(1:end),filename(1,1:end-4),'_',...
        num2str(Intensity),'_',...
        num2str(Sigma),'_WindSTORM_PLUS_',modestring,'.csv'], 'w' );
    fprintf( fid, '%s\n', dhead);
    fclose( fid );
    dlmwrite([pathname(1:end),filename(1,1:end-4),'_',...
        num2str(Intensity),'_',...
        num2str(Sigma),...
        '_WindSTORM_PLUS_',modestring,'.csv'],result,'-append');
else
        dhead = '"id","frame","x [px]","y [px]","intensity [photon]"';
    fid = fopen( [pathname(1:end), '\',filename(1:end-4),'_',...
        num2str(Intensity),'_',...
        num2str(Sigma),'_WindSTORM_PLUS_',modestring,'.csv'], 'w' );
    fprintf( fid, '%s\n', dhead);
    fclose( fid );
    dlmwrite([pathname(1:end), '\',filename(1:end-4),'_',...
        num2str(Intensity),'_',...
        num2str(Sigma),...
        '_WindSTORM_PLUS_',modestring,'.csv'],result,'-append');
end

end