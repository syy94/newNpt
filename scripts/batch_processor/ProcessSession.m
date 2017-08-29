function ProcessSession(varargin)
%ProcessSession		Process session data
%	ProcessSession(ARG1,ARG2,...) performs the calculations specified 
%	by the arguments ARG1, ARG2, etc., or all the calculations if there
%	are no arguments. This function should be called from the directory
%	containing all the data from one session. The arguments can be of the
%	following:
%		'eye'			Peforms calculations on only the eye signals.
%		'extraction'	Performs spike extraction on unit signals. If
%		                extraction is redone then the FD folder is deleted.
%                       By default, the extraction algorithm looks only for 
%                       local minima, although this behavior can be
%                       modified using the 'PositiveOnly' and
%                       'NegativePositive' options described below.
%		'highpass'		High-pass filters broadband signals only.
%       'highpasslow'   Highpass Low Cutoff Frequency.  Default is 500.
%       'highpasshigh'  Highpass High Cutoff Frequency.  Default is 10000.
%		'redo'			Performs the relevant calculations regardless of
%						of whether the calculations have already been 
%						performed.
%		'lowpass'		Low-pass filters broadband signals only. This
%						this calculation is not performed unless explicitly
%						requested.
%       'lowpasslow'    Lowpass Low Cutoff Frequency.  Default is 1.
%       'lowpasshigh'   Lowpass High Cutoff Frequency.  Default is 200.
%       'timing'        Checks the duration of the first control trigger
%                       if the Control trigger channel was acquired. Saves
%                       the onset of the Presenter triggers if that channel
%                       was acquired. Saves the datapoints corresponding to
%                       vertical syncs if Presenter's vertical sync channel
%                       was acquired. This option is not performed by
%                       default.
%       'threshold'     Uses the number of standard deviations passed in
%                       after this argument during the extraction process.
%                       6 standard deviations is the default.
%       'sort_algo'     Uses the automatic spike sorting algorithm passed in
%                       following this argument.  Either 'none' , 'BB' or 'KK'.
%                       'KK' is the default.
%       'clustoptions'  Optional input arguments for RunClustBatch.
%                       (e.g. ProcessSession('clustoptions',{'Do_AutoClust',
%                       'no'}).
%       'groups'        Performs processes only on groups passed in.  ie.
%                       'groups',[2 5] would only do processing on groups 2
%                       and 5. Group numbers are the order of the groups in
%                       the descriptor file and not the actual group number.
%       'PositiveOnly'  Extracts waveforms by looking for local maxima.
%       'NegativePositive' Extracts waveforms by looking first for local
%                          minima and then local maxima.
%
%       Alternately, some arguments can be passed in as:
%       ['argument type' 'Value'], 'Value'
%       redo, extraction, eye, highpass, lowpass, timing, have this
%       functionality.  ie. 'redoValue','1' is the same as 'redo'.
%
%	Dependencies: nptDir, nptFileParts, nptPWD, nptReadStreamerFile,
%		nptGaussianConv, nptEyeCalibAnalysis, nptWriteStreamerFile,
%		nptLowPassFilter, nptHighPassFilter, ChannelIndex, ExtractorWrapper,
%		nptTetrodeExtractor, nptWriteDat, ReadDescriptor, GroupSignals.

%argument to select what data type to process
eyeflag=0;
extractionflag=0;
lowpassflag=0;
highpassflag=0;
timingflag=0;
threshold_flag=0;
SNR_flag=0;
chunksize_flag=0;
groups_flag=0;
sort_algo='KK';
single_flag=0;
% variable used to check if we are to extract from a broadband signal that has 
% been high-pass filtered already
extracthighpass=0;
% variable used to store the directory path to the session directory
% used mainly for broadband signals which have highpass subdirectories
dirprefix = '';
clustoptions = {};

% default value for variable so we can skip extraction if there are no
% relevant signals 
sumX = [];

if ~isempty(varargin) 
    num_args = nargin;
    
    redo=0;
    for i=1:num_args
        if(ischar(varargin{i}))
            switch varargin{i}
                case('eye')
                    eyeflag=1;
                case('eyeValue')
                    eyeflag = varargin{i+1};
                case('extraction')
                    extractionflag=1;
                case('extractionValue')
                    extractionflag = varargin{i+1};
                case('lowpass')
                    lowpassflag=1;
                case('lowpassValue')
                    lowpassflag = varargin{i+1};  
                case('lowpasslow')
                    lowpasslow = varargin{i+1};
                case('lowpasshigh')
                    lowpasshigh = varargin{i+1};  
                case('highpass')
                    highpassflag=1;
                case('highpassValue')
                    highpassflag = varargin{i+1};
                case('highpasslow')
                    highpasslow = varargin{i+1}; 
                case('highpasshigh')
                    highpasshigh = varargin{i+1};  
                case('timing')
                    timingflag = 1;
                case('timingValue')
                    timingflag = varargin{i+1};
                case('redo')% if passed redo argument, ignore the marker file
                    % processedsession.txt
                    redo=1;
                case('redoValue')
                    redo = varargin{i+1};
                case('threshold')
                    threshold_flag=1;
                    extract_sigma=varargin{i+1};
                    %extractionflag=1;
                case('SNRExtractionCutoff')
                    SNRExtractionCutoff = varargin{i+1};
                    if ~isempty(SNRExtractionCutoff) & ~isspace(SNRExtractionCutoff)
                        SNR_flag=1;
                    else
                        SNRExtractionCutoff=0;
                    end
                case('SNRSortCutoff')
                    SNRSortCutoff = varargin{i+1};
                    if ~isempty(SNRSortCutoff) & ~isspace(SNRSortCutoff)
                        SNR_flag=1;
                    else
                        SNRSortCutoff=0;
                    end
                case('chunkSize')
                    chunkSize = varargin{i+1};
                    if ~isempty(chunkSize) && ~isspace(chunkSize)
                        chunksize_flag=1;
                    end
                case('sort_algo')
                    sort_algo=varargin{i+1};
                case('clustoptions')
                    clustoptions = varargin{i+1};
                case ('groups')
                    groups=varargin{i+1};
                    if ~isempty(groups) && ~isspace(groups)
                        groups_flag=1;
                        extractionflag=1;
                    end
            end % switch
        end % if(ischar)
    end  
    %check if redo was the only argument, in which case
    %we need to redo everything
    if redo==1 & num_args==1
        eyeflag=1;
        extractionflag=1;
        lowpassflag=1;
        highpassflag=1;
    end
else % if ~isempty(varargin) & ~isempty(varargin{1})
    eyeflag=1;
    extractionflag=1;
    lowpassflag=1;
    highpassflag=1;
    redo=0;
end % if ~isempty(varargin) & ~isempty(varargin{1})

% should we skip this session
marker = nptDir('skip.txt');
% check for processedsession.txt unless redo is 1
if redo==0
    marker=[marker nptDir('processedsession.txt')];
end

if isempty(marker)
    % [path,sessionname] = nptFileParts(nptPWD);
    % seslist = nptDir([ '*' sessionname '_descriptor.txt'],'CaseInsensitive');  
    seslist = nptDir('*_descriptor.txt','CaseInsensitive');
    % make sure seslist not 0, e.g. when we are using a fake
    % calibration session
    if size(seslist,1)~=0
        sessionname = seslist(1).name(1:end-15);
        fprintf('\t\tPROCESSING SESSION %s ...\n',sessionname);
        
        %%%%%%	Get Descriptor Info	%%%%%
        % descriptor = nptDir('*_descriptor.txt');
        % descriptor_info = ReadDescriptor(descriptor.name);
        descriptor_info = ReadDescriptor(seslist.name);
        neurongroup_info=GroupSignals(descriptor_info);
        if groups_flag==0
            groups = 1:size(neurongroup_info,2);
        end
        
        %if  ((strcmp(descriptor_info.description{i},'vertical1')) & (strcmp(descriptor_info.state{i},'Active'))) 
        ini = nptDir('*.ini','CaseInsensitive');
        inisize = size(ini,1);
        for j = 1:inisize
            if isempty(findstr(ini(j).name,'_rfs'))
                isCalib=IsEyeCalib(ini(j).name);
                if isCalib==1
                    init_info = ReadIniFileWrapper(ini(j).name); 
                else
                    fprintf('Not Eye Calibration!\n')
                end
                break;
            end
        end        
        
        for i = 1:descriptor_info.number_of_channels
            if ((strcmp(descriptor_info.description{i},'broadband')) & (strcmp(descriptor_info.state{i},'Active'))) 
                % check if there are broadband signals in this session which have been 
                % high-passed filtered that we just want to run the extraction on.
                if highpassflag==0 & extractionflag==1
                    extracthighpass = 1;         
                end
            end
        end
        
        if extractionflag & redo    %feature files need to be recalculated
            if isdir('sort')
                cd('sort')
                if isdir('FD')
                    cd('FD')
                    delete('*.fd')
                    cd ..
                end
                cd ..
            end
            
        end
        
        
        durations=[];
        num_spikes=[];
        tmeans=[];
        thresholds=[];
        trigDurations=[];
        presTrigOnsets=[];
        syncOnsets=[];
        smSyncs=[];
        % If extracthighpass, we want to get the high-passed data from the 
        % highpass directory instead
        if extracthighpass==1
            % need to cd into directory because dirlist will return only the list
            % of filenames instead of prefixing the filenames with the highpass 
            % directory if we do dir(['highpass' filesep '*_highpass.0*'])
            cd('highpass');
            dirlist = [nptDir('*_highpass.0*'); nptDir('*_highpass.1*')];
            highpassfilename = [sessionname '_highpass'];
            dirprefix = ['..' filesep];
            % read sorter header to get chunckSize
            hdrfilename = nptDir(['..' filesep 'sort' filesep '*.hdr'],'CaseInsensitive');
            [max_duration,min_duration, trials,waves,rawfile,fs,channels, ...
                means,thresholds,numChunks,chunkSize] = nptReadSorterHdr(hdrfilename.name);
        else	
            cdir = nptPWD;
            cdirl = size(cdir,2);
            dirlist = [nptDir(['*' cdir(cdirl-1:cdirl) '.0*']); nptDir(['*' cdir(cdirl-1:cdirl) '.1*'])];
            if isempty(dirlist) 
                
                single_flag = 1;
                binfile = [sessionname '.bin'];
                dtype = DaqType(binfile);
                if strcmp(dtype,'Streamer')
                    [num_channels,sampling_rate,scan_order]=nptReadStreamerFileHeader(binfile);
                    headersize = 73;
                    if chunksize_flag
                        chunkSize = chunkSize*sampling_rate;
                    else
                        chunkSize=500000;       %chunkSize has units of datapoints.
                    end
                elseif strcmp(dtype,'UEI')
                    data = ReadUEIFile('FileName',binfile,'Header');
                    sampling_rate = data.samplingRate;
                    num_channels = data.numChannels;
                    headersize = 90;
                    if chunksize_flag
                        chunkSize = chunkSize*sampling_rate;
                    else
                        chunkSize = 15000;       %chunkSize has units of datapoints.
                    end
                else 
                    error('unknown file type')
                end
                b = nptDir(binfile);
                chunkSize = (ceil(chunkSize/sampling_rate))*sampling_rate; %round up to the nearest second in datapoint units.
                num_trials = ceil((b.bytes-headersize)/2/num_channels/chunkSize);
                numChunks = num_trials;
                fprintf('Single data .bin file\nBreaking %s into %i chunks of %i datapoints each\n',binfile,num_trials,chunkSize);
                dirlist = [1:num_trials]';
            end
        end
        
        if(timingflag==1)
            % get list of sync files
            smdirlist = nptDir([dirprefix '*.snc0*']);
        end
        
        
        
        trials = size(dirlist,1);
        if timingflag==1
            smtrials = size(smdirlist,1);
            if (smtrials~=0) && (smtrials~=trials)
                fprintf('\t\tWarning: Number of sync monitor files do not match number of trial files!\n');
                fprintf('\t\tWarning: Skipping analysis of sync monitor files!\n');
                smtrials = 0;
            end
        end
        
        % initialize data in case we don't enter the loop
        eyedata=[];
        broadband=[];
        lowpass=[];
        uunit=[];
        unit=[];
        eyescanorder=[];
        lowpassscanorder=[];
        broadbandscanorder=[];
        
        % use shortcut or operator so we don't have to check everything if
        % one is true
        if eyeflag || extractionflag || lowpassflag || highpassflag || timingflag
            for i = 1:trials			%loop on trials
                % clear data before processing next trials
                eyedata=[];
                broadband=[];
                lowpass=[];
                uunit=[];
                unit=[];
                eyescanorder=[];
                lowpassscanorder=[];
                broadbandscanorder=[];
                
                if single_flag
                    Binsize = [(i-1)*chunkSize+1 chunkSize*i];
                    if strcmp(dtype,'Streamer')
                        [data,num_channels,sampling_rate,scan_order] = nptReadStreamerFileChunk(binfile,Binsize);
                    elseif strcmp(dtype,'UEI')
                        data = ReadUEIFile('FileName',binfile,'Samples',Binsize,'Units','MilliVolts');
                        sampling_rate = data.samplingRate;
                        num_channels = data.numChannels;
                        data = data.rawdata;
                    end
                    fprintf('\t\tReading in datachunk: %i  binsize: %i  channels: %i\n',i,chunkSize,num_channels); 
                else
                    [path filename ext] = nptFileParts(dirlist(i).name);
                    trialname = ext(2:length(ext));
                    [data,num_channels,sampling_rate,scan_order,points] = nptReadStreamerFile(dirlist(i).name);
                    fprintf('\t\tReading in datafile: %s  channels: %i\n',dirlist(i).name,num_channels); 
                    if (points==0)
                        % print warning
                        fprintf('Warning: %s is empty!\n',dirlist(i).name);
                        % check if empty trial is the last trial present
                        if(i~=trials)
                            % create skip.txt and break out of loop
                            sfid = fopen([dirprefix 'skip.txt'],'wt');
                            return;
                        end
                        % remove this trial from trials 
                        trials = i - 1;
                        % create file to indicate that the last file is incomplete
                        incfid = fopen('emptylasttrial.txt','wt');
                        fclose(incfid);
                        % break out of loop
                        break;
                    end
                end
                % get sampling_rate in ms since that is used more often
                srms = sampling_rate/1000;
                
                % check to see if we are supposed to be extracting from high-pass filtered data
                if extracthighpass==1
                    % just put the data in unit since presumably we have checked the
                    % Active/Inactive state before
                    uunit=data;
                else
                    for j=1:num_channels
                        des = sprintf('%s',descriptor_info.description{j});
                        switch des
                            case ('vertical1')
                                if strcmp(descriptor_info.state{j},'Active')  & eyeflag==1 
                                    eyedata(1,:)=data(j,:);
                                    eyescanorder = [eyescanorder; descriptor_info.channel(j)];
                                end
                            case('horizontal1')
                                if strcmp(descriptor_info.state{j},'Active') & eyeflag==1  
                                    eyedata(2,:)=data(j,:);
                                    eyescanorder = [eyescanorder; descriptor_info.channel(j)];
                                end
                            case{'lfp','lowpass'}			%lfp is an outdated description but still used for backcompatibility.
                                if strcmp(descriptor_info.state{j},'Active') & lowpassflag==1
                                    lowpass = [lowpass ; data(j,:)];
                                    lowpassscanorder = [lowpassscanorder; descriptor_info.channel(j)];
                                end
                            case('broadband')
                                if strcmp(descriptor_info.state{j},'Active') & highpassflag==1 
                                    broadband = [broadband ; data(j,:)];
                                    broadbandscanorder = [broadbandscanorder; descriptor_info.channel(j)];
                                end
                                if strcmp(descriptor_info.state{j},'Active') & lowpassflag==1 
                                    lowpass = [lowpass ; data(j,:)];
                                    lowpassscanorder = [lowpassscanorder; descriptor_info.channel(j)];
                                end
                            case {'electrode','highpass','tetrode'}		%electrode and tetrode are outdated descriptions but still used for backcompatibility.
                                if strcmp(descriptor_info.state{j},'Active') & extractionflag==1
                                    uunit=[uunit ; data(j,:)];
                                end
                                if strcmp(descriptor_info.state{j},'Active') & lowpassflag==1 
                                    lowpass = [lowpass ; data(j,:)];
                                    lowpassscanorder = [lowpassscanorder; descriptor_info.channel(j)];
                                end
                            case ('trigger')
                                if timingflag==1
                                    fprintf('extracting trigger duration/');
                                    tdur = nptThresholdCrossings(data(j,:),2500,'falling');
                                    if length(tdur)>1
                                        % print warning
                                        fprintf('Warning: Trigger falls below threshold more than once!\n');
                                    end
                                    % column 1 in trigDurations is in data points and
                                    % column 2 is in ms so subtract 1 from data point
                                    % since data point 1 is 0 ms.
                                    % trigDurations = [trigDurations; tdur(1) (tdur(1)-1)/srms];
                                    trigDurations = [trigDurations; tdur(1)];
                                end
                            case ('pres_trig')
                                if timingflag==1
                                    fprintf('extracting Presenter trigger onsets/');
                                    presTrigOnsets = concatenate(presTrigOnsets,nptThresholdCrossings(data(j,:),2500,'rising'),0,'DiscardEmptyA');
                                end
                            case ('pres_sync')
                                if timingflag==1
                                    fprintf('extracting sync onsets/');
                                    syncOnsets = concatenate(syncOnsets,nptThresholdCrossings(data(j,:),2500,'rising'),0,'DiscardEmptyA');
                                end
                        end % switch des
                    end % for j=1:num_channels
                end % if extracthighpass==1
                
                % if processing timing, gets syncs from sync monitor file
                if (timingflag==1) & (smtrials~=0)
                    fprintf('reading sync monitor file/');
                    syncs = nptReadSyncsFile([dirprefix smdirlist(i).name]);
                    % need to transpose syncs before concatenating since it is a column vector
                    % pad with -1 since sync points can't be negative
                    smSyncs = concatenate(smSyncs,syncs',-1,'DiscardEmptyA');
                end
                
                % indent twice since this is usually called by ProcessDay, which is called by 
                % ProcessDays
                % fprintf('\t\t');
                if ~isempty(eyedata)
                    if isCalib
                        fprintf('creating calibration dxy matrix/');
                        [eyefilt , resample_rate, G, sigma, SamplesPerMS] = nptGaussianConv(eyedata,sampling_rate);
                        [eyefilt,number_spikes] = nptRemoveNoiseSpike(eyefilt,resample_rate);
                        fprintf(['Removing ' num2str(number_spikes) ' Artifacts/']);
                        dxy.meanVH(1:2,i) = nptEyeCalibAnalysis(eyefilt , G , sigma, SamplesPerMS);
                    end
                    %process all eye signals including calibration sessions
                    fprintf('subsampling eye/');
                    if ~isCalib
                        [eyefilt , resample_rate, G, sigma, SamplesPerMS] = nptGaussianConv(eyedata,sampling_rate);
                        [eyefilt,number_spikes] = nptRemoveNoiseSpike(eyefilt,resample_rate);
                        fprintf(['Removing ' num2str(number_spikes) ' Artifacts/']);
                    end
                    eyefiltfilename = [filename '_eyefilt.' trialname];
                    status=nptWriteDataFile(eyefiltfilename , resample_rate , eyefilt);
                end
                
                if ~isempty(lowpass)
                    fprintf('lowpass filtering/');
                    if ~exist('lowpasslow','var')
                        lowpasslow = 1;
                    end
                    if ~exist('lowpasshigh','var')
                        lowpasshigh = 200;
                    end
                    [lfp , resample_rate] = nptLowPassFilter(lowpass,sampling_rate,lowpasslow,lowpasshigh);
                    if single_flag
                        lfpfilename = [binfile(1:end-4) '_lfp.' num2strpad(i,4)];
                    else
                        lfpfilename = [filename '_lfp.' trialname];
                    end
                    nptWriteStreamerFile(lfpfilename , resample_rate , lfp , lowpassscanorder);
                end
                
                if ~isempty(broadband)
                    fprintf('highpass filtering broadband/');
                    if ~exist('highpasslow','var')
                        highpasslow = 500;
                    end
                    if ~exist('highpasshigh','var')
                        highpasshigh = 10000;
                    end
                    broadband = nptHighPassFilter(broadband,sampling_rate,highpasslow,highpasshigh); 
                    
                    if single_flag
                        highpassfilename = [binfile(1:end-4) '_highpass.' num2strpad(i,4)];
                    else
                        highpassfilename = [filename '_highpass.' trialname];
                    end
                    
                    nptWriteStreamerFile(highpassfilename,sampling_rate,broadband,broadbandscanorder);
                    
                    %now combine broadband and uunit while maintaining channel sequence order
                    if ~isempty(uunit) 
                        [unitindex bbindex] = ChannelIndex (descriptor_info);
                        ucounter=0;
                        bbcounter=0;
                        for k=1:num_channels
                            a=find(unitindex == k);
                            if ~isempty(a)
                                ucounter=ucounter+1;
                                unit=[unit ; uunit(ucounter,:)];
                            end
                            a=find(bbindex == k);
                            if ~isempty(a)
                                bbcounter=bbcounter+1;
                                unit = [unit ; broadband(bbcounter,:)];
                            end
                        end   
                    else 
                        unit=[unit ; broadband];
                    end
                else 
                    unit=uunit;
                    clear uunit;
                end
                
                if ~isempty(unit)
                    if threshold_flag==0
                        extract_sigma=6;
                    end
                    if SNR_flag
                        fprintf('calculating extraction threshold and SNR/');
                        [SNR(:,i),noiseSTD(:,i)] = CalcSNRandThreshold(unit,neurongroup_info,groups);
                    else
                        fprintf('unit extracting/');
                        [sumX(:,:,i), sumX2(:,:,i), n(:,i)] = extractionThreshold(unit,neurongroup_info,extract_sigma,groups);
                    end
                end
                
                fprintf('\n');
                clear data;
            end	%loops over trials
        end %if any flags are checked
        clear unit;
        
        
                
        %%%%%%%%%%%%% EXTRACTION %%%%%%%%%%%%%        
        
        if( extractionflag )%& ~isempty(ExtractThreshold) )
            if SNR_flag
                %average noiseSTD and SNR across all trials
                SNR = mean(SNR,2);
                tt = extract_sigma * mean(noiseSTD,2);
                %remove groups that have small SNR.
                for ii=groups
                    ch = neurongroup_info(ii).channels;
                    threshold(ii,:) = tt(ch);  %change form to [group x channel]
                    if sum(SNR(ch) < SNRExtractionCutoff)
                        groups = setxor(groups,ii);
                    end
                end
                tmean = zeros(size(threshold));    %assume mean was zero after highpass filtering.
            else %do it the original way
                [tmean,stdev]  = calcSTD(sumX, sumX2, n);
            end

            %append extracted waveforms after each trial
            if extractionflag==1
                for i=groups
                    groupname = num2strpad(neurongroup_info(i).group,4);
                    fidt = ['fidtime' groupname];
                    timefilename = [groupname 'time.tmp'];   %just a temp file containing timestamps
                    eval([fidt '=fopen(''' dirprefix timefilename ''',''w'',''ieee-le'');'])
                    extractfilename = [sessionname 'g' groupname 'waveforms.bin'];   %a waveform temp file that is later added to end of timestamp file
                    fidw = ['fidwave' groupname];
                    eval([fidw '=fopen(''' dirprefix extractfilename ''',''w'',''ieee-le'');'])
                    eval(['fwrite(' fidw ',zeros(1,100),''int8'');'])    %100 bytes reserved for header
                end
            end
           
            
            
            for i = 1:trials			%loop on trials
                
                %unit is obtained from the data file.  If a highpass file
                %exists then we want to get it from there.  The highpass file
                %can exist in two places depending on whether it was just
                %recomputed or already exists in the highpass directory.
                %If no highpass then we need to get the data from the trial
                %file which is already highpassed.  Just need to sort out the
                %correct channels.     
                %if processing only select groups then groups is set and we
                %should use this but unit is still all groups.  The logic for
                %seperate groups is within extractorwrapper.
                
                if single_flag && ~highpassflag && strcmp(dtype,'Streamer')
                    Binsize = [(i-1)*chunkSize+1 chunkSize*i];
                    [ p filename ext] = fileparts(binfile);
                    [data,num_channels,sampling_rate,scan_order] = nptReadStreamerFileChunk(binfile,Binsize);
                    fprintf('\t\tReading in datachunk: %i  chunkSize: %i  channels: %i\t',i,chunkSize,num_channels); 
                elseif extracthighpass  %using old highpass files
                    % we should already be in the highpass directory so
                    % just read the files from the current directory
                    [path filename ext] = nptFileParts(dirlist(i).name);
                    trialname = ext(2:length(ext));
                    [unit,num_channels,sampling_rate,scan_order,points] = nptReadStreamerFile(dirlist(i).name);
                    fprintf('\t\tReading in datafile: %s  channels: %i\t',dirlist(i).name,num_channels); 
                elseif highpassflag %using newly created highpass files
                    dirlist = [nptDir('*_highpass.0*'); nptDir('*_highpass.1*')];
                    [path filename ext] = nptFileParts(dirlist(i).name);
                    trialname = ext(2:length(ext));
                    [unit,num_channels,sampling_rate,scan_order,points] = nptReadStreamerFile(dirlist(i).name);
                    fprintf('\t\tReading in datafile: %s  channels: %i\t',dirlist(i).name,num_channels); 
                else [path filename ext] = nptFileParts(dirlist(i).name);
                    trialname = ext(2:length(ext));
                    [data,num_channels,sampling_rate,scan_order,points] = nptReadStreamerFile(dirlist(i).name);
                    fprintf('\t\tReading in datafile: %s  channels: %i\t',dirlist(i).name,num_channels); 
                end
                                
                if (~extracthighpass) && (~highpassflag) 
                    unit = [];
                    for j=1:num_channels
                        des = sprintf('%s',descriptor_info.description{j});
                        switch des
                            case {'electrode','highpass','tetrode'}		%electrode and tetrode are outdated descriptions but still used for backcompatibility.
                                if strcmp(descriptor_info.state{j},'Active') & extractionflag==1
                                    unit=[unit ; data(j,:)];
                                end
                        end % switch des
                    end % for j=1:num_channels
                end % if extracthighpass==1
                             
                if SNR_flag
                    [unit_extracted,duration] = ExtractorWrapper2(unit,neurongroup_info,sampling_rate,tmean,threshold,groups);
                else
                    [unit_extracted,duration,threshold] = ExtractorWrapper(unit,descriptor_info,neurongroup_info,sampling_rate,tmean,stdev,groups,extract_sigma,varargin{:});
                end
               
                %append unit_extracted to dat file immediately
                spikes_per_trial=[];
                for group = groups
                    groupname = num2strpad(neurongroup_info(group).group,4);
                    fid = ['fidtime' groupname];
                    eval(['fwrite(' fid ',unit_extracted(group).times,''uint64'');'])
                    fid=['fidwave' groupname];
                    eval(['fwrite(' fid ',transpose(unit_extracted(group).waveforms),''int16'');'])
                    spikes_per_trial(group) = size(unit_extracted(group).times,1);
                end
                num_spikes = [num_spikes spikes_per_trial'];
                durations = [durations duration];
                if size(tmean,2)==1 %electrode
                    tmeans = [tmean zeros(size(tmean,1),3)];
                    thresholds = [threshold zeros(size(threshold,1),3)];
                elseif size(tmean,2)==2 %stereotrode
                    tmeans = [tmean zeros(size(neurongroup_info,2),2)];
                    thresholds = [threshold zeros(size(neurongroup_info,2),2)];
                elseif size(tmean,2)==4 %tetrode   
                    tmeans = tmean;
                    thresholds = threshold;
                elseif size(tmean,2)>4 %polytrode
                    tmeans = tmean;
                    thresholds = threshold;
                end
                for gr=groups
                    extract_info.group(gr).trial(i).means = tmeans(gr,:);
                    extract_info.group(gr).trial(i).thresholds = thresholds(gr,:);
                end
                fprintf('\n');
            end%for i = 1:trials
        end%if extractionflag
        
        
        % if we were extracting from high-pass filtered data, we have to go back
        % up to the root session directory
        if extracthighpass==1
            cd ..
        end
        
        % save timing data
        if timingflag==1
            % get presTrigOnsets and syncOnsets in ms. Do this here
            % since we know the sampling rate.
            presTrigOnsetsMS = (presTrigOnsets-1)/srms;
            syncOnsetsMS = (syncOnsets-1)/srms;
            trigDurations = [trigDurations (trigDurations-1)/srms];
            save([sessionname 'timing'],'trigDurations','presTrigOnsets','syncOnsets','smSyncs','presTrigOnsetsMS','syncOnsetsMS');
        end
        
        %write dat files
        if exist('unit_extracted')
            rawfilename = filename;
            % round duration up to the next largest integer to make sure
            % that we have a round number of an integer number of data points
            % when we convert durations back to data points
            max_duration = ceil(max(durations));
            % get min duration as well
            min_duration = min(durations);
            % get the exact duration that will be written to the header file and 
            % use that precision for all computations
            % durationstr = num2str(duration,'%6f');
            % duration = str2num(durationstr);
            
            for i=groups	%loop over groups            
                groupname = num2strpad(neurongroup_info(i).group,4);
                fidt = ['fidtime' groupname];
                timefilename = [groupname 'time.tmp'];   %just a temp file containing timestamps
                fidw = ['fidwave' groupname]; 
                extractfilename = [sessionname 'g' groupname '_waveforms.bin'];   %file inwhich timestamps are appended.           
                
                eval(['s=fclose(' fidt ');'])
                % don't need dirprefix since we would already have done cd .. if extracthighpass==1
                eval([fidt '=fopen(''' timefilename ''',''r'',''ieee-le'');'])
                eval(['time = fread(' fidt ',inf,''uint64'');'])
                eval(['s=fclose(' fidt ');'])
                delete(timefilename);   %just temp file
                time = StretchTimes(time,num_spikes(i,:),max_duration);        %add max duration to each trial
                
                %waveform file
                num_cha=length(neurongroup_info(i).channels);
                sum_spikes=sum(num_spikes(i,:));
                eval(['WriteWaveformsHeader(' fidw ',sum_spikes,num_cha);']) %add header info
                eval(['fseek(' fidw ',100+2*32*num_cha*sum_spikes,''bof'');'])
                eval(['fwrite(' fidw ',time,''uint64'');'])
                eval(['fclose(' fidw ');'])
                
                totalwaveforms=sum(num_spikes(i,:));
                % since UEI data is broken up into trials, we won't write
                % numChunks and chunkSize into the header file so that it
                % can be inspected like trial-based data. The data will be
                % recombined in adjspikes back into one long trial.
                if ( single_flag && strcmp(dtype,'Streamer') )
                    trials=1;
                    sum_max_duration = sum(durations);
                    sum_min_duration=0;
                    % write raw channel numbers if signals are not broadband
                    nptWriteSorterHdr( groupname , sampling_rate , ...
                        sum_max_duration , sum_min_duration, trials , totalwaveforms , rawfilename, ...
                        neurongroup_info(i).channels, extract_info.group(i),numChunks,chunkSize );
                    
                    % multiple trial header used with sorter1
                elseif (~isempty(broadband) || extracthighpass==1)
                    % write channel numbers if signals are broadband
                    % UEI polytrode data are written here so that the
                    % trial-based format is maintained
                    nptWriteSorterHdr( groupname , sampling_rate , ...
                        max_duration , min_duration, trials , totalwaveforms , rawfilename, ...
                        neurongroup_info(i).channels, extract_info.group(i) );
                else                  
                    % write raw channel numbers if signals are not broadband
                    nptWriteSorterHdr( groupname , sampling_rate , ...
                        max_duration , min_duration,  trials , totalwaveforms , rawfilename, ...
                        neurongroup_info(i).raw_channels, extract_info.group(i) );
                end
            end %loop over groups
            
%             if SNR_flag
%                 %do not sort groups that have small SNR.
%                 for ii=groups
%                     ch = neurongroup_info(ii).channels;
%                     if sum(SNR(ch) < SNRSortCutoff)
%                         groups = setxor(groups,ii);
%                         %write as ispikes
%                         ispikes('Group',num2strpad(ii,3),'UseSort',0)
%                         %and then remove them from RunClustBatch somehow.
%                     end
%                 end
%             end
            
            % RunClustBatch should only be run when units are extracted
            % so move this section inside the if statement checking for
            % the presence of the variable unitextracted
            sort=0;       
            %where are the waveforms.bin files?
            wavelist = nptDir('*waveforms.bin');
            if ~isempty(wavelist) 
                sort=1;
            elseif   isempty(wavelist) && isdir('sort')        
                cd('sort')
                wavelist = nptDir('*waveforms.bin');
                if ~isempty(wavelist)
                    sort=2;
                else
                    cd ..
                end
            end
            
            if(sort && ~strcmp(sort_algo,'none'))
                [hdrsz , num_spikes, num_cha, gain, ptswv] = ReadWaveformsHeader(wavelist(1).name);
                %look for KK batch file in current directory first
                batchlist = nptDir('Batch_*.txt');
                if ~isempty(batchlist)
                    p=pwd;
                else
                    p=which('RunClustBatch');
                    [p,n,e]=fileparts(p);
                end
                
                % RunClustBatch turns on diary so if diary is already on, we
                % should save the diaryname so we can turn it off now and turn
                % it back on later. This will only work if diary was turned on
                % using: diary([pwd filesep 'diary']).
                diaryname = '';
                if strcmp(get(0,'Diary'),'on')
                    diaryname = get(0,'DiaryFile');
                    diary off
                end
                
                if strcmp(sort_algo,'BB')
                    if num_cha==1
                        RunClustBatch([p filesep 'Batch_BBClustEE.txt'],clustoptions{:})
                    elseif num_cha==4
                        RunClustBatch([p filesep 'Batch_BBClust.txt'],clustoptions{:})
                    end
                end
                if strcmp(sort_algo,'KK')
                    if num_cha==1
                        RunClustBatch([p filesep 'Batch_KKwikEE.txt'],clustoptions{:})
                    elseif num_cha==4
                        RunClustBatch([p filesep 'Batch_KKwik.txt'],clustoptions{:})      
                    end
                end
                
                % turn diary back on if it was on before
                % YSC 11/17/03
                if ~isempty(diaryname)
                    diary(diaryname)
                end 
            end
            if sort==2
                cd ..
            end
        end%if exist unitextracted
        
        if ~isempty(eyedata) & isCalib
            %collate all meanVH points by their targets,
            %calculate the mean (x,y) around each target
            NumberOfPoints = init_info.GridCols * init_info.GridRows;
            dxy.avgVH = zeros(2,NumberOfPoints);
            for i=1:NumberOfPoints
                % find(init_info.StimulusSequence==(i-1));
                ind=find(init_info.StimulusSequence==(i-1));
                dxy.avgVH(:,i) = mean(dxy.meanVH(1:2,ind),2);
            end
            %write dxy file
            fid=fopen([sessionname '_dxy.bin'],'w','ieee-le');
            fwrite(fid, init_info.ScreenWidth, 'int32');
            fwrite(fid, init_info.ScreenHeight, 'int32');
            fwrite(fid, init_info.GridRows, 'int32');
            fwrite(fid, init_info.GridCols, 'int32');
            fwrite(fid, init_info.Xsize, 'int32');
            fwrite(fid, init_info.Ysize, 'int32');
            fwrite(fid, init_info.CenterX, 'int32');
            fwrite(fid, init_info.CenterY, 'int32');
            fwrite(fid, init_info.NumBlocks, 'int32');
            fwrite(fid, dxy.meanVH, 'double');
            fwrite(fid, dxy.avgVH, 'double');
            fclose(fid);
        end
        
        
        
        fprintf('\t\tDone!\n');
        %create marker file to show this session has been processed
        fid=fopen('processedsession.txt','wt');
        fclose(fid);
    end % if seslist ~= 0   
end  %is there a marker file present

